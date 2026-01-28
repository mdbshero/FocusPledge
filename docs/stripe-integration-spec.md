# Stripe Integration Specification — Focus Credits Purchase

**Document purpose:** Technical specification for Stripe-based Focus Credits (FC) purchase flow with server-authoritative fulfillment, webhook idempotency, and security guardrails.

**Last updated:** January 28, 2026

---

## Overview

FocusPledge uses **Stripe** for in-app credits purchases on iOS. Credits are fulfilled server-side via Cloud Functions after payment confirmation. All balance updates are ledger-driven and idempotent.

### Key Principles

1. **Server-authoritative:** Client never writes `wallet.credits`; only server via ledger
2. **Idempotent:** Webhook replay or duplicate events never double-credit
3. **Auditable:** Every credit purchase creates an immutable ledger entry
4. **Secure:** Webhook signature verification prevents spoofing
5. **Closed-loop economy:** No cash-out, no withdrawals (App Store compliance)

---

## Credits Pack SKUs

### Reference Rate (Internal)

**100 FC = $1.00 USD**

This rate is for internal consistency. Actual pricing can include value-add margins.

### Recommended Pack Structure

| Pack ID         | Credits | USD Price | $/100 FC | Value Bonus | Target User       |
| --------------- | ------- | --------- | -------- | ----------- | ----------------- |
| `starter_pack`  | 500 FC  | $5.99     | $1.20    | 20% premium | First-time buyers |
| `standard_pack` | 1000 FC | $9.99     | $1.00    | At-rate     | Regular users     |
| `value_pack`    | 2500 FC | $19.99    | $0.80    | 20% bonus   | Engaged users     |
| `premium_pack`  | 5000 FC | $34.99    | $0.70    | 30% bonus   | Power users       |

**Pricing notes:**

- Starter pack has a premium to offset transaction fees + onboarding costs
- Value/Premium packs offer bonus credits (psychological anchor for retention)
- All packs are **non-consumable in-app purchase framing** but fulfilled as credits balance

### SKU Metadata (Stripe Product)

Each pack is a Stripe Product with:

- `product_id`: e.g., `focus_credits_1000`
- `metadata.pack_id`: `standard_pack`
- `metadata.credits_amount`: `1000`
- `metadata.currency`: `usd`
- Pricing: Stripe Price object linked to Product

---

## Purchase Flow Architecture

### High-Level Flow

```
[iOS Client] → createCreditsPurchaseIntent() → [Cloud Function]
                                                     ↓
                                              Stripe API: create PaymentIntent
                                                     ↓
[iOS Client] ← client_secret ← [Cloud Function]
     ↓
[iOS Client presents Stripe Payment Sheet]
     ↓
User completes payment → Stripe processes → Webhook fires
                                                     ↓
                                    [Cloud Function: handleStripeWebhook]
                                                     ↓
                                    Verify signature + idempotency
                                                     ↓
                                    Post ledger entry: credits_purchase
                                                     ↓
                                    Update users.wallet.credits (atomic)
                                                     ↓
[iOS Client polls or listens] → sees updated balance
```

### Components

1. **Client SDK:** Stripe iOS SDK (PaymentSheet)
2. **Cloud Function (callable):** `createCreditsPurchaseIntent(packId, idempotencyKey)`
3. **Cloud Function (webhook):** `handleStripeWebhook(event)` via HTTPS endpoint
4. **Firestore collections:**
   - `ledger/{entryId}` — immutable credit purchase records
   - `stripeEvents/{eventId}` — processed event IDs for idempotency
   - `users/{uid}.wallet.credits` — materialized balance

---

## Cloud Function 1: `createCreditsPurchaseIntent()`

### Signature (Callable Function)

```typescript
export const createCreditsPurchaseIntent = functions.https.onCall(
  async (data: CreatePurchaseIntentRequest, context: CallableContext) => {
    // Implementation
  },
);
```

### Request Schema

```typescript
interface CreatePurchaseIntentRequest {
  packId: string; // e.g., "standard_pack"
  idempotencyKey: string; // client-generated UUID for request deduplication
}
```

### Validations (Server-Side)

1. **Authentication:** `context.auth.uid` must exist (user signed in)
2. **Pack exists:** `packId` maps to valid SKU in config/database
3. **Idempotency:** Check if a PaymentIntent already exists for this `userId + idempotencyKey`
   - If exists, return cached `client_secret`
   - Prevents duplicate PaymentIntents for same purchase attempt

### Logic

1. Fetch pack metadata from Firestore or hardcoded config:

   ```typescript
   const packs = {
     starter_pack: { credits: 500, priceUsd: 599 },
     standard_pack: { credits: 1000, priceUsd: 999 },
     value_pack: { credits: 2500, priceUsd: 1999 },
     premium_pack: { credits: 5000, priceUsd: 3499 },
   };
   ```

2. Check idempotency:

   ```typescript
   const existingIntent = await db
     .collection("paymentIntents")
     .where("userId", "==", userId)
     .where("idempotencyKey", "==", idempotencyKey)
     .limit(1)
     .get();

   if (!existingIntent.empty) {
     return { client_secret: existingIntent.docs[0].data().client_secret };
   }
   ```

3. Create Stripe PaymentIntent:

   ```typescript
   const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

   const paymentIntent = await stripe.paymentIntents.create({
     amount: pack.priceUsd, // in cents
     currency: "usd",
     metadata: {
       userId,
       packId,
       creditsAmount: pack.credits.toString(),
       idempotencyKey,
     },
     automatic_payment_methods: { enabled: true },
   });
   ```

4. Store pending purchase record:

   ```typescript
   await db.collection("paymentIntents").doc(paymentIntent.id).set({
     paymentIntentId: paymentIntent.id,
     userId,
     packId,
     creditsAmount: pack.credits,
     priceUsd: pack.priceUsd,
     idempotencyKey,
     status: "pending",
     createdAt: admin.firestore.FieldValue.serverTimestamp(),
   });
   ```

5. Return client secret:
   ```typescript
   return { client_secret: paymentIntent.client_secret };
   ```

### Response Schema

```typescript
interface CreatePurchaseIntentResponse {
  client_secret: string;
}
```

### Error Handling

- Invalid `packId` → `invalid-argument`
- Missing `idempotencyKey` → `invalid-argument`
- Unauthenticated → `unauthenticated`
- Stripe API errors → `internal` with sanitized message (do not leak API keys)

---

## Cloud Function 2: `handleStripeWebhook()`

### Signature (HTTPS Endpoint)

```typescript
export const handleStripeWebhook = functions.https.onRequest(
  async (req: Request, res: Response) => {
    // Implementation
  },
);
```

### Webhook Events to Handle

Primary event: `payment_intent.succeeded`

Optional (for monitoring):

- `payment_intent.payment_failed`
- `payment_intent.canceled`

### Security: Signature Verification

```typescript
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

const sig = req.headers["stripe-signature"] as string;
let event: Stripe.Event;

try {
  event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
} catch (err) {
  console.error("Webhook signature verification failed:", err.message);
  res.status(400).send(`Webhook Error: ${err.message}`);
  return;
}
```

**Critical:** Always verify signature before processing. Prevents spoofed webhooks from granting free credits.

### Idempotency Strategy

#### Primary Key: Stripe Event ID

Each Stripe event has a unique `event.id` (e.g., `evt_1AbC2dEfGhIjKlMn`). Store processed event IDs:

```typescript
const eventId = event.id;
const eventRef = db.collection("stripeEvents").doc(eventId);

const eventSnap = await eventRef.get();
if (eventSnap.exists) {
  console.log(`Event ${eventId} already processed. Returning 200.`);
  res.status(200).send({ received: true });
  return;
}
```

#### Secondary Key: PaymentIntent ID + User ID

For `payment_intent.succeeded`, also check if ledger entry exists:

```typescript
const paymentIntentId = event.data.object.id;
const ledgerQuery = await db
  .collection("ledger")
  .where("metadata.paymentIntentId", "==", paymentIntentId)
  .limit(1)
  .get();

if (!ledgerQuery.empty) {
  console.log(
    `Ledger entry for PaymentIntent ${paymentIntentId} exists. Skipping.`,
  );
  res.status(200).send({ received: true });
  return;
}
```

**Why two checks?**

- Event ID check: fast path for exact replay
- PaymentIntent check: defense against event ID spoofing or duplicate processing via different events

### Fulfillment Logic (payment_intent.succeeded)

```typescript
const paymentIntent = event.data.object as Stripe.PaymentIntent;
const userId = paymentIntent.metadata.userId;
const creditsAmount = Number(paymentIntent.metadata.creditsAmount);
const packId = paymentIntent.metadata.packId;
const idempotencyKey = paymentIntent.metadata.idempotencyKey;

await db.runTransaction(async (tx) => {
  // 1. Mark event as processed
  tx.set(eventRef, {
    eventId,
    type: event.type,
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    paymentIntentId: paymentIntent.id,
    userId,
  });

  // 2. Post ledger entry
  const ledgerRef = db.collection("ledger").doc();
  tx.set(ledgerRef, {
    entryId: ledgerRef.id,
    kind: "credits_purchase",
    userId,
    amount: creditsAmount,
    metadata: {
      paymentIntentId: paymentIntent.id,
      packId,
      priceUsd: paymentIntent.amount,
      currency: paymentIntent.currency,
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    idempotencyKey,
  });

  // 3. Update materialized balance
  const userRef = db.collection("users").doc(userId);
  tx.set(
    userRef,
    {
      wallet: {
        credits: admin.firestore.FieldValue.increment(creditsAmount),
        lifetimePurchased: admin.firestore.FieldValue.increment(creditsAmount),
      },
    },
    { merge: true },
  );

  // 4. Update paymentIntent record status
  const intentRef = db.collection("paymentIntents").doc(paymentIntent.id);
  tx.update(intentRef, {
    status: "succeeded",
    fulfilledAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});

console.log(`Fulfilled ${creditsAmount} credits for user ${userId}`);
res.status(200).send({ received: true });
```

### Webhook Response Rules

- **Always return 200** if event was successfully processed or already processed
- Return **400** if signature verification fails
- Return **500** only if processing failed and Stripe should retry

Stripe will retry failed webhooks (non-200 responses) for up to 3 days.

---

## Firestore Collections

### `paymentIntents/{paymentIntentId}`

Purpose: Track pending/completed purchases client-initiated.

Schema:

```typescript
{
  paymentIntentId: string;
  userId: string;
  packId: string;
  creditsAmount: number;
  priceUsd: number;
  idempotencyKey: string;
  status: 'pending' | 'succeeded' | 'failed' | 'canceled';
  createdAt: Timestamp;
  fulfilledAt?: Timestamp;
}
```

### `stripeEvents/{eventId}`

Purpose: Idempotency store for processed webhook events.

Schema:

```typescript
{
  eventId: string; // Stripe event.id
  type: string; // e.g., "payment_intent.succeeded"
  processedAt: Timestamp;
  paymentIntentId: string;
  userId: string;
}
```

Index: `eventId` (document ID, auto-indexed)

### `ledger/{entryId}`

Purpose: Immutable record of all credit transactions (see main spec).

Relevant entry for purchases:

```typescript
{
  entryId: string;
  kind: "credits_purchase";
  userId: string;
  amount: number; // credits amount
  metadata: {
    paymentIntentId: string;
    packId: string;
    priceUsd: number;
    currency: string;
  }
  createdAt: Timestamp;
  idempotencyKey: string;
}
```

---

## Client Integration (iOS)

### 1. Install Stripe SDK

```swift
// Podfile or SPM
pod 'Stripe'
```

### 2. Purchase Flow

```swift
import Stripe

func purchaseCredits(packId: String) async throws {
  // 1. Call Cloud Function to get client_secret
  let callable = Functions.functions().httpsCallable("createCreditsPurchaseIntent")
  let result = try await callable.call([
    "packId": packId,
    "idempotencyKey": UUID().uuidString
  ])

  let clientSecret = result.data["client_secret"] as! String

  // 2. Present Stripe Payment Sheet
  var configuration = PaymentSheet.Configuration()
  configuration.merchantDisplayName = "FocusPledge"
  configuration.allowsDelayedPaymentMethods = false

  let paymentSheet = PaymentSheet(
    paymentIntentClientSecret: clientSecret,
    configuration: configuration
  )

  let result = try await paymentSheet.present(from: viewController)

  switch result {
  case .completed:
    print("Payment succeeded! Credits will be added shortly.")
    // Poll Firestore or wait for listener to detect balance update
  case .canceled:
    print("Payment canceled by user")
  case .failed(let error):
    print("Payment failed: \(error.localizedDescription)")
  }
}
```

### 3. Listen for Balance Updates

```swift
// Firestore listener on users/{uid}
db.collection("users").document(userId).addSnapshotListener { snapshot, error in
  guard let data = snapshot?.data(),
        let credits = data["wallet"]?["credits"] as? Int else { return }

  // Update UI
  self.creditsLabel.text = "\(credits) FC"
}
```

---

## Security Considerations

### 1. Webhook Signature Verification

- ✅ Always verify `stripe-signature` header before processing
- ✅ Use environment variable for webhook secret (never hardcode)
- ✅ Return 400 for invalid signatures (prevents spoofing)

### 2. Idempotency Enforcement

- ✅ Check `stripeEvents/{eventId}` before processing
- ✅ Check `ledger` for existing `paymentIntentId` as secondary defense
- ✅ Use Firestore transactions to ensure atomic writes

### 3. Metadata Validation

- ✅ Validate `userId` in PaymentIntent metadata matches authenticated user (if possible)
- ✅ Verify `creditsAmount` matches expected pack configuration
- ✅ Reject if metadata is missing or malformed

### 4. Rate Limiting (Future)

- Consider rate-limiting `createCreditsPurchaseIntent()` to prevent abuse
- Stripe has built-in fraud detection; rely on it initially

### 5. Secrets Management

- ✅ Store Stripe keys as Firebase secrets:
  ```bash
  firebase functions:secrets:set STRIPE_SECRET_KEY
  firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
  ```
- ✅ Never log or expose secrets in responses

---

## Testing Strategy

### Test Mode (Development)

1. Use Stripe **test mode** keys
2. Test webhook locally with Stripe CLI:
   ```bash
   stripe listen --forward-to http://localhost:5001/PROJECT_ID/us-central1/handleStripeWebhook
   ```
3. Trigger test events:
   ```bash
   stripe trigger payment_intent.succeeded
   ```

### Test Cases

| Test Case                                | Expected Outcome                            |
| ---------------------------------------- | ------------------------------------------- |
| Valid purchase → webhook succeeds        | Ledger entry created, balance updated       |
| Replay webhook (same event ID)           | Returns 200, no duplicate credit            |
| Replay webhook (same PaymentIntent ID)   | Returns 200, no duplicate credit            |
| Invalid signature                        | Returns 400, no processing                  |
| Malformed metadata                       | Returns 200, logged error, no fulfillment   |
| Concurrent webhooks (same PaymentIntent) | Only one creates ledger entry (transaction) |

### Production Cutover

1. Switch to Stripe **production keys**
2. Update webhook endpoint URL in Stripe Dashboard
3. Monitor webhook delivery logs in Stripe Dashboard
4. Set up alerting for webhook failures (>5% failure rate)

---

## Monitoring & Observability

### Key Metrics

1. **Purchase success rate:** `payment_intent.succeeded / payment_intent.created`
2. **Fulfillment latency:** time from webhook receipt to balance update
3. **Webhook replay rate:** `stripeEvents` already-processed hits per hour
4. **Failed webhooks:** track non-200 responses

### Logging (Cloud Functions)

```typescript
console.log("[STRIPE] Purchase fulfilled", {
  userId,
  creditsAmount,
  paymentIntentId,
  packId,
  timestamp: Date.now(),
});
```

### Alerting Rules

- Webhook signature verification failure rate > 1%
- Webhook processing errors > 5%
- Fulfillment transaction failures > 0.1%

---

## Error Scenarios & Recovery

### Scenario 1: Webhook Never Arrives

**Cause:** Network issue, Stripe outage, misconfigured endpoint

**Detection:** User reports payment succeeded but no credits

**Recovery:**

1. Check Stripe Dashboard → Webhooks → Recent Events
2. Manually replay event from Dashboard
3. If event was never sent, query PaymentIntent by ID and manually fulfill:
   ```typescript
   const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
   // Manually call fulfillment logic
   ```

### Scenario 2: Transaction Fails Midway

**Cause:** Firestore timeout, conflict, quota exceeded

**Detection:** Webhook returns 500, Stripe retries

**Recovery:**

- Stripe will automatically retry for 3 days
- If retries exhausted, manually replay event

### Scenario 3: Double-Credit Bug

**Cause:** Idempotency check bypassed, logic error

**Detection:** User balance higher than expected, duplicate ledger entries

**Recovery:**

1. Identify duplicate ledger entries (same `paymentIntentId`)
2. Post corrective `admin_correction` ledger entry (negative amount)
3. Update materialized balance via reconciliation job

---

## Configuration Checklist

### Development Environment

- [ ] Stripe test mode account created
- [ ] Test API keys added to Firebase secrets
- [ ] Webhook endpoint deployed and URL added to Stripe Dashboard (test mode)
- [ ] Stripe CLI installed for local webhook testing

### Production Environment

- [ ] Stripe production account verified (business details submitted)
- [ ] Production API keys added to Firebase secrets
- [ ] Webhook endpoint URL added to Stripe Dashboard (production mode)
- [ ] Webhook secret generated and stored as Firebase secret
- [ ] Alerting configured for webhook failures
- [ ] Packs configured as Stripe Products/Prices

---

## Open Questions & Future Enhancements

1. **Promotional codes / discounts?**
   - Stripe supports coupon codes natively
   - Could pass `promotion_code` in PaymentIntent metadata

2. **Apple In-App Purchase (IAP) compliance?**
   - Current design uses Stripe (web payments, not IAP)
   - Verify App Store guidelines: digital goods via IAP vs credits via web
   - May need to switch to IAP for App Store approval (TBD)

3. **Refunds?**
   - Stripe supports refunds via API
   - Would need `credits_refund_reversal` ledger entry to deduct credits
   - Requires policy: refund window (e.g., 14 days), abuse prevention

4. **Subscription packs?**
   - Stripe supports recurring payments
   - Could offer "monthly credits bundle" with auto-renewal

---

## Summary

This spec defines a **secure, idempotent, auditable** Stripe integration for Focus Credits purchases. Key guarantees:

✅ **Server-authoritative:** No client-side balance manipulation  
✅ **Idempotent:** Webhooks can be replayed safely  
✅ **Auditable:** Every credit has an immutable ledger entry  
✅ **Secure:** Signature verification prevents spoofing  
✅ **Testable:** Full test mode workflow with Stripe CLI

Implementation can proceed with confidence that the design is robust and compliant with FocusPledge's security-first principles.

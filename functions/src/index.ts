import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

if (!admin.apps.length) admin.initializeApp();
import reconcileIncremental from './reconcile/incrementalReconcile';
const db = admin.firestore();

// Initialize Stripe (will use process.env.STRIPE_SECRET_KEY from Firebase secrets)
// In test environment, use a dummy key if not provided
const stripeKey = process.env.STRIPE_SECRET_KEY || 'sk_test_dummy_key_for_tests';
const stripe = new Stripe(stripeKey, {
  apiVersion: '2026-01-28.clover',
});

type Resolution = 'SUCCESS' | 'FAILURE';

export async function handleResolveSession(data: any, context: any) {
  const sessionId: string = data?.sessionId;
  const resolution: Resolution = data?.resolution;
  const idempotencyKey: string = data?.idempotencyKey;
  const reason: string | undefined = data?.reason;

  if (!sessionId || !resolution || !idempotencyKey) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  const sessionRef = db.collection('sessions').doc(sessionId);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(sessionRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Session not found');
    }

    const session = snap.data() as any;
    const currentSettlementKey = session?.settlement?.idempotencyKey;

    if (currentSettlementKey === idempotencyKey) {
      return { status: 'already_settled', resolution: session.settlement.resolution };
    }

    if (currentSettlementKey && currentSettlementKey !== idempotencyKey) {
      throw new functions.https.HttpsError('failed-precondition', 'Session already settled with different idempotency key');
    }

    if (session.status !== 'ACTIVE') {
      if (session.settlement?.idempotencyKey) {
        return { status: 'already_settled', resolution: session.settlement.resolution };
      }
      throw new functions.https.HttpsError('failed-precondition', 'Session not active');
    }

    const userId = session.userId as string;
    const pledgedAmount = session.pledgeAmount || 0;
    const sessionType = session.type || 'PLEDGE';
    const now = admin.firestore.FieldValue.serverTimestamp();
    const userRef = db.collection('users').doc(userId);

    // =========================================================================
    // REDEMPTION SESSION RESOLUTION
    // =========================================================================
    if (sessionType === 'REDEMPTION') {
      if (resolution === 'SUCCESS') {
        // Redemption success: rescue Frozen Votes, convert Ash → Obsidian, clear deadline
        const userSnap = await tx.get(userRef);
        const userData = userSnap.exists ? userSnap.data() as any : {};
        const currentAsh = userData?.wallet?.ash || 0;
        const currentPurgatoryVotes = userData?.wallet?.purgatoryVotes || 0;

        // Ledger: frozen_votes_rescue
        if (currentPurgatoryVotes > 0) {
          const rescueRef = db.collection('ledger').doc();
          tx.set(rescueRef, {
            entryId: rescueRef.id,
            kind: 'frozen_votes_rescue',
            userId,
            amount: currentPurgatoryVotes,
            metadata: { sessionId },
            createdAt: now,
            idempotencyKey,
          });
        }

        // Ledger: ash_to_obsidian_conversion
        if (currentAsh > 0) {
          const conversionRef = db.collection('ledger').doc();
          tx.set(conversionRef, {
            entryId: conversionRef.id,
            kind: 'ash_to_obsidian_conversion',
            userId,
            amount: currentAsh,
            metadata: { sessionId, ashConverted: currentAsh, obsidianGranted: currentAsh },
            createdAt: now,
            idempotencyKey,
          });
        }

        // Update wallet: zero out purgatoryVotes and ash, add obsidian, clear deadline
        tx.set(userRef, {
          wallet: {
            purgatoryVotes: 0,
            ash: 0,
            obsidian: admin.firestore.FieldValue.increment(currentAsh),
          },
          deadlines: { redemptionExpiry: admin.firestore.FieldValue.delete() },
        }, { merge: true } as any);

        tx.update(sessionRef, {
          status: 'COMPLETED',
          'settlement.resolvedAt': now,
          'settlement.resolution': 'SUCCESS',
          'settlement.idempotencyKey': idempotencyKey,
          'settlement.votesRescued': currentPurgatoryVotes,
          'settlement.ashConverted': currentAsh,
          'settlement.obsidianGranted': currentAsh,
        });

        return {
          status: 'settled',
          resolution: 'SUCCESS',
          votesRescued: currentPurgatoryVotes,
          ashConverted: currentAsh,
          obsidianGranted: currentAsh,
        };
      }

      // REDEMPTION FAILURE: Frozen Votes are lost permanently, ash remains
      const userSnap = await tx.get(userRef);
      const userData = userSnap.exists ? userSnap.data() as any : {};
      const lostVotes = userData?.wallet?.purgatoryVotes || 0;

      // Ledger: frozen_votes_burn (permanent loss)
      if (lostVotes > 0) {
        const burnRef = db.collection('ledger').doc();
        tx.set(burnRef, {
          entryId: burnRef.id,
          kind: 'frozen_votes_burn',
          userId,
          amount: lostVotes,
          metadata: { sessionId, reason },
          createdAt: now,
          idempotencyKey,
        });
      }

      // Update wallet: zero out purgatoryVotes, clear deadline
      tx.set(userRef, {
        wallet: { purgatoryVotes: 0 },
        deadlines: { redemptionExpiry: admin.firestore.FieldValue.delete() },
      }, { merge: true } as any);

      tx.update(sessionRef, {
        status: 'FAILED',
        'settlement.resolvedAt': now,
        'settlement.resolution': 'FAILURE',
        'settlement.idempotencyKey': idempotencyKey,
        'settlement.votesLost': lostVotes,
      });

      return { status: 'settled', resolution: 'FAILURE', votesLost: lostVotes };
    }

    // =========================================================================
    // PLEDGE SESSION RESOLUTION (existing logic)
    // =========================================================================
    if (resolution === 'SUCCESS') {
      const ledgerRef = db.collection('ledger').doc();
      tx.set(ledgerRef, {
        entryId: ledgerRef.id,
        kind: 'credits_refund',
        userId,
        amount: pledgedAmount,
        metadata: { sessionId },
        createdAt: now,
        idempotencyKey,
      });

      tx.update(sessionRef, {
        status: 'COMPLETED',
        'settlement.resolvedAt': now,
        'settlement.resolution': 'SUCCESS',
        'settlement.idempotencyKey': idempotencyKey,
      });

      return { status: 'settled', resolution: 'SUCCESS' };
    }

    // FAILURE branch
    const burnRef = db.collection('ledger').doc();
    tx.set(burnRef, {
      entryId: burnRef.id,
      kind: 'credits_burn',
      userId,
      amount: pledgedAmount,
      metadata: { sessionId, reason },
      createdAt: now,
      idempotencyKey,
    });

    const ashRef = db.collection('ledger').doc();
    const ashAmount = pledgedAmount; // policy: 1:1 for now
    tx.set(ashRef, {
      entryId: ashRef.id,
      kind: 'ash_grant',
      userId,
      amount: ashAmount,
      metadata: { sessionId },
      createdAt: now,
      idempotencyKey,
    });

    const redemptionExpiry = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000));
    
    // Update user: set redemption deadline, increment purgatoryVotes (Frozen Votes) and ash
    tx.set(userRef, {
      deadlines: { redemptionExpiry },
      wallet: {
        purgatoryVotes: admin.firestore.FieldValue.increment(pledgedAmount),
        ash: admin.firestore.FieldValue.increment(ashAmount),
      }
    }, { merge: true } as any);

    tx.update(sessionRef, {
      status: 'FAILED',
      'settlement.resolvedAt': now,
      'settlement.resolution': 'FAILURE',
      'settlement.idempotencyKey': idempotencyKey,
    });

    return { status: 'settled', resolution: 'FAILURE' };
  });
}

export const resolveSession = functions.https.onCall(handleResolveSession);

// ============================================================================
// SHOP PURCHASE
// ============================================================================

/**
 * Purchase a shop item with Obsidian currency
 * Validates item exists, user has enough Obsidian, and hasn't already purchased the item
 */
export async function handlePurchaseShopItem(data: any, context: any) {
  const userId: string = data?.userId;
  const itemId: string = data?.itemId;
  const idempotencyKey: string = data?.idempotencyKey;

  if (!userId || !itemId || !idempotencyKey) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: userId, itemId, idempotencyKey');
  }

  return db.runTransaction(async (tx) => {
    // Idempotency check
    const existingPurchase = await db.collection('shop').doc('purchases').collection('records')
      .where('userId', '==', userId)
      .where('itemId', '==', itemId)
      .limit(1)
      .get();

    if (!existingPurchase.empty) {
      return { status: 'already_purchased', purchaseId: existingPurchase.docs[0].id };
    }

    // Fetch the item from catalog
    const itemRef = db.collection('shop').doc('catalog').collection('items').doc(itemId);
    const itemSnap = await tx.get(itemRef);

    if (!itemSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Item not found in catalog');
    }

    const item = itemSnap.data() as any;
    if (!item.isAvailable) {
      throw new functions.https.HttpsError('failed-precondition', 'Item is not currently available');
    }

    const price = item.price || 0;

    // Fetch user wallet
    const userRef = db.collection('users').doc(userId);
    const userSnap = await tx.get(userRef);
    const userData = userSnap.exists ? userSnap.data() as any : {};
    const currentObsidian = userData?.wallet?.obsidian || 0;

    if (currentObsidian < price) {
      throw new functions.https.HttpsError('failed-precondition', `Insufficient Obsidian. Need ${price}, have ${currentObsidian}`);
    }

    // Deduct obsidian
    tx.set(userRef, {
      wallet: { obsidian: admin.firestore.FieldValue.increment(-price) }
    }, { merge: true } as any);

    // Record purchase
    const purchaseRef = db.collection('shop').doc('purchases').collection('records').doc();
    tx.set(purchaseRef, {
      purchaseId: purchaseRef.id,
      userId,
      itemId,
      itemName: item.name || '',
      pricePaid: price,
      purchasedAt: admin.firestore.FieldValue.serverTimestamp(),
      idempotencyKey,
    });

    // Ledger entry
    const ledgerRef = db.collection('ledger').doc();
    tx.set(ledgerRef, {
      entryId: ledgerRef.id,
      kind: 'obsidian_spend',
      userId,
      amount: price,
      metadata: { itemId, itemName: item.name, purchaseId: purchaseRef.id },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      idempotencyKey,
    });

    return { status: 'purchased', purchaseId: purchaseRef.id, itemName: item.name, pricePaid: price };
  });
}

export const purchaseShopItem = functions.https.onCall(handlePurchaseShopItem);

export async function handleStartSession(data: any, context: any) {
  const userId: string = data?.userId;
  const pledgeAmount: number = data?.pledgeAmount ?? 0;
  const durationMinutes: number = data?.durationMinutes || 60;
  const idempotencyKey: string = data?.idempotencyKey;
  const sessionType: string = data?.type || 'PLEDGE';

  if (!userId || !idempotencyKey) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  if (sessionType !== 'PLEDGE' && sessionType !== 'REDEMPTION') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid session type. Must be PLEDGE or REDEMPTION');
  }

  if (sessionType === 'PLEDGE' && !pledgeAmount) {
    throw new functions.https.HttpsError('invalid-argument', 'pledgeAmount required for PLEDGE sessions');
  }

  const sessionsRef = db.collection('sessions');
  const sessionId = `${userId}_${Date.now()}`;
  const sessionRef = sessionsRef.doc(sessionId);

  return db.runTransaction(async (tx) => {
    // Idempotency: ensure no existing session with same idempotencyKey for this user
    const q = await db.collection('sessions').where('userId', '==', userId).where('idempotencyKey', '==', idempotencyKey).limit(1).get();
    if (!q.empty) {
      return { status: 'already_started', sessionId: q.docs[0].id };
    }

    const userRef = db.collection('users').doc(userId);
    const userSnap = await tx.get(userRef);

    if (sessionType === 'REDEMPTION') {
      // Validate: user must have an active redemption window
      const userData = userSnap.exists ? userSnap.data() : null;
      const redemptionExpiry = userData?.deadlines?.redemptionExpiry;

      if (!redemptionExpiry) {
        throw new functions.https.HttpsError('failed-precondition', 'No active redemption window');
      }

      const expiryDate = redemptionExpiry.toDate ? redemptionExpiry.toDate() : new Date(redemptionExpiry);
      if (expiryDate < new Date()) {
        throw new functions.https.HttpsError('failed-precondition', 'Redemption window has expired');
      }

      // Validate: user must have purgatoryVotes > 0
      const purgatoryVotes = userData?.wallet?.purgatoryVotes || 0;
      if (purgatoryVotes <= 0) {
        throw new functions.https.HttpsError('failed-precondition', 'No Frozen Votes to redeem');
      }

      // No credits are locked for redemption sessions
      tx.set(sessionRef, {
        sessionId,
        userId,
        type: 'REDEMPTION',
        status: 'ACTIVE',
        pledgeAmount: 0,
        durationMinutes,
        startTime: admin.firestore.FieldValue.serverTimestamp(),
        native: {},
        settlement: {},
        idempotencyKey,
      });

      return { status: 'started', sessionId };
    }

    // PLEDGE session flow (existing logic)
    const ledgerRef = db.collection('ledger').doc();

    // Compute derived balance by aggregating ledger entries for the user.
    // If no ledger entries exist, fall back to the stored `users.wallet.credits` value.
    const ledgerSnap = await tx.get(db.collection('ledger').where('userId', '==', userId));
    let derivedCredits = 0;
    ledgerSnap.docs.forEach(d => {
      const e: any = d.data();
      const amt = Number(e.amount || 0);
      if (e.kind === 'credits_purchase' || e.kind === 'credits_refund') derivedCredits += amt;
      if (e.kind === 'credits_burn' || e.kind === 'credits_lock') derivedCredits -= amt;
    });

    const reportedCredits = userSnap.exists ? (userSnap.data()?.wallet?.credits || 0) : 0;

    if (ledgerSnap.empty) {
      derivedCredits = reportedCredits;
    }

    if (derivedCredits < pledgeAmount) {
      throw new functions.https.HttpsError('failed-precondition', 'Insufficient credits');
    }

    // Atomically decrement the user's stored wallet balance to prevent races
    const newCredits = derivedCredits - pledgeAmount;
    tx.set(userRef, { wallet: { credits: newCredits } }, { merge: true } as any);

    // Lock credits via ledger entry
    tx.set(ledgerRef, {
      entryId: ledgerRef.id,
      kind: 'credits_lock',
      userId,
      amount: pledgeAmount,
      metadata: { sessionId },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      idempotencyKey,
    });

    tx.set(sessionRef, {
      sessionId,
      userId,
      type: 'PLEDGE',
      status: 'ACTIVE',
      pledgeAmount,
      durationMinutes,
      startTime: admin.firestore.FieldValue.serverTimestamp(),
      native: {},
      settlement: {},
      idempotencyKey,
    });

    return { status: 'started', sessionId };
  });
}

export const startSession = functions.https.onCall(handleStartSession);

export async function handleHeartbeatSession(data: any, context: any) {
  const sessionId: string = data?.sessionId;
  if (!sessionId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing sessionId');
  }
  const sessionRef = db.collection('sessions').doc(sessionId);
  await sessionRef.update({ 'native.lastCheckedAt': admin.firestore.FieldValue.serverTimestamp() });
  return { status: 'ok' };
}

export const heartbeatSession = functions.https.onCall(handleHeartbeatSession);

// Reconciliation: aggregate ledger entries per user and materialize `users.wallet.credits`.
export async function handleReconcileAllUsers(data: any, context: any) {
  const ledgerSnap = await db.collection('ledger').get();
  const sums = new Map<string, number>();
  ledgerSnap.docs.forEach(d => {
    const e: any = d.data();
    const userId = e.userId;
    if (!userId) return;
    const amt = Number(e.amount || 0);
    let cur = sums.get(userId) || 0;
    if (e.kind === 'credits_purchase' || e.kind === 'credits_refund') cur += amt;
    if (e.kind === 'credits_burn' || e.kind === 'credits_lock') cur -= amt;
    sums.set(userId, cur);
  });

  const batch = db.batch();
  for (const [userId, credits] of sums.entries()) {
    const userRef = db.collection('users').doc(userId);
    batch.set(userRef, { wallet: { credits } }, { merge: true } as any);
  }

  if (sums.size > 0) await batch.commit();
  return { reconciledUsers: sums.size };
}

// Scheduled wrapper (runs in production every 5 minutes)
export const reconcileAllUsers = functions.pubsub.schedule('every 5 minutes').onRun(handleReconcileAllUsers as any);

// Incremental reconcile scheduled wrapper (runs every 15 minutes)
export async function handleReconcileIncremental(data: any, context: any) {
  const result = await reconcileIncremental(db, { pageSize: 500 })
  return result
}

export const reconcileIncrementalScheduled = functions.pubsub.schedule('every 15 minutes').onRun(handleReconcileIncremental as any);

// ============================================================================
// SCHEDULED SESSION EXPIRY JOB
// ============================================================================

/**
 * Finds sessions with stale heartbeats and auto-resolves them as FAILURE
 * Runs every 5 minutes to catch sessions that should have ended but haven't been resolved
 */
export async function handleExpireStaleSessions(data: any, context: any) {
  const now = Date.now();
  const graceMinutes = 10; // Grace period after expected session end
  const cutoffTime = admin.firestore.Timestamp.fromMillis(now - graceMinutes * 60 * 1000);

  console.log(`Checking for stale sessions with lastCheckedAt < ${cutoffTime.toDate().toISOString()}`);

  // Find ACTIVE sessions with stale heartbeat
  const staleSessionsSnap = await db
    .collection('sessions')
    .where('status', '==', 'ACTIVE')
    .where('native.lastCheckedAt', '<', cutoffTime)
    .limit(50) // Process in batches
    .get();

  if (staleSessionsSnap.empty) {
    console.log('No stale sessions found');
    return { processed: 0 };
  }

  console.log(`Found ${staleSessionsSnap.size} stale sessions to resolve`);

  let resolved = 0;
  let failed = 0;

  // Process each stale session
  for (const doc of staleSessionsSnap.docs) {
    const session = doc.data();
    const sessionId = session.sessionId;
    const idempotencyKey = `auto_expire_${sessionId}_${now}`;

    try {
      // Call resolveSession to mark as FAILURE
      await handleResolveSession({
        sessionId,
        resolution: 'FAILURE',
        idempotencyKey,
        reason: 'no_heartbeat',
      }, {});

      console.log(`Auto-resolved stale session: ${sessionId}`);
      resolved++;
    } catch (err: any) {
      console.error(`Failed to auto-resolve session ${sessionId}:`, err.message);
      failed++;
    }
  }

  console.log(`Expiry job complete: ${resolved} resolved, ${failed} failed`);
  return { processed: staleSessionsSnap.size, resolved, failed };
}

export const expireStaleSessionsScheduled = functions.pubsub.schedule('every 5 minutes').onRun(handleExpireStaleSessions as any);

// ============================================================================
// STRIPE INTEGRATION
// ============================================================================

// Credit packs configuration
const CREDIT_PACKS: Record<string, { credits: number; priceUsd: number }> = {
  starter_pack: { credits: 500, priceUsd: 599 },
  standard_pack: { credits: 1000, priceUsd: 999 },
  value_pack: { credits: 2500, priceUsd: 1999 },
  premium_pack: { credits: 5000, priceUsd: 3499 },
};

/**
 * Creates a Stripe PaymentIntent for purchasing credits
 * Callable function: called from iOS client when user initiates purchase
 */
export async function handleCreateCreditsPurchaseIntent(data: any, context: any) {
  const packId: string = data?.packId;
  const idempotencyKey: string = data?.idempotencyKey;

  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be signed in');
  }

  if (!packId || !idempotencyKey) {
    throw new functions.https.HttpsError('invalid-argument', 'packId and idempotencyKey are required');
  }

  const pack = CREDIT_PACKS[packId];
  if (!pack) {
    throw new functions.https.HttpsError('invalid-argument', `Invalid packId: ${packId}`);
  }

  const userId = context.auth.uid;

  // Check for existing PaymentIntent with this idempotencyKey (client retry protection)
  const existingIntent = await db
    .collection('paymentIntents')
    .where('userId', '==', userId)
    .where('idempotencyKey', '==', idempotencyKey)
    .limit(1)
    .get();

  if (!existingIntent.empty) {
    const existing = existingIntent.docs[0].data();
    console.log(`Returning cached PaymentIntent for idempotencyKey=${idempotencyKey}`);
    return { client_secret: existing.client_secret };
  }

  // Create new Stripe PaymentIntent
  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: pack.priceUsd,
      currency: 'usd',
      metadata: {
        userId,
        packId,
        creditsAmount: pack.credits.toString(),
        idempotencyKey,
      },
      automatic_payment_methods: { enabled: true },
    });

    // Store pending purchase record
    await db.collection('paymentIntents').doc(paymentIntent.id).set({
      paymentIntentId: paymentIntent.id,
      userId,
      packId,
      creditsAmount: pack.credits,
      priceUsd: pack.priceUsd,
      idempotencyKey,
      status: 'pending',
      client_secret: paymentIntent.client_secret,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Created PaymentIntent ${paymentIntent.id} for user ${userId}, pack ${packId}`);
    return { client_secret: paymentIntent.client_secret };
  } catch (err: any) {
    console.error('Failed to create PaymentIntent:', err);
    throw new functions.https.HttpsError('internal', 'Failed to create payment intent');
  }
}

export const createCreditsPurchaseIntent = functions.https.onCall(handleCreateCreditsPurchaseIntent);

/**
 * Webhook handler for Stripe events
 * Verifies signature and processes payment_intent.succeeded events
 */
export const handleStripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'] as string;
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!webhookSecret) {
    console.error('STRIPE_WEBHOOK_SECRET not configured');
    res.status(500).send('Webhook secret not configured');
    return;
  }

  let event: Stripe.Event;

  try {
    // Verify webhook signature
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err: any) {
    console.error('Webhook signature verification failed:', err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  // Idempotency check: have we already processed this event?
  const eventId = event.id;
  const eventRef = db.collection('stripeEvents').doc(eventId);

  try {
    const eventSnap = await eventRef.get();
    if (eventSnap.exists) {
      console.log(`Event ${eventId} already processed. Returning 200.`);
      res.status(200).send({ received: true, status: 'already_processed' });
      return;
    }

    // Handle specific event types
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentIntentSucceeded(event, eventRef);
        break;
      
      case 'payment_intent.payment_failed':
        await handlePaymentIntentFailed(event, eventRef);
        break;
      
      case 'payment_intent.canceled':
        await handlePaymentIntentCanceled(event, eventRef);
        break;
      
      default:
        console.log(`Unhandled event type: ${event.type}`);
        // Mark as processed even if we don't handle it
        await eventRef.set({
          eventId,
          type: event.type,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          status: 'ignored',
        });
    }

    res.status(200).send({ received: true });
  } catch (error: any) {
    console.error('Error processing webhook:', error);
    res.status(500).send(`Webhook processing error: ${error.message}`);
  }
});

/**
 * Handle payment_intent.succeeded event
 * Fulfills credits purchase by posting ledger entry and updating user balance
 */
async function handlePaymentIntentSucceeded(event: Stripe.Event, eventRef: FirebaseFirestore.DocumentReference) {
  const paymentIntent = event.data.object as Stripe.PaymentIntent;
  const userId = paymentIntent.metadata.userId;
  const creditsAmount = Number(paymentIntent.metadata.creditsAmount);
  const packId = paymentIntent.metadata.packId;
  const idempotencyKey = paymentIntent.metadata.idempotencyKey || `pi_${paymentIntent.id}`;

  if (!userId || !creditsAmount || !packId) {
    console.error('Missing required metadata in PaymentIntent:', paymentIntent.metadata);
    throw new Error('Invalid PaymentIntent metadata');
  }

  // Secondary idempotency check: verify no ledger entry exists for this PaymentIntent
  const ledgerQuery = await db
    .collection('ledger')
    .where('metadata.paymentIntentId', '==', paymentIntent.id)
    .limit(1)
    .get();

  if (!ledgerQuery.empty) {
    console.log(`Ledger entry for PaymentIntent ${paymentIntent.id} already exists. Skipping fulfillment.`);
    
    // Still mark event as processed
    await eventRef.set({
      eventId: event.id,
      type: event.type,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentIntentId: paymentIntent.id,
      userId,
      status: 'already_fulfilled',
    });
    
    return;
  }

  // Fulfill purchase in a transaction
  await db.runTransaction(async (tx) => {
    // 1. Mark event as processed
    tx.set(eventRef, {
      eventId: event.id,
      type: event.type,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentIntentId: paymentIntent.id,
      userId,
      status: 'fulfilled',
    });

    // 2. Post ledger entry
    const ledgerRef = db.collection('ledger').doc();
    tx.set(ledgerRef, {
      entryId: ledgerRef.id,
      kind: 'credits_purchase',
      userId,
      amount: creditsAmount,
      metadata: {
        paymentIntentId: paymentIntent.id,
        packId,
        priceUsd: paymentIntent.amount, // in cents
        currency: paymentIntent.currency,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      idempotencyKey,
    });

    // 3. Update materialized balance
    const userRef = db.collection('users').doc(userId);
    tx.set(
      userRef,
      {
        wallet: {
          credits: admin.firestore.FieldValue.increment(creditsAmount),
          lifetimePurchased: admin.firestore.FieldValue.increment(creditsAmount),
        },
      },
      { merge: true }
    );

    // 4. Update paymentIntent record status (if exists)
    const intentRef = db.collection('paymentIntents').doc(paymentIntent.id);
    const intentSnap = await tx.get(intentRef);
    if (intentSnap.exists) {
      tx.update(intentRef, {
        status: 'succeeded',
        fulfilledAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  console.log(`Fulfilled ${creditsAmount} credits for user ${userId} (PaymentIntent: ${paymentIntent.id})`);
}

/**
 * Handle payment_intent.payment_failed event
 * Logs failure for monitoring
 */
async function handlePaymentIntentFailed(event: Stripe.Event, eventRef: FirebaseFirestore.DocumentReference) {
  const paymentIntent = event.data.object as Stripe.PaymentIntent;
  const userId = paymentIntent.metadata.userId;

  await eventRef.set({
    eventId: event.id,
    type: event.type,
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    paymentIntentId: paymentIntent.id,
    userId,
    status: 'payment_failed',
  });

  // Update paymentIntent record if exists
  const intentRef = db.collection('paymentIntents').doc(paymentIntent.id);
  const intentSnap = await intentRef.get();
  if (intentSnap.exists) {
    await intentRef.update({
      status: 'failed',
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  console.log(`Payment failed for user ${userId} (PaymentIntent: ${paymentIntent.id})`);
}

/**
 * Handle payment_intent.canceled event
 * Updates records for monitoring
 */
async function handlePaymentIntentCanceled(event: Stripe.Event, eventRef: FirebaseFirestore.DocumentReference) {
  const paymentIntent = event.data.object as Stripe.PaymentIntent;
  const userId = paymentIntent.metadata.userId;

  await eventRef.set({
    eventId: event.id,
    type: event.type,
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    paymentIntentId: paymentIntent.id,
    userId,
    status: 'canceled',
  });

  // Update paymentIntent record if exists
  const intentRef = db.collection('paymentIntents').doc(paymentIntent.id);
  const intentSnap = await intentRef.get();
  if (intentSnap.exists) {
    await intentRef.update({
      status: 'canceled',
      canceledAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  console.log(`Payment canceled for user ${userId} (PaymentIntent: ${paymentIntent.id})`);
}

export const stripeWebhook = handleStripeWebhook;

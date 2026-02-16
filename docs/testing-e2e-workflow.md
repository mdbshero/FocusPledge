# End-to-End Testing Workflow

**Date**: February 16, 2026  
**Status**: Backend ↔ Flutter integration complete; ready for manual testing

## Prerequisites

1. Firebase emulators running:
   ```bash
   cd functions
   npm run serve
   ```

2. Flutter app configured for emulator:
   ```bash
   flutter run --dart-define=USE_EMULATOR=true
   ```

## Test Scenarios

### 1. Buy Credits Flow

**Steps:**
1. Launch app → Sign in (anonymous or Apple Sign-In)
2. Navigate to "Buy Credits" screen
3. Select a credits pack (e.g., Standard Pack - 500 FC / $3.99)
4. Tap "Purchase"

**Expected Results:**
- ✅ Cloud Function `createCreditsPurchaseIntent` is called
- ✅ Returns a Stripe `clientSecret`
- ✅ Snackbar shows: "Payment intent created! Client secret: pi_..."

**Note:** Actual Stripe payment sheet requires `flutter_stripe` package (not yet integrated). For now, webhook simulation required to credit account.

**Manual webhook simulation:**
```bash
# In functions directory
npm run test -- --testNamePattern="Stripe webhook"
```

### 2. Start Pledge Session Flow

**Steps:**
1. Verify wallet has credits (from Test 1 or manual Firestore setup)
2. Navigate to "Start Pledge" screen
3. Select pledge amount (e.g., 500 FC) and duration (e.g., 60 minutes)
4. Tap "Start Session"

**Expected Results:**
- ✅ Cloud Function `handleStartSession` is called
- ✅ Ledger entry `credits_lock` created
- ✅ Session document created in Firestore with `status: ACTIVE`
- ✅ Navigate to "Active Session" screen showing countdown timer
- ✅ Wallet shows reduced available credits

### 3. Active Session Heartbeat

**Steps:**
1. Stay on Active Session screen for 30+ seconds
2. Check Firestore session document

**Expected Results:**
- ✅ `sessions/{sessionId}.native.lastCheckedAt` updates every 30 seconds
- ✅ Countdown timer ticks down smoothly

### 4. Session Success Resolution (Manual)

**Steps:**
1. Wait for session timer to reach 0:00 (or use Firestore Console to set endTime to past)
2. Manually call `handleResolveSession` with `resolution: SUCCESS`

**Firebase Console:**
```javascript
// In Firestore Console (or use Cloud Functions test UI)
// Call: handleResolveSession
{
  "sessionId": "<your-session-id>",
  "resolution": "SUCCESS",
  "idempotencyKey": "test_success_1"
}
```

**Expected Results:**
- ✅ Session status changes to `COMPLETED`
- ✅ Ledger entry `credits_refund` created
- ✅ Wallet credits restored
- ✅ Completion screen shows success message

### 5. Session Failure Resolution (Manual)

**Steps:**
1. Start a session (repeat Test 2)
2. Manually call `handleResolveSession` with `resolution: FAILURE`

**Firebase Console:**
```javascript
{
  "sessionId": "<your-session-id>",
  "resolution": "FAILURE",
  "reason": "manual_test",
  "idempotencyKey": "test_failure_1"
}
```

**Expected Results:**
- ✅ Session status changes to `FAILED`
- ✅ Ledger entries: `credits_burn` + `ash_grant`
- ✅ Wallet: credits NOT refunded, ash balance increased
- ✅ `purgatoryVotes` (Frozen Votes) increased
- ✅ `deadlines.redemptionExpiry` set to now + 24h
- ✅ Completion screen shows failure message + redemption timer

### 6. Wallet Real-time Updates

**Steps:**
1. Open wallet screen
2. Trigger balance change (buy credits, start session, resolve session)
3. Observe wallet UI

**Expected Results:**
- ✅ Wallet balances update in real-time without manual refresh
- ✅ Redemption warning appears when `redemptionExpiry` is set

## Known Limitations (as of Feb 16, 2026)

- **Stripe payment sheet**: Not yet integrated (requires `flutter_stripe` package)
- **iOS Screen Time enforcement**: Not yet connected (native bridge exists but DeviceActivity extension pending)
- **Automated session resolution**: Currently requires manual Cloud Function calls; scheduler expiry job handles stale heartbeats
- **Redemption session flow**: UI exists but backend integration pending

## Next Steps

1. Add `flutter_stripe` package and wire up payment sheet
2. Create DeviceActivity Monitor Extension (iOS native)
3. Wire native violation detection → `handleResolveSession(FAILURE)`
4. Implement redemption session support in backend
5. Add automated session resolution on timer completion

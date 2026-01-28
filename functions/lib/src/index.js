"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.stripeWebhook = exports.handleStripeWebhook = exports.reconcileIncrementalScheduled = exports.reconcileAllUsers = exports.heartbeatSession = exports.startSession = exports.resolveSession = void 0;
exports.handleResolveSession = handleResolveSession;
exports.handleStartSession = handleStartSession;
exports.handleHeartbeatSession = handleHeartbeatSession;
exports.handleReconcileAllUsers = handleReconcileAllUsers;
exports.handleReconcileIncremental = handleReconcileIncremental;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const stripe_1 = __importDefault(require("stripe"));
if (!admin.apps.length)
    admin.initializeApp();
const incrementalReconcile_1 = __importDefault(require("./reconcile/incrementalReconcile"));
const db = admin.firestore();
// Initialize Stripe (will use process.env.STRIPE_SECRET_KEY from Firebase secrets)
// In test environment, use a dummy key if not provided
const stripeKey = process.env.STRIPE_SECRET_KEY || 'sk_test_dummy_key_for_tests';
const stripe = new stripe_1.default(stripeKey, {
    apiVersion: '2026-01-28.clover',
});
async function handleResolveSession(data, context) {
    const sessionId = data?.sessionId;
    const resolution = data?.resolution;
    const idempotencyKey = data?.idempotencyKey;
    const reason = data?.reason;
    if (!sessionId || !resolution || !idempotencyKey) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    const sessionRef = db.collection('sessions').doc(sessionId);
    return db.runTransaction(async (tx) => {
        const snap = await tx.get(sessionRef);
        if (!snap.exists) {
            throw new functions.https.HttpsError('not-found', 'Session not found');
        }
        const session = snap.data();
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
        const userId = session.userId;
        const pledgedAmount = session.pledgeAmount || 0;
        const now = admin.firestore.FieldValue.serverTimestamp();
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
        const userRef = db.collection('users').doc(userId);
        const redemptionExpiry = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000));
        // Update user: set redemption deadline and increment purgatoryVotes (Frozen Votes)
        tx.set(userRef, {
            deadlines: { redemptionExpiry },
            wallet: { purgatoryVotes: admin.firestore.FieldValue.increment(pledgedAmount) }
        }, { merge: true });
        tx.update(sessionRef, {
            status: 'FAILED',
            'settlement.resolvedAt': now,
            'settlement.resolution': 'FAILURE',
            'settlement.idempotencyKey': idempotencyKey,
        });
        return { status: 'settled', resolution: 'FAILURE' };
    });
}
exports.resolveSession = functions.https.onCall(handleResolveSession);
async function handleStartSession(data, context) {
    const userId = data?.userId;
    const pledgeAmount = data?.pledgeAmount;
    const durationMinutes = data?.durationMinutes || 60;
    const idempotencyKey = data?.idempotencyKey;
    if (!userId || !pledgeAmount || !idempotencyKey) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    const sessionsRef = db.collection('sessions');
    const sessionId = `${userId}_${Date.now()}`;
    const sessionRef = sessionsRef.doc(sessionId);
    const ledgerRef = db.collection('ledger').doc();
    return db.runTransaction(async (tx) => {
        // Idempotency: ensure no existing session with same idempotencyKey for this user
        const q = await db.collection('sessions').where('userId', '==', userId).where('idempotencyKey', '==', idempotencyKey).limit(1).get();
        if (!q.empty) {
            return { status: 'already_started', sessionId: q.docs[0].id };
        }
        // Compute derived balance by aggregating ledger entries for the user.
        // If no ledger entries exist, fall back to the stored `users.wallet.credits` value.
        const ledgerSnap = await tx.get(db.collection('ledger').where('userId', '==', userId));
        let derivedCredits = 0;
        ledgerSnap.docs.forEach(d => {
            const e = d.data();
            const amt = Number(e.amount || 0);
            if (e.kind === 'credits_purchase' || e.kind === 'credits_refund')
                derivedCredits += amt;
            if (e.kind === 'credits_burn' || e.kind === 'credits_lock')
                derivedCredits -= amt;
        });
        const userRef = db.collection('users').doc(userId);
        const userSnap = await tx.get(userRef);
        const reportedCredits = userSnap.exists ? (userSnap.data()?.wallet?.credits || 0) : 0;
        if (ledgerSnap.empty) {
            derivedCredits = reportedCredits;
        }
        if (derivedCredits < pledgeAmount) {
            throw new functions.https.HttpsError('failed-precondition', 'Insufficient credits');
        }
        // Atomically decrement the user's stored wallet balance to prevent races
        const newCredits = derivedCredits - pledgeAmount;
        tx.set(userRef, { wallet: { credits: newCredits } }, { merge: true });
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
exports.startSession = functions.https.onCall(handleStartSession);
async function handleHeartbeatSession(data, context) {
    const sessionId = data?.sessionId;
    if (!sessionId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing sessionId');
    }
    const sessionRef = db.collection('sessions').doc(sessionId);
    await sessionRef.update({ 'native.lastCheckedAt': admin.firestore.FieldValue.serverTimestamp() });
    return { status: 'ok' };
}
exports.heartbeatSession = functions.https.onCall(handleHeartbeatSession);
// Reconciliation: aggregate ledger entries per user and materialize `users.wallet.credits`.
async function handleReconcileAllUsers(data, context) {
    const ledgerSnap = await db.collection('ledger').get();
    const sums = new Map();
    ledgerSnap.docs.forEach(d => {
        const e = d.data();
        const userId = e.userId;
        if (!userId)
            return;
        const amt = Number(e.amount || 0);
        let cur = sums.get(userId) || 0;
        if (e.kind === 'credits_purchase' || e.kind === 'credits_refund')
            cur += amt;
        if (e.kind === 'credits_burn' || e.kind === 'credits_lock')
            cur -= amt;
        sums.set(userId, cur);
    });
    const batch = db.batch();
    for (const [userId, credits] of sums.entries()) {
        const userRef = db.collection('users').doc(userId);
        batch.set(userRef, { wallet: { credits } }, { merge: true });
    }
    if (sums.size > 0)
        await batch.commit();
    return { reconciledUsers: sums.size };
}
// Scheduled wrapper (runs in production every 5 minutes)
exports.reconcileAllUsers = functions.pubsub.schedule('every 5 minutes').onRun(handleReconcileAllUsers);
// Incremental reconcile scheduled wrapper (runs every 15 minutes)
async function handleReconcileIncremental(data, context) {
    const result = await (0, incrementalReconcile_1.default)(db, { pageSize: 500 });
    return result;
}
exports.reconcileIncrementalScheduled = functions.pubsub.schedule('every 15 minutes').onRun(handleReconcileIncremental);
// ============================================================================
// STRIPE INTEGRATION
// ============================================================================
/**
 * Webhook handler for Stripe events
 * Verifies signature and processes payment_intent.succeeded events
 */
exports.handleStripeWebhook = functions.https.onRequest(async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!webhookSecret) {
        console.error('STRIPE_WEBHOOK_SECRET not configured');
        res.status(500).send('Webhook secret not configured');
        return;
    }
    let event;
    try {
        // Verify webhook signature
        event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
    }
    catch (err) {
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
    }
    catch (error) {
        console.error('Error processing webhook:', error);
        res.status(500).send(`Webhook processing error: ${error.message}`);
    }
});
/**
 * Handle payment_intent.succeeded event
 * Fulfills credits purchase by posting ledger entry and updating user balance
 */
async function handlePaymentIntentSucceeded(event, eventRef) {
    const paymentIntent = event.data.object;
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
        tx.set(userRef, {
            wallet: {
                credits: admin.firestore.FieldValue.increment(creditsAmount),
                lifetimePurchased: admin.firestore.FieldValue.increment(creditsAmount),
            },
        }, { merge: true });
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
async function handlePaymentIntentFailed(event, eventRef) {
    const paymentIntent = event.data.object;
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
async function handlePaymentIntentCanceled(event, eventRef) {
    const paymentIntent = event.data.object;
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
exports.stripeWebhook = exports.handleStripeWebhook;
//# sourceMappingURL=index.js.map
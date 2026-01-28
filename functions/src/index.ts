import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

if (!admin.apps.length) admin.initializeApp();
import reconcileIncremental from './reconcile/incrementalReconcile';
const db = admin.firestore();

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

export async function handleStartSession(data: any, context: any) {
  const userId: string = data?.userId;
  const pledgeAmount: number = data?.pledgeAmount;
  const durationMinutes: number = data?.durationMinutes || 60;
  const idempotencyKey: string = data?.idempotencyKey;

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
      const e: any = d.data();
      const amt = Number(e.amount || 0);
      if (e.kind === 'credits_purchase' || e.kind === 'credits_refund') derivedCredits += amt;
      if (e.kind === 'credits_burn' || e.kind === 'credits_lock') derivedCredits -= amt;
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

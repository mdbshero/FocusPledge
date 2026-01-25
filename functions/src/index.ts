import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();
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
    tx.update(userRef, { 'deadlines.redemptionExpiry': redemptionExpiry });

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

export const startSession = functions.https.onCall(async (data, context) => {
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
});

export const heartbeatSession = functions.https.onCall(async (data, context) => {
  const sessionId: string = data?.sessionId;
  if (!sessionId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing sessionId');
  }
  const sessionRef = db.collection('sessions').doc(sessionId);
  await sessionRef.update({ 'native.lastCheckedAt': admin.firestore.FieldValue.serverTimestamp() });
  return { status: 'ok' };
});

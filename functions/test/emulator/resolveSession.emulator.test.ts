// Ensure emulator environment variables for project detection are set
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-project';
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG || JSON.stringify({ projectId: process.env.GCLOUD_PROJECT });

import { expect } from 'chai';
import admin from 'firebase-admin';
import { handleResolveSession } from '../../src/index';

// These tests run under `firebase emulators:exec --only firestore` which
// provides FIRESTORE_EMULATOR_HOST and an isolated emulator instance.

const db = admin.firestore();

describe('resolveSession emulator integration', function () {
  this.timeout(10000);

  before(async () => {
    // Ensure admin app uses emulator settings from env
    // Note: index.ts already called initializeApp at import time.
  });

  afterEach(async () => {
    // Clean up collections used in tests
    // Delete all docs in sessions, users, ledger
    const colPaths = ['sessions', 'users', 'ledger'];
    for (const p of colPaths) {
      const snap = await db.collection(p).get();
      const batch = db.batch();
      snap.docs.forEach(d => batch.delete(d.ref));
      await batch.commit();
    }
  });

  it('success path: writes credits_refund and completes session', async () => {
    // create user and session
    await db.collection('users').doc('user_1').set({ uid: 'user_1' });
    await db.collection('sessions').doc('sess_success').set({
      sessionId: 'sess_success',
      userId: 'user_1',
      status: 'ACTIVE',
      pledgeAmount: 100,
      startTime: admin.firestore.Timestamp.now(),
      durationMinutes: 1,
      settlement: {}
    });

    const res: any = await handleResolveSession({ sessionId: 'sess_success', resolution: 'SUCCESS', idempotencyKey: 'k1' }, {});
    expect(res.status).to.equal('settled');
    expect(res.resolution).to.equal('SUCCESS');

    const ledgerSnap = await db.collection('ledger').where('idempotencyKey', '==', 'k1').get();
    expect(ledgerSnap.size).to.be.greaterThan(0);

    const sessionDoc = await db.collection('sessions').doc('sess_success').get();
    expect(sessionDoc.data()?.status).to.equal('COMPLETED');
  });

  it('failure path: writes credits_burn + ash_grant and sets redemptionExpiry', async () => {
    await db.collection('users').doc('user_2').set({ uid: 'user_2', wallet: { purgatoryVotes: 0 } });
    await db.collection('sessions').doc('sess_fail').set({
      sessionId: 'sess_fail',
      userId: 'user_2',
      status: 'ACTIVE',
      pledgeAmount: 50,
      startTime: admin.firestore.Timestamp.now(),
      durationMinutes: 1,
      settlement: {}
    });

    const res: any = await handleResolveSession({ sessionId: 'sess_fail', resolution: 'FAILURE', idempotencyKey: 'k2', reason: 'native_violation' }, {});
    expect(res.status).to.equal('settled');
    expect(res.resolution).to.equal('FAILURE');

    const burnSnap = await db.collection('ledger').where('kind', '==', 'credits_burn').where('idempotencyKey', '==', 'k2').get();
    expect(burnSnap.size).to.equal(1);

    const ashSnap = await db.collection('ledger').where('kind', '==', 'ash_grant').where('idempotencyKey', '==', 'k2').get();
    expect(ashSnap.size).to.equal(1);

    const userDoc = await db.collection('users').doc('user_2').get();
    expect(userDoc.data()?.deadlines?.redemptionExpiry).to.exist;
    expect(userDoc.data()?.wallet?.purgatoryVotes).to.equal(50);
  });

  it('idempotency: repeated calls with same key do not duplicate ledger entries', async () => {
    await db.collection('users').doc('user_3').set({ uid: 'user_3' });
    await db.collection('sessions').doc('sess_idem').set({
      sessionId: 'sess_idem',
      userId: 'user_3',
      status: 'ACTIVE',
      pledgeAmount: 30,
      startTime: admin.firestore.Timestamp.now(),
      durationMinutes: 1,
      settlement: {}
    });

    const call = async () => await handleResolveSession({ sessionId: 'sess_idem', resolution: 'FAILURE', idempotencyKey: 'k3', reason: 'native_violation' }, {});
    const r1: any = await call();
    const r2: any = await call();
    expect(r1.status).to.equal('settled');
    expect(r2.status).to.equal('already_settled');

    const ashSnap = await db.collection('ledger').where('kind', '==', 'ash_grant').where('idempotencyKey', '==', 'k3').get();
    expect(ashSnap.size).to.equal(1);
  });
});

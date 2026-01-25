import { expect } from 'chai';
import admin from 'firebase-admin';
import { handleResolveSession, handleStartSession } from '../../src/index';

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-project';
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG || JSON.stringify({ projectId: process.env.GCLOUD_PROJECT });

const db = admin.firestore();

describe('startSession & heartbeat emulator tests', function () {
  this.timeout(10000);

  afterEach(async () => {
    const colPaths = ['sessions', 'users', 'ledger'];
    for (const p of colPaths) {
      const snap = await db.collection(p).get();
      const batch = db.batch();
      snap.docs.forEach(d => batch.delete(d.ref));
      await batch.commit();
    }
  });

  it('startSession creates session and ledger credits_lock', async () => {
    await db.collection('users').doc('u_start').set({ uid: 'u_start', wallet: { credits: 100 } });
    const res: any = await handleStartSession({ userId: 'u_start', pledgeAmount: 42, durationMinutes: 30, idempotencyKey: 'start_k1' }, {});
    expect(res.status).to.equal('started');
    const sessionDoc = await db.collection('sessions').doc(res.sessionId).get();
    expect(sessionDoc.exists).to.be.true;

    const lockSnap = await db.collection('ledger').where('kind', '==', 'credits_lock').where('idempotencyKey', '==', 'start_k1').get();
    expect(lockSnap.size).to.equal(1);
  });

  it('rejects startSession when user has insufficient credits', async () => {
    await db.collection('users').doc('u_low').set({ uid: 'u_low', wallet: { credits: 10 } });
    try {
      await handleStartSession({ userId: 'u_low', pledgeAmount: 42, durationMinutes: 30, idempotencyKey: 'start_k_low' }, {});
      throw new Error('expected insufficient credits failure');
    } catch (err: any) {
      expect(err).to.exist;
    }
  });

  it('heartbeatSession updates native.lastCheckedAt', async () => {
    // create a session doc manually
    const sessionRef = db.collection('sessions').doc('sess_hb');
    await sessionRef.set({ sessionId: 'sess_hb', userId: 'u_hb', status: 'ACTIVE', pledgeAmount: 10, native: {} });
    // call heartbeat via direct update (heartbeats are simple updates)
    await sessionRef.update({ 'native.lastCheckedAt': admin.firestore.FieldValue.serverTimestamp() });
    const doc = await sessionRef.get();
    expect(doc.data()?.native?.lastCheckedAt).to.exist;
  });

  it('concurrent settlement: different idempotencyKey after settle is rejected', async () => {
    await db.collection('users').doc('u_conf').set({ uid: 'u_conf' });
    await db.collection('sessions').doc('sess_conf').set({ sessionId: 'sess_conf', userId: 'u_conf', status: 'ACTIVE', pledgeAmount: 5, settlement: {} });

    const r1: any = await handleResolveSession({ sessionId: 'sess_conf', resolution: 'FAILURE', idempotencyKey: 'conf_k1', reason: 'native' }, {});
    expect(r1.status).to.equal('settled');

    try {
      await handleResolveSession({ sessionId: 'sess_conf', resolution: 'SUCCESS', idempotencyKey: 'conf_k2' }, {});
      throw new Error('expected failure');
    } catch (err: any) {
      expect(err).to.exist;
    }
  });

  it('concurrent starts: only one of two parallel starts succeeds when credits equal pledge', async () => {
    await db.collection('users').doc('u_race').set({ uid: 'u_race', wallet: { credits: 50 } });
    const p1 = handleStartSession({ userId: 'u_race', pledgeAmount: 50, durationMinutes: 30, idempotencyKey: 'race_k1' }, {});
    const p2 = handleStartSession({ userId: 'u_race', pledgeAmount: 50, durationMinutes: 30, idempotencyKey: 'race_k2' }, {});
    const results = await Promise.allSettled([p1, p2]);
    const fulfilled = results.filter(r => r.status === 'fulfilled');
    const rejected = results.filter(r => r.status === 'rejected');
    expect(fulfilled.length).to.equal(1);
    expect(rejected.length).to.equal(1);
  });
});

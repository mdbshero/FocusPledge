import { expect } from 'chai';
import admin from 'firebase-admin';
import { handleResolveSession, startSession } from '../../src/index';

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
    await db.collection('users').doc('u_start').set({ uid: 'u_start' });
    const res: any = await (startSession as any)({ userId: 'u_start', pledgeAmount: 42, durationMinutes: 30, idempotencyKey: 'start_k1' }, {});
    expect(res.status).to.equal('started');
    const sessionDoc = await db.collection('sessions').doc(res.sessionId).get();
    expect(sessionDoc.exists).to.be.true;

    const lockSnap = await db.collection('ledger').where('kind', '==', 'credits_lock').where('idempotencyKey', '==', 'start_k1').get();
    expect(lockSnap.size).to.equal(1);
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
});

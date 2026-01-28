// Stale session expiry job emulator tests
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-project';
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG || JSON.stringify({ projectId: process.env.GCLOUD_PROJECT });

import { expect } from 'chai';
import admin from 'firebase-admin';
import { handleExpireStaleSessions } from '../../src/index';

const db = admin.firestore();

describe('expireStaleSessionsScheduled emulator tests', function () {
  this.timeout(10000);

  afterEach(async () => {
    // Clean up collections
    const colPaths = ['sessions', 'users', 'ledger'];
    for (const p of colPaths) {
      const snap = await db.collection(p).get();
      const batch = db.batch();
      snap.docs.forEach(d => batch.delete(d.ref));
      await batch.commit();
    }
  });

  it('resolves ACTIVE session with stale heartbeat', async () => {
    // Create user
    await db.collection('users').doc('user_expiry_1').set({
      uid: 'user_expiry_1',
      wallet: { credits: 100 },
    });

    // Create ACTIVE session with stale heartbeat (15 minutes ago)
    const staleTimestamp = admin.firestore.Timestamp.fromMillis(Date.now() - 15 * 60 * 1000);
    await db.collection('sessions').doc('sess_stale_1').set({
      sessionId: 'sess_stale_1',
      userId: 'user_expiry_1',
      status: 'ACTIVE',
      pledgeAmount: 50,
      native: {
        lastCheckedAt: staleTimestamp,
      },
      settlement: {},
    });

    // Run expiry job
    const result = await handleExpireStaleSessions({}, {});

    expect(result.processed).to.equal(1);
    expect(result.resolved).to.equal(1);

    // Verify session was resolved as FAILURE
    const sessionDoc = await db.collection('sessions').doc('sess_stale_1').get();
    expect(sessionDoc.data()?.status).to.equal('FAILED');
    expect(sessionDoc.data()?.settlement?.resolution).to.equal('FAILURE');

    // Verify ledger entries were created
    const burnSnap = await db.collection('ledger').where('kind', '==', 'credits_burn').where('metadata.sessionId', '==', 'sess_stale_1').get();
    expect(burnSnap.size).to.equal(1);

    const ashSnap = await db.collection('ledger').where('kind', '==', 'ash_grant').where('metadata.sessionId', '==', 'sess_stale_1').get();
    expect(ashSnap.size).to.equal(1);
  });

  it('ignores ACTIVE session with recent heartbeat', async () => {
    await db.collection('users').doc('user_expiry_2').set({
      uid: 'user_expiry_2',
      wallet: { credits: 100 },
    });

    // Create ACTIVE session with recent heartbeat (2 minutes ago)
    const recentTimestamp = admin.firestore.Timestamp.fromMillis(Date.now() - 2 * 60 * 1000);
    await db.collection('sessions').doc('sess_recent').set({
      sessionId: 'sess_recent',
      userId: 'user_expiry_2',
      status: 'ACTIVE',
      pledgeAmount: 30,
      native: {
        lastCheckedAt: recentTimestamp,
      },
      settlement: {},
    });

    // Run expiry job
    const result = await handleExpireStaleSessions({}, {});

    expect(result.processed).to.equal(0);

    // Verify session is still ACTIVE
    const sessionDoc = await db.collection('sessions').doc('sess_recent').get();
    expect(sessionDoc.data()?.status).to.equal('ACTIVE');
  });

  it('ignores already COMPLETED sessions', async () => {
    await db.collection('users').doc('user_expiry_3').set({
      uid: 'user_expiry_3',
      wallet: { credits: 100 },
    });

    // Create COMPLETED session with stale heartbeat
    const staleTimestamp = admin.firestore.Timestamp.fromMillis(Date.now() - 20 * 60 * 1000);
    await db.collection('sessions').doc('sess_completed').set({
      sessionId: 'sess_completed',
      userId: 'user_expiry_3',
      status: 'COMPLETED',
      pledgeAmount: 40,
      native: {
        lastCheckedAt: staleTimestamp,
      },
      settlement: {
        resolution: 'SUCCESS',
        idempotencyKey: 'manual_settle_1',
      },
    });

    // Run expiry job
    const result = await handleExpireStaleSessions({}, {});

    expect(result.processed).to.equal(0);

    // Verify session is still COMPLETED
    const sessionDoc = await db.collection('sessions').doc('sess_completed').get();
    expect(sessionDoc.data()?.status).to.equal('COMPLETED');
  });

  it('handles multiple stale sessions in batch', async () => {
    // Create 3 stale sessions
    await db.collection('users').doc('user_expiry_4').set({
      uid: 'user_expiry_4',
      wallet: { credits: 300 },
    });

    const staleTimestamp = admin.firestore.Timestamp.fromMillis(Date.now() - 15 * 60 * 1000);

    for (let i = 1; i <= 3; i++) {
      await db.collection('sessions').doc(`sess_batch_${i}`).set({
        sessionId: `sess_batch_${i}`,
        userId: 'user_expiry_4',
        status: 'ACTIVE',
        pledgeAmount: 25,
        native: {
          lastCheckedAt: staleTimestamp,
        },
        settlement: {},
      });
    }

    // Run expiry job
    const result = await handleExpireStaleSessions({}, {});

    expect(result.processed).to.equal(3);
    expect(result.resolved).to.equal(3);

    // Verify all sessions were resolved
    for (let i = 1; i <= 3; i++) {
      const sessionDoc = await db.collection('sessions').doc(`sess_batch_${i}`).get();
      expect(sessionDoc.data()?.status).to.equal('FAILED');
    }
  });
});

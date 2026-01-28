"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
// Ensure emulator environment variables for project detection are set
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-project';
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG || JSON.stringify({ projectId: process.env.GCLOUD_PROJECT });
const chai_1 = require("chai");
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const index_1 = require("../../src/index");
// These tests run under `firebase emulators:exec --only firestore` which
// provides FIRESTORE_EMULATOR_HOST and an isolated emulator instance.
const db = firebase_admin_1.default.firestore();
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
            startTime: firebase_admin_1.default.firestore.Timestamp.now(),
            durationMinutes: 1,
            settlement: {}
        });
        const res = await (0, index_1.handleResolveSession)({ sessionId: 'sess_success', resolution: 'SUCCESS', idempotencyKey: 'k1' }, {});
        (0, chai_1.expect)(res.status).to.equal('settled');
        (0, chai_1.expect)(res.resolution).to.equal('SUCCESS');
        const ledgerSnap = await db.collection('ledger').where('idempotencyKey', '==', 'k1').get();
        (0, chai_1.expect)(ledgerSnap.size).to.be.greaterThan(0);
        const sessionDoc = await db.collection('sessions').doc('sess_success').get();
        (0, chai_1.expect)(sessionDoc.data()?.status).to.equal('COMPLETED');
    });
    it('failure path: writes credits_burn + ash_grant and sets redemptionExpiry', async () => {
        await db.collection('users').doc('user_2').set({ uid: 'user_2', wallet: { purgatoryVotes: 0 } });
        await db.collection('sessions').doc('sess_fail').set({
            sessionId: 'sess_fail',
            userId: 'user_2',
            status: 'ACTIVE',
            pledgeAmount: 50,
            startTime: firebase_admin_1.default.firestore.Timestamp.now(),
            durationMinutes: 1,
            settlement: {}
        });
        const res = await (0, index_1.handleResolveSession)({ sessionId: 'sess_fail', resolution: 'FAILURE', idempotencyKey: 'k2', reason: 'native_violation' }, {});
        (0, chai_1.expect)(res.status).to.equal('settled');
        (0, chai_1.expect)(res.resolution).to.equal('FAILURE');
        const burnSnap = await db.collection('ledger').where('kind', '==', 'credits_burn').where('idempotencyKey', '==', 'k2').get();
        (0, chai_1.expect)(burnSnap.size).to.equal(1);
        const ashSnap = await db.collection('ledger').where('kind', '==', 'ash_grant').where('idempotencyKey', '==', 'k2').get();
        (0, chai_1.expect)(ashSnap.size).to.equal(1);
        const userDoc = await db.collection('users').doc('user_2').get();
        (0, chai_1.expect)(userDoc.data()?.deadlines?.redemptionExpiry).to.exist;
        (0, chai_1.expect)(userDoc.data()?.wallet?.purgatoryVotes).to.equal(50);
    });
    it('idempotency: repeated calls with same key do not duplicate ledger entries', async () => {
        await db.collection('users').doc('user_3').set({ uid: 'user_3' });
        await db.collection('sessions').doc('sess_idem').set({
            sessionId: 'sess_idem',
            userId: 'user_3',
            status: 'ACTIVE',
            pledgeAmount: 30,
            startTime: firebase_admin_1.default.firestore.Timestamp.now(),
            durationMinutes: 1,
            settlement: {}
        });
        const call = async () => await (0, index_1.handleResolveSession)({ sessionId: 'sess_idem', resolution: 'FAILURE', idempotencyKey: 'k3', reason: 'native_violation' }, {});
        const r1 = await call();
        const r2 = await call();
        (0, chai_1.expect)(r1.status).to.equal('settled');
        (0, chai_1.expect)(r2.status).to.equal('already_settled');
        const ashSnap = await db.collection('ledger').where('kind', '==', 'ash_grant').where('idempotencyKey', '==', 'k3').get();
        (0, chai_1.expect)(ashSnap.size).to.equal(1);
    });
});
//# sourceMappingURL=resolveSession.emulator.test.js.map
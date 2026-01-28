"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const chai_1 = require("chai");
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const index_1 = require("../../src/index");
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-project';
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG || JSON.stringify({ projectId: process.env.GCLOUD_PROJECT });
const db = firebase_admin_1.default.firestore();
describe('reconcile ledger -> users wallet', function () {
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
    it('aggregates ledger entries and writes users.wallet.credits', async () => {
        // ledger: +100 purchase, -30 burn, +10 refund => 80
        await db.collection('ledger').add({ userId: 'u_rec', kind: 'credits_purchase', amount: 100 });
        await db.collection('ledger').add({ userId: 'u_rec', kind: 'credits_burn', amount: 30 });
        await db.collection('ledger').add({ userId: 'u_rec', kind: 'credits_refund', amount: 10 });
        // pre-existing incorrect wallet
        await db.collection('users').doc('u_rec').set({ uid: 'u_rec', wallet: { credits: 0 } });
        const res = await (0, index_1.handleReconcileAllUsers)({}, {});
        (0, chai_1.expect)(res.reconciledUsers).to.equal(1);
        const u = await db.collection('users').doc('u_rec').get();
        (0, chai_1.expect)(u.exists).to.be.true;
        (0, chai_1.expect)(u.data()?.wallet?.credits).to.equal(80);
    });
});
//# sourceMappingURL=reconcile.emulator.test.js.map
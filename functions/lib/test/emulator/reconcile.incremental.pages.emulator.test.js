"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const chai_1 = require("chai");
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const incrementalReconcile_1 = require("../../src/reconcile/incrementalReconcile");
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-project';
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG || JSON.stringify({ projectId: process.env.GCLOUD_PROJECT });
if (!firebase_admin_1.default.apps.length)
    firebase_admin_1.default.initializeApp();
const db = firebase_admin_1.default.firestore();
describe('incremental reconcile paging', function () {
    this.timeout(20000);
    afterEach(async () => {
        const colPaths = ['sessions', 'users', 'ledger', 'reconcile_state'];
        for (const p of colPaths) {
            const snap = await db.collection(p).get();
            const batch = db.batch();
            snap.docs.forEach(d => batch.delete(d.ref));
            await batch.commit();
        }
    });
    it('applies deltas across multiple pages', async () => {
        // create two users with zero reported credits
        await db.collection('users').doc('uA').set({ uid: 'uA', wallet: { credits: 0 } });
        await db.collection('users').doc('uB').set({ uid: 'uB', wallet: { credits: 0 } });
        const base = Date.now();
        // create 5 ledger entries; pageSize will be 2 -> requires 3 pages
        const entries = [
            { userId: 'uA', kind: 'credits_purchase', amount: 10 },
            { userId: 'uB', kind: 'credits_purchase', amount: 5 },
            { userId: 'uA', kind: 'credits_burn', amount: 3 },
            { userId: 'uB', kind: 'credits_purchase', amount: 7 },
            { userId: 'uA', kind: 'credits_refund', amount: 2 },
        ];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            const ref = db.collection('ledger').doc();
            await ref.set({
                entryId: ref.id,
                userId: e.userId,
                kind: e.kind,
                amount: e.amount,
                createdAt: firebase_admin_1.default.firestore.Timestamp.fromMillis(base + i),
            });
        }
        // run reconcileIncremental repeatedly until no more processed
        let totalProcessed = 0;
        while (true) {
            const res = await (0, incrementalReconcile_1.reconcileIncremental)(db, { pageSize: 2, resumeDocPath: 'reconcile_state/incremental_test' });
            totalProcessed += res.processed || 0;
            if (!res.processed || res.processed === 0)
                break;
        }
        (0, chai_1.expect)(totalProcessed).to.equal(entries.length);
        const uA = await db.collection('users').doc('uA').get();
        const uB = await db.collection('users').doc('uB').get();
        // expected uA: +10 -3 +2 = 9
        (0, chai_1.expect)(uA.data()?.wallet?.credits).to.equal(9);
        // expected uB: +5 +7 = 12
        (0, chai_1.expect)(uB.data()?.wallet?.credits).to.equal(12);
    });
});
//# sourceMappingURL=reconcile.incremental.pages.emulator.test.js.map
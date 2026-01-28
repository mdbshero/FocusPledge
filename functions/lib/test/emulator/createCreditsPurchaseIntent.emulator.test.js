"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
// createCreditsPurchaseIntent emulator tests
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-project';
process.env.FIREBASE_CONFIG = process.env.FIREBASE_CONFIG || JSON.stringify({ projectId: process.env.GCLOUD_PROJECT });
const chai_1 = require("chai");
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const index_1 = require("../../src/index");
const db = firebase_admin_1.default.firestore();
describe('createCreditsPurchaseIntent emulator tests', function () {
    this.timeout(10000);
    afterEach(async () => {
        // Clean up collections
        const colPaths = ['paymentIntents', 'users'];
        for (const p of colPaths) {
            const snap = await db.collection(p).get();
            const batch = db.batch();
            snap.docs.forEach(d => batch.delete(d.ref));
            await batch.commit();
        }
    });
    it.skip('creates PaymentIntent with valid packId and idempotencyKey', async () => {
        const mockContext = {
            auth: { uid: 'user_purchase_1' },
        };
        const result = await (0, index_1.handleCreateCreditsPurchaseIntent)({
            packId: 'standard_pack',
            idempotencyKey: 'idem_test_1',
        }, mockContext);
        (0, chai_1.expect)(result).to.have.property('client_secret');
        (0, chai_1.expect)(result.client_secret).to.be.a('string');
        // Verify PaymentIntent record was stored
        const intentsSnap = await db.collection('paymentIntents').where('idempotencyKey', '==', 'idem_test_1').get();
        (0, chai_1.expect)(intentsSnap.size).to.equal(1);
        const intentDoc = intentsSnap.docs[0].data();
        (0, chai_1.expect)(intentDoc.userId).to.equal('user_purchase_1');
        (0, chai_1.expect)(intentDoc.packId).to.equal('standard_pack');
        (0, chai_1.expect)(intentDoc.creditsAmount).to.equal(1000);
        (0, chai_1.expect)(intentDoc.priceUsd).to.equal(999);
        (0, chai_1.expect)(intentDoc.status).to.equal('pending');
    });
    it.skip('returns cached PaymentIntent on idempotency retry', async () => {
        const mockContext = {
            auth: { uid: 'user_purchase_2' },
        };
        // First call
        const result1 = await (0, index_1.handleCreateCreditsPurchaseIntent)({
            packId: 'value_pack',
            idempotencyKey: 'idem_test_2',
        }, mockContext);
        // Second call with same idempotencyKey (client retry)
        const result2 = await (0, index_1.handleCreateCreditsPurchaseIntent)({
            packId: 'value_pack',
            idempotencyKey: 'idem_test_2',
        }, mockContext);
        (0, chai_1.expect)(result1.client_secret).to.equal(result2.client_secret);
        // Verify only one PaymentIntent was created
        const intentsSnap = await db.collection('paymentIntents').where('idempotencyKey', '==', 'idem_test_2').get();
        (0, chai_1.expect)(intentsSnap.size).to.equal(1);
    });
    it('rejects unauthenticated request', async () => {
        const mockContext = {}; // No auth
        try {
            await (0, index_1.handleCreateCreditsPurchaseIntent)({
                packId: 'standard_pack',
                idempotencyKey: 'idem_test_3',
            }, mockContext);
            throw new Error('Expected unauthenticated error');
        }
        catch (err) {
            (0, chai_1.expect)(err.code).to.equal('unauthenticated');
        }
    });
    it('rejects invalid packId', async () => {
        const mockContext = {
            auth: { uid: 'user_purchase_3' },
        };
        try {
            await (0, index_1.handleCreateCreditsPurchaseIntent)({
                packId: 'invalid_pack',
                idempotencyKey: 'idem_test_4',
            }, mockContext);
            throw new Error('Expected invalid-argument error');
        }
        catch (err) {
            (0, chai_1.expect)(err.code).to.equal('invalid-argument');
            (0, chai_1.expect)(err.message).to.include('Invalid packId');
        }
    });
    it('rejects missing idempotencyKey', async () => {
        const mockContext = {
            auth: { uid: 'user_purchase_4' },
        };
        try {
            await (0, index_1.handleCreateCreditsPurchaseIntent)({
                packId: 'standard_pack',
            }, mockContext);
            throw new Error('Expected invalid-argument error');
        }
        catch (err) {
            (0, chai_1.expect)(err.code).to.equal('invalid-argument');
            (0, chai_1.expect)(err.message).to.include('idempotencyKey');
        }
    });
});
//# sourceMappingURL=createCreditsPurchaseIntent.emulator.test.js.map
"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const chai_1 = require("chai");
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const incrementalReconcile_1 = require("../../src/reconcile/incrementalReconcile");
if (!firebase_admin_1.default.apps.length)
    firebase_admin_1.default.initializeApp();
const db = firebase_admin_1.default.firestore();
describe('incremental reconcile scaffold', () => {
    it('exports reconcileIncremental function', async () => {
        (0, chai_1.expect)(typeof incrementalReconcile_1.reconcileIncremental).to.equal('function');
        const result = await (0, incrementalReconcile_1.reconcileIncremental)(db, { pageSize: 10, resumeDocPath: 'reconcile_state/incremental_test_min' });
        (0, chai_1.expect)(result).to.have.property('processed');
    });
});
//# sourceMappingURL=reconcile.incremental.emulator.test.js.map
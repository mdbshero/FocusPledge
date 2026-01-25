import { expect } from 'chai'
import admin from 'firebase-admin'
import { reconcileIncremental } from '../../src/reconcile/incrementalReconcile'

if (!admin.apps.length) admin.initializeApp()
const db = admin.firestore()

describe('incremental reconcile scaffold', () => {
  it('exports reconcileIncremental function', async () => {
    expect(typeof reconcileIncremental).to.equal('function')
    const result = await reconcileIncremental(db, { pageSize: 10, resumeDocPath: 'reconcile_state/incremental_test_min' })
    expect(result).to.have.property('processed')
  })
})

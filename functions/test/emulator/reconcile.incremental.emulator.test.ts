import { expect } from 'chai'
import admin from 'firebase-admin'
import { reconcileIncremental } from '../../src/reconcile/incrementalReconcile'

if (!admin.apps.length) admin.initializeApp()

describe('incremental reconcile scaffold', () => {
  it('exports reconcileIncremental function', async () => {
    expect(typeof reconcileIncremental).to.equal('function')
    const result = await reconcileIncremental({} as any, { pageSize: 10 })
    expect(result).to.have.property('processed')
  })
})

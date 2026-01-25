import { expect } from 'chai'
import { reconcileIncremental } from '../../src/reconcile/incrementalReconcile'

describe('incremental reconcile scaffold', () => {
  it('exports reconcileIncremental function', async () => {
    expect(typeof reconcileIncremental).to.equal('function')
    const result = await reconcileIncremental({} as any, { pageSize: 10 })
    expect(result).to.have.property('processed')
  })
})

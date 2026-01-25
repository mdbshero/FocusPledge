import admin from 'firebase-admin'

/**
 * Incremental reconciliation implementation (paged).
 *
 * Behavior:
 *  - Pages through `ledger` ordered by `createdAt, entryId` using a resume
 *    token stored in `reconcile_state/incremental`.
 *  - Aggregates per-user deltas in each page and applies them using
 *    `FieldValue.increment(delta)` to avoid full-table reads.
 *  - Advances resume token after successfully committing the batch.
 *
 * Notes/TODO:
 *  - This implementation assumes `ledger.createdAt` is set and stable.
 *  - For production with large datasets you may want multi-worker
 *    sharding and idempotent resume semantics.
 */
export async function reconcileIncremental(
  db: FirebaseFirestore.Firestore,
  opts: { pageSize?: number; resumeDocPath?: string } = {}
): Promise<{ processed: number; resumeToken?: { createdAt?: FirebaseFirestore.Timestamp; entryId?: string } }> {
  const pageSize = opts.pageSize || 500
  const resumeDocPath = opts.resumeDocPath || 'reconcile_state/incremental'

  const resumeRef = db.doc(resumeDocPath)
  const resumeSnap = await resumeRef.get()
  let startAfterValues: any[] | undefined
  if (resumeSnap.exists) {
    const data = resumeSnap.data() as any
    if (data?.lastCreatedAt || data?.lastEntryId) {
      startAfterValues = [data.lastCreatedAt || null, data.lastEntryId || null]
    }
  }

  let q: FirebaseFirestore.Query = db.collection('ledger').orderBy('createdAt').orderBy('entryId').limit(pageSize)
  if (startAfterValues) q = q.startAfter(...startAfterValues)

  const snap = await q.get()
  if (snap.empty) return { processed: 0 }

  const deltas = new Map<string, number>()
  let lastCreatedAt: FirebaseFirestore.Timestamp | undefined
  let lastEntryId: string | undefined

  snap.docs.forEach(d => {
    const e: any = d.data()
    const userId = e.userId
    if (!userId) return
    const amt = Number(e.amount || 0)
    let cur = deltas.get(userId) || 0
    if (e.kind === 'credits_purchase' || e.kind === 'credits_refund') cur += amt
    if (e.kind === 'credits_burn' || e.kind === 'credits_lock') cur -= amt
    deltas.set(userId, cur)

    lastCreatedAt = e.createdAt || lastCreatedAt
    lastEntryId = e.entryId || d.id
  })

  const batch = db.batch()
  for (const [userId, delta] of deltas.entries()) {
    if (delta === 0) continue
    const userRef = db.collection('users').doc(userId)
    batch.set(userRef, { wallet: { credits: admin.firestore.FieldValue.increment(delta) } }, { merge: true } as any)
  }

  // Advance resume token
  const resumeData: any = {}
  if (lastCreatedAt) resumeData.lastCreatedAt = lastCreatedAt
  if (lastEntryId) resumeData.lastEntryId = lastEntryId
  resumeData.updatedAt = admin.firestore.FieldValue.serverTimestamp()
  batch.set(resumeRef, resumeData, { merge: true } as any)

  await batch.commit()

  return { processed: snap.size, resumeToken: { createdAt: lastCreatedAt, entryId: lastEntryId } }
}

export default reconcileIncremental

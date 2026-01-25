Chore: Reconcile + startSession hardening (2026-01-25)

- Harden `startSession` to check derived balance and prevent double-spend
- Add ledger-based reconciliation job + schedule wrapper
- Add emulator tests: credit sufficiency, concurrency, idempotency, reconciliation

Follow-up: incremental/paged reconciliation on branch `feat/reconcile-incremental`.

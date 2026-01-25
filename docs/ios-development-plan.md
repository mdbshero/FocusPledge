# FocusPledge — iOS Development & Deployment Plan (Flutter + Firebase + Stripe + Screen Time)

**Document purpose**: a highly actionable, end-to-end checklist to build and ship FocusPledge on iOS with strong security guarantees (server-authoritative economy + session logic) and Apple Screen Time enforcement.

**Audience**: a mixed team of humans + AI agents. Each task is labeled with who can reliably complete it.

**Guardrails (non-negotiable)**

- **Security first**: balances and session settlement are **server-authoritative** (Firebase Cloud Functions). The Flutter client never performs economy math.
- **Skill-first / no gambling framing**: avoid “Bet”, “Gamble”, “Wager”, “Odds”, “Jackpot”, “Win money” in UI and code. Use “Pledge”, “Commitment”, “Credits”, “Outcome”, “Redemption”.
- **Closed-loop arcade economy**: users buy **Focus Credits (FC)** packs; FC/Ash/Obsidian are **non-redeemable** in-app currencies (no cash-out, no withdrawals).
- **Auditability**: all balance changes are immutable ledger entries; balances are derived on the server.
- **Anti-cheat**: session state persists on the server; failure can occur even if the app is terminated.
- **Legal posture (Florida game of skill)**: the product is designed to be a **skill-based** system (user behavior/discipline) and not a game of chance; keep copy and flows aligned.

---

## Terminology (Session 1 alignment)

- **Approved terms:** Focus Credits (FC), Ash, Obsidian, Frozen Votes, Redemption Session, Pledge Session, Impact Points, Credits pack.
- **Forbidden terms (do not use in UI or copy):** Bet, Gamble, Wager, Odds, Jackpot, Win money, Prize, Betting.
- **Tone guideline:** Use "pledge", "commitment", "credits", "outcome", "redemption" — emphasize skill, discipline, and closed-loop economy. Avoid chance/gambling framing anywhere in text or code identifiers that are user-facing.
- **Currency rule:** `Focus Credits (FC)` are strictly in-app, non-redeemable credits. All balance math must be server-authoritative; client shows derived balances only.
- **Action:** Audit UI copy and code identifiers for forbidden terms; flag and replace occurrences with approved terminology before iOS submission.

### Replacement suggestions

- **Mapping (user-facing):**
  - `Bet` / `Gamble` / `Wager` / `Betting` → `Pledge` / `Commitment`
  - `Odds` / `Win money` / `Prize` / `Jackpot` → `Outcome` / `Result` / `Redemption`

- **Mapping (code identifiers / internal):**
  - Avoid identifiers like `bet_amount`, `wager`, `jackpotReward`. Use `pledge_amount`, `commitmentAmount`, `redemptionReward` instead.
  - Use `focusCredits`, `ashBalance`, `obsidianBalance`, `frozenVotes` for model fields.

- **Suggested workflow:**
  1. Run a repo-wide search for forbidden terms (done). If matches outside docs are found, create automated replacement PRs limited to testable strings files.
  2. For UI strings (Dart/ARB/JSON/Plist), prefer human review before bulk replace to avoid changing legal or historical text.
  3. Add a CI lint rule to fail on forbidden user-facing terms (strings in `lib/`, `assets/`, localization files).

## 0) Assumptions & scope

### Assumptions

- Target platforms: **iOS first** (iPhone). iPad optional later.
- In-app economy: **Focus Credits (FC)** are purchased via Stripe.
  - Reference rate (for internal consistency): **100 FC = $1.00**.
  - App-facing copy should treat FC as **in-app credits** (closed-loop; non-redeemable).
- Stripe mode: start in **test mode**, then switch to production after validation.
- Firebase: Auth + Firestore + Cloud Functions + Cloud Scheduler.
- Screen Time: FamilyControls + DeviceActivity + ManagedSettings.

### MVP definition (ship-worthy)

1. Sign-in
2. Purchase Focus Credits packs (Stripe)
3. Display wallet (read-only client): Credits, Ash, Obsidian, Frozen Votes
4. Create a pledge session (pledge Credits + duration)
5. Enforce distraction blocking (Screen Time shielding) during session
6. Auto-resolve success/failure on server (ledger + Phoenix Protocol outcomes)
7. Redemption loop: complete a Redemption Session within 24h to rescue Frozen Votes and convert Ash → Obsidian (conversion details TBD)
8. Basic shop (“Black Market”): buy at least one cosmetic using Obsidian
9. Minimal analytics + crash reporting

### Timeline style

- Durations are estimates for a focused build (single senior engineer + AI agent assistance).
- Where tasks depend on external approvals (Apple entitlements / Stripe verification), the plan includes realistic lead times.

---

## Firestore schema & invariants (Session 2)

This section defines the minimal Firestore collections and server-enforced invariants for the Phoenix Protocol. Clients may read `users/*` and `sessions/*` but must never write authoritative balance fields — all mutations are performed by Cloud Functions.

Collections (minimal set):

- `users/{uid}` (readable by user)
  - Fields:
    - `uid: string`
    - `wallet: { credits: number, ash: number, obsidian: number, purgatoryVotes: number, lifetimePurchased: number }`
    - `deadlines: { redemptionExpiry?: timestamp }`
    - `status: { currentTheme?: string, appIcon?: string }`
  - Notes: `wallet.*` is derived and only writable by server functions.

- `sessions/{sessionId}`
  - Fields:
    - `sessionId`, `userId`, `type` (PLEDGE|REDEMPTION), `status` (ACTIVE|COMPLETED|FAILED)
    - `pledgeAmount`, `durationMinutes`, `startTime`, `endTime?`
    - `native: { lastCheckedAt?: timestamp, failureFlag?: bool, failureReason?: string }`
    - `settlement: { resolvedAt?: timestamp, resolvedBy?: string, resolution?: string, idempotencyKey?: string }`
  - Notes: sessions are created by `startSession()` callable and settled only via `resolveSession()`.

- `ledger/{entryId}` (immutable event store)
  - Each ledger entry is append-only and contains: `entryId`, `userId`, `kind` (credits_purchase|credits_lock|credits_burn|credits_refund|ash_grant|obsidian_grant|shop_purchase), `amount`, `metadata`, `createdAt`, `idempotencyKey`
  - Balances are derived by aggregating `ledger/*` for a user (server-side). `ledger` writes only from Cloud Functions.

- `stripeEvents/{eventId}` (idempotency store)
  - Stores processed Stripe event IDs to prevent replay double-crediting.

- `shop/catalog/{itemId}` and `shop/purchases/{purchaseId}` (optional)

Security invariants (server-enforced):

- Clients may read their own `users/{uid}` and `sessions/{sessionId}` documents.
- Clients may NOT write to `users.{wallet.*}` or `ledger/*`.
- `sessions.status` transitions are monotonic: only `ACTIVE` -> `COMPLETED|FAILED` allowed by server functions.
- All settlement operations are idempotent and must include an `idempotencyKey`.
- Any credits that are 'burned' must be recorded in the ledger with `credits_burn` and must reduce derived balance accordingly.

Testing & validation checklist:

- Rules unit tests to verify: client cannot write `wallet.*`, client can only read own `users/*`.
- Functions unit tests: posting a `credits_purchase` ledger entry updates derived `users.wallet.credits` exactly once (idempotent replay).
- Integration test: startSession -> simulate native failure -> resolveSession(FAILURE) -> ledger entries and `users.deadlines.redemptionExpiry` set.

## `resolveSession()` settlement spec (Session 2 continuation)

Purpose: single authoritative function to settle sessions. It must be server-only, idempotent, and produce immutable ledger entries that drive derived balances.

Signature (callable):

- `resolveSession(sessionId: string, resolution: 'SUCCESS'|'FAILURE', idempotencyKey: string, reason?: string, nativeEvidence?: object)`

Validations (server):

- Verify `sessions/{sessionId}` exists and is `status: ACTIVE` (if already settled, return idempotent success).
- Verify `idempotencyKey` has not produced a different settlement for this session.
- Confirm server-side time indicates session end (compute from `startTime + durationMinutes`) or that a failure was reported by native evidence or scheduler.

State machine (monotonic transitions):

- `ACTIVE` -> `COMPLETED` (on SUCCESS)
- `ACTIVE` -> `FAILED` (on FAILURE)
- Any attempt to move `COMPLETED|FAILED` -> other is rejected; subsequent calls with same `idempotencyKey` return existing result.

Ledger & side effects (atomic transaction where possible):

- On SUCCESS:
  - Append ledger entry: `{ kind: 'credits_refund', userId, amount: pledgedAmount, metadata: { sessionId } , idempotencyKey }`
  - Optionally append `impact_points_grant` ledger entry if the product awards points.
  - Update `sessions/{sessionId}.status = COMPLETED`, `settlement.resolvedAt`, `settlement.resolution = SUCCESS`, `settlement.idempotencyKey`.

- On FAILURE:
  - Append ledger entry: `{ kind: 'credits_burn', userId, amount: pledgedAmount, metadata: { sessionId, reason }, idempotencyKey }`
  - Append ledger entry: `{ kind: 'ash_grant', userId, amount: ashAmount, metadata: { sessionId }, idempotencyKey }` (if policy awards Ash)
  - Update `users/{uid}.deadlines.redemptionExpiry = now + 24h` (as a derived field set within the same transaction)
  - Update `sessions/{sessionId}.status = FAILED`, `settlement.*` as above.

Idempotency rules:

- Use `sessionId` + `idempotencyKey` as the unique key. Store processed keys in `sessions/{sessionId}.settlement.idempotencyKey` and/or a `settlementEvents/{key}` collection.
- If a `resolveSession` call repeats with same `idempotencyKey`, return prior settlement result (no duplicate ledger writes).
- If a different `idempotencyKey` is submitted after settlement, reject to prevent conflicting resolutions.

Security & auditability:

- All ledger entries are immutable; never amend an existing ledger entry — only append corrective entries (`admin_correction`) if needed.
- Settlement callable requires elevated privileges (server SDK) — clients cannot call directly unless via authenticated Callable Functions with server-side checks.

Testing scenarios:

- Idempotency: call `resolveSession` twice with same `idempotencyKey` — verify only one set of ledger entries exists and session status unchanged.
- Success path: start -> heartbeat -> resolve(SUCCESS) -> credits_refund + session COMPLETED.
- Failure path (native evidence): start -> native writes failure -> resolve(FAILURE) -> credits_burn + ash_grant + redemptionExpiry set.
- Replay protection: replay Stripe webhook / scheduler triggers should not double-settle.

Example settlement payload (FAILURE):

```json
{
  "sessionId": "sess_001",
  "resolution": "FAILURE",
  "idempotencyKey": "settle_sess_001_v1",
  "reason": "native_violation",
  "nativeEvidence": {
    "appBundleId": "com.example.facebook",
    "timestamp": "..."
  }
}
```

Exit criteria for this spec:

- `resolveSession()` implemented as a Cloud Function that is idempotent, writes ledger entries, updates session status, and sets redemption deadlines on failure. Unit tests cover idempotency and both settlement branches.

### `startSession` and `heartbeat` (added)

- `startSession(userId, pledgeAmount, durationMinutes, idempotencyKey)`
  - Validations: pledge bounds, sufficient credits (server-validated), unique `idempotencyKey` per user.
  - Side effects: append immutable ledger entry `credits_lock`; create `sessions/{sessionId}` with `status: ACTIVE` and store `idempotencyKey`.

- `heartbeatSession(sessionId)`
  - Writes `sessions/{sessionId}.native.lastCheckedAt` with server timestamp to indicate device heartbeat.
  - The scheduler marks sessions failed when heartbeat is stale beyond grace window.

Tests added (Firestore emulator):

- `startSession` — verifies `sessions/*` created and `ledger` `credits_lock` entry exists.
- `heartbeat` — verifies `native.lastCheckedAt` is written.
- Concurrent settlement edge case — resolving with a different `idempotencyKey` after settlement is rejected.

## 1) High-level timeline overview

**Phase 1 — Foundations (Week 1)**

- Repo structure, Flutter architecture skeleton
- Firebase project + environments (dev/staging/prod)
- Firestore security model + Cloud Functions scaffolding

**Phase 2 — Phoenix Protocol economy + session engine (Weeks 2–3)**

- Stripe Credits pack purchase pipeline with webhooks
- Ledger + derived balance updates (Credits/Ash/Obsidian/Votes)
- Session lifecycle + settlement centered on `resolveSession()`

**Phase 3 — Screen Time enforcement (Weeks 3–5)**

- iOS native plugin + extension targets
- Authorization flow + app selection UI
- Shielding + violation detection + server fail

**Phase 4 — Product features (Weeks 5–6)**

- Redemption loop + Obsidian shop cosmetics
- Blacklist management UX
- Notifications + session UX polish

**Phase 5 — Hardening + compliance + release (Weeks 6–8)**

- Security review + tests + monitoring
- Privacy policy + App Store metadata
- TestFlight → App Store submission

> **Risk note**: Apple Screen Time entitlements/behavior are the biggest schedule risk. Plan for iteration on-device.

---

## 2) Task taxonomy (who can do what)

Tasks are labeled by who can reliably complete them:

### AI-agent-reliable tasks (A)

An AI agent can reliably complete these without human-only credentials/approvals:

- Flutter/Dart implementation and refactors
- Cloud Functions code (TypeScript) and Firestore rules drafts
- Unit/integration tests scaffolding
- Static analysis, linting, formatting
- Documentation, architecture diagrams (text-based)
- CI pipeline configuration

### Human-required tasks (H)

Requires a person due to credentials, legal judgment, external approvals, or physical device testing:

- Creating/owning Apple Developer account and App Store Connect configuration
- Requesting/obtaining Screen Time-related entitlements/capabilities (if Apple approval required)
- Stripe account activation/verification and production key management
- Real device testing on multiple iOS versions
- Legal review: privacy policy/terms, payment disclosures, closed-loop economy disclosures
- App Store screenshots, marketing copy, and submission

### Mixed tasks (M)

AI can prepare 80–95%, human completes final steps:

- Firebase project creation + secrets provisioning
- Stripe dashboard configuration (webhook endpoints) and verifying events
- App Store Connect setup steps (agent can provide click-by-click checklists)

---

## 2.5) Daily sessions plan (1–2h/day, starting Sun Jan 25, 2026)

Designed for solo development with AI agent support. Each day is one coherent work session with a concrete output.

| Date       |                           Session (goal) |   Est. | Output (definition of done)                                                   |
| ---------- | ---------------------------------------: | -----: | ----------------------------------------------------------------------------- |
| Sun Jan 25 |         ~~Plan alignment + terminology~~ | 1–1.5h | Doc aligned end-to-end to Credits/Ash/Obsidian and skill-first wording        |
| Mon Jan 26 |        ~~Firestore schema + invariants~~ |   1–2h | Schema section drafted (users/sessions/ledger invariants)                     |
| Tue Jan 27 |    ~~Settlement spec: `resolveSession`~~ |   1–2h | Idempotent state machine + ledger entry types documented                      |
| Wed Jan 28 |                Stripe Credits packs spec |   1–2h | Pack SKUs + PaymentIntent + webhook + replay safety documented                |
| Thu Jan 29 |                   iOS native bridge spec |   1–2h | MethodChannel API + App Group keys + polling loop defined                     |
| Fri Jan 30 |          Flutter UX map + copy checklist |   1–2h | Screen list + UX states + skill-first copy checklist                          |
| Sat Jan 31 |               Repo scaffolding checklist |   1–2h | Concrete steps to add Firebase/Functions/Stripe deps + local dev flow         |
| Sun Feb 1  |          ~~Backend: Functions scaffold~~ |   1–2h | Functions project skeleton + lint/test + placeholder callable                 |
| Mon Feb 2  |         Backend: Stripe webhook skeleton |   1–2h | Verified signature path + event idempotency store stub                        |
| Tue Feb 3  |        Backend: Credits pack fulfillment |   1–2h | `credits_purchase` ledger posting + wallet crediting stub                     |
| Wed Feb 4  |     ~~Backend: `startSession` skeleton~~ |   1–2h | Validations + credits lock ledger stub + session doc                          |
| Thu Feb 5  |   ~~Backend: `resolveSession` skeleton~~ |   1–2h | SUCCESS/FAILURE branches stubbed + idempotency guard                          |
| Fri Feb 6  |            Backend: scheduler expiry job |   1–2h | Scheduled function skeleton for stale heartbeat resolution                    |
| Sat Feb 7  |             Security rules draft + tests |   1–2h | Rules draft + rules test harness skeleton                                     |
| Sun Feb 8  |                Flutter: app architecture |   1–2h | Feature folders + routing + state mgmt baseline                               |
| Mon Feb 9  |                       Flutter: auth flow |   1–2h | Sign-in screen + Firebase Auth wiring stub                                    |
| Tue Feb 10 |                   Flutter: wallet screen |   1–2h | Wallet UI (credits/ash/obsidian/votes) reading from Firestore                 |
| Wed Feb 11 |                  Flutter: buy credits UI |   1–2h | Credits pack picker + call to backend intent (stubbed)                        |
| Thu Feb 12 |                 Flutter: pledge setup UI |   1–2h | Pledge amount + duration UI + call `startSession`                             |
| Fri Feb 13 |          Flutter: active session “Pulse” |   1–2h | Timer UI + heartbeat loop + safety copy                                       |
| Sat Feb 14 |              iOS: MethodChannel scaffold |   1–2h | `requestAuthorization/presentAppPicker/startSession/checkSessionStatus` wired |
| Sun Feb 15 |                   iOS: App Group storage |   1–2h | Shared keys + read/write utilities + debug viewer                             |
| Mon Feb 16 |     iOS: DeviceActivity extension target |   1–2h | Extension created + monitoring schedule stub                                  |
| Tue Feb 17 |              iOS: shielding apply/remove |   1–2h | Basic ManagedSettings shielding toggles during session window                 |
| Wed Feb 18 |                  iOS: violation flagging |   1–2h | Extension writes `sessionFailed` with reason to App Group                     |
| Thu Feb 19 | Flutter: native polling + fail reconcile |   1–2h | Poll `checkSessionStatus` + call `resolveSession(FAILURE)`                    |
| Fri Feb 20 |          Backend: end-to-end settle path |   1–2h | `resolveSession` writes wallet updates + session status transitions           |
| Sat Feb 21 |              Flutter: completion screens |   1–2h | Success/failure screens + redemption timer display                            |
| Sun Feb 22 |           Flutter: redemption session UI |   1–2h | Start redemption session + show expiry + results screen                       |
| Mon Feb 23 |      Backend: redemption session support |   1–2h | `type: REDEMPTION` flow supported in `startSession/resolveSession`            |
| Tue Feb 24 |         Shop: catalog + inventory schema |   1–2h | Firestore shop catalog/inventory schema + read-only UI                        |
| Wed Feb 25 |                  Shop: purchase function |   1–2h | Server purchase callable (deduct obsidian, grant cosmetic)                    |
| Thu Feb 26 |                         Flutter: shop UI |   1–2h | Catalog list + purchase flow wired                                            |
| Fri Feb 27 |                            Observability |   1–2h | Analytics events + structured logging in functions                            |
| Sat Feb 28 |              Tests: Functions unit tests |   1–2h | Unit tests for idempotency + core settlement invariants                       |
| Sun Mar 1  |            Tests: integration happy path |   1–2h | Manual test script + emulator runbook                                         |
| Mon Mar 2  |           Tests: iOS on-device checklist |   1–2h | Repeatable device test checklist for Screen Time + failure                    |
| Tue Mar 3  |                    Hardening: edge cases |   1–2h | App kill/background/relaunch reconciliation paths                             |
| Wed Mar 4  |                 App Store metadata draft |   1–2h | Skill-first description + disclosures draft + privacy checklist               |
| Thu Mar 5  |                          TestFlight prep |   1–2h | Build settings + versioning + release checklist                               |
| Fri Mar 6  |           TestFlight upload + smoke test |   1–2h | First TestFlight build uploaded + smoke test checklist                        |
| Sat Mar 7  |             App Store submission session |   1–2h | Submission checklist complete + “expected questions” answers prepared         |

After submission: plan 1–2h/day for review responses and bugfix builds.

---

## 3) Detailed plan by phase (with timelines)

### Phase 1 — Foundations (Week 1 | ~3–5 days engineering)

#### 1.1 Repository + architecture skeleton (A | 0.5–1 day)

- Establish Flutter app layers:
  - `lib/app/` (routing + app shell)
  - `lib/features/` (wallet, sessions, settings, shop)
  - `lib/services/` (firebase, api, analytics)
  - `lib/models/` (typed models)
  - `lib/state/` (state management: Riverpod or Bloc)
- Decide state mgmt (recommend: **Riverpod** for testability + modularity)
- Add environment configuration (dev/staging/prod)
- Add error reporting hooks (Crashlytics stub)

**Exit criteria**

- App launches to a placeholder home screen
- App has routing + a dependency injection/story

#### 1.2 Firebase project(s) & environments (M | 0.5–1 day + setup time)

- Create Firebase projects:
  - `focuspledge-dev`
  - `focuspledge-staging`
  - `focuspledge-prod`
- Configure iOS app IDs and download `GoogleService-Info.plist`
- Enable:
  - Firebase Auth
  - Firestore
  - Cloud Functions
  - (Optional) Cloud Storage

**Human inputs needed**

- Firebase console access
- Bundle ID finalization

**Exit criteria**

- Flutter connects to Firebase in dev
- Auth can sign-in (anonymous or Apple Sign-In stub for now)

#### 1.3 Firestore schema + Security Rules baseline (A | 0.5–1 day)

- Implement Firestore Security Rules:
  - Users can read their own user doc and session docs
  - Users cannot write wallet balances or ledger entries
  - Users can write limited “requests” collections (or call Callable Functions only)
- Choose one approach:
  - **Callable Functions only** (recommended): client never writes request docs
  - Or a `requests/` collection + triggers (more complex)

**Exit criteria**

- Rules deployed to dev
- A basic “read my profile” works
- A simulated wallet write from client is denied

#### 1.3.1 Phoenix Protocol Firestore schema (spec draft)

This schema is intentionally simple, client-readable, and server-writable. All balance mutations happen in Cloud Functions.

**Collection: `users/{uid}`**

```json
{
  "uid": "user_12345",
  "wallet": {
    "credits": 1500,
    "ash": 500,
    "obsidian": 25,
    "purgatoryVotes": 500,
    "lifetimePurchased": 5000
  },
  "status": {
    "currentTheme": "midnight_matte",
    "appIcon": "void_black",
    "streakType": "obsidian"
  },
  "deadlines": {
    "redemptionExpiry": "2026-01-25T14:30:00Z"
  }
}
```

**Collection: `sessions/{sessionId}`**

```json
{
  "sessionId": "sess_001",
  "userId": "user_12345",
  "type": "PLEDGE",
  "status": "ACTIVE",
  "pledgeAmount": 500,
  "startTime": "2026-01-25T13:30:00Z",
  "durationMinutes": 60,
  "deviceActivityToken": "...",
  "native": {
    "lastCheckedAt": "2026-01-25T13:31:00Z",
    "failureFlag": false,
    "failureReason": null
  },
  "settlement": {
    "resolvedAt": null,
    "resolvedBy": null,
    "resolution": null,
    "idempotencyKey": null
  }
}
```

**Invariants (enforced server-side)**

- Client cannot increment `users.wallet.*` fields directly.
- `sessions.status` transitions are monotonic (`ACTIVE` → `COMPLETED|FAILED`), and settlement is idempotent.
- “Credits burned” means total Credits supply decreases server-side (ledger entry represents destruction).
- Redemption eligibility is time-based using `users.deadlines.redemptionExpiry` (conversion details TBD).

#### 1.4 Cloud Functions scaffolding + deployment pipeline (A/M | 1–2 days)

- Create functions project (TypeScript):
  - Lint + test configuration
  - Shared helpers for idempotency
  - Structured logging
- Set up secrets management:
  - Stripe keys as Firebase secrets
  - Webhook signing secret
- Configure build/deploy scripts (CI-friendly)

**Exit criteria**

- `helloWorld` callable works
- Secrets access works in dev

---

### Phase 2 — Phoenix Protocol economy + session engine (Weeks 2–3 | ~6–10 days engineering)

#### 2.1 Stripe Credits packs: PaymentIntent + webhook posting (A/M | 2–3 days)

- Callable: `createCreditsPurchaseIntent(packId)`
  - Creates Stripe PaymentIntent
  - Returns client secret
  - Stores a pending purchase record keyed by idempotency
- Webhook handler:
  - Validates signature
  - Posts immutable ledger entry for `credits_purchase`
  - Updates derived `users/{uid}.wallet.credits` and `lifetimePurchased` in a Firestore transaction
- Add idempotency:
  - Stripe event ID in `stripeEvents/{eventId}`
  - Ledger `idempotencyKey` for “at most once” posting

**Human inputs needed**

- Stripe dashboard access
- Webhook endpoint configuration

**Exit criteria**

- Buy a Credits pack in test mode → `wallet.credits` updates
- Replaying the webhook does not double-credit

#### 2.2 Ledger + derived balances (A | 1–2 days)

- Implement server-only invariants for Phoenix balances:
  - Credits/Ash/Obsidian/Votes are derived from ledger entries
  - Credits can be **locked**, **refunded**, or **burned**; burning reduces total supply
- On every posted ledger entry:
  - Update balances atomically
  - Append ledger entry immutably
- Add admin correction mechanism (restricted)

**Exit criteria**

- Balance is always consistent with ledger
- Tampering attempts fail due to rules

#### 2.3 Session lifecycle + settlement: `resolveSession()` (A | 2–3 days)

- `startSession(pledgeCredits, durationMinutes, deviceId, deviceActivityToken, selectionSnapshot)`
  - Validations: pledge bounds, max 1 active session, sufficient Credits
  - Ledger: Credits **lock** (`credits_lock`)
  - Create session doc `ACTIVE`
- `heartbeatSession(sessionId, deviceId)`
  - Updates server heartbeat timestamp
- `resolveSession(sessionId, resolution, reason?, nativeEvidence?)`
  - **The only settlement pathway** (idempotent)
  - Success:
    - Ledger: unlock/refund Credits (`credits_refund`)
    - Award **Impact Points** (charity voting power)
  - Failure:
    - Ledger: burn locked Credits (`credits_burn`)
    - Grant Ash (`ash_grant`)
    - Increment `purgatoryVotes` (“Frozen Votes”)
    - Set `users/{uid}.deadlines.redemptionExpiry = now + 24h`

**Exit criteria**

- Happy path: start → heartbeat → `resolveSession(SUCCESS)` → Credits refunded + Impact Points granted
- Failure path: `resolveSession(FAILURE)` → Credits burned + Ash granted + Frozen Votes updated + deadline set
- All functions are idempotent

#### 2.4 Redemption loop (A/M | 1–2 days)

Redemption is a second-chance skill loop triggered after a failure.

- Failure creates:
  - `wallet.ash += pledgeAmount`
  - `wallet.purgatoryVotes += pledgeAmount` (Frozen Votes)
  - `deadlines.redemptionExpiry = now + 24h`
- A “Redemption Session” completed before `redemptionExpiry`:
  - Converts Ash → Obsidian (conversion details TBD)
  - Rescues Frozen Votes (policy details TBD)

**Implementation note**: treat redemption as a session type (`type: REDEMPTION`) resolved through the same `resolveSession()` machinery.

#### 2.5 Anti-cheat: scheduled expiry + server time authority (A/M | 1–2 days)

- Scheduler runs every 1–5 minutes:
  - Finds `ACTIVE` sessions whose heartbeat is stale beyond grace window
  - Resolves as failure (reason: no_heartbeat) per policy
- Ensure server-side time is authoritative:
  - End time computed from `startTime + durationMinutes`
  - Ignore client time for settlement decisions

**Exit criteria**

- Force quit app during session → session resolves after grace period
- Reopening app shows final status from server

---

### Phase 3 — iOS Screen Time enforcement (Weeks 3–5 | ~8–12 days engineering + approvals)

> This is the most complex slice. Expect iterations on real devices.

#### 3.1 Apple entitlement & capability readiness (H/M | 1 day + 1–3+ weeks lead)

- Confirm requirements for:
  - FamilyControls
  - DeviceActivity
  - ManagedSettings
- Add capability in Xcode (may require Apple approval depending on entitlement)
- Prepare justification for Apple if requested:
  - Productivity purpose
  - User-controlled selection
  - Clear disclosures

**Exit criteria**

- App can compile with frameworks and entitlements on a real device

#### 3.2 Flutter ↔ iOS plugin scaffold (A | 1–2 days)

Create a platform plugin with a MethodChannel-first API:

- `requestAuthorization()`
- `getAuthorizationStatus()`
- `presentAppPicker()`
- `startSession(sessionId, durationMinutes)` (host app sets schedule + begins monitoring)
- `stopSession(sessionId)`
- `checkSessionStatus(sessionId)` (Flutter polls; returns failure flags + reason)
- `getAppGroupState()` (debug)
- Add an App Group for shared storage between app and extensions

**Exit criteria**

- Flutter can call into Swift and receive a callback

#### 3.3 Authorization + app selection UX (A | 1–2 days)

- Implement FamilyControls authorization flow
- Implement FamilyActivityPicker
- Store selection snapshot to App Group
- Mirror selection to Firestore user settings (server-validated write)

**Exit criteria**

- User can authorize and select distracting apps on device

#### 3.4 DeviceActivity Monitor Extension (A | 2–4 days)

- Create extension target
- Start monitoring aligned to active pledge window
- Handle callbacks (interval start/end)
- Apply ManagedSettings shields during active window

**Exit criteria**

- When session starts, blocked apps show iOS shield UI
- When session ends, shields are removed

#### 3.5 Violation detection → server settlement (A | 2–3 days)

Extension writes a durable failure flag to App Group storage:

- `sessionFailed=true` (+ `reason`, + `timestamp`, + `sessionId`)

Flutter periodically polls `checkSessionStatus(sessionId)` and, on failure:

- Calls server settlement: `resolveSession(sessionId, FAILURE, reason, nativeEvidence)`

Ensure failure is robust even if the app is backgrounded:

- On next resume, app reconciles App Group state and settles server-side

**Exit criteria**

- Opening blocked app during an active session results in server failure + settlement

#### 3.6 Resilience: reboot/kill/reinstall behavior (A/H | 1–2 days)

- Re-apply shielding if server session is still active and user relaunches
- Ensure session is resolved by server scheduler if user never returns

**Exit criteria**

- No path allows escaping settlement by terminating the app

Flutter periodically polls `checkSessionStatus(sessionId)` and, on failure:

- Calls server settlement: `resolveSession(sessionId, FAILURE, reason, nativeEvidence)`

Ensure failure is robust even if the app is backgrounded:

- On next resume, app reconciles App Group state and settles server-side
  - Converts Ash → Obsidian (conversion details TBD)
  - Rescues Frozen Votes (policy details TBD)
  - Credits / Ash / Obsidian / Frozen Votes
  - Buy Credits packs (Stripe)
- Scheduler runs every 1–5 minutes:
  - Session setup: duration + pledge Credits
  - “Pulse” countdown
  - success: Credits returned + Impact Points earned
  - failure: Credits burned + Ash gained + Frozen Votes at risk + Redemption timer

#### 4.3 Obsidian shop cosmetics (A | 1–2 days)

- Obsidian balance (server-authoritative)
- Shop catalog (from Firestore config): themes, app icons, status badges
- Purchase function (server-side): deduct Obsidian, increment inventory

- User can buy a cosmetic with Obsidian

#### 4.4 Redemption UX (A | 1–2 days)

- Show redemption timer (`redemptionExpiry`) after a failed pledge
- Allow starting a Redemption Session
- On completion, show “rescued votes” outcome and any Ash→Obsidian conversion (details TBD)

**Exit criteria**

- User can complete a Redemption Session flow end-to-end

- Crashlytics + Analytics (events: credits purchase started/succeeded, session started/resolved, redemption started/resolved)

- Closed-loop economy disclosures (no cash-out, no withdrawals)
- Skill-first disclosures and copy review (avoid chance-based framing)
  - FamilyControls
  - DeviceActivity
- Production credits purchase and session settlement work end-to-end
- Add capability in Xcode (may require Apple approval depending on entitlement)
  - credits purchase intent
  - Stripe webhook handler (credits pack fulfillment)
  - session start/heartbeat
  - session settlement: `resolveSession`
  - redemption session start/settlement (via `resolveSession`)

- Shielding engages only during an active pledge window
- Violation flag is written to App Group and reliably results in server-side settlement

#### 3.2 Flutter ↔ iOS plugin scaffold (A | 1–2 days)

- Pledge session flow UI + Pulse screen
- Redemption session flow UI
- Shop + inventory (Obsidian cosmetics)

### Testing deliverables

- Rules tests covering “client can’t write balances” and session access boundaries
- Cloud Functions unit tests for idempotency + core invariants
- Manual iOS device test checklist for Screen Time enforcement + backgrounding
- Pre-submission regression checklist (happy path + failure + redemption)
- `presentAppPicker()`
- `startSession(sessionId, durationMinutes)` (host app sets schedule + begins monitoring)
- `stopSession(sessionId)`
- `checkSessionStatus(sessionId)` (Flutter polls; returns failure flags + reason)

4. **Redemption policy**

- Define precisely to avoid exploit paths (eligibility, timing, what gets rescued).

5. **Native signal handling**

- Polling (`checkSessionStatus`) vs event streams; polling is preferred for robustness.

6. **Impact Points / votes storage model**

- Per-user counters vs event-sourced vote ledger.

- **Legal/compliance ambiguity (skill vs chance framing)**
  - Mitigation: strict wording guardrails, closed-loop economy disclosures, and early review of flows/copy.
- Flutter can call into Swift and receive a callback

2. Confirm: **no withdrawals / no cash-out** (closed-loop) for v1?
3. How should **Impact Points / charity votes** be stored and tallied (per-user counter vs vote events collection)?
4. Redemption details (we can defer conversions, but should lock the shape):

- What is rescued on redemption (all Frozen Votes vs some)?
- Any cooldowns or rate limits?
- Implement FamilyActivityPicker
- Store selection snapshot to App Group
- Mirror selection to Firestore user settings (server-validated write)

**Exit criteria**

- User can authorize and select distracting apps on device

#### 3.4 DeviceActivity Monitor Extension (A | 2–4 days)

- Create extension target
- Start monitoring aligned to active pledge window
- Handle callbacks (interval start/end)
- Apply ManagedSettings shields during active window

**Exit criteria**

- When session starts, blocked apps show iOS shield UI
- When session ends, shields are removed

#### 3.5 Violation detection → server fail (A | 2–3 days)

Extension writes a durable failure flag to App Group storage:

- `sessionFailed=true` (+ `reason`, + `timestamp`, + `sessionId`)

Flutter periodically polls `checkSessionStatus(sessionId)` and, on failure:

- Calls server settlement: `resolveSession(sessionId, FAILURE, reason, nativeEvidence)`

Ensure failure is robust even if the app is backgrounded:

- On next resume, app reconciles App Group state and settles server-side

**Exit criteria**

- Opening blocked app during an active session results in server failure + settlement

#### 3.6 Resilience: reboot/kill/reinstall behavior (A/H | 1–2 days)

- Re-apply shielding if server session is still active and user relaunches
- Ensure session is resolved by server scheduler if user never returns

**Exit criteria**

- No path allows escaping settlement by terminating the app

---

### Phase 4 — Product features (Weeks 5–6 | ~5–8 days engineering)

#### 4.1 Wallet UI + history (A | 1–2 days)

- Wallet screen:
  - Credits / Ash / Obsidian / Frozen Votes
  - Buy Credits packs (Stripe)
  - Recent ledger history (read-only)
- Transaction detail view

**Exit criteria**

- User can see accurate balances + transaction history

#### 4.2 Pledge session UX (A | 1–2 days)

- Pledge setup: duration + pledge Credits
- Active session screen (“Pulse”):
  - countdown
  - explicit “skill-first” explanation of failure conditions
  - periodic heartbeat + native failure polling
- Completion screens:
  - success: Credits returned + Impact Points earned
  - failure: Credits burned + Ash gained + Frozen Votes at risk + Redemption timer

**Exit criteria**

- Clear UX flow with safe wording, no gambling framing

#### 4.3 Redemption UX (A | 1–2 days)

- After failure, show `redemptionExpiry` countdown
- Allow starting a Redemption Session
- On completion, show “rescued votes” outcome and any Ash→Obsidian conversion (details TBD)

**Exit criteria**

- User can complete a Redemption Session flow end-to-end

#### 4.4 Obsidian shop cosmetics (A | 1–2 days)

- Obsidian balance (server-authoritative)
- Shop catalog (from Firestore config): themes, app icons, status badges
- Purchase function (server-side): deduct Obsidian, grant cosmetic/inventory

**Exit criteria**

- User can buy a cosmetic with Obsidian

#### 4.5 Notifications (optional for MVP) (A/M | 1–2 days)

- Local/push notifications:
  - pledge ending soon
  - pledge resolved
  - redemption expiry reminder
- Requires APNs setup (human input)

---

### Phase 5 — Hardening, compliance, and App Store release (Weeks 6–8 | ~6–10 days + review time)

#### 5.1 Security review + threat modeling (A/H | 1–2 days)

- Threat model:
  - replay attacks
  - idempotency failures
  - client tampering
  - webhook spoofing
  - privilege escalation (rules)
- Add tests:
  - Cloud Functions unit tests
  - Rules tests
  - Flutter unit/widget tests (minimum: session UI state machine)

**Exit criteria**

- Documented threats + mitigations
- Automated tests cover core invariants

#### 5.2 Observability + incident readiness (A/M | 1–2 days)

- Crashlytics + Analytics (events: credits purchase started/succeeded, pledge started/resolved, redemption started/resolved)
- Cloud Functions alerting (error rate, webhook failures)
- Admin dashboard stub (optional)

**Exit criteria**

- Errors are visible and actionable

#### 5.3 Performance & iOS polish (A/H | 1–2 days)

- Cold start and navigation performance
- iOS-specific UX:
  - haptics
  - system fonts
  - accessibility labels

**Exit criteria**

- Smooth, native-feeling iOS experience

#### 5.4 Legal & product disclosures (H/M | 2–5 days)

- Privacy policy (Screen Time usage disclosure)
- Terms of service
- Payment/dispute policy
- Closed-loop economy disclosures (no cash-out, no withdrawals)
- Skill-first disclosures and copy review (avoid chance-based framing)

**Exit criteria**

- Legal docs ready and linked in app

#### 5.5 App Store Connect + TestFlight (H/M | 1–2 days)

- App metadata:
  - description
  - keywords
  - categories
  - age rating
- Screenshots + preview video (optional)
- Upload build to TestFlight
- Internal + external testing

**Exit criteria**

- TestFlight build distributed

#### 5.6 Production cutover (H/M | 1–2 days)

- Switch Stripe keys to production
- Confirm webhook endpoints for production
- Firebase production project locked down:
  - IAM
  - rules
  - secrets

**Exit criteria**

- Production credits purchase and session settlement work end-to-end

#### 5.7 App Store submission & review (H | 3–14 days variable)

- Submit for review
- Respond to Apple questions, especially around Screen Time usage
- Iterate on rejections quickly

**Exit criteria**

- App approved and live

---

## 4) Deliverables checklist (what “done” looks like)

### Backend deliverables

- Cloud Functions:
  - credits purchase intent
  - Stripe webhook handler (credits pack fulfillment)
  - pledge start/heartbeat
  - settlement: `resolveSession` (pledge + redemption)
  - scheduled expiry
  - shop purchase (Obsidian)
- Firestore Security Rules enforcing server-only money writes
- Rules + functions tests
- Environment separation (dev/staging/prod)

### iOS deliverables

- Screen Time authorization flow works on-device
- App picker selection persists and is used for shielding
- Shielding engages only during active pledge window
- Violation flag is written to App Group and reliably results in server-side settlement

### Flutter deliverables

- Wallet UI (balances + history)
- Pledge session flow UI + Pulse screen
- Redemption session flow UI
- Settings for distraction list
- Shop + inventory (Obsidian cosmetics)
- Robust handling of offline/resume states

### Testing deliverables

- Rules tests covering “client can’t write balances” and session access boundaries
- Cloud Functions unit tests for idempotency + core invariants
- Flutter widget tests for key screens and state transitions
- Manual iOS device test checklist for Screen Time enforcement + backgrounding
- Pre-submission regression checklist (happy path + failure + redemption)

### Release deliverables

- Privacy policy + terms accessible in-app
- Observability configured
- TestFlight and App Store submission completed

---

## 5) Key technical decisions (make early)

1. **Callable Functions vs request-doc triggers**
   - Recommendation: **Callable Functions** for simplicity and immediate responses.
2. **Idempotency strategy**
   - Required for Stripe webhooks and all settlement endpoints.
3. **Session authority**
   - Server decides success/failure/expiry.
   - Device enforces shielding and reports violations.
4. **Redemption policy**

- Define precisely to avoid exploit paths (eligibility, timing, what gets rescued).

5. **Native signal handling**

- Polling (`checkSessionStatus`) vs event streams; polling is preferred for robustness.

6. **Impact Points / votes storage model**

- Per-user counters vs event-sourced vote ledger.

---

## 6) Risks and mitigations

- **Apple Screen Time entitlement delays**
  - Mitigation: request early (Week 1). Build backend + UI while waiting.
- **Violation detection edge cases** (backgrounding, extension lifecycle)
  - Mitigation: write violations to App Group and reconcile on resume; rely on server expiry for termination.
- **Stripe webhook reliability**
  - Mitigation: idempotency + event store + alerting.
- **Rules misconfiguration**
  - Mitigation: rules unit tests + least-privilege approach.
- **Legal/compliance ambiguity (skill vs chance framing)**
  - Mitigation: strict wording guardrails, closed-loop economy disclosures, and early review of flows/copy.

---

## 7) Questions (to finalize plan and reduce rework)

1. Do you want **Apple Sign-In only**, or also email/password?
2. Confirm: **no withdrawals / no cash-out** (closed-loop) for v1?
3. How should **Impact Points / charity votes** be stored and tallied (per-user counter vs vote events collection)?
4. Redemption details (we can defer conversions, but should lock the shape):

- What is rescued on redemption (all Frozen Votes vs some)?
- Any cooldowns or rate limits?

5. What’s the target iOS minimum version? (Recommendation: iOS 16+ for modern APIs and best Screen Time behavior.)

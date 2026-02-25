# FocusPledge — iOS Development & Deployment Plan (Flutter + Firebase + Stripe + Screen Time)

**Document purpose**: a highly actionable, end-to-end checklist to build and ship FocusPledge on iOS with strong security guarantees (server-authoritative economy + session logic) and Apple Screen Time enforcement.

**Audience**: a mixed team of humans + AI agents. Each task is labeled with who can reliably complete it.

**Last updated:** February 26, 2026

**Guardrails (non-negotiable)**

- **Security first**: balances and session settlement are **server-authoritative** (Firebase Cloud Functions). The Flutter client never performs economy math.
- **Skill-first / no gambling framing**: avoid "Bet", "Gamble", "Wager", "Odds", "Jackpot", "Win money" in UI and code. Use "Pledge", "Commitment", "Credits", "Outcome", "Redemption".
- **Closed-loop arcade economy**: users buy **Focus Credits (FC)** packs; FC/Ash/Obsidian are **non-redeemable** in-app currencies (no cash-out, no withdrawals).
- **Auditability**: all balance changes are immutable ledger entries; balances are derived on the server.
- **Anti-cheat**: session state persists on the server; failure can occur even if the app is terminated.
- **Legal posture (Florida game of skill)**: the product is designed to be a **skill-based** system (user behavior/discipline) and not a game of chance; keep copy and flows aligned.

---

## Progress Summary

### ✅ Phase 1 — Foundations (COMPLETE)

- ✅ Repository initialized and pushed to GitHub: `mdbshero/FocusPledge`
- ✅ Flutter app architecture with feature-based folder structure (auth, wallet, session, shop, settings)
- ✅ Routing configuration using go_router with authentication guards
- ✅ State management setup using Riverpod
- ✅ Firebase integration (Auth, Firestore, Functions) with emulator support
- ✅ Application theme with skill-first color palette (avoiding gambling aesthetics)
- ✅ Core data models (Wallet, Session, SessionStatus, SessionType, ShopItem, ShopPurchase)
- ✅ Firebase project setup guide with dev/staging/prod environment configuration
- ✅ Firestore Security Rules enforcing server-authoritative economy (15 test cases)
- ✅ Forbidden-terms scanner and CI workflow

### ✅ Phase 2 — Phoenix Protocol Economy + Session Engine (COMPLETE)

- ✅ Cloud Functions (TypeScript): `startSession`, `resolveSession`, `heartbeatSession`
- ✅ Hardened `startSession`: ledger-driven balance checks, idempotency guards, atomic wallet updates
- ✅ `resolveSession()` with purgatoryVotes increment, redemptionExpiry deadline, full idempotency
- ✅ Incremental + full reconciliation jobs (materializes `users.wallet.credits` from `ledger/*`)
- ✅ Stripe webhook handler (`handleStripeWebhook`) with signature verification, dual idempotency
- ✅ Credits purchase intent (`createCreditsPurchaseIntent`) with pack configuration (starter/standard/value/premium)
- ✅ Scheduled session expiry job (`expireStaleSessionsScheduled`) — auto-resolves stale sessions every 5 minutes
- ✅ `handleStartSession` updated for `type: REDEMPTION` — validates expiry + purgatoryVotes
- ✅ `handleResolveSession` REDEMPTION branches (rescue votes / ash→obsidian on SUCCESS, burn votes on FAILURE)
- ✅ `handlePurchaseShopItem` Cloud Function — validates item, checks Obsidian, deducts currency, records purchase
- ✅ All backend tests passing: **21/21** (session management, Stripe, reconciliation, expiry)

### ✅ Phase 3 — iOS Screen Time Enforcement (CODE COMPLETE — needs on-device testing)

- ✅ MethodChannel scaffold with 7 core methods (auth/picker/start/stop/check/status/debug)
- ✅ App Group configuration (`group.com.focuspledge.shared`)
- ✅ AppGroupStorage.swift shared helper singleton
- ✅ FocusPledgeMonitor DeviceActivity extension (PBXNativeTarget, embedded in Runner.app/PlugIns/)
- ✅ ScreenTimeBridge.swift: startSession → App Group → DeviceActivityCenter → ManagedSettings shields
- ✅ Violation flagging: extension writes sessionFailed + reason + appBundleId to App Group
- ✅ Flutter polling: 5-second failure check → auto resolveSession(FAILURE) when violation detected
- ✅ AppDelegate.swift reconcileOnLaunch() for re-applying shields after app kill/relaunch
- ✅ Extension .appex embedded in app bundle (verified)
- ⚠️ **PENDING: On-device testing** — DeviceActivity/ManagedSettings/FamilyControls only work on real hardware, not simulator

### ✅ Phase 4 — Product Features (MOSTLY COMPLETE)

- ✅ Authentication flow with Apple Sign-In + anonymous auth
- ✅ Wallet screen with live Firestore streaming, all balances, redemption deadline warnings
- ✅ Buy Credits UI with 4-tier pack picker (Starter/Standard/Value/Premium)
- ✅ Pledge setup screen with amount/duration selection and validation
- ✅ Active session "Pulse" screen with countdown timer, heartbeat, completion flow
- ✅ Session state streaming and real-time Firestore updates
- ✅ Animated completion screens (success: credits returned; failure: Ash/Frozen Votes + redemption countdown)
- ✅ RedemptionSetupScreen with expiry countdown, stake display, duration picker, outcomes card
- ✅ Full shop UI with category-grouped grid, rarity badges, owned state, purchase confirmation
- ✅ BackendService.dart wiring (Flutter UI ↔ all Cloud Functions)
- ✅ Apple Sign-In (`sign_in_with_apple` + `crypto` packages, nonce-based OAuth flow)
- ✅ Stripe payment sheet (`flutter_stripe` package, init + present payment sheet, success/cancel/error handling)
- ✅ Tab navigation with `StatefulShellRoute.indexedStack` + `NavigationBar` (Home, Wallet, Shop, Settings)
- ✅ Dashboard / home screen (greeting, wallet summary card, quick actions, redemption warning, Focus Cycle explainer)
- ✅ Onboarding flow (3 pages: Welcome → How It Works → Screen Time Permission, with skip + `shared_preferences` persistence)
- ✅ Settings screen (account info, Apple account linking for guests, Screen Time permission status, blocked apps management, sign-out)
- ✅ Analytics service (`firebase_analytics` + `firebase_crashlytics`, 20+ event types, GoRouter navigation observer)

### 🟡 Remaining Work — What Still Needs to Be Done

#### Critical (App Store Blockers)

| Task | Status | Notes |
|------|--------|-------|
| **Apple Sign-In implementation** | ✅ Done | `sign_in_with_apple` + `crypto` packages. Nonce-based OAuth flow in `auth_provider.dart`. Display name update on first sign-in. |
| **Stripe payment sheet connection** | ✅ Done | `flutter_stripe` package. `buy_credits_screen.dart` initializes + presents Stripe payment sheet. Handles success, cancellation, and errors. Analytics events for purchase flow. |
| **On-device Screen Time testing** | ❌ Not done | All Screen Time code is built but only tested on simulator (where it's a no-op). Must validate shielding, violation detection, and reconcileOnLaunch on a real iPhone. |

#### High Priority (Required for Shippable Product)

| Task | Status | Notes |
|------|--------|-------|
| **Onboarding / first-run flow** | ✅ Done | 3-page PageView: Welcome → How It Works → Screen Time Permission. `shared_preferences` first-launch detection. Skip button + `onboardingCompleteProvider` in router. |
| **Tab navigation / shell route** | ✅ Done | `StatefulShellRoute.indexedStack` with 4 branches + `NavigationBar` (Home, Wallet, Shop, Settings). `ShellScreen` widget. Nested routes under wallet branch. |
| **Settings screen** | ✅ Done | Account info with avatar, Apple account linking for guests, Screen Time permission status + enable button, blocked apps management, sign-out with confirmation dialog. Privacy Policy + Terms links wired. |
| **Analytics & crash reporting** | ✅ Done | `AnalyticsService` with 20+ event methods. `FirebaseCrashlytics` in `main.dart`. Cloud Functions structured logging via `logger.ts`. |
| **Flutter tests** | ✅ Done | 87 tests passing: model unit tests (Wallet, Session, ShopItem, enums), format helpers, widget tests (ErrorView, LoadingView, EmptyState, BalanceChip, SectionHeader). |
| **Dashboard / home screen** | ✅ Done | `DashboardScreen` with time-based greeting, wallet summary card, quick action cards, redemption warning banner, Focus Cycle explainer, history shortcuts. |

#### Medium Priority (Polish & Completeness)

| Task | Status | Notes |
|------|--------|-------|
| **Session history view** | ✅ Done | `SessionHistoryScreen` with stats summary (total/success/failed/active, success rate bar), session list tiles. Route: `/wallet/session/history`. |
| **Transaction/ledger history** | ✅ Done | `TransactionHistoryScreen` with ledger entries, icons, amounts. Route: `/wallet/transactions`. |
| **Push notifications** | ❌ Not started | No session reminders, redemption deadline warnings, or completion alerts. Requires APNs setup (human task). |
| **Offline support / error handling** | ✅ Done | `ConnectivityNotifier` service with DNS-based check, `OfflineBanner` widget, `ShellScreen` integration. Shared error/loading/empty-state widgets. |
| **Shared/reusable widgets** | ✅ Done | `ErrorView`, `LoadingView`, `BalanceChip`, `SectionHeader`, `EmptyState`, `OfflineBanner` + `FormatHelpers` utility. |

#### Release (Pre-Submission)

| Task | Status | Notes |
|------|--------|-------|
| **Privacy policy** | ✅ Done | `docs/privacy-policy.md` + `PrivacyPolicyScreen` in-app screen. Screen Time, payments, analytics disclosures. |
| **Terms of service** | ✅ Done | `docs/terms-of-service.md` + `TermsOfServiceScreen` in-app screen. Closed-loop economy, skill-based, no cash-out. |
| **App Store metadata** | ✅ Done | `docs/app-store-metadata.md` — description, keywords, age rating, review notes, screenshot list. |
| **Cloud Functions structured logging** | ✅ Done | `functions/src/logger.ts` utility; all handlers updated with structured JSON logs. |
| **Production Firebase project** | ❌ Not started | IAM, rules deployment, secrets (human task) |
| **Production Stripe keys** | ❌ Not started | Switch from test to production, configure webhook endpoints (human task) |
| **TestFlight build** | ❌ Not started | Build settings, versioning, release checklist (human task) |

---

## Completed Work Log

### January 28, 2026

- Repository initialized and pushed to GitHub: `mdbshero/FocusPledge`
- Forbidden-terms scanner and CI workflow added
- Cloud Functions scaffold: `startSession`, `resolveSession`, `heartbeatSession`
- Hardened `startSession`: ledger-driven balance checks, idempotency, atomic wallet updates
- `resolveSession()` with purgatoryVotes, redemptionExpiry, full idempotency
- Incremental + full reconciliation jobs
- 11/11 emulator integration tests passing
- GitHub Actions workflow + README CI badge
- Stripe webhook handler with signature verification, dual idempotency
- Credits purchase intent with pack configuration
- Scheduled session expiry job (5-min interval, 50 sessions/batch)
- All specification documents completed (Stripe, iOS native bridge, Flutter UX, repo scaffolding)

### January 29, 2026

- Firebase project setup guide (dev/staging/prod)
- Flutter app architecture (feature-based folder structure)
- Routing (go_router) + authentication guards
- Riverpod state management
- Firebase integration with emulator support
- Application theme (skill-first color palette)
- Core data models (Wallet, Session, SessionStatus, SessionType)
- Firestore Security Rules + 15 test cases
- Placeholder screens for all main features

### February 9–14, 2026

- Authentication flow (Apple Sign-In stub + anonymous auth)
- Wallet screen with live Firestore streaming
- Buy Credits UI (4-tier pack picker + Stripe backend stub)
- Pledge setup screen (amount/duration selection)
- Active session "Pulse" screen (countdown, heartbeat, completion)
- Session state streaming + real-time Firestore updates
- TypeScript type fixes in Cloud Functions
- MethodChannel scaffold (7 core methods + App Group config)
- Platform availability guards for iOS 16+

### February 16–17, 2026

- Fixed SIGABRT crash from duplicate Firebase initialization
- BackendService.dart wiring (all Cloud Functions callable from UI)
- AppGroupStorage.swift singleton
- FocusPledgeMonitor DeviceActivity extension (full Xcode target)
- ScreenTimeBridge.swift rewrite (real implementation)
- Flutter session lifecycle wiring (native polling + auto-resolve)
- AppDelegate.swift reconcileOnLaunch()
- Buy credits Row overflow fix
- App builds and runs on iPhone 16e simulator with Firebase emulators

### February 21, 2026

- Animated completion screens (success/failure with transitions)
- Live countdown timer from `redemptionExpiryProvider`
- RedemptionSetupScreen (expiry countdown, stake display, duration picker, outcomes card)
- Route registered: `/session/redemption-setup`
- `handleStartSession` updated for `type: REDEMPTION`
- `handleResolveSession` REDEMPTION branches (rescue votes, ash→obsidian, burn votes)
- BackendService.startRedemptionSession() Flutter wrapper
- Pledge FAILURE branch now also increments materialized `wallet.ash`
- ShopItem/ShopPurchase models
- Shop providers (catalog, purchases, owned items)
- `handlePurchaseShopItem` Cloud Function
- Full shop UI (catalog grid, rarity badges, purchase flow)

### February 25, 2026

- **Apple Sign-In** — `sign_in_with_apple` + `crypto` packages added; full nonce-based OAuth flow in `auth_provider.dart`; display name update on first sign-in; `signInWithApple()` button on sign-in screen with analytics tracking
- **Stripe Payment Sheet** — `flutter_stripe` package added; `buy_credits_screen.dart` now initializes + presents native Stripe payment sheet; handles success, user cancellation (`StripeException`), and errors; analytics events for purchase start/complete/cancel
- **Tab Navigation + Shell Route** — `StatefulShellRoute.indexedStack` with 4 branches (Home, Wallet, Shop, Settings); `ShellScreen` with `NavigationBar`; wallet sub-routes nested (`/wallet/buy-credits`, `/wallet/session/setup`, etc.)
- **Dashboard / Home Screen** — `DashboardScreen` with time-based greeting, wallet summary card (all 4 balances), quick action cards (Start Session, Buy Credits, Redeem Ash), redemption warning banner with countdown, Focus Cycle explainer
- **Onboarding Flow** — 3-page `PageView`: Welcome → How It Works → Screen Time Permission; first-launch detection via `shared_preferences`; skip button; `onboardingCompleteProvider` in router redirect logic
- **Settings Screen** — Full implementation replacing stub: account info with avatar, Apple account linking for guest users, Screen Time permission status + enable button, blocked apps management, version info, terms/privacy placeholders, sign-out with confirmation dialog
- **Analytics + Crash Reporting** — `AnalyticsService` with 20+ event methods (auth, session, purchase, redemption, shop, onboarding, screen time); `FirebaseCrashlytics` fatal error recording in `main.dart`; `FirebaseAnalyticsObserver` on GoRouter; `FirebaseService` updated with analytics + crashlytics accessors
- **Packages added:** `sign_in_with_apple`, `crypto`, `flutter_stripe`, `shared_preferences`, `firebase_analytics`, `firebase_crashlytics`
- Zero compile errors, `flutter analyze --no-fatal-infos` clean

### February 26, 2026

- **Shared Reusable Widgets** — Created 6 widgets + 1 utility: `ErrorView`, `LoadingView`, `BalanceChip` (with factory constructors for Credits/Ash/Obsidian/FrozenVotes), `SectionHeader`, `EmptyState`, `OfflineBanner` in `lib/shared/widgets/`; `FormatHelpers` utility in `lib/shared/utils/` with duration/countdown/relativeTime/shortDateTime/statusColor/sessionTypeIcon
- **Session History Screen** — `SessionHistoryScreen` with stats summary (total/success/failed/active counts, success rate progress bar) and session list tiles with status badges. New providers: `sessionHistoryProvider`, `completedSessionCountProvider`, `failedSessionCountProvider`, `LedgerEntry` class + `ledgerHistoryProvider`
- **Transaction History Screen** — `TransactionHistoryScreen` with ledger entry list showing icon, description, timestamp, +/- amount. Route: `/wallet/transactions`
- **Offline Support** — `ConnectivityNotifier` (StateNotifier checking DNS every 10s) + `connectivityProvider`; `OfflineBanner` widget with retry button; `ShellScreen` integration showing banner when offline
- **Navigation Links** — Added Session History + Transaction History shortcut buttons to both `WalletScreen` and `DashboardScreen`
- **Flutter Tests** — 87 tests passing: model tests (Wallet serialization/copyWith, Session enums/status, ShopItem enums/constructors), format helper tests, widget tests (ErrorView, LoadingView, EmptyState, BalanceChip, SectionHeader). Replaced stale default counter test.
- **Cloud Functions Structured Logging** — Created `functions/src/logger.ts` (JSON structured logs with severity/timestamp/context). Updated all handlers: `resolveSession`, `startSession`, `purchaseShopItem`, `expireStaleSessions`, `createCreditsPurchaseIntent`, `stripeWebhook` + payment event handlers. TypeScript compiles clean.
- **Privacy Policy** — `docs/privacy-policy.md` + `PrivacyPolicyScreen` in-app screen. Covers: Screen Time data (on-device only), Firebase Auth/Firestore/Analytics, Stripe payments, virtual currency disclaimer, children's privacy, data rights.
- **Terms of Service** — `docs/terms-of-service.md` + `TermsOfServiceScreen` in-app screen. Covers: skill-based system, closed-loop economy, no cash-out, session rules, prohibited conduct, liability.
- **App Store Metadata** — `docs/app-store-metadata.md` — app name, subtitle, category, full description, keywords, age rating, App Review notes (skill-based not gambling), screenshot list.
- **Settings Screen Updated** — Terms of Service and Privacy Policy links now navigate to in-app screens instead of TODO placeholders.
- **Routes Added** — `/wallet/session/history`, `/wallet/transactions`, `/settings/privacy-policy`, `/settings/terms-of-service`
- **Package added:** `intl` (for DateFormat in format helpers)

---

## Terminology

- **Approved terms:** Focus Credits (FC), Ash, Obsidian, Frozen Votes, Redemption Session, Pledge Session, Impact Points, Credits pack.
- **Forbidden terms (do not use in UI or copy):** Bet, Gamble, Wager, Odds, Jackpot, Win money, Prize, Betting.
- **Tone guideline:** Use "pledge", "commitment", "credits", "outcome", "redemption" — emphasize skill, discipline, and closed-loop economy.
- **Currency rule:** Focus Credits (FC) are strictly in-app, non-redeemable credits. All balance math must be server-authoritative.

### Replacement mappings

- **User-facing:** Bet/Gamble/Wager/Betting → Pledge/Commitment | Odds/Win money/Prize/Jackpot → Outcome/Result/Redemption
- **Code identifiers:** bet_amount/wager/jackpotReward → pledge_amount/commitmentAmount/redemptionReward | Use focusCredits, ashBalance, obsidianBalance, frozenVotes

---

## Assumptions & Scope

### Assumptions

- Target platforms: **iOS first** (iPhone). iPad optional later.
- In-app economy: **Focus Credits (FC)** purchased via Stripe. Reference rate: **100 FC = $1.00**.
- Stripe mode: start in **test mode**, switch to production after validation.
- Firebase: Auth + Firestore + Cloud Functions + Cloud Scheduler.
- Screen Time: FamilyControls + DeviceActivity + ManagedSettings.

### MVP definition (ship-worthy)

1. ✅ Sign-in (anonymous + Apple Sign-In implemented)
2. ✅ Purchase Focus Credits packs (backend + Stripe payment sheet connected)
3. ✅ Display wallet: Credits, Ash, Obsidian, Frozen Votes
4. ✅ Create a pledge session (pledge Credits + duration)
5. ✅ Enforce distraction blocking (Screen Time shielding) — **needs on-device testing**
6. ✅ Auto-resolve success/failure on server (ledger + Phoenix Protocol)
7. ✅ Redemption loop (Redemption Session within 24h, rescue Frozen Votes, Ash → Obsidian)
8. ✅ Basic shop: buy cosmetics using Obsidian
9. ✅ Minimal analytics + crash reporting (Firebase Analytics + Crashlytics configured)

---

## Firestore Schema & Invariants

Collections (minimal set):

- **`users/{uid}`** (readable by user)
  - `uid: string`
  - `wallet: { credits, ash, obsidian, purgatoryVotes, lifetimePurchased }`
  - `deadlines: { redemptionExpiry?: timestamp }`
  - `status: { currentTheme?, appIcon? }`
  - Note: `wallet.*` is derived and only writable by server functions.

- **`sessions/{sessionId}`**
  - `sessionId`, `userId`, `type` (PLEDGE|REDEMPTION), `status` (ACTIVE|COMPLETED|FAILED)
  - `pledgeAmount`, `durationMinutes`, `startTime`, `endTime?`
  - `native: { lastCheckedAt?, failureFlag?, failureReason? }`
  - `settlement: { resolvedAt?, resolvedBy?, resolution?, idempotencyKey? }`

- **`ledger/{entryId}`** (immutable event store)
  - `entryId`, `userId`, `kind`, `amount`, `metadata`, `createdAt`, `idempotencyKey`
  - Kinds: `credits_purchase`, `credits_lock`, `credits_burn`, `credits_refund`, `ash_grant`, `obsidian_grant`, `ash_to_obsidian_conversion`, `frozen_votes_rescue`, `frozen_votes_burn`, `obsidian_spend`

- **`stripeEvents/{eventId}`** — processed Stripe event IDs (idempotency)
- **`paymentIntents/{paymentIntentId}`** — pending/fulfilled purchases
- **`shop/catalog/items/{itemId}`** + **`shop/purchases/records/{purchaseId}`**
- **`reconcile_state/incremental`** — resume token for paged reconciliation

Security invariants:

- Clients may read their own `users/{uid}` and `sessions/{sessionId}` documents
- Clients may NOT write to `users.wallet.*` or `ledger/*`
- `sessions.status` transitions are monotonic: only `ACTIVE` → `COMPLETED|FAILED`
- All settlement operations are idempotent with `idempotencyKey`

---

## Task Taxonomy

### AI-agent-reliable tasks (A)

- Flutter/Dart implementation and refactors
- Cloud Functions code (TypeScript) and Firestore rules drafts
- Unit/integration tests scaffolding
- Static analysis, linting, formatting
- Documentation
- CI pipeline configuration

### Human-required tasks (H)

- Apple Developer account and App Store Connect configuration
- Screen Time entitlements (if Apple approval required)
- Stripe account activation and production key management
- Real device testing on multiple iOS versions
- Legal review: privacy policy/terms, payment disclosures
- App Store screenshots, marketing copy, submission

### Mixed tasks (M)

- Firebase project creation + secrets provisioning
- Stripe dashboard configuration (webhook endpoints)
- App Store Connect setup steps

---

## Daily Sessions Plan (remaining work)

All sessions prior to Feb 25 are **complete** (see Completed Work Log above).

| Date | Task | Time | Deliverable |
|------|------|------|-------------|
| **Wed Feb 25** | ✅ Apple Sign-In implementation | 1–2h | `sign_in_with_apple` + `crypto` wired, nonce OAuth flow, sign-in screen updated |
| **Thu Feb 26** | ✅ Stripe payment sheet connection | 1–2h | `flutter_stripe` integrated, payment sheet init/present, success/cancel/error handling |
| **Fri Feb 27** | ✅ Tab navigation + shell route | 1–2h | `StatefulShellRoute.indexedStack` + `NavigationBar` (Home, Wallet, Shop, Settings) |
| **Sat Feb 28** | ✅ Dashboard / home screen | 1–2h | Wallet summary card, quick actions, redemption warning, Focus Cycle explainer |
| **Sun Mar 1** | ✅ Onboarding flow (3 screens) | 1–2h | Welcome → How It Works → Screen Time Permission. `shared_preferences` + skip logic |
| **Mon Mar 2** | ✅ Settings screen implementation | 1–2h | Account info, Screen Time status, blocked apps, Apple linking, sign-out |
| **Tue Mar 3** | ✅ Analytics + crash reporting | 1–2h | `AnalyticsService` (20+ events) + `FirebaseCrashlytics` + GoRouter observer |
| **Wed Mar 4** | Flutter tests — models + providers | 1–2h | Unit tests for Wallet, Session, ShopItem models. Provider tests for wallet, auth |
| **Thu Mar 5** | Flutter tests — widget tests | 1–2h | Widget tests for pledge setup, active session, completion screens |
| **Fri Mar 6** | Session history + transaction history | 1–2h | Past sessions list screen, ledger/transaction history on wallet |
| **Sat Mar 7** | On-device Screen Time testing (H) | 1–2h | Test shielding, violation detection, reconcileOnLaunch on real iPhone hardware |
| **Sun Mar 8** | Hardening: edge cases | 1–2h | App kill/background/relaunch reconciliation, offline handling, error states |
| **Mon Mar 9** | Observability: Cloud Functions logging | 1–2h | Structured logging in functions, error alerting configuration |
| **Tue Mar 10** | App Store metadata draft | 1–2h | Skill-first description, keywords, categories, age rating, privacy checklist |
| **Wed Mar 11** | Legal: privacy policy + terms | 1–2h | Privacy policy (Screen Time disclosure), terms of service, closed-loop disclosures |
| **Thu Mar 12** | Production Firebase + Stripe cutover | 1–2h | Production project, deploy rules, set secrets, switch Stripe keys, configure webhook endpoints |
| **Fri Mar 13** | TestFlight prep + upload | 1–2h | Build settings, versioning, first TestFlight build uploaded |
| **Sat Mar 14** | TestFlight smoke testing | 1–2h | Full regression: sign-in → buy credits → pledge → session → resolve → redemption → shop |
| **Sun Mar 15** | App Store submission session | 1–2h | Submission checklist, review notes explaining skill-based economy, expected questions prepared |

After submission: plan 1–2h/day for review responses and bugfix builds.

---

## Detailed Plan by Phase

### ✅ Phase 1 — Foundations (COMPLETE)

#### ✅ 1.1 Repository + architecture skeleton

- Flutter app layers: `lib/app/`, `lib/features/`, `lib/services/`, `lib/models/`, `lib/shared/`
- State management: Riverpod
- Environment configuration (dev + emulator support)

#### ✅ 1.2 Firebase project(s) & environments

- Firebase project configured with emulator support
- GoogleService-Info.plist for emulator config (demo-focuspledge)
- Auth, Firestore, Cloud Functions enabled

#### ✅ 1.3 Firestore schema + Security Rules

- Callable Functions approach (client never writes request docs)
- Security Rules deployed with 15 test cases
- Server-authoritative wallet writes enforced

#### ✅ 1.4 Cloud Functions scaffolding + deployment pipeline

- TypeScript functions project with lint + test
- Firebase emulator integration verified
- GitHub Actions CI workflow

---

### ✅ Phase 2 — Phoenix Protocol Economy + Session Engine (COMPLETE)

#### ✅ 2.1 Stripe Credits packs: PaymentIntent + webhook

- `createCreditsPurchaseIntent(packId)` — 4 packs (starter/standard/value/premium)
- `handleStripeWebhook()` — signature verification + dual idempotency (event ID + PaymentIntent ID)
- Tests: 6/6 passing

#### ✅ 2.2 Ledger + derived balances

- Immutable ledger entries for all balance changes
- Full + incremental reconciliation jobs
- Tests: 3/3 passing

#### ✅ 2.3 Session lifecycle + settlement

- `startSession` — ledger-driven balance check, `credits_lock`, idempotency
- `heartbeatSession` — server timestamp update
- `resolveSession` — SUCCESS (credits_refund) and FAILURE (credits_burn + ash_grant + purgatoryVotes + redemptionExpiry)
- Tests: 8/8 passing

#### ✅ 2.4 Redemption loop

- `type: REDEMPTION` in startSession (validates expiry + purgatoryVotes > 0)
- REDEMPTION SUCCESS: rescue Frozen Votes, Ash → Obsidian (1:1), clear deadline
- REDEMPTION FAILURE: burn Frozen Votes permanently, clear deadline

#### ✅ 2.5 Anti-cheat: scheduled expiry

- `expireStaleSessionsScheduled` runs every 5 minutes
- Auto-resolves ACTIVE sessions with stale heartbeats (>10min grace) as FAILURE
- Tests: 4/4 passing

---

### ✅ Phase 3 — iOS Screen Time Enforcement (CODE COMPLETE — awaiting device testing)

#### ✅ 3.1 Apple entitlement & capability readiness

- FamilyControls, DeviceActivity, ManagedSettings frameworks added
- Entitlements configured for app + extension
- Deployment target: iOS 16.0

#### ✅ 3.2 Flutter ↔ iOS plugin scaffold

- MethodChannel with 7 methods: `requestAuthorization`, `getAuthorizationStatus`, `presentAppPicker`, `startSession`, `stopSession`, `checkSessionStatus`, `getAppGroupState`
- App Group: `group.com.focuspledge.shared`

#### ✅ 3.3 Authorization + app selection UX

- FamilyControls authorization flow implemented
- FamilyActivityPicker for app selection
- Selection stored in App Group

#### ✅ 3.4 DeviceActivity Monitor Extension

- FocusPledgeMonitor extension target in Xcode
- `intervalDidStart` → apply shields, `intervalDidEnd` → remove shields, `eventDidReachThreshold` → flag violation
- Embedded in Runner.app/PlugIns/

#### ✅ 3.5 Violation detection → server settlement

- Extension writes `sessionFailed=true` + reason + appBundleId to App Group
- Flutter polls every 5 seconds, auto-calls `resolveSession(FAILURE)` on detection

#### ✅ 3.6 Resilience: reboot/kill/reinstall

- `reconcileOnLaunch()` in AppDelegate re-applies shields if active session exists
- Server scheduler resolves sessions if user never returns

#### ⚠️ 3.7 On-device validation (PENDING — requires real hardware)

- [ ] Verify shielding appears on blocked apps during session
- [ ] Verify violation flag is written when user attempts to bypass
- [ ] Verify reconcileOnLaunch re-shields after force quit
- [ ] Verify session resolves after heartbeat staleness (app killed entirely)
- [ ] Test on iOS 16, 17, and 18 if possible

---

### Phase 4 — Product Features (PARTIALLY COMPLETE)

#### ✅ 4.1 Wallet UI

- ✅ Wallet screen with Credits, Ash, Obsidian, Frozen Votes balances
- ✅ Live Firestore streaming
- ✅ Redemption deadline warning banner with "Start Redemption" CTA
- ⬜ Transaction/ledger history view

#### ✅ 4.2 Pledge session UX

- ✅ Pledge setup: duration + pledge Credits selection
- ✅ Active session "Pulse" screen with countdown timer + heartbeat
- ✅ Native failure polling (5s interval) + auto-resolution
- ✅ Animated completion screens (success + failure)

#### ✅ 4.3 Redemption UX

- ✅ RedemptionSetupScreen with expiry countdown, stake display, duration picker
- ✅ Outcomes card explaining success vs failure
- ✅ "Start Redemption" button on wallet warning banner

#### ✅ 4.4 Obsidian shop cosmetics

- ✅ Shop catalog from Firestore with category-grouped grid
- ✅ Rarity badges, owned state, Obsidian balance chip
- ✅ Purchase confirmation dialog + `handlePurchaseShopItem` Cloud Function

#### ✅ 4.5 Apple Sign-In (DONE)

- `sign_in_with_apple` + `crypto` packages added to `pubspec.yaml`
- Nonce-based OAuth flow: generate nonce → SHA256 hash → `getAppleIDCredential` → `OAuthProvider` credential → `signInWithCredential`
- Display name update on first sign-in (Apple only sends name once)
- Sign-in screen updated with Apple Sign-In as primary button
- Analytics tracking: `AnalyticsService.logSignIn(method: 'apple')`

#### ✅ 4.6 Stripe Payment Sheet (DONE)

- `flutter_stripe` package added; Stripe publishable key initialized in `main.dart`
- `buy_credits_screen.dart` calls `createCreditsPurchaseIntent` → `initPaymentSheet` → `presentPaymentSheet`
- Handles: success (pop back + snackbar), cancellation (`StripeException` with `FailureCode.Canceled`), errors
- Analytics events: `logPurchaseStart`, `logPurchaseComplete`, `logPurchaseCancelled`

#### ✅ 4.7 Tab Navigation + Dashboard (DONE)

- `StatefulShellRoute.indexedStack` with 4 `StatefulShellBranch` branches
- `ShellScreen` with Material 3 `NavigationBar` (Home, Wallet, Shop, Settings)
- Wallet sub-routes nested: `/wallet/buy-credits`, `/wallet/session/setup`, `/wallet/session/active/:id`, `/wallet/session/redemption-setup`
- `DashboardScreen`: time-based greeting, wallet summary (all 4 balances), quick action cards, redemption warning banner, Focus Cycle explainer

#### ✅ 4.8 Onboarding Flow (DONE)

- 3-page `PageView` with `PageController`: Welcome → How It Works → Screen Time Permission
- Skip button on all pages → `completeOnboarding()`
- First-launch detection: `shared_preferences` `onboarding_complete` flag
- `onboardingCompleteProvider` checked in router redirect logic
- Screen Time permission page: request authorization + status display + "Continue without" fallback

#### ✅ 4.9 Settings Screen (DONE)

- Full replacement of stub implementation
- Account section: avatar, display name / email, guest indicator
- Apple account linking card for anonymous users (calls `signInWithApple`)
- Screen Time section: permission status (approved/denied/not configured) + enable button + blocked apps management
- About section: version, terms of service, privacy policy (placeholder taps)
- Sign-out with confirmation dialog warning about guest progress loss

#### ⬜ 4.10 Session History (NOT DONE — Medium)

- No way to view past sessions
- Need a list of completed/failed sessions with details

#### ⬜ 4.11 Notifications (optional for MVP)

- Local/push notifications for session events, redemption deadlines
- Requires APNs setup (human task)

---

### Phase 5 — Hardening, Compliance, and App Store Release (NOT STARTED)

#### ⬜ 5.1 Security review + threat modeling (A/H | 1–2 days)

- Threat model: replay attacks, idempotency failures, client tampering, webhook spoofing
- Add tests: Cloud Functions unit tests, Flutter widget tests
- Document threats + mitigations

#### ⬜ 5.2 Observability + incident readiness (A/M | 1–2 days)

- ✅ Firebase Analytics events in Flutter: 20+ event types (auth, session, purchase, redemption, shop, onboarding)
- ✅ Crashlytics integration for crash reporting (fatal error recording in main.dart)
- ✅ GoRouter navigation observer (FirebaseAnalyticsObserver)
- ⬜ Cloud Functions structured logging + error alerting

#### ⬜ 5.3 Performance & iOS polish (A/H | 1–2 days)

- Cold start optimization
- iOS-specific UX: haptics, system fonts, accessibility labels
- Loading skeleton screens, unified error widgets

#### ⬜ 5.4 Legal & product disclosures (H/M | 2–5 days)

- Privacy policy (Screen Time usage disclosure)
- Terms of service
- Payment/dispute policy
- Closed-loop economy disclosures (no cash-out, no withdrawals)
- Skill-first disclosures (avoid chance-based framing)

#### ⬜ 5.5 App Store Connect + TestFlight (H/M | 1–2 days)

- App metadata: description, keywords, categories, age rating
- Screenshots + preview video (optional)
- Upload build to TestFlight
- Internal + external testing

#### ⬜ 5.6 Production cutover (H/M | 1–2 days)

- Switch Stripe keys to production
- Confirm webhook endpoints
- Firebase production project: IAM, rules, secrets

#### ⬜ 5.7 App Store submission & review (H | 3–14 days variable)

- Submit for review
- Respond to Apple questions (especially Screen Time usage)
- Iterate on rejections

---

## Deliverables Checklist

### Backend deliverables

- [x] Cloud Functions: credits purchase intent
- [x] Cloud Functions: Stripe webhook handler
- [x] Cloud Functions: pledge start/heartbeat
- [x] Cloud Functions: `resolveSession` (pledge + redemption)
- [x] Cloud Functions: scheduled expiry
- [x] Cloud Functions: shop purchase (Obsidian)
- [x] Firestore Security Rules (server-only money writes)
- [x] Rules + functions tests (21/21 passing)
- [ ] Environment separation (dev/staging/prod — dev only currently)
- [ ] Structured logging + alerting in Cloud Functions

### iOS deliverables

- [x] Screen Time authorization flow (code complete)
- [x] App picker selection + App Group storage
- [x] Shielding via ManagedSettings during sessions
- [x] Violation flagging to App Group
- [x] Extension .appex embedded in bundle
- [ ] On-device validation on real hardware
- [ ] Multi-iOS-version testing (16, 17, 18)

### Flutter deliverables

- [x] Wallet UI (balances + redemption warnings)
- [x] Pledge session flow + Pulse screen
- [x] Redemption session flow
- [x] Shop + inventory (Obsidian cosmetics)
- [x] Completion screens (animated success/failure)
- [x] Apple Sign-In implementation
- [x] Stripe payment sheet integration
- [x] Tab navigation (ShellRoute + NavigationBar)
- [x] Dashboard / home screen
- [x] Onboarding flow (3 screens)
- [x] Settings screen (account, blocked apps, sign-out)
- [ ] Session history view
- [ ] Transaction/ledger history
- [ ] Offline handling / error states
- [ ] Reusable shared widgets

### Testing deliverables

- [x] Firestore Security Rules tests (15 cases)
- [x] Cloud Functions emulator tests (21/21)
- [ ] Flutter model unit tests
- [ ] Flutter provider tests
- [ ] Flutter widget tests (key screens)
- [ ] Manual iOS device test checklist
- [ ] Pre-submission regression checklist

### Release deliverables

- [ ] Privacy policy + terms accessible in-app
- [x] Observability configured (Analytics + Crashlytics on Flutter side)
- [ ] Production Firebase + Stripe cutover
- [ ] TestFlight build distributed
- [ ] App Store submission completed

---

## Key Technical Decisions (Made)

1. **Callable Functions** — client never writes request docs directly
2. **Idempotency strategy** — `sessionId + idempotencyKey` for sessions; dual check (event ID + PaymentIntent ID) for Stripe
3. **Session authority** — server decides success/failure/expiry; device enforces shielding and reports violations
4. **Redemption policy** — all Frozen Votes rescued on redemption SUCCESS; all burned on FAILURE; Ash → Obsidian 1:1
5. **Native signal handling** — polling (`checkSessionStatus` every 5s) for robustness
6. **State management** — Riverpod with stream-based Firestore providers

---

## Risks and Mitigations

- **Apple Screen Time entitlement delays** — Code is built, needs device testing. Plan for iteration.
- **Violation detection edge cases** (backgrounding, extension lifecycle) — Writes to App Group + reconcileOnLaunch + server expiry scheduler.
- **Stripe webhook reliability** — Dual idempotency + event store + alerting.
- **Rules misconfiguration** — 15 rules unit tests + least-privilege approach.
- **Legal/compliance (skill vs chance framing)** — Strict wording guardrails, forbidden-terms CI scanner, closed-loop economy disclosures.
- **~~Apple Sign-In not implemented~~** — ✅ Resolved. Full nonce-based OAuth flow implemented with `sign_in_with_apple` package.

---

## Open Questions

1. ~~Do you want **Apple Sign-In only**, or also keep email/password + anonymous?~~ → **Decided:** Apple Sign-In (primary) + anonymous/guest (for testing). Email/password available but not prominent.
2. How should **Impact Points / charity votes** be stored and tallied?
3. What's the target iOS minimum version? (Currently: iOS 16+ for Screen Time APIs)
4. Any cooldowns or rate limits on redemption sessions?

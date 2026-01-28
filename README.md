# FocusPledge

![Functions Emulator Tests](https://github.com/mdbshero/FocusPledge/actions/workflows/functions-emulator-tests.yml/badge.svg)

**A skill-based focus commitment app leveraging iOS Screen Time API, Flutter, Firebase, and Stripe.**

FocusPledge helps users build discipline by pledging Focus Credits on timed focus sessions. Success means getting your credits back. Failure means they're burned—but you earn Ash for a second chance through Redemption Sessions.

---

## 🚀 Project Status (January 28, 2026)

**Backend:** ✅ Core complete (21/21 tests passing)  
**Frontend:** 🔜 Starting Flutter UI (Week 2)  
**iOS Native:** 🔜 Screen Time integration (Week 3)

### Completed Features

- ✅ Session management (start/heartbeat/resolve with full idempotency)
- ✅ Stripe integration (webhook + purchase intent with dual idempotency)
- ✅ Ledger-based economy (server-authoritative balances)
- ✅ Reconciliation jobs (full + incremental paged)
- ✅ Scheduled expiry job (auto-resolve stale sessions)
- ✅ Comprehensive test suite (21 passing tests with Firebase emulators)

### Next Up

- Security rules + tests (Sat Feb 7)
- Flutter app architecture (Sun Feb 8)
- Auth flow + wallet UI (Week 2)
- iOS Screen Time integration (Week 3)

---

## 📚 Documentation

**Development Plan:**

- [iOS Development Plan](docs/ios-development-plan.md) - Complete build & ship roadmap
- [Backend Implementation Status](docs/backend-implementation-status.md) - Detailed feature completion tracking

**Specifications:**

- [Stripe Integration Spec](docs/stripe-integration-spec.md) - Payment flow & fulfillment
- [iOS Native Bridge Spec](docs/ios-native-bridge-spec.md) - MethodChannel API design
- [Flutter UX Spec](docs/flutter-ux-spec.md) - 18-screen UX map with copy guidelines
- [Repo Scaffolding Checklist](docs/repo-scaffolding-checklist.md) - Firebase & tooling setup

---

## 🏗️ Architecture

### Tech Stack

- **Frontend:** Flutter (iOS focus, with future Android/Web support)
- **Backend:** Firebase Cloud Functions (TypeScript)
- **Database:** Cloud Firestore (Native mode)
- **Payments:** Stripe (iOS SDK + webhook fulfillment)
- **Native:** Swift (Screen Time API via MethodChannel)
- **CI/CD:** GitHub Actions

### Key Design Principles

1. **Server-Authoritative Economy**: All balance calculations happen server-side. Clients never write to wallet fields.
2. **Ledger-Based Accounting**: Immutable append-only log of all balance changes. Balances are materialized views.
3. **Idempotency Everywhere**: Duplicate requests (session starts, settlements, webhooks) are handled safely.
4. **Skill-First Framing**: Avoid gambling terminology. Use "pledge", "commitment", "credits", "redemption".
5. **Closed-Loop Economy**: Focus Credits (FC), Ash, and Obsidian are non-redeemable in-app currencies.

---

## 🧪 Testing

### Run Backend Tests

```bash
cd functions
npm install
npm run test:emulator
```

**Current Results:** ✅ 21/21 passing

**Test Coverage:**

- Session lifecycle (start/heartbeat/resolve): 8 tests
- Stripe integration (webhook/purchase): 6 tests
- Reconciliation (full/incremental): 3 tests
- Scheduled jobs (expiry): 4 tests

---

## 🔐 Security & Compliance

- **Data Privacy**: Compliant with iOS data handling requirements
- **No Gambling**: Skill-based system with deterministic outcomes
- **Forbidden Terms**: Automated scanner blocks "bet", "gamble", "wager", "odds", "jackpot"
- **Closed-Loop**: No cash-out or withdrawal features
- **Florida Legal Posture**: Designed as game of skill (user discipline), not chance

---

## 📋 Development Workflow

### Daily Schedule (Week 1-2)

Tracked in [ios-development-plan.md](docs/ios-development-plan.md) with 1-2 hour daily tasks:

- **Week 1 (Complete)**: Backend functions + Stripe + tests
- **Week 2 (Current)**: Flutter app architecture + wallet/auth/pledge UI
- **Week 3**: iOS Screen Time integration + native bridge
- **Weeks 4-6**: Product features + polish
- **Weeks 6-8**: Hardening + App Store submission

---

## 🚢 Deployment

### Firebase Projects

- `focuspledge-dev` - Development environment
- `focuspledge-staging` - Pre-production testing
- `focuspledge-prod` - Production (when ready)

### Required Secrets

Configure via `firebase functions:secrets:set`:

- `STRIPE_SECRET_KEY` - Stripe API key
- `STRIPE_WEBHOOK_SECRET` - Webhook signing secret

### Deploy Functions

```bash
cd functions
npm run build
firebase deploy --only functions
```

---

## 📱 App Store Requirements

- [ ] Apple Developer account (human required)
- [ ] FamilyControls entitlement request (Apple approval)
- [ ] DeviceActivity entitlement request (Apple approval)
- [ ] Privacy policy hosted URL
- [ ] App Store metadata with skill-first framing
- [ ] TestFlight beta testing
- [ ] App Store submission

---

## 🤝 Contributing

This project uses a mixed human + AI agent workflow. See [ios-development-plan.md](docs/ios-development-plan.md) for task taxonomy (which tasks are AI-reliable vs human-required).

**Code Standards:**

- TypeScript for Cloud Functions
- Dart/Flutter for mobile app
- Swift for iOS native extensions
- All commits go through automated tests
- Forbidden-terms scanner blocks gambling language

---

## 📄 License

[License TBD - Placeholder]

---

## 🔗 Links

- **Repository:** [github.com/mdbshero/FocusPledge](https://github.com/mdbshero/FocusPledge)
- **CI/CD:** [GitHub Actions](https://github.com/mdbshero/FocusPledge/actions)
- **Backend Status:** [Implementation Status Doc](docs/backend-implementation-status.md)

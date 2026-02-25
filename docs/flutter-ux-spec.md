# Flutter UX Specification — Screen Map & Copy Checklist

**Document purpose:** Comprehensive screen-by-screen UX specification with state transitions, skill-first copy guidelines, and anti-gambling framing compliance.

**Last updated:** February 26, 2026

**Implementation status:** All core screens implemented. Auth (Apple Sign-In + anonymous), wallet, buy credits (Stripe payment sheet), pledge setup, active session with Pulse countdown, redemption setup, shop, dashboard home, onboarding (3-page flow), settings (full implementation). Tab navigation via `StatefulShellRoute` with 4 branches (Home, Wallet, Shop, Settings). Analytics + Crashlytics integrated. Session setup wires to native Screen Time. Active session includes failure polling and auto-resolution.

---

## Overview

FocusPledge is a **skill-based commitment tool** that uses a closed-loop arcade economy. All copy must emphasize:

- **Discipline** over chance
- **Commitment** over gambling
- **Focus Credits** as in-app currency (non-redeemable)
- **Phoenix Protocol** as a second-chance redemption loop

This document maps all screens, their states, navigation flows, and copy requirements.

---

## Copy Guidelines (Non-Negotiable)

### ✅ Approved Terms

| Category | Approved Terms                                    |
| -------- | ------------------------------------------------- |
| Currency | Focus Credits (FC), Ash, Obsidian, Frozen Votes   |
| Actions  | Pledge, Commit, Redeem, Rescue                    |
| Sessions | Focus Session, Pledge Session, Redemption Session |
| Outcomes | Success, Failure, Result, Outcome                 |
| Shop     | Black Market, Cosmetics, Themes                   |
| Voting   | Impact Points, Charity Votes                      |

### ❌ Forbidden Terms

Never use in UI, copy, or user-facing code:

| Forbidden                       | Reason                      |
| ------------------------------- | --------------------------- |
| Bet, Gamble, Wager, Betting     | Gambling framing            |
| Odds, Jackpot, Win money, Prize | Chance-based framing        |
| Payout, Cashout, Withdrawal     | Implies redeemable currency |
| Stake, Ante                     | Poker/gambling terminology  |
| Lottery, Raffle                 | Games of chance             |

**Replacement examples:**

- "Place a bet" → "Make a pledge"
- "Win credits" → "Earn credits back"
- "Betting amount" → "Pledge amount"

---

## Screen Hierarchy

```
App Shell
├── Splash / Onboarding
├── Auth (Sign In)
├── Home (Tab Bar)
│   ├── Dashboard Tab
│   ├── Sessions Tab
│   ├── Shop Tab
│   └── Profile Tab
├── Pledge Flow
│   ├── Pledge Setup
│   ├── App Selection (Native Picker)
│   ├── Active Session (Pulse)
│   └── Session Result
├── Redemption Flow
│   ├── Redemption Timer
│   ├── Redemption Session
│   └── Redemption Result
├── Credits Purchase Flow
│   ├── Pack Selection
│   └── Stripe Payment Sheet
└── Settings
    ├── Account
    ├── Blocked Apps
    └── About
```

---

## Screen Specifications

### 1. Splash Screen

**Purpose:** App launch, check auth state, load user data.

**States:**

- Loading (spinner + logo)
- Error (network issues, show retry)

**Navigation:**

- If authenticated → Dashboard
- If not authenticated → Auth

**Copy:**

- Logo only or "FocusPledge" wordmark
- No copy needed

---

### 2. Onboarding (First Launch Only)

**Purpose:** Explain concept, request Screen Time authorization.

**Screens:**

1. **Welcome**
   - Headline: "Master Your Focus"
   - Subheadline: "Commit credits to block distractions. Stay focused, earn rewards."
   - CTA: "Get Started"

2. **How It Works**
   - Step 1: "Pledge Focus Credits to block apps"
   - Step 2: "Stay focused for the session duration"
   - Step 3: "Success returns your credits + Impact Points"
   - Callout: "Fail? Get a second chance with Redemption"
   - CTA: "Continue"

3. **Screen Time Permission**
   - Headline: "Enable Focus Blocking"
   - Body: "FocusPledge uses Screen Time to block distracting apps during your sessions. Your selection stays private."
   - CTA: "Grant Permission"
   - Skip: "Maybe Later" (proceeds to app, but sessions will fail without permission)

**Copy Rules:**

- ✅ Use "pledge", "commit", "session"
- ❌ Never "bet", "gamble", "wager"

---

### 3. Auth Screen

**Purpose:** Sign in with Apple or email.

**Layout:**

- Logo
- Headline: "Sign In to FocusPledge"
- Sign in with Apple button
- (Optional) Email/password fields
- Footer: "By signing in, you agree to our Terms and Privacy Policy"

**Copy:**

- Keep minimal and standard

**Navigation:**

- On success → Dashboard
- On error → Show error message, allow retry

---

### 4. Dashboard Tab (Home)

**Purpose:** At-a-glance status, quick actions, redemption timer (if active).

**Layout:**

```
┌────────────────────────────────────┐
│  Wallet Summary                    │
│  💎 1,250 FC  🔥 500 Ash  ⚫ 25 Obsidian │
│  ❄️ 500 Frozen Votes               │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│  [Redemption Timer Card]           │  ← Only if redemptionExpiry active
│  ⏰ 18h 42m remaining               │
│  "Complete a Redemption Session    │
│   to rescue your Frozen Votes"     │
│  [Start Redemption] button         │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│  Active Session Card               │  ← If session active
│  🟢 Focus Session Active           │
│  ⏱️ 42:15 remaining                │
│  [View Session] button             │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│  Quick Actions                     │
│  [Start Focus Session]             │
│  [Buy Credits]                     │
└────────────────────────────────────┘

Recent Activity (last 5 transactions)
```

**States:**

1. **No active session, no redemption timer:** Show quick actions
2. **Active session:** Highlight session card, disable "Start Focus Session"
3. **Redemption timer active:** Show redemption card prominently
4. **Post-failure (within 24h):** Show redemption urgency

**Copy:**

- Wallet labels: "Focus Credits", "Ash", "Obsidian", "Frozen Votes"
- Redemption card: "Rescue your votes before time runs out"
- CTA: "Start Focus Session" (not "Place Bet" or "Start Wager")

---

### 5. Sessions Tab

**Purpose:** Browse history of pledge and redemption sessions.

**Layout:**

- Filter: All / Pledge / Redemption
- Sort: Recent / Oldest
- List of session cards

**Session Card:**

```
┌────────────────────────────────────┐
│ 🟢 Success  |  500 FC  |  60 min   │
│ Jan 27, 2:30 PM                    │
│ +500 FC returned, +500 Impact Points│
└────────────────────────────────────┘

┌────────────────────────────────────┐
│ 🔴 Failed  |  500 FC  |  60 min    │
│ Jan 26, 10:00 AM                   │
│ -500 FC burned, +500 Ash, ❄️ 500 Frozen│
└────────────────────────────────────┘
```

**Copy:**

- Status: "Success" or "Failed" (not "Win" or "Loss")
- Details: "Credits returned", "Credits burned", "Ash gained"

**Navigation:**

- Tap card → Session Detail screen

---

### 6. Shop Tab

**Purpose:** Browse and purchase cosmetics with Obsidian.

**Layout:**

- Tabs: Themes / App Icons / Badges
- Grid of items with preview, name, price

**Item Card:**

```
┌────────────────────────────────────┐
│  [Preview Image]                   │
│  Midnight Matte Theme              │
│  ⚫ 50 Obsidian                     │
│  [Purchase] or [Owned]             │
└────────────────────────────────────┘
```

**Copy:**

- Section title: "Black Market" (thematic, not literal gambling reference)
- Currency label: "Obsidian"
- CTA: "Purchase" (not "Buy", to avoid cash-like framing)

**States:**

- Owned items: Show "Equipped" or "Owned" badge
- Insufficient balance: Disable button, show "Need X more Obsidian"

---

### 7. Profile Tab

**Purpose:** View stats, settings, logout.

**Layout:**

- User info (name, avatar)
- Stats:
  - Lifetime pledges: 25
  - Success rate: 80%
  - Impact Points: 12,500
  - Current streak: 5 days
- Links:
  - Manage Blocked Apps
  - Transaction History
  - Settings
  - Help & FAQ
  - Logout

**Copy:**

- Stats labels: neutral, achievement-oriented
- "Success rate" (not "Win rate")

---

### 8. Pledge Setup Screen

**Purpose:** Configure and start a pledge session.

**Layout:**

```
┌────────────────────────────────────┐
│  Start Focus Session               │
└────────────────────────────────────┘

Pledge Amount
[Slider: 100 FC - 5,000 FC]
Selected: 500 FC

Duration
[Buttons: 30 min | 60 min | 90 min | 120 min]
Selected: 60 min

Blocked Apps
[Manage Apps] button → Native picker
Currently blocking: 5 apps

┌────────────────────────────────────┐
│  Commitment Summary                │
│  • Pledge: 500 FC                  │
│  • Duration: 60 minutes            │
│  • On success: +500 FC, +500 Impact Points│
│  • On failure: -500 FC (burned),   │
│    +500 Ash, ❄️ 500 Frozen Votes   │
└────────────────────────────────────┘

[Start Session] button
```

**Validations:**

- Sufficient balance (show error if not)
- At least 1 app selected (prompt to manage apps)
- Screen Time authorization granted

**Copy:**

- Title: "Start Focus Session" (not "Place Bet")
- Summary box:
  - "Pledge: X FC" (not "Bet: X FC")
  - "On success: Credits returned + Impact Points earned"
  - "On failure: Credits burned, Ash gained, Frozen Votes at risk"
- CTA: "Start Session" or "Commit"

**Explainer (Optional Tooltip):**

> "Your pledged credits are locked during the session. Stay focused to get them back with bonus Impact Points. Opening a blocked app fails the session."

**Navigation:**

- On "Manage Apps" → Native app picker (MethodChannel)
- On "Start Session" → Call backend `startSession()` → Active Session screen

---

### 9. Active Session Screen (Pulse)

**Purpose:** Show countdown, emphasize commitment, poll for native failures.

**Layout:**

```
┌────────────────────────────────────┐
│         Focus Session Active       │
└────────────────────────────────────┘

[Large animated timer: 42:15]

🔒 Your 5 apps are blocked
💎 500 FC pledged

Stay focused to earn:
  +500 FC (returned)
  +500 Impact Points

[Minimalist UI: no distractions]

[End Session Early] button (small, bottom)
```

**States:**

1. **Active:** Countdown, heartbeat every 5s, poll `checkSessionStatus` every 5s
2. **Failure detected:** Immediately transition to Result screen
3. **Time expired:** Transition to Result screen (success)

**Copy:**

- Headline: "Focus Session Active" (not "Bet Active")
- Subtext: "Stay focused. Avoid blocked apps."
- Warning (if user tries to navigate away): "Leaving the app won't cancel your session. Shielding stays active."

**CTA:**

- "End Session Early" → Confirm dialog:
  > "Ending early will fail the session. You'll lose your pledged credits. Are you sure?"
  > [Cancel] [End Session]

**Polling Logic:**

- Every 5s, call `checkSessionStatus(sessionId)`
- If `failed: true`, navigate to Result (Failure)
- On time expiry (countdown reaches 0:00), call backend `resolveSession(SUCCESS)`, navigate to Result (Success)

---

### 10. Session Result Screen

**Purpose:** Show outcome, explain what happened, next steps.

**Layout (Success):**

```
┌────────────────────────────────────┐
│          🎉 Success!               │
└────────────────────────────────────┘

You stayed focused for 60 minutes.

Rewards:
  +500 FC (returned)
  +500 Impact Points

Your new balance:
  💎 1,250 FC  🌟 12,500 Impact Points

[Continue] button
```

**Layout (Failure):**

```
┌────────────────────────────────────┐
│      💥 Session Failed             │
└────────────────────────────────────┘

You opened a blocked app.

Consequences:
  -500 FC (burned)
  +500 Ash
  ❄️ 500 Frozen Votes (at risk)

Phoenix Protocol Active:
Complete a Redemption Session within 24h
to rescue your Frozen Votes and convert
Ash → Obsidian.

[Start Redemption Session] button
[Return to Dashboard]
```

**Copy:**

- Success: Positive, reward-focused
- Failure: Educational, not punitive; emphasize second chance

**Navigation:**

- Success: [Continue] → Dashboard
- Failure: [Start Redemption Session] → Redemption Timer screen or directly to Redemption Setup

---

### 11. Redemption Timer Screen

**Purpose:** Show urgency, explain Phoenix Protocol, allow starting redemption.

**Layout:**

```
┌────────────────────────────────────┐
│       ⏰ Redemption Window         │
└────────────────────────────────────┘

[Large countdown: 18h 42m remaining]

Your 500 Frozen Votes are at risk.

Complete a Redemption Session to:
  • Rescue Frozen Votes → Impact Points
  • Convert Ash → Obsidian

Fail again, and Frozen Votes are lost.

[Start Redemption Session] button
```

**Copy:**

- Tone: Urgent but hopeful
- Explain stakes: "Frozen Votes are lost if you don't redeem"
- Emphasize skill: "This is your second chance to prove your focus"

**States:**

- Timer active: Show countdown, CTA enabled
- Timer expired: Show "Redemption Window Closed", explain votes lost, CTA disabled

---

### 12. Redemption Session Setup

**Purpose:** Configure redemption session (shorter duration, different rules).

**Layout:**

```
┌────────────────────────────────────┐
│     Start Redemption Session       │
└────────────────────────────────────┘

No credits pledged for Redemption.
Success restores your Frozen Votes.

Duration: 30 minutes (fixed)

Blocked Apps:
[Same as last session]

[Start Redemption Session] button
```

**Copy:**

- No pledge amount (redemption is a "free" second chance)
- Shorter duration (30 min default, configurable)
- Same enforcement rules

**Navigation:**

- On start → Active Redemption Session screen (similar to Pulse, different copy)

---

### 13. Redemption Session Active

**Layout:**

```
┌────────────────────────────────────┐
│    Redemption Session Active       │
└────────────────────────────────────┘

[Timer: 28:30]

🔥 Rescue your Frozen Votes
Stay focused for 30 minutes.

On success:
  ❄️ 500 Frozen Votes → 🌟 500 Impact Points
  🔥 500 Ash → ⚫ 50 Obsidian (10:1 conversion)

[End Session Early] (same warning as pledge)
```

**Copy:**

- Emphasize redemption theme: "Phoenix Protocol", "Second Chance"
- Show conversion ratios clearly

---

### 14. Redemption Result Screen

**Layout (Success):**

```
┌────────────────────────────────────┐
│     🔥 Redemption Successful!      │
└────────────────────────────────────┘

You rescued your Frozen Votes!

Rewards:
  ❄️ 500 Frozen Votes → 🌟 500 Impact Points
  🔥 500 Ash → ⚫ 50 Obsidian

Your redemption timer is cleared.

[Continue to Dashboard]
```

**Layout (Failure):**

```
┌────────────────────────────────────┐
│   💔 Redemption Failed             │
└────────────────────────────────────┘

You opened a blocked app again.

Your Frozen Votes are lost.

Ash remains for future redemptions.

[Return to Dashboard]
```

**Copy:**

- Success: Celebratory, emphasize rescue
- Failure: Acknowledge loss, but not punitive; future opportunities remain

---

### 15. Credits Purchase Flow

**Purpose:** Buy Focus Credits packs via Stripe.

**Layout:**

```
┌────────────────────────────────────┐
│         Buy Focus Credits          │
└────────────────────────────────────┘

Current Balance: 💎 250 FC

┌────────────────────────────────────┐
│  Starter Pack                      │
│  500 FC                            │
│  $5.99                             │
│  [Select]                          │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│  Standard Pack  ⭐ Most Popular    │
│  1,000 FC                          │
│  $9.99                             │
│  [Select]                          │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│  Value Pack  🎁 20% Bonus          │
│  2,500 FC                          │
│  $19.99                            │
│  [Select]                          │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│  Premium Pack  💎 30% Bonus        │
│  5,000 FC                          │
│  $34.99                            │
│  [Select]                          │
└────────────────────────────────────┘

Footer: "Focus Credits are in-app currency only.
No withdrawals or cash redemption."
```

**Copy:**

- Title: "Buy Focus Credits" (not "Purchase Chips" or "Buy Tokens")
- Disclosure: **Required** — "In-app currency only. Non-redeemable."
- Pack labels: Emphasize value (bonus credits), not gambling framing

**Navigation:**

- On select → Call backend `createCreditsPurchaseIntent(packId)` → Present Stripe Payment Sheet
- On success → Firestore listener updates balance, show confirmation toast
- On failure → Show error, allow retry

---

### 16. Manage Blocked Apps Screen

**Purpose:** View and update app selection for sessions.

**Layout:**

```
┌────────────────────────────────────┐
│        Blocked Apps                │
└────────────────────────────────────┘

Currently Blocking (5 apps):
  📱 Instagram
  📱 Twitter
  📱 TikTok
  📱 YouTube
  📱 Reddit

[Change Selection] button → Native picker
```

**Copy:**

- Neutral, functional
- Explain: "These apps will be blocked during Focus Sessions"

**Navigation:**

- [Change Selection] → MethodChannel `presentAppPicker()`

---

### 17. Transaction History Screen

**Purpose:** Full ledger view (read-only).

**Layout:**

- List of ledger entries, grouped by date
- Show kind, amount, timestamp

```
Jan 28, 2026
  +1,000 FC  Credits Purchase  2:30 PM
  -500 FC    Pledge Lock       3:00 PM
  -500 FC    Credits Burned    4:00 PM
  +500 Ash   Ash Grant         4:00 PM
```

**Copy:**

- Entry types: "Credits Purchase", "Pledge Lock", "Credits Refund", "Credits Burned", "Ash Grant", "Shop Purchase"
- Read-only; no actions

---

### 18. Settings Screen

**Purpose:** Account management, preferences, legal.

**Sections:**

- **Account**
  - Email / Apple ID
  - Change password (if email auth)
  - Delete account
- **Preferences**
  - Notifications (on/off)
  - Haptics (on/off)
- **Legal**
  - Terms of Service
  - Privacy Policy
  - Licenses
- **About**
  - App version
  - Contact support

**Copy:**

- Standard, minimal

---

## Navigation Flows

### Happy Path: Pledge Success

1. Dashboard → Start Focus Session
2. Pledge Setup (select amount, duration, apps) → Start Session
3. Active Session (countdown) → Timer expires
4. Session Result (Success) → Dashboard
5. Balance updated, Impact Points granted

### Failure Path: Redemption

1. Dashboard → Start Focus Session
2. Pledge Setup → Start Session
3. Active Session → User opens blocked app → Failure detected
4. Session Result (Failure) → Redemption Timer screen
5. Start Redemption Session → Redemption Setup → Redemption Active
6. Redemption Success → Dashboard with votes rescued

### Purchase Path

1. Dashboard → Buy Credits
2. Pack Selection → Stripe Payment Sheet
3. Payment succeeds → Balance updates → Dashboard with toast

---

## Copy Checklist (Pre-Launch Review)

Use this checklist to audit all UI strings before App Store submission:

### ✅ Required Checks

- [ ] Search codebase for forbidden terms: `bet`, `gamble`, `wager`, `odds`, `jackpot`, `win money`, `prize`, `payout`, `cashout`, `withdrawal`
- [ ] All currency references use "Focus Credits (FC)", "Ash", "Obsidian", "Frozen Votes"
- [ ] All session references use "pledge", "commit", "session", "redeem"
- [ ] All outcome references use "success", "failure", "result" (not "win", "loss")
- [ ] Stripe purchase flow includes closed-loop disclosure: "In-app currency only. Non-redeemable."
- [ ] No copy implies monetary value of credits (avoid "$X value" framing)
- [ ] Redemption is framed as "second chance" / "skill-based recovery" (not "double-or-nothing")
- [ ] All CTAs are action-oriented: "Start Session", "Purchase", "Redeem" (not "Bet Now", "Place Wager")

### 🎨 Tone Checks

- [ ] Failure screens are educational, not punitive
- [ ] Success screens are celebratory but not jackpot-like
- [ ] Redemption screens emphasize discipline and second chances
- [ ] Shop is thematic ("Black Market") but not gambling-themed

### 📱 App Store Compliance

- [ ] No screenshots show gambling-like UI (slot machines, poker chips, etc.)
- [ ] App description uses approved terminology
- [ ] Age rating reflects skill-based mechanics (12+ likely appropriate)

---

## Accessibility Requirements

### Minimum Standards

1. **VoiceOver support:** All buttons, labels, and images have descriptive labels
2. **Dynamic Type:** All text scales with system font size
3. **Color contrast:** Meets WCAG AA (4.5:1 for normal text)
4. **Touch targets:** Minimum 44x44 pt for tappable elements

### Specific Considerations

- Timer countdown: Announce remaining time periodically (every 5 min)
- Session status: Clear VoiceOver labels ("Session active", "Session failed")
- Wallet balances: Accessible labels ("Focus Credits: 1250", not just "1250")

---

## Error States & Edge Cases

### Insufficient Credits

- **Where:** Pledge Setup
- **Message:** "You need X more Focus Credits to pledge this amount. [Buy Credits]"

### Screen Time Not Authorized

- **Where:** Pledge Setup
- **Message:** "Screen Time authorization is required to block apps. [Grant Permission]"
- **Action:** Call `requestAuthorization()`

### No Apps Selected

- **Where:** Pledge Setup
- **Message:** "Select at least one app to block. [Manage Apps]"

### Network Errors (Settlement)

- **Where:** Session Result
- **Message:** "Connection issue. Your session result is being processed. Check back shortly."
- **Behavior:** Show loading state, retry settlement in background

### Payment Failure

- **Where:** Credits Purchase
- **Message:** "Payment failed: [error]. Please try again or contact support."

### Redemption Timer Expired

- **Where:** Redemption Timer
- **Message:** "Redemption window closed. Your Frozen Votes were lost. Future failures will create new redemption opportunities."

---

## Animation & Polish Guidelines

### Key Animations

1. **Timer countdown:** Smooth, minute-based updates; final 10s show seconds
2. **Session start:** Quick fade + haptic feedback
3. **Failure detection:** Red flash + error sound (short, non-alarming)
4. **Success celebration:** Confetti or sparkle particle effect (tasteful, not slot-machine-like)
5. **Balance updates:** Number count-up animation (0.5s)

### Haptics

- Session start: Medium impact
- Session end (success): Success notification haptic
- Session end (failure): Warning haptic (not error; less harsh)
- Button taps: Light impact

---

## Testing Scenarios

### Manual UX Testing Checklist

- [ ] Complete happy path: Buy credits → Start session → Stay focused → Success → Credits returned
- [ ] Complete failure path: Start session → Open blocked app → Failure → Start redemption → Success → Votes rescued
- [ ] Purchase flow: Select pack → Stripe payment → Balance updates
- [ ] Edge case: Force quit during active session → Relaunch → Failure detected → Settlement triggered
- [ ] Edge case: Timer expires while app backgrounded → Result screen on foreground
- [ ] Accessibility: Navigate entire app with VoiceOver enabled
- [ ] Copy audit: Search for forbidden terms in all UI strings

---

## Summary

This UX spec provides:

- ✅ **18 screen specifications** with layout, copy, and states
- ✅ **Navigation flows** for happy path, failure, and purchase
- ✅ **Copy checklist** for anti-gambling compliance
- ✅ **Error states** and edge case handling
- ✅ **Accessibility requirements**
- ✅ **Testing checklist**

Implementation can proceed with confidence that the UX is skill-focused, compliant, and user-friendly.

# FocusPledge — Launch Checklist (Step-by-Step)

> **Last updated:** February 25, 2026
> Follow every step in order. Check each box as you complete it.
> Estimated total time: 6–10 hours across multiple days (Apple review takes 1–3 days).

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Apple Developer Account & App Registration](#2-apple-developer-account--app-registration)
3. [Firebase Production Project](#3-firebase-production-project)
4. [Stripe Production Setup](#4-stripe-production-setup)
5. [Xcode Project Configuration](#5-xcode-project-configuration)
6. [On-Device Screen Time Testing](#6-on-device-screen-time-testing)
7. [Push Notifications (Optional for v1)](#7-push-notifications-optional-for-v1)
8. [Pre-Flight Checks](#8-pre-flight-checks)
9. [TestFlight Build](#9-testflight-build)
10. [App Store Submission](#10-app-store-submission)
11. [Post-Launch](#11-post-launch)

---

## 1. Prerequisites

Before you start, make sure you have all of these ready.

- [ ] **Apple Developer Program membership** ($99/year) — [developer.apple.com/programs](https://developer.apple.com/programs/)
- [ ] **Stripe account** with identity verification complete — [dashboard.stripe.com](https://dashboard.stripe.com/)
- [ ] **Physical iPhone** running iOS 16.0+ (Screen Time APIs don't work on simulator)
- [ ] **Xcode 15+** installed and up to date
- [ ] **Firebase CLI** installed:
  ```
  npm install -g firebase-tools
  ```
- [ ] **Stripe CLI** installed:
  ```
  brew install stripe/stripe-cli/stripe
  ```
- [ ] **Flutter** working:
  ```
  flutter doctor
  ```
  Confirm no issues for the iOS toolchain.
- [ ] **Git status clean** — verify you're on the latest `main`:
  ```
  cd /Users/matthewbshero/Projects/focus_pledge
  git pull origin main
  git status
  ```

---

## 2. Apple Developer Account & App Registration

### 2.1 Register the App ID

1. Go to [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Click the **+** button → **App IDs** → **App**
3. Fill in:
   - **Description:** `FocusPledge`
   - **Bundle ID (Explicit):** `com.focuspledge.app`
4. Under **Capabilities**, enable:
   - [x] **Sign In with Apple**
   - [x] **App Groups** — add group: `group.com.focuspledge.shared`
   - [x] **Family Controls** (this is the Screen Time entitlement)
   - [x] **Push Notifications** (enable now even if not using yet)
5. Click **Continue** → **Register**

### 2.2 Register the Extension App ID

1. Same page → **+** → **App IDs** → **App**
2. Fill in:
   - **Description:** `FocusPledge Monitor Extension`
   - **Bundle ID (Explicit):** `com.focuspledge.app.FocusPledgeMonitor`
3. Under **Capabilities**, enable:
   - [x] **App Groups** — add group: `group.com.focuspledge.shared`
   - [x] **Family Controls**
4. Click **Continue** → **Register**

### 2.3 Request Family Controls Entitlement

> ⚠️ **This is a gated entitlement.** Apple must approve your access.

1. Go to [developer.apple.com/contact/request/family-controls-distribution](https://developer.apple.com/contact/request/family-controls-distribution)
2. Fill out the form:
   - **App name:** FocusPledge
   - **Bundle ID:** `com.focuspledge.app`
   - **Use case:** Productivity app that blocks distracting apps during timed focus sessions using DeviceActivity and ManagedSettings frameworks. Users voluntarily pledge virtual credits and must avoid blocked apps. This is a self-control tool, not a parental control app.
3. Submit and **wait for approval email** (typically 1–5 business days)
4. ✅ **Do not proceed to TestFlight until this is approved**

### 2.4 Configure Sign In with Apple (Services ID)

1. Go to [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Click **+** → **Services IDs**
3. Fill in:
   - **Description:** `FocusPledge Sign In`
   - **Identifier:** `com.focuspledge.signin`
4. Click **Continue** → **Register**
5. Click on the newly created Service ID
6. Check **Sign In with Apple** → **Configure**
7. Set:
   - **Primary App ID:** `com.focuspledge.app`
   - **Domains and Subdomains:** `focuspledge.app` (or your domain)
   - **Return URLs:** `https://focuspledge-prod.firebaseapp.com/__/auth/handler`
8. Click **Save** → **Continue** → **Save**

### 2.5 Create Provisioning Profiles

1. Go to [developer.apple.com/account/resources/profiles](https://developer.apple.com/account/resources/profiles/list)
2. Create **Development** profile:
   - Type: iOS App Development
   - App ID: `com.focuspledge.app`
   - Select your development certificate and device
3. Create **Distribution** profile:
   - Type: App Store Connect
   - App ID: `com.focuspledge.app`
   - Select your distribution certificate
4. Repeat both for the extension: `com.focuspledge.app.FocusPledgeMonitor`
5. Download all 4 profiles, double-click to install

---

## 3. Firebase Production Project

### 3.1 Create the Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com/)
2. Click **Add project**
3. Project name: `FocusPledge`
4. Project ID: `focuspledge-prod` (or let Firebase auto-generate)
5. **Enable Google Analytics** → select or create a GA property
6. Click **Create project**

### 3.2 Upgrade to Blaze Plan

1. In the Firebase console, click the ⚙️ gear → **Usage and billing**
2. Click **Modify plan** → **Blaze (pay as you go)**
3. Add a payment method
4. Set budget alert: **$50/month** to start

### 3.3 Enable Authentication

1. Go to **Authentication** → **Sign-in method**
2. Click **Add new provider**
3. Enable **Apple**:
   - **Services ID:** `com.focuspledge.signin` (from step 2.4)
   - **Apple Team ID:** `74S95ZD486`
   - Click **Save**

### 3.4 Create Firestore Database

1. Go to **Firestore Database** → **Create database**
2. Select **Start in production mode**
3. Location: **us-central1** (or closest to your users)
4. Click **Enable**

### 3.5 Register the iOS App

1. Go to **Project Settings** → **General** → **Your apps**
2. Click **Add app** → iOS icon
3. **Apple bundle ID:** `com.focuspledge.app`
4. **App nickname:** FocusPledge
5. Click **Register app**
6. **Download `GoogleService-Info.plist`**
7. **Replace** the file at:
   ```
   ios/Runner/GoogleService-Info.plist
   ```
   with the downloaded file.

> ⚠️ The current `GoogleService-Info.plist` points to `demo-focuspledge`. You MUST replace it.

### 3.6 Link Firebase CLI to Production Project

```bash
cd /Users/matthewbshero/Projects/focus_pledge

# Login (if not already)
firebase login

# Add the production project
firebase use --add
# Select your production project → alias it as "prod"

# Switch to production
firebase use prod

# Verify
firebase projects:list
```

### 3.7 Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

Verify in Firebase Console → Firestore → **Rules** tab that the rules match `firestore.rules`.

### 3.8 Deploy Firestore Indexes

```bash
firebase deploy --only firestore:indexes
```

### 3.9 Set Firebase Secrets (Stripe Keys)

You'll need your Stripe **test** keys first for initial testing, then swap to production later.

```bash
# Set Stripe secret key
firebase functions:secrets:set STRIPE_SECRET_KEY
# When prompted, paste: sk_test_... (your Stripe test secret key)

# Set Stripe webhook secret (you'll get this in Step 4)
# Come back to this after completing Step 4.3
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# When prompted, paste: whsec_... (from Stripe webhook setup)
```

### 3.10 Deploy Cloud Functions

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

Wait for deployment to complete. Note the function URLs printed in the terminal — you'll need the `handleStripeWebhook` URL for Step 4.

### 3.11 Verify Deployment

1. Go to Firebase Console → **Functions**
2. Confirm these functions are listed:
   - `startSession`
   - `resolveSession`
   - `createCreditsPurchaseIntent`
   - `purchaseShopItem`
   - `expireStaleSessions`
   - `handleStripeWebhook`
3. Check **Logs** tab — should show "Function deployed" messages

### 3.12 Enable App Check (Recommended)

1. Go to Firebase Console → **App Check**
2. Click **Register** → select **DeviceCheck** for iOS
3. Enable enforcement for **Firestore** and **Cloud Functions**
4. This prevents unauthorized API calls from non-app clients

---

## 4. Stripe Production Setup

### 4.1 Verify Stripe Account

1. Go to [dashboard.stripe.com/settings/account](https://dashboard.stripe.com/settings/account)
2. Complete **business verification** if not already done:
   - Business type, address, tax ID
   - Bank account for payouts
3. Confirm account is **activated** (not in test-only mode)

### 4.2 Get API Keys

1. Go to [dashboard.stripe.com/apikeys](https://dashboard.stripe.com/apikeys)
2. **For initial testing** — use test mode keys:
   - Copy **Publishable key:** `pk_test_...`
   - Copy **Secret key:** `sk_test_...`
3. **For production** (do this right before App Store submission):
   - Toggle to **Live mode** at the top of the Stripe dashboard
   - Copy **Publishable key:** `pk_live_...`
   - Copy **Secret key:** `sk_live_...`

### 4.3 Configure Webhook Endpoint

1. Go to [dashboard.stripe.com/webhooks](https://dashboard.stripe.com/test/webhooks) (start in test mode)
2. Click **Add endpoint**
3. **Endpoint URL:** paste the `handleStripeWebhook` URL from Step 3.10 output. It looks like:
   ```
   https://us-central1-focuspledge-prod.cloudfunctions.net/handleStripeWebhook
   ```
4. Under **Select events to listen to**, click **+ Select events**:
   - [x] `payment_intent.succeeded`
   - [x] `payment_intent.payment_failed`
   - [x] `payment_intent.canceled`
5. Click **Add endpoint**
6. On the endpoint page, click **Reveal** under **Signing secret**
7. Copy the signing secret (`whsec_...`)
8. **Now go back and complete Step 3.9** — set the `STRIPE_WEBHOOK_SECRET`:
   ```bash
   firebase use prod
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
   # Paste: whsec_...
   ```

### 4.4 Test the Webhook

```bash
# In a terminal, login to Stripe CLI
stripe login

# Forward test events to your deployed function
stripe listen --forward-to https://us-central1-focuspledge-prod.cloudfunctions.net/handleStripeWebhook

# In another terminal, trigger a test event
stripe trigger payment_intent.succeeded
```

Check Firebase Functions logs to confirm the webhook was received and processed.

### 4.5 Update Stripe Publishable Key in App

Open `lib/main.dart` and replace the placeholder key:

```dart
Stripe.publishableKey = const String.fromEnvironment(
  'STRIPE_PUBLISHABLE_KEY',
  defaultValue: 'pk_test_YOUR_ACTUAL_TEST_KEY_HERE',
);
```

> For production, you'll pass the key via `--dart-define` at build time (see Step 9).

---

## 5. Xcode Project Configuration

### 5.1 Change Bundle Identifier

The current bundle ID is `com.example.focusPledge` — it must be changed to `com.focuspledge.app`.

1. Open **Xcode**:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select **Runner** project in the left sidebar
3. Select **Runner** target → **General** tab
4. Change **Bundle Identifier** to: `com.focuspledge.app`
5. Select **FocusPledgeMonitor** target → **General** tab
6. Change **Bundle Identifier** to: `com.focuspledge.app.FocusPledgeMonitor`
7. For **both targets**, set **Team** to your Apple Developer team (should already be `74S95ZD486`)

### 5.2 Set Deployment Target

1. Select **Runner** project (not target) → **Info** tab → **Deployment Target**
2. Set **iOS Deployment Target** to `16.0` (required for Screen Time APIs)
3. Select **Runner** target → **General** → verify **Minimum Deployments** is `16.0`
4. Select **FocusPledgeMonitor** target → verify it's also `16.0`

### 5.3 Verify Capabilities (Runner Target)

1. Select **Runner** target → **Signing & Capabilities** tab
2. Confirm these capabilities are present (add any that are missing with **+ Capability**):
   - [x] **Sign In with Apple**
   - [x] **App Groups** → `group.com.focuspledge.shared`
   - [x] **Family Controls**
   - [x] **Push Notifications** (optional for v1, but add now)
3. Confirm **Signing Certificate** is set and **Provisioning Profile** is Automatic or the one you created

### 5.4 Verify Capabilities (FocusPledgeMonitor Target)

1. Select **FocusPledgeMonitor** target → **Signing & Capabilities**
2. Confirm:
   - [x] **App Groups** → `group.com.focuspledge.shared`
   - [x] **Family Controls**

### 5.5 Update Podfile Platform

Open `ios/Podfile` and uncomment/update the platform line:

```ruby
platform :ios, '16.0'
```

Then run:
```bash
cd ios
pod install
cd ..
```

### 5.6 Verify Info.plist

Open `ios/Runner/Info.plist` in Xcode and add these keys if not present:

1. **Privacy - Family Controls Usage Description** (required for Screen Time):
   - Key: `NSFamilyControlsUsageDescription`
   - Value: `FocusPledge needs Screen Time access to block distracting apps during your focus sessions.`

2. **Privacy - Face ID Usage Description** (if using biometrics later):
   - Key: `NSFaceIDUsageDescription`
   - Value: `FocusPledge uses Face ID to secure your account.`

### 5.7 Verify Entitlements

Check that `ios/Runner/Runner.entitlements` contains:
```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.focuspledge.shared</string>
</array>
```

Check that `ios/FocusPledgeMonitor/FocusPledgeMonitor.entitlements` contains the same keys.

✅ Both files already have this — just verify they're still correct after any Xcode changes.

### 5.8 Build & Verify

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --debug
```

This should build without errors. If you see signing errors, double-check your team and provisioning profiles in Xcode.

---

## 6. On-Device Screen Time Testing

> ⚠️ This can ONLY be done on a physical iPhone. Screen Time APIs are no-ops on the simulator.

### 6.1 Connect Your iPhone

1. Connect iPhone via USB
2. Trust the computer on iPhone if prompted
3. In Xcode: **Window** → **Devices and Simulators** → confirm your device appears
4. On iPhone: **Settings** → **Privacy & Security** → **Developer Mode** → turn **ON**

### 6.2 Run the App on Device

```bash
flutter run --debug -d <your-device-id>
```

Or from Xcode: select your iPhone as the run destination and press **▶ Run**.

### 6.3 Test Authorization Flow

1. Open the app on your iPhone
2. Navigate to **Settings** screen
3. Tap **Enable Screen Time**
4. The iOS permission dialog should appear: "FocusPledge would like to manage Screen Time"
5. Tap **Allow**
6. Verify the settings screen updates to show "Screen Time: Enabled"

### 6.4 Test App Picker

1. Navigate to **Settings** → tap **Manage Blocked Apps**
2. The native iOS app picker should appear
3. Select 2-3 apps to block (e.g., Safari, YouTube, TikTok)
4. Tap **Done**
5. Verify the selected apps are shown in the settings list

### 6.5 Test a Focus Session (End-to-End)

> For this test, make sure you have credits in your wallet. If using test Firebase, you can manually add credits via Firestore console:
> Go to Firestore → `users/{your-uid}` → set `wallet.credits` to `1000`.

1. Go to **Wallet** tab → **Start Pledge**
2. Set pledge amount: `100 FC`
3. Set duration: `2 minutes` (shortest possible for testing)
4. Tap **Start Session**
5. Verify:
   - [ ] Session starts successfully
   - [ ] Timer countdown appears
   - [ ] Try opening one of your blocked apps — it should show the iOS shield overlay
6. **Wait for the session to complete** (2 minutes)
7. Verify:
   - [ ] Session resolves as SUCCESS
   - [ ] Credits are returned to wallet

### 6.6 Test Session Failure

1. Start another 2-minute session
2. **While the session is active**, try to bypass the blocked app:
   - Open a blocked app
   - The DeviceActivity Monitor extension should detect this
3. Verify:
   - [ ] Session is marked as FAILED
   - [ ] Credits burn into Ash
   - [ ] Frozen Votes appear in wallet
   - [ ] Redemption deadline (24h) is set

### 6.7 Test App Kill / Background Recovery

1. Start a session
2. **Force-kill the app** (swipe up from app switcher)
3. Reopen the app
4. Verify:
   - [ ] `reconcileOnLaunch()` fires (check debug console)
   - [ ] Session state is recovered from App Group storage
   - [ ] Active session screen appears with correct remaining time
   - [ ] Shields are still applied (blocked apps still blocked)

### 6.8 Test Edge Cases

- [ ] Start a session, turn phone off, turn it back on → session should still be tracked
- [ ] Start a session, put app in background for the full duration → should resolve correctly
- [ ] Try starting two sessions simultaneously → should be prevented
- [ ] Test with 0 credits → should show insufficient balance error

---

## 7. Push Notifications (Optional for v1)

> You can skip this section for initial launch and add it in v1.1. If you want it for v1, follow these steps.

### 7.1 Create APNs Key

1. Go to [developer.apple.com/account/resources/authkeys](https://developer.apple.com/account/resources/authkeys/list)
2. Click **+** → **Keys**
3. Key name: `FocusPledge Push`
4. Enable **Apple Push Notifications service (APNs)**
5. Click **Continue** → **Register**
6. **Download the `.p8` file** — save it securely (you can only download once)
7. Note the **Key ID** shown on the page

### 7.2 Upload to Firebase

1. Go to Firebase Console → **Project Settings** → **Cloud Messaging**
2. Under **Apple app configuration**, click **Upload** next to APNs Authentication Key
3. Upload the `.p8` file
4. Enter:
   - **Key ID:** (from step 7.1)
   - **Team ID:** `74S95ZD486`
5. Click **Upload**

### 7.3 Add Firebase Messaging to Flutter

```bash
cd /Users/matthewbshero/Projects/focus_pledge
flutter pub add firebase_messaging
```

Then create a notification service and configure message handling. This requires additional code — defer to a separate implementation task.

---

## 8. Pre-Flight Checks

Run through this entire checklist before building for TestFlight.

### 8.1 Code Quality

```bash
cd /Users/matthewbshero/Projects/focus_pledge

# Analyze Dart code
flutter analyze --no-fatal-infos
# Should pass with info-level warnings only (no errors or warnings)

# Run all tests
flutter test
# Should see: "All tests passed!" (87 tests)

# Build TypeScript functions
cd functions && npm run build && cd ..
# Should compile with no errors
```

### 8.2 Configuration Verification

- [ ] `ios/Runner/GoogleService-Info.plist` points to your **production** Firebase project (check `PROJECT_ID` field inside the plist)
- [ ] `.firebaserc` has your production project set:
  ```json
  {
    "projects": {
      "default": "focuspledge-prod"
    }
  }
  ```
- [ ] Stripe publishable key in `lib/main.dart` is set (test key for TestFlight, live key for App Store)
- [ ] Firebase Functions are deployed to production
- [ ] Stripe webhook is configured with production function URL
- [ ] Firestore security rules are deployed to production

### 8.3 Manual Smoke Test

Do a full end-to-end test on your physical iPhone against the **production** Firebase project:

1. [ ] Sign in with Apple → user document created in Firestore
2. [ ] Buy credits (use Stripe test card `4242 4242 4242 4242`) → credits appear in wallet
3. [ ] Start a pledge session → session document created, timer starts, apps blocked
4. [ ] Complete session → credits returned
5. [ ] Start and fail a session → ash granted, redemption deadline set
6. [ ] View session history → all sessions listed
7. [ ] View transaction history → all ledger entries listed
8. [ ] Check settings → privacy policy and terms load
9. [ ] Sign out and sign back in → data persists

### 8.4 Privacy & Legal

- [ ] Privacy policy is accessible at a public URL: `https://focuspledge.app/privacy`
  - If you don't have a website yet, deploy `docs/privacy-policy.md` to a GitHub Pages site or use a free hosting service
- [ ] Support URL is accessible: `https://focuspledge.app/support`
  - At minimum, create a simple page with your email address
- [ ] Terms of service accessible in-app via Settings screen

---

## 9. TestFlight Build

### 9.1 Set Version Number

Open `pubspec.yaml` and set the version for release:

```yaml
version: 1.0.0+1
```

> `1.0.0` is the user-facing version. `+1` is the build number. Increment the build number for each TestFlight upload.

### 9.2 Build the Release IPA

```bash
cd /Users/matthewbshero/Projects/focus_pledge

# Clean everything
flutter clean
flutter pub get
cd ios && pod install && cd ..

# Build release
flutter build ipa \
  --release \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_KEY_HERE
```

> Replace `pk_test_YOUR_KEY_HERE` with your actual Stripe publishable key.
> For final App Store build, use `pk_live_YOUR_KEY_HERE`.

This will:
- Build the iOS release binary
- Create an `.xcarchive` in `build/ios/archive/`
- Create an `.ipa` in `build/ios/ipa/`

### 9.3 Upload to App Store Connect

**Option A: Using Xcode (recommended first time)**

1. Open Xcode:
   ```bash
   open build/ios/archive/Runner.xcarchive
   ```
2. In the Xcode Organizer window, select the archive
3. Click **Distribute App**
4. Select **App Store Connect** → **Upload**
5. Follow the prompts (signing, entitlements verification)
6. Click **Upload**

**Option B: Using command line**

```bash
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/focus_pledge.ipa \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```

### 9.4 Configure TestFlight

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com/)
2. Click **My Apps** → **FocusPledge** (create the app if it doesn't exist yet — see Step 10.1 first)
3. Go to **TestFlight** tab
4. Your uploaded build should appear (may take 5-15 minutes to process)
5. Click on the build → **Manage** compliance → select **None** for encryption (unless you use non-standard encryption)
6. Add **External Testers** group:
   - Click **+** → create group (e.g., "Beta Testers")
   - Add tester email addresses
   - Select the build → **Add build to group**
7. Testers receive an email invitation to install via TestFlight app

### 9.5 TestFlight Validation

Have testers (or yourself) run through the full flow on TestFlight:

- [ ] App installs from TestFlight
- [ ] Onboarding flow completes
- [ ] Sign in with Apple works
- [ ] Screen Time permission granted
- [ ] App blocking works during sessions
- [ ] Credit purchase works (Stripe test mode)
- [ ] Session success and failure resolve correctly
- [ ] App doesn't crash (check Crashlytics dashboard)

---

## 10. App Store Submission

### 10.1 Create App in App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com/) → **My Apps** → **+** → **New App**
2. Fill in:
   - **Platforms:** iOS
   - **Name:** `FocusPledge — Focus With Stakes`
   - **Primary Language:** English (U.S.)
   - **Bundle ID:** `com.focuspledge.app`
   - **SKU:** `focuspledge-ios-v1`
   - **User Access:** Full Access
3. Click **Create**

### 10.2 Fill in App Information

Go to **App Information**:

- **Subtitle:** `Put your credits on the line. Stay focused. Earn rewards.`
- **Category:** Primary: **Productivity**, Secondary: **Lifestyle**
- **Content Rights:** Does not contain third-party content
- **Age Rating:** Fill out the questionnaire:
  - Simulated Gambling: **Infrequent/Mild** (virtual currency with stakes)
  - All other categories: **None**
  - → Should result in **12+** rating

### 10.3 Fill in Pricing

Go to **Pricing and Availability**:

- **Price:** Free
- **Availability:** All territories (or select specific ones)
- **In-App Purchases:** None (Stripe purchases are not IAP)

> ⚠️ **Important note on Stripe vs IAP:** Apple's guidelines require digital goods and services to use In-App Purchase. Focus Credits are virtual currency used within the app. There is a risk Apple may reject this and require you to use IAP instead of Stripe. Be prepared to argue that Focus Credits are a "digital token for productivity services" or pivot to IAP if required. See the review notes you'll provide below.

### 10.4 Prepare Screenshots

You need screenshots for these device sizes (at minimum):

| Device | Size | Required |
|--------|------|----------|
| iPhone 6.7" (15 Pro Max) | 1290 × 2796 | ✅ Yes |
| iPhone 6.5" (11 Pro Max) | 1242 × 2688 | ✅ Yes |
| iPhone 5.5" (8 Plus) | 1242 × 2208 | Optional |
| iPad 12.9" | 2048 × 2732 | If supporting iPad |

**Take these screenshots** (on device or simulator for 6.7" and 6.5"):

1. **Dashboard** — shows wallet summary, greeting, quick actions
2. **Active Session** — shows countdown timer, pledge amount, blocked apps
3. **Wallet** — shows all currency balances, action buttons
4. **Session History** — shows stats summary and session list
5. **Shop** — shows purchasable items with Obsidian prices
6. **Settings** — shows account info and Screen Time status

**How to take screenshots:**

```bash
# Run on iPhone 15 Pro Max simulator for 6.7" shots
flutter run -d "iPhone 15 Pro Max"
# Then use Cmd+S in Simulator to save screenshot

# Run on iPhone 11 Pro Max simulator for 6.5" shots
flutter run -d "iPhone 11 Pro Max"
```

### 10.5 Fill in Version Information

Go to **iOS App** → version **1.0.0** tab:

**Promotional Text:**
```
Challenge yourself to stay focused. Pledge credits, lock distracting apps, and earn rewards for self-control.
```

**Description:**
> Copy the full description from `docs/app-store-metadata.md` — the section starting with "Take control of your screen time with real stakes."

**Keywords:**
```
focus, productivity, screen time, pledge, credits, self-control, distraction blocker, focus timer, digital wellness, app blocker
```

**Support URL:** `https://focuspledge.app/support`

**Marketing URL:** `https://focuspledge.app`

**Screenshots:** Upload the screenshots from Step 10.4

**What's New:**
```
Initial release
```

### 10.6 App Review Information

**Contact Information:**
- Your name, email, phone number

**Notes for Review:**
```
Demo Account:
Email: review@focuspledge.app
Password: [create this account and provide password]

Key Points for Review:

1. This is a skill-based productivity app, NOT a gambling app. Session outcomes
   are determined entirely by user behavior (whether they open blocked apps
   during a focus session). There is no element of chance.

2. Virtual currencies (Focus Credits, Ash, Obsidian, Frozen Votes) have NO
   real-world monetary value and CANNOT be cashed out or transferred to
   other users.

3. The app uses the Screen Time API (FamilyControls / DeviceActivity /
   ManagedSettings frameworks) to monitor and restrict app usage during
   active focus sessions only. Screen Time data stays on-device and is never
   transmitted to our servers.

4. Payments are processed through Stripe for virtual Focus Credits only.
   Credits exist solely within the app's closed-loop economy:
   Real money → Credits → (pledge) → Ash → (redeem) → Obsidian → Shop items.
   There is no path back to real money.

5. The "Focus Pledge Monitor" extension uses DeviceActivity to detect if
   the user opens a blocked app during a session. This runs as a
   background extension and writes violation flags to App Group shared
   storage, which the main app reads.
```

> ⚠️ **Create the demo account before submitting:**
> 1. In your production Firebase, create a test user via Firebase Console → Authentication → Add User
> 2. Or sign in with a test Apple ID and note the credentials
> 3. Pre-load the account with credits so the reviewer can test the full flow

### 10.7 Switch to Production Stripe Keys

**Only do this when you're ready for the final App Store build:**

1. Update Firebase secrets:
   ```bash
   firebase use prod
   firebase functions:secrets:set STRIPE_SECRET_KEY
   # Paste: sk_live_...
   ```

2. Update Stripe webhook:
   - Go to [dashboard.stripe.com/webhooks](https://dashboard.stripe.com/webhooks) (live mode)
   - Add the same endpoint URL as in Step 4.3
   - Get the new webhook signing secret
   ```bash
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
   # Paste: whsec_... (live mode secret)
   ```

3. Redeploy functions:
   ```bash
   firebase deploy --only functions
   ```

4. Rebuild the app with live key:
   ```bash
   flutter build ipa \
     --release \
     --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_YOUR_KEY_HERE
   ```

5. Upload new build → submit for review

### 10.8 Submit for Review

1. In App Store Connect, go to your app → version **1.0.0**
2. Under **Build**, click **+** and select your uploaded build
3. Review all fields one more time
4. Click **Add for Review**
5. Click **Submit to App Review**

**Expected timeline:** 1–3 business days for initial review. You'll get an email when it's approved or if changes are requested.

---

## 11. Post-Launch

### 11.1 Monitor (Day 1)

- [ ] Check **Firebase Crashlytics** for any crash reports
- [ ] Check **Firebase Analytics** for user signups and session starts
- [ ] Check **Stripe Dashboard** for payment processing
- [ ] Check **Firebase Functions Logs** for any errors:
  ```bash
  firebase functions:log --only handleStripeWebhook
  firebase functions:log --only startSession
  firebase functions:log --only resolveSession
  ```

### 11.2 Monitor (Week 1)

- [ ] Review crash-free rate in Crashlytics (target: >99%)
- [ ] Review session success/failure rates
- [ ] Check Stripe webhook delivery success rate
- [ ] Monitor Firebase billing (should be well under $50/month initially)
- [ ] Respond to any App Store reviews

### 11.3 Known Post-Launch Tasks

- [ ] Set up Firebase Cloud Functions **minimum instances** if cold starts are an issue:
  ```bash
  # In functions/src/index.ts, add minInstances option to critical functions
  ```
- [ ] Implement push notifications (session reminders, redemption deadline warnings)
- [ ] Set up monitoring alerts (Stripe webhook failures, function errors)
- [ ] Consider adding Firebase Remote Config for feature flags and A/B testing
- [ ] Plan v1.1 features based on user feedback

---

## Quick Reference: Key Identifiers

| Item | Value |
|------|-------|
| Bundle ID (app) | `com.focuspledge.app` |
| Bundle ID (extension) | `com.focuspledge.app.FocusPledgeMonitor` |
| App Group | `group.com.focuspledge.shared` |
| Team ID | `74S95ZD486` |
| Firebase Project | `focuspledge-prod` |
| Stripe Publishable (test) | `pk_test_...` |
| Stripe Secret (test) | `sk_test_...` |
| Services ID (Apple Sign-In) | `com.focuspledge.signin` |
| MethodChannel | `com.focuspledge/screen_time` |

---

## Quick Reference: Key Commands

```bash
# Firebase
firebase use prod
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase functions:log
firebase functions:secrets:set STRIPE_SECRET_KEY

# Flutter
flutter clean && flutter pub get
cd ios && pod install && cd ..
flutter analyze --no-fatal-infos
flutter test
flutter run -d <device-id> --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx
flutter build ipa --release --dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_xxx

# Stripe
stripe login
stripe listen --forward-to <webhook-url>
stripe trigger payment_intent.succeeded
```

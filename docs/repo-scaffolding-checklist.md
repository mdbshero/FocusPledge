# Repository Scaffolding Checklist

**Document purpose:** Step-by-step checklist to configure the FocusPledge repository with all necessary dependencies, Firebase integration, and local development environment.

**Last updated:** January 28, 2026

---

## Overview

This checklist walks through:

1. Firebase project setup (dev/staging/prod environments)
2. Flutter dependencies and configuration
3. Cloud Functions dependencies and secrets
4. Stripe integration setup
5. Local development workflow
6. CI/CD configuration

**Estimated time:** 2-3 hours for initial setup (human required for Firebase/Stripe console access)

---

## Prerequisites

- [ ] macOS development machine with Xcode installed
- [ ] Flutter SDK installed (stable channel, >= 3.16.0)
- [ ] Node.js installed (>= 18.x for Functions)
- [ ] Firebase CLI installed: `npm install -g firebase-tools`
- [ ] Stripe CLI installed (optional, for webhook testing): `brew install stripe/stripe-cli/stripe`
- [ ] Git repository cloned: `git clone https://github.com/mdbshero/FocusPledge.git`

---

## Phase 1: Firebase Project Setup (Human Required)

### 1.1 Create Firebase Projects

**Action:** Create three Firebase projects for environment separation.

**Steps:**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create projects:
   - `focuspledge-dev` (Development)
   - `focuspledge-staging` (Staging)
   - `focuspledge-prod` (Production)
3. For each project:
   - Skip Google Analytics (or enable if desired)
   - Choose Blaze (pay-as-you-go) plan for Cloud Functions

**Checklist:**

- [ ] `focuspledge-dev` project created
- [ ] `focuspledge-staging` project created
- [ ] `focuspledge-prod` project created
- [ ] All projects on Blaze plan

---

### 1.2 Enable Firebase Services

**For each project (dev/staging/prod):**

**Authentication:**

- [ ] Enable Apple Sign-In provider
  - Go to Authentication → Sign-in method → Apple
  - Configure Service ID and Team ID (from Apple Developer account)
- [ ] (Optional) Enable Email/Password provider

**Firestore:**

- [ ] Enable Firestore in Native mode
- [ ] Choose region: `us-central1` (or closest to target users)
- [ ] Start in test mode initially (rules will be deployed later)

**Cloud Functions:**

- [ ] Functions automatically enabled with Blaze plan
- [ ] Default region: `us-central1`

**Cloud Storage (Optional for MVP):**

- [ ] Enable if needed for user-uploaded content

---

### 1.3 Register iOS App

**For each Firebase project:**

1. Click "Add app" → iOS
2. iOS bundle ID:
   - Dev: `com.focuspledge.app.dev`
   - Staging: `com.focuspledge.app.staging`
   - Prod: `com.focuspledge.app`
3. App nickname: "FocusPledge iOS (Dev/Staging/Prod)"
4. Download `GoogleService-Info.plist`
5. Save to:
   - Dev: `ios/Runner/Firebase/Dev/GoogleService-Info.plist`
   - Staging: `ios/Runner/Firebase/Staging/GoogleService-Info.plist`
   - Prod: `ios/Runner/Firebase/Prod/GoogleService-Info.plist`

**Checklist:**

- [ ] iOS app registered in `focuspledge-dev`
- [ ] iOS app registered in `focuspledge-staging`
- [ ] iOS app registered in `focuspledge-prod`
- [ ] All 3 `GoogleService-Info.plist` files downloaded and organized

---

### 1.4 Configure Xcode Build Schemes

**Action:** Create Xcode schemes for each environment.

**Steps:**

1. Open `ios/Runner.xcworkspace` in Xcode
2. Product → Scheme → Manage Schemes
3. Duplicate "Runner" scheme 3 times:
   - `Runner-Dev`
   - `Runner-Staging`
   - `Runner-Prod`
4. For each scheme:
   - Edit Scheme → Build → Pre-actions → Add "Run Script" action:

     ```bash
     # Runner-Dev
     cp "${PROJECT_DIR}/Runner/Firebase/Dev/GoogleService-Info.plist" "${PROJECT_DIR}/Runner/GoogleService-Info.plist"

     # Runner-Staging
     cp "${PROJECT_DIR}/Runner/Firebase/Staging/GoogleService-Info.plist" "${PROJECT_DIR}/Runner/GoogleService-Info.plist"

     # Runner-Prod
     cp "${PROJECT_DIR}/Runner/Firebase/Prod/GoogleService-Info.plist" "${PROJECT_DIR}/Runner/GoogleService-Info.plist"
     ```
5. Update Bundle IDs in Build Settings for each Configuration:
   - Create Debug-Dev, Debug-Staging, Debug-Prod configurations
   - Create Release-Dev, Release-Staging, Release-Prod configurations

**Checklist:**

- [ ] 3 Xcode schemes created (Dev, Staging, Prod)
- [ ] Pre-actions scripts copy correct `GoogleService-Info.plist`
- [ ] Bundle IDs configured per environment

---

## Phase 2: Flutter Dependencies

### 2.1 Add Firebase Dependencies

**Action:** Update `pubspec.yaml` with Firebase packages.

**Dependencies to add:**

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^2.24.0
  firebase_auth: ^4.15.0
  cloud_firestore: ^4.13.0
  cloud_functions: ^4.5.0
  firebase_analytics: ^10.7.0
  firebase_crashlytics: ^3.4.0

  # State Management
  riverpod: ^2.4.9
  flutter_riverpod: ^2.4.9

  # UI
  go_router: ^12.1.0
  flutter_svg: ^2.0.9

  # Utilities
  intl: ^0.18.1
  uuid: ^4.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

**Run:**

```bash
cd /Users/matthewbshero/Projects/focus_pledge
flutter pub get
```

**Checklist:**

- [ ] `pubspec.yaml` updated with Firebase dependencies
- [ ] `flutter pub get` ran successfully
- [ ] No dependency conflicts

---

### 2.2 Configure Flutter Firebase

**Action:** Initialize Firebase in Flutter app.

**Create:** `lib/core/firebase_config.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: _getFirebaseOptions(),
    );
  }

  static FirebaseOptions _getFirebaseOptions() {
    // These values come from GoogleService-Info.plist
    // In production, use flutter_dotenv or similar for secrets management
    if (kDebugMode) {
      return const FirebaseOptions(
        apiKey: 'YOUR_DEV_API_KEY',
        appId: 'YOUR_DEV_APP_ID',
        messagingSenderId: 'YOUR_DEV_SENDER_ID',
        projectId: 'focuspledge-dev',
        storageBucket: 'focuspledge-dev.appspot.com',
        iosBundleId: 'com.focuspledge.app.dev',
      );
    } else {
      return const FirebaseOptions(
        apiKey: 'YOUR_PROD_API_KEY',
        appId: 'YOUR_PROD_APP_ID',
        messagingSenderId: 'YOUR_PROD_SENDER_ID',
        projectId: 'focuspledge-prod',
        storageBucket: 'focuspledge-prod.appspot.com',
        iosBundleId: 'com.focuspledge.app',
      );
    }
  }
}
```

**Update:** `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusPledge',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('FocusPledge')),
      ),
    );
  }
}
```

**Checklist:**

- [ ] `firebase_config.dart` created
- [ ] `main.dart` updated with Firebase initialization
- [ ] App builds successfully: `flutter run`
- [ ] No Firebase initialization errors in console

---

### 2.3 Add iOS Platform Configuration

**Action:** Update iOS native files for Firebase.

**Update:** `ios/Podfile`

```ruby
platform :ios, '15.0'  # Minimum iOS 15 for Screen Time APIs

# ... existing config ...

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # Required for Firebase
  pod 'FirebaseFirestore', :git => 'https://github.com/invertase/firestore-ios-sdk-frameworks.git', :tag => '10.18.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    # Fix for Xcode 15+
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

**Run:**

```bash
cd ios
pod install
cd ..
```

**Checklist:**

- [ ] `Podfile` updated
- [ ] `pod install` completed successfully
- [ ] `ios/Podfile.lock` generated

---

## Phase 3: Cloud Functions Configuration

### 3.1 Initialize Firebase Functions

**Note:** Functions are already scaffolded in `functions/` directory.

**Verify setup:**

```bash
cd functions
npm install
npm run build
```

**Checklist:**

- [ ] `npm install` completed without errors
- [ ] TypeScript compiles: `npm run build`
- [ ] Tests pass: `npm run test:emulator`

---

### 3.2 Configure Firebase CLI

**Action:** Login and set default project.

**Commands:**

```bash
firebase login
firebase use --add
# Select focuspledge-dev and create alias "dev"
# Repeat for staging and prod
```

**Create:** `.firebaserc`

```json
{
  "projects": {
    "dev": "focuspledge-dev",
    "staging": "focuspledge-staging",
    "prod": "focuspledge-prod",
    "default": "focuspledge-dev"
  }
}
```

**Checklist:**

- [ ] Firebase CLI logged in
- [ ] `.firebaserc` created with all environments
- [ ] Default project set to `dev`

---

### 3.3 Add Stripe Secrets to Firebase

**Action:** Store Stripe API keys as Firebase secrets.

**For dev environment:**

```bash
firebase use dev
firebase functions:secrets:set STRIPE_SECRET_KEY
# Paste your Stripe test mode secret key when prompted

firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# Paste your webhook signing secret when prompted
```

**Repeat for staging and prod with appropriate keys.**

**Update:** `functions/src/index.ts` to use secrets:

```typescript
import * as functions from "firebase-functions";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2023-10-16",
});
```

**Checklist:**

- [ ] `STRIPE_SECRET_KEY` set for dev
- [ ] `STRIPE_WEBHOOK_SECRET` set for dev
- [ ] Secrets set for staging and prod
- [ ] Functions code updated to read from `process.env`

---

### 3.4 Deploy Firestore Security Rules

**Create:** `firestore.rules`

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    // Users collection
    match /users/{userId} {
      allow read: if isOwner(userId);
      allow write: if false;  // Only server can write via Cloud Functions

      // Exception: allow user to read own data
      allow get: if isOwner(userId);
    }

    // Sessions collection
    match /sessions/{sessionId} {
      allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
      allow write: if false;  // Only server can write
    }

    // Ledger collection (immutable audit log)
    match /ledger/{entryId} {
      allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
      allow write: if false;  // Only server can append entries
    }

    // Stripe events (internal only)
    match /stripeEvents/{eventId} {
      allow read, write: if false;  // Server-only
    }

    // Payment intents (internal tracking)
    match /paymentIntents/{intentId} {
      allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
      allow write: if false;  // Server-only
    }

    // Shop catalog (public read)
    match /shop/catalog/{itemId} {
      allow read: if true;
      allow write: if false;
    }

    // Shop purchases (user can read own)
    match /shop/purchases/{purchaseId} {
      allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
      allow write: if false;
    }
  }
}
```

**Deploy:**

```bash
firebase deploy --only firestore:rules --project dev
```

**Checklist:**

- [ ] `firestore.rules` created
- [ ] Rules deployed to dev
- [ ] Verified in Firebase Console → Firestore → Rules

---

### 3.5 Deploy Cloud Functions (Initial)

**Action:** Deploy placeholder functions to dev.

**Command:**

```bash
cd functions
npm run build
firebase deploy --only functions --project dev
```

**Expected output:**

- Functions deployed:
  - `startSession`
  - `heartbeatSession`
  - `resolveSession`
  - `reconcileAllUsers`
  - `reconcileIncrementalScheduled`

**Checklist:**

- [ ] Functions deployed to `focuspledge-dev`
- [ ] No deployment errors
- [ ] Functions visible in Firebase Console → Functions

---

## Phase 4: Stripe Integration Setup

### 4.1 Create Stripe Account

**Action:** Create Stripe account and configure test mode.

**Steps:**

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/register)
2. Create account (use business details)
3. Enable test mode (toggle in top-right)
4. Get test API keys:
   - Developers → API keys → Reveal test key
   - Copy "Secret key" (starts with `sk_test_`)
5. Create webhook endpoint:
   - Developers → Webhooks → Add endpoint
   - URL: `https://us-central1-focuspledge-dev.cloudfunctions.net/handleStripeWebhook`
   - Events: Select `payment_intent.succeeded`, `payment_intent.payment_failed`
   - Copy "Signing secret" (starts with `whsec_`)

**Checklist:**

- [ ] Stripe account created
- [ ] Test mode API keys obtained
- [ ] Webhook endpoint created and configured
- [ ] Signing secret obtained
- [ ] Secrets already set in Firebase (Phase 3.3)

---

### 4.2 Create Stripe Products

**Action:** Create Credits pack products in Stripe Dashboard.

**For each pack:**

1. Products → Add product
2. Product details:
   - Name: "Starter Pack - 500 FC"
   - Pricing: One-time, $5.99 USD
   - Metadata:
     - `pack_id`: `starter_pack`
     - `credits_amount`: `500`
3. Repeat for Standard, Value, Premium packs

**Or use Stripe CLI:**

```bash
stripe products create \
  --name="Starter Pack - 500 FC" \
  --metadata[pack_id]=starter_pack \
  --metadata[credits_amount]=500

stripe prices create \
  --product=<PRODUCT_ID> \
  --currency=usd \
  --unit-amount=599
```

**Checklist:**

- [ ] 4 products created (Starter, Standard, Value, Premium)
- [ ] Metadata includes `pack_id` and `credits_amount`
- [ ] Prices configured in USD cents

---

### 4.3 Test Webhook Locally

**Action:** Use Stripe CLI to forward webhooks to local functions emulator.

**Commands:**

Terminal 1:

```bash
cd functions
firebase emulators:start --only functions,firestore
```

Terminal 2:

```bash
stripe listen --forward-to http://localhost:5001/focuspledge-dev/us-central1/handleStripeWebhook
```

Terminal 3:

```bash
stripe trigger payment_intent.succeeded
```

**Expected:** Webhook received, function logs show processing.

**Checklist:**

- [ ] Emulator running
- [ ] Stripe CLI forwarding webhooks
- [ ] Test webhook triggers function
- [ ] No errors in function logs

---

## Phase 5: iOS Native Platform Channel

### 5.1 Create MethodChannel Bridge

**Create:** `ios/Runner/NativeBridge.swift`

```swift
import Flutter
import FamilyControls
import DeviceActivity

class NativeBridge {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.focuspledge.native_bridge",
            binaryMessenger: registrar.messenger()
        )

        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "requestAuthorization":
                self.requestAuthorization(result: result)
            case "getAuthorizationStatus":
                self.getAuthorizationStatus(result: result)
            case "presentAppPicker":
                self.presentAppPicker(result: result)
            case "startNativeSession":
                if let args = call.arguments as? [String: Any] {
                    self.startNativeSession(args: args, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                }
            case "stopNativeSession":
                if let args = call.arguments as? [String: Any] {
                    self.stopNativeSession(args: args, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                }
            case "checkSessionStatus":
                if let args = call.arguments as? [String: Any] {
                    self.checkSessionStatus(args: args, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // Implementation stubs (see ios-native-bridge-spec.md for full code)
    static func requestAuthorization(result: @escaping FlutterResult) {
        // TODO: Implement
        result(["authorized": false, "error": "Not implemented"])
    }

    static func getAuthorizationStatus(result: FlutterResult) {
        result(["status": "notDetermined"])
    }

    static func presentAppPicker(result: @escaping FlutterResult) {
        result(["selected": false])
    }

    static func startNativeSession(args: [String: Any], result: @escaping FlutterResult) {
        result(["success": false, "error": "Not implemented"])
    }

    static func stopNativeSession(args: [String: Any], result: FlutterResult) {
        result(["success": true])
    }

    static func checkSessionStatus(args: [String: Any], result: FlutterResult) {
        result(["failed": false])
    }
}
```

**Update:** `ios/Runner/AppDelegate.swift`

```swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    NativeBridge.register(with: controller.registrar(forPlugin: "NativeBridge"))

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

**Checklist:**

- [ ] `NativeBridge.swift` created with method stubs
- [ ] `AppDelegate.swift` registers bridge
- [ ] App builds successfully in Xcode

---

### 5.2 Add App Group Entitlement

**Action:** Configure App Group for extension communication.

**Steps:**

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target → Signing & Capabilities
3. Click "+ Capability" → App Groups
4. Add identifier: `group.com.focuspledge.shared`
5. Save

**Create:** `ios/Runner/Runner.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.focuspledge.shared</string>
    </array>
</dict>
</plist>
```

**Checklist:**

- [ ] App Group capability added to Runner target
- [ ] `Runner.entitlements` file created
- [ ] App builds with entitlements

---

## Phase 6: Local Development Workflow

### 6.1 Environment Switching

**Action:** Create helper scripts for switching environments.

**Create:** `scripts/use-dev.sh`

```bash
#!/bin/bash
firebase use dev
echo "Switched to DEV environment"
```

**Create:** `scripts/use-staging.sh`

```bash
#!/bin/bash
firebase use staging
echo "Switched to STAGING environment"
```

**Create:** `scripts/use-prod.sh`

```bash
#!/bin/bash
firebase use prod
echo "Switched to PROD environment"
```

**Make executable:**

```bash
chmod +x scripts/*.sh
```

**Checklist:**

- [ ] Environment scripts created
- [ ] Scripts work: `./scripts/use-dev.sh`

---

### 6.2 Local Emulator Setup

**Create:** `firebase.json`

```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": {
    "source": "functions",
    "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]
  },
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080
    },
    "functions": {
      "port": 5001
    },
    "ui": {
      "enabled": true,
      "port": 4000
    },
    "singleProjectMode": true
  }
}
```

**Create:** `firestore.indexes.json`

```json
{
  "indexes": [
    {
      "collectionGroup": "ledger",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "sessions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

**Start emulators:**

```bash
firebase emulators:start
```

**Emulator UI:** http://localhost:4000

**Checklist:**

- [ ] `firebase.json` created
- [ ] `firestore.indexes.json` created
- [ ] Emulators start without errors
- [ ] Emulator UI accessible

---

### 6.3 Flutter Debug Configuration

**Update:** `lib/core/firebase_config.dart` to use emulators in debug:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static Future<void> initialize() async {
    await Firebase.initializeApp(options: _getFirebaseOptions());

    if (kDebugMode) {
      _useEmulators();
    }
  }

  static void _useEmulators() {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  }

  // ... rest of config
}
```

**Checklist:**

- [ ] Emulator connection logic added
- [ ] App connects to local emulators in debug mode
- [ ] Firestore writes visible in Emulator UI

---

## Phase 7: CI/CD Configuration

### 7.1 GitHub Actions for Functions Tests

**Create:** `.github/workflows/functions-tests.yml`

```yaml
name: Functions Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: "18"
          cache: "npm"
          cache-dependency-path: functions/package-lock.json

      - name: Install dependencies
        working-directory: functions
        run: npm ci

      - name: Install Firebase Tools
        run: npm install -g firebase-tools

      - name: Run emulator tests
        working-directory: functions
        run: npm run test:emulator
```

**Checklist:**

- [ ] GitHub Actions workflow created
- [ ] Workflow runs on push to main
- [ ] Tests pass in CI

---

### 7.2 Forbidden Terms Scanner

**Already exists:** `tools/check_forbidden_terms.sh`

**Verify it runs:**

```bash
./tools/check_forbidden_terms.sh
```

**Checklist:**

- [ ] Scanner runs without errors
- [ ] No forbidden terms detected in UI strings

---

## Phase 8: Documentation & Cleanup

### 8.1 Update README

**Update:** `README.md` with setup instructions

````markdown
# FocusPledge

Discipline-based focus commitment tool with Screen Time enforcement.

## Setup

### Prerequisites

- Flutter SDK (>= 3.16.0)
- Node.js (>= 18.x)
- Firebase CLI
- Xcode (for iOS development)

### Local Development

1. Clone repository:
   ```bash
   git clone https://github.com/mdbshero/FocusPledge.git
   cd FocusPledge
   ```
````

2. Install dependencies:

   ```bash
   flutter pub get
   cd functions && npm install && cd ..
   ```

3. Start Firebase emulators:

   ```bash
   firebase emulators:start
   ```

4. Run app:
   ```bash
   flutter run
   ```

## Architecture

See `docs/` for detailed specifications:

- [Firestore Schema](docs/ios-development-plan.md#firestore-schema--invariants-session-2)
- [Cloud Functions](docs/ios-development-plan.md#phase-2--phoenix-protocol-economy--session-engine-weeks-23--610-days-engineering)
- [iOS Native Bridge](docs/ios-native-bridge-spec.md)
- [Flutter UX](docs/flutter-ux-spec.md)
- [Stripe Integration](docs/stripe-integration-spec.md)

## Testing

```bash
# Flutter tests
flutter test

# Functions emulator tests
cd functions
npm run test:emulator
```

## Deployment

```bash
# Deploy to dev
firebase use dev
firebase deploy --only functions,firestore:rules

# Deploy to prod
firebase use prod
firebase deploy --only functions,firestore:rules
```

```

**Checklist:**
- [ ] README updated with setup instructions
- [ ] Architecture links added
- [ ] Testing commands documented

---

### 8.2 Create .gitignore Entries

**Verify:** `.gitignore` includes:

```

# Flutter/Dart

.dart_tool/
.packages
build/
.flutter-plugins
.flutter-plugins-dependencies

# iOS

ios/Pods/
ios/.symlinks/
ios/Flutter/Flutter.framework
ios/Flutter/Flutter.podspec
ios/Runner/GoogleService-Info.plist # Copied by build script
\*.xcworkspace/xcuserdata/

# Functions

functions/node_modules/
functions/lib/
functions/firestore-debug.log

# Firebase

.firebase/

# Secrets (DO NOT COMMIT)

.env
\*.plist # Except versioned configs
firebase-debug.log
firestore-debug.log

# IDE

.vscode/
.idea/
\*.iml

````

**Checklist:**
- [ ] `.gitignore` configured
- [ ] No secrets or generated files in git

---

## Phase 9: Verification & Testing

### 9.1 End-to-End Smoke Test

**Checklist:**

- [ ] Flutter app builds: `flutter build ios`
- [ ] App runs on simulator (without Screen Time, functions work)
- [ ] Firebase connection works (can read/write Firestore via emulator)
- [ ] Cloud Functions callable from Flutter (test with `startSession` stub)
- [ ] Emulator tests pass: `npm run test:emulator`
- [ ] No forbidden terms detected: `./tools/check_forbidden_terms.sh`

---

### 9.2 Deploy to Dev Environment

**Steps:**
```bash
firebase use dev
firebase deploy --only functions,firestore:rules
````

**Verify:**

- [ ] Functions deployed to `focuspledge-dev`
- [ ] Rules deployed to Firestore
- [ ] Flutter app (in release mode) connects to dev Firebase
- [ ] Can create a test user and session (end-to-end)

---

## Summary

This checklist provides:

- ✅ Firebase project setup (3 environments)
- ✅ Flutter dependencies and configuration
- ✅ Cloud Functions deployment pipeline
- ✅ Stripe integration setup
- ✅ iOS native bridge scaffold
- ✅ Local development with emulators
- ✅ CI/CD with GitHub Actions
- ✅ Documentation and testing procedures

**Completion time:** ~2-3 hours (with human for Firebase/Stripe console access)

**Next steps:** Begin implementation of backend functions (Stripe webhook, scheduled jobs) or Flutter UI screens per daily schedule.

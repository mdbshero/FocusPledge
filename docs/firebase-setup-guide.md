# Firebase Project Setup Guide

**Last updated:** January 29, 2026

This guide walks through creating and configuring Firebase projects for FocusPledge with proper environment separation and security.

---

## Overview

We'll create three Firebase projects:

- `focuspledge-dev` - Development environment
- `focuspledge-staging` - Staging/pre-production
- `focuspledge-prod` - Production

---

## Prerequisites

- [ ] Firebase CLI installed: `npm install -g firebase-tools`
- [ ] Firebase account (Google account)
- [ ] Billing enabled on Firebase/Google Cloud (required for Cloud Functions)

---

## Step 1: Create Firebase Projects

### 1.1 Create Projects in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Create three projects:

**Development Project:**

- Project name: `FocusPledge Dev`
- Project ID: `focuspledge-dev`
- Enable Google Analytics: Optional (recommended for dev)

**Staging Project:**

- Project name: `FocusPledge Staging`
- Project ID: `focuspledge-staging`
- Enable Google Analytics: Yes

**Production Project:**

- Project name: `FocusPledge`
- Project ID: `focuspledge-prod`
- Enable Google Analytics: Yes

### 1.2 Upgrade to Blaze Plan

For each project:

1. Go to Project Settings → Usage and billing
2. Click "Modify plan"
3. Select "Blaze (pay as you go)"
4. Add payment method
5. Set up budget alerts (recommended: $50/month for dev, $200/month for prod)

---

## Step 2: Enable Firebase Services

For **each project** (dev, staging, prod), enable:

### 2.1 Authentication

1. Go to Authentication → Sign-in method
2. Enable providers:
   - ✅ **Apple** (required for iOS App Store)
     - Service ID: `com.focuspledge.signin`
     - Bundle ID: `com.focuspledge.app`
   - ✅ **Email/Password** (optional, for testing)

**Apple Sign-In setup:**

- Requires Apple Developer account
- Configure in Xcode under "Signing & Capabilities" → Sign in with Apple
- Add Service ID in Apple Developer portal

### 2.2 Firestore Database

1. Go to Firestore Database
2. Click "Create database"
3. Select mode:
   - **Dev:** Start in test mode (we'll deploy rules later)
   - **Staging/Prod:** Start in production mode
4. Select location: `us-central1` (or closest to your users)
5. Click "Enable"

### 2.3 Cloud Functions

1. Already set up in `functions/` directory
2. Will deploy later with `firebase deploy --only functions`

### 2.4 Cloud Storage (Optional)

If you need to store user-generated content:

1. Go to Storage
2. Click "Get started"
3. Start in production mode
4. Use same location as Firestore

---

## Step 3: iOS App Configuration

For **each project**, register the iOS app:

### 3.1 Register iOS App

1. Go to Project Settings → General
2. Click "Add app" → iOS
3. Fill in details:
   - **Bundle ID:**
     - Dev: `com.focuspledge.app.dev`
     - Staging: `com.focuspledge.app.staging`
     - Prod: `com.focuspledge.app`
   - **App nickname:** FocusPledge (Dev/Staging/Prod)
   - **App Store ID:** (leave blank for now)
4. Click "Register app"

### 3.2 Download GoogleService-Info.plist

1. Download `GoogleService-Info.plist`
2. Rename and save:
   - Dev: `ios/firebase/dev/GoogleService-Info.plist`
   - Staging: `ios/firebase/staging/GoogleService-Info.plist`
   - Prod: `ios/firebase/prod/GoogleService-Info.plist`

**Important:** Add to `.gitignore`:

```
ios/firebase/*/GoogleService-Info.plist
```

### 3.3 Configure Xcode Build Configurations

Create build configurations in Xcode:

1. Open `ios/Runner.xcworkspace`
2. Select Runner project → Info tab
3. Duplicate configurations:
   - Duplicate Debug → Debug-Dev
   - Duplicate Debug → Debug-Staging
   - Duplicate Release → Release-Staging
   - Keep Release for production

4. Add Run Script phase to copy correct `GoogleService-Info.plist`:

```bash
# Copy Firebase config based on configuration
case "${CONFIGURATION}" in
  "Debug-Dev" | "Debug" )
    cp -r "${PROJECT_DIR}/firebase/dev/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
    ;;
  "Debug-Staging" | "Release-Staging" )
    cp -r "${PROJECT_DIR}/firebase/staging/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
    ;;
  "Release" )
    cp -r "${PROJECT_DIR}/firebase/prod/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
    ;;
esac
```

---

## Step 4: Firebase CLI Configuration

### 4.1 Login to Firebase

```bash
firebase login
```

### 4.2 Initialize Firebase in Project

```bash
cd /Users/matthewbshero/Projects/focus_pledge
firebase init
```

Select:

- ✅ Firestore
- ✅ Functions
- ✅ Storage (optional)
- ✅ Emulators

Configuration:

- Firestore rules: `firestore.rules`
- Firestore indexes: `firestore.indexes.json`
- Functions language: TypeScript (already set up)
- Emulators: Firestore, Functions, Auth

### 4.3 Configure Multiple Projects

```bash
# Add all three projects
firebase use --add

# Select focuspledge-dev, alias: dev
# Select focuspledge-staging, alias: staging
# Select focuspledge-prod, alias: prod

# Set dev as default
firebase use dev
```

Verify with:

```bash
firebase projects:list
```

---

## Step 5: Configure Secrets

### 5.1 Stripe API Keys

For **each environment**, set Stripe secrets:

```bash
# Development
firebase use dev
firebase functions:secrets:set STRIPE_SECRET_KEY
# Paste test key: sk_test_...
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# Paste test webhook secret: whsec_...

# Staging
firebase use staging
firebase functions:secrets:set STRIPE_SECRET_KEY
# Paste test key: sk_test_...
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# Paste test webhook secret: whsec_...

# Production
firebase use prod
firebase functions:secrets:set STRIPE_SECRET_KEY
# Paste live key: sk_live_...
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# Paste live webhook secret: whsec_...
```

### 5.2 Verify Secrets

```bash
firebase functions:secrets:access STRIPE_SECRET_KEY
firebase functions:secrets:access STRIPE_WEBHOOK_SECRET
```

---

## Step 6: Deploy Initial Setup

### 6.1 Deploy Security Rules

```bash
firebase use dev
firebase deploy --only firestore:rules
```

### 6.2 Deploy Cloud Functions

```bash
firebase use dev
cd functions
npm run build
cd ..
firebase deploy --only functions
```

### 6.3 Verify Deployment

1. Check Functions in Firebase Console → Functions
2. Verify callable functions are listed
3. Test with emulator or direct call

---

## Step 7: Configure Stripe Webhooks

For **each environment**, configure webhook endpoints:

### 7.1 Get Function URLs

```bash
firebase use dev
firebase functions:list
```

Copy the URL for `handleStripeWebhook`

### 7.2 Add Webhook in Stripe Dashboard

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/test/webhooks)
2. Click "Add endpoint"
3. Paste function URL: `https://us-central1-focuspledge-dev.cloudfunctions.net/handleStripeWebhook`
4. Select events:
   - ✅ `payment_intent.succeeded`
   - ✅ `payment_intent.payment_failed`
   - ✅ `payment_intent.canceled`
5. Click "Add endpoint"
6. Copy "Signing secret" (starts with `whsec_`)
7. Update Firebase secret:
   ```bash
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
   ```

Repeat for staging and production environments.

---

## Step 8: Test Environment Setup

### 8.1 Start Firebase Emulators

```bash
firebase use dev
firebase emulators:start
```

This starts:

- Firestore Emulator: `http://localhost:8080`
- Functions Emulator: `http://localhost:5001`
- Auth Emulator: `http://localhost:9099`
- Emulator UI: `http://localhost:4000`

### 8.2 Run Functions Tests

```bash
cd functions
npm test
```

Should see: **21/21 tests passing**

### 8.3 Test Flutter Connection

```bash
flutter run --dart-define=ENV=dev
```

App should connect to dev Firebase project.

---

## Environment Variables

### Flutter Environment Configuration

Create files:

**`lib/config/firebase_options_dev.dart`**

```dart
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return ios;
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_DEV_API_KEY',
    appId: 'YOUR_DEV_APP_ID',
    messagingSenderId: 'YOUR_DEV_SENDER_ID',
    projectId: 'focuspledge-dev',
    storageBucket: 'focuspledge-dev.appspot.com',
    iosBundleId: 'com.focuspledge.app.dev',
  );
}
```

Create similar files for staging and prod.

**Add to `.gitignore`:**

```
lib/config/firebase_options_*.dart
```

---

## Security Checklist

Before going to production:

- [ ] Enable App Check for production project
- [ ] Configure Firestore Security Rules (no test mode)
- [ ] Rotate all API keys after initial setup
- [ ] Set up Cloud Functions minimum instances for prod (avoid cold starts)
- [ ] Configure CORS for production domains only
- [ ] Enable audit logging in Google Cloud Console
- [ ] Set up monitoring and alerting
- [ ] Configure budget alerts ($200/month recommended for prod)
- [ ] Review IAM permissions (principle of least privilege)
- [ ] Enable 2FA on Firebase/Google account

---

## Deployment Commands Quick Reference

```bash
# Switch environments
firebase use dev
firebase use staging
firebase use prod

# Deploy everything
firebase deploy

# Deploy specific services
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes

# Deploy specific function
firebase deploy --only functions:startSession

# View logs
firebase functions:log
firebase functions:log --only handleStripeWebhook

# Test locally
firebase emulators:start
firebase emulators:start --only functions,firestore
```

---

## Troubleshooting

### "Billing account not configured"

- Go to Google Cloud Console
- Link billing account to project
- Enable Cloud Functions API

### "Insufficient permissions"

- Check IAM roles in Google Cloud Console
- Ensure you have "Editor" or "Owner" role

### "Function deployment failed"

- Check `functions/src/index.ts` for TypeScript errors
- Run `npm run build` locally first
- Check function size (max 512MB for gen2)

### "Stripe webhook signature verification failed"

- Verify webhook secret matches Stripe dashboard
- Check function logs for exact error
- Use Stripe CLI for local testing: `stripe listen --forward-to localhost:5001/.../handleStripeWebhook`

---

## Next Steps

After completing this setup:

1. ✅ All three Firebase projects configured
2. ✅ Cloud Functions deployed and tested
3. ✅ Stripe webhooks configured
4. ✅ Flutter can connect to Firebase

**Continue to:**

- [Security Rules implementation](./security-rules-spec.md)
- [Flutter architecture setup](./flutter-architecture-guide.md)
- [iOS native bridge implementation](./ios-native-bridge-spec.md)

---

## Resources

- [Firebase Console](https://console.firebase.google.com/)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Stripe Dashboard](https://dashboard.stripe.com/)
- [Apple Developer Portal](https://developer.apple.com/)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:ui';
import 'services/firebase_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await FirebaseService.initialize();

  // Initialize Stripe
  // TODO: Move publishable key to environment config / Firebase Remote Config
  Stripe.publishableKey = const String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_placeholder',
  );

  // Initialize Crashlytics only if Firebase initialized successfully
  if (FirebaseService.isInitialized) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(const ProviderScope(child: FocusPledgeApp()));
}

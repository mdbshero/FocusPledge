import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Firebase initialization and configuration
class FirebaseService {
  static bool _initialized = false;

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseFunctions get functions => FirebaseFunctions.instance;
  static FirebaseAnalytics get analytics => FirebaseAnalytics.instance;
  static FirebaseCrashlytics get crashlytics => FirebaseCrashlytics.instance;

  /// Initialize Firebase with appropriate configuration
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️  Firebase already initialized');
      return;
    }

    try {
      // Let the native GoogleService-Info.plist handle default app configuration
      await Firebase.initializeApp();

      // Configure emulator for local development
      const useEmulator = bool.fromEnvironment(
        'USE_EMULATOR',
        defaultValue: false,
      );

      if (useEmulator) {
        debugPrint('🔧 Configuring Firebase emulators...');
        await _configureEmulators();
        debugPrint('✅ Firebase initialized with EMULATOR mode');
      } else {
        debugPrint('✅ Firebase initialized for PRODUCTION');
      }

      _initialized = true;
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - allow app to continue without Firebase
    }
  }

  /// Configure Firebase emulators for local development
  static Future<void> _configureEmulators() async {
    try {
      const host = 'localhost';

      debugPrint('   - Firestore emulator: $host:8080');
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);

      debugPrint('   - Functions emulator: $host:5001');
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);

      debugPrint('   - Auth emulator: $host:9099');
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    } catch (e) {
      debugPrint('⚠️  Error configuring emulators: $e');
      rethrow;
    }
  }
}

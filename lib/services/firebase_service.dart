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

  /// Whether Firebase was successfully initialized
  static bool get isInitialized => _initialized;

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
      // Configure emulator for local development
      const useEmulator = bool.fromEnvironment(
        'USE_EMULATOR',
        defaultValue: false,
      );

      if (useEmulator) {
        // In emulator mode, the native SDK may have already initialized from
        // GoogleService-Info.plist during plugin registration. Just ensure
        // Firebase is initialized and configure the emulators.
        debugPrint('🔧 Initializing Firebase for EMULATOR mode...');
        try {
          await Firebase.initializeApp();
        } catch (e) {
          // [core/duplicate-app] is expected if native SDK already initialized
          if (e.toString().contains('duplicate-app')) {
            debugPrint('   ℹ️  Firebase already initialized natively, reusing');
          } else {
            rethrow;
          }
        }
        await _configureEmulators();
        debugPrint('✅ Firebase initialized with EMULATOR mode');
      } else {
        // In production, let the native GoogleService-Info.plist handle config
        await Firebase.initializeApp();
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

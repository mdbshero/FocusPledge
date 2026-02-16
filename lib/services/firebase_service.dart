import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Firebase initialization and configuration
class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseFunctions get functions => FirebaseFunctions.instance;

  /// Initialize Firebase with appropriate configuration
  static Future<void> initialize() async {
    // Configure emulator for local development
    const useEmulator = bool.fromEnvironment(
      'USE_EMULATOR',
      defaultValue: false,
    );

    if (useEmulator) {
      // For emulator, initialize with fake project
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'fake-api-key',
          appId: '1:123456789:web:abcdef',
          messagingSenderId: '123456789',
          projectId: 'demo-focuspledge',
        ),
      );
      await _configureEmulators();
    } else {
      // For production, use firebase_options.dart
      // TODO: Generate with `flutterfire configure`
      await Firebase.initializeApp(
        // options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  /// Configure Firebase emulators for local development
  static Future<void> _configureEmulators() async {
    const host = 'localhost';

    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  }
}

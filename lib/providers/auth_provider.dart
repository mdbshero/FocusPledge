import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import '../services/firebase_service.dart';

/// Provides the current authentication state
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.auth.authStateChanges();
});

/// Provides the current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// Authentication service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Authentication service
class AuthService {
  final FirebaseAuth _auth = FirebaseService.auth;

  /// Generate a random nonce string
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// SHA256 hash of a string
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign in with Apple
  Future<UserCredential> signInWithApple() async {
    // Generate nonce for security
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    // Request Apple credential
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    // Create Firebase OAuthCredential
    final oauthCredential = OAuthProvider(
      'apple.com',
    ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

    // Sign in with Firebase
    final userCredential = await _auth.signInWithCredential(oauthCredential);

    // Update display name if provided (Apple only sends name on first sign-in)
    if (appleCredential.givenName != null) {
      await userCredential.user?.updateDisplayName(
        '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'
            .trim(),
      );
    }

    return userCredential;
  }

  /// Sign in with email and password (for testing)
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in anonymously (for testing)
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

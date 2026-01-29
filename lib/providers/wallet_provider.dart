import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';

/// Provides the current user's wallet data
final walletProvider = StreamProvider<Wallet?>((ref) {
  final user = ref.watch(currentUserProvider);

  if (user == null) {
    return Stream.value(null);
  }

  return FirebaseService.firestore
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists) {
          return const Wallet(
            credits: 0,
            ash: 0,
            obsidian: 0,
            purgatoryVotes: 0,
            lifetimePurchased: 0,
          );
        }

        final data = doc.data();
        if (data == null || !data.containsKey('wallet')) {
          return const Wallet(
            credits: 0,
            ash: 0,
            obsidian: 0,
            purgatoryVotes: 0,
            lifetimePurchased: 0,
          );
        }

        return Wallet.fromJson(data['wallet'] as Map<String, dynamic>);
      });
});

/// Provides the user's redemption expiry deadline
final redemptionExpiryProvider = StreamProvider<DateTime?>((ref) {
  final user = ref.watch(currentUserProvider);

  if (user == null) {
    return Stream.value(null);
  }

  return FirebaseService.firestore
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;

        final data = doc.data();
        if (data == null || !data.containsKey('deadlines')) return null;

        final deadlines = data['deadlines'] as Map<String, dynamic>?;
        if (deadlines == null || !deadlines.containsKey('redemptionExpiry')) {
          return null;
        }

        final timestamp = deadlines['redemptionExpiry'] as Timestamp?;
        return timestamp?.toDate();
      });
});

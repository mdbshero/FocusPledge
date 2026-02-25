import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';

/// Provides the current user's session history (most recent first, limit 50)
final sessionHistoryProvider = StreamProvider<List<Session>>((ref) {
  final user = ref.watch(currentUserProvider);

  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseService.firestore
      .collection('sessions')
      .where('userId', isEqualTo: user.uid)
      .orderBy('startTime', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList(),
      );
});

/// Provides the count of completed sessions
final completedSessionCountProvider = Provider<int>((ref) {
  final sessions = ref.watch(sessionHistoryProvider).valueOrNull ?? [];
  return sessions.where((s) => s.isCompleted).length;
});

/// Provides the count of failed sessions
final failedSessionCountProvider = Provider<int>((ref) {
  final sessions = ref.watch(sessionHistoryProvider).valueOrNull ?? [];
  return sessions.where((s) => s.isFailed).length;
});

/// Provides the user's ledger/transaction history (most recent first, limit 100)
final ledgerHistoryProvider = StreamProvider<List<LedgerEntry>>((ref) {
  final user = ref.watch(currentUserProvider);

  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseService.firestore
      .collection('ledger')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => LedgerEntry.fromFirestore(doc)).toList(),
      );
});

/// A single ledger entry representing a balance change
class LedgerEntry {
  final String entryId;
  final String userId;
  final String kind;
  final int amount;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const LedgerEntry({
    required this.entryId,
    required this.userId,
    required this.kind,
    required this.amount,
    required this.createdAt,
    required this.metadata,
  });

  factory LedgerEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LedgerEntry(
      entryId: doc.id,
      userId: data['userId'] as String? ?? '',
      kind: data['kind'] as String? ?? '',
      amount: data['amount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Human-readable description
  String get description {
    switch (kind) {
      case 'credits_purchase':
        return 'Purchased Focus Credits';
      case 'credits_lock':
        return 'Credits pledged to session';
      case 'credits_refund':
        return 'Credits returned (success)';
      case 'credits_burn':
        return 'Credits burned (failure)';
      case 'ash_grant':
        return 'Ash received';
      case 'ash_to_obsidian_conversion':
        return 'Ash converted to Obsidian';
      case 'obsidian_grant':
        return 'Obsidian received';
      case 'obsidian_spend':
        return 'Obsidian spent in shop';
      case 'frozen_votes_rescue':
        return 'Frozen Votes rescued';
      case 'frozen_votes_burn':
        return 'Frozen Votes burned';
      default:
        return kind.replaceAll('_', ' ');
    }
  }

  /// Icon for this entry kind
  IconData get icon {
    switch (kind) {
      case 'credits_purchase':
        return Icons.add_card;
      case 'credits_lock':
        return Icons.lock_outline;
      case 'credits_refund':
        return Icons.check_circle_outline;
      case 'credits_burn':
        return Icons.local_fire_department;
      case 'ash_grant':
        return Icons.local_fire_department;
      case 'ash_to_obsidian_conversion':
        return Icons.diamond;
      case 'obsidian_grant':
        return Icons.diamond;
      case 'obsidian_spend':
        return Icons.shopping_bag;
      case 'frozen_votes_rescue':
        return Icons.ac_unit;
      case 'frozen_votes_burn':
        return Icons.ac_unit;
      default:
        return Icons.receipt_long;
    }
  }

  /// Whether this entry represents a positive change
  bool get isPositive {
    return [
      'credits_purchase',
      'credits_refund',
      'ash_grant',
      'obsidian_grant',
      'ash_to_obsidian_conversion',
      'frozen_votes_rescue',
    ].contains(kind);
  }
}

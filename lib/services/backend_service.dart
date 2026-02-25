import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

/// Service for calling Firebase Cloud Functions
class BackendService {
  static FirebaseFunctions get _functions => FirebaseService.functions;
  static FirebaseAuth get _auth => FirebaseService.auth;

  /// Create a Stripe PaymentIntent for credits purchase
  /// Returns the client secret for presenting the payment sheet
  static Future<Map<String, dynamic>> createCreditsPurchaseIntent({
    required String packId,
    String? idempotencyKey,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final key =
        idempotencyKey ?? 'mobile_${DateTime.now().millisecondsSinceEpoch}';

    final result = await _functions
        .httpsCallable('createCreditsPurchaseIntent')
        .call({'packId': packId, 'idempotencyKey': key});

    return {
      'clientSecret': result.data['clientSecret'] as String,
      'purchaseId': result.data['purchaseId'] as String,
      'amount': result.data['amount'] as int,
    };
  }

  /// Start a new pledge session
  /// Returns the sessionId
  static Future<String> startSession({
    required int pledgeAmount,
    required int durationMinutes,
    String? type,
    String? idempotencyKey,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final key =
        idempotencyKey ?? 'mobile_${DateTime.now().millisecondsSinceEpoch}';

    final result = await _functions.httpsCallable('handleStartSession').call({
      'pledgeAmount': pledgeAmount,
      'durationMinutes': durationMinutes,
      'idempotencyKey': key,
      if (type != null) 'type': type,
    });

    return result.data['sessionId'] as String;
  }

  /// Start a redemption session (no credits locked — purely a focus challenge)
  /// Returns the sessionId
  static Future<String> startRedemptionSession({
    required int durationMinutes,
    String? idempotencyKey,
  }) async {
    return startSession(
      pledgeAmount: 0,
      durationMinutes: durationMinutes,
      type: 'REDEMPTION',
      idempotencyKey:
          idempotencyKey ??
          'redemption_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Send heartbeat for an active session
  static Future<void> heartbeatSession({required String sessionId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    await _functions.httpsCallable('handleHeartbeatSession').call({
      'sessionId': sessionId,
    });
  }

  /// Resolve a session with SUCCESS or FAILURE
  static Future<Map<String, dynamic>> resolveSession({
    required String sessionId,
    required String resolution, // 'SUCCESS' or 'FAILURE'
    String? reason,
    Map<String, dynamic>? nativeEvidence,
    String? idempotencyKey,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final key =
        idempotencyKey ??
        'settle_${sessionId}_${DateTime.now().millisecondsSinceEpoch}';

    final result = await _functions.httpsCallable('handleResolveSession').call({
      'sessionId': sessionId,
      'resolution': resolution,
      'idempotencyKey': key,
      if (reason != null) 'reason': reason,
      if (nativeEvidence != null) 'nativeEvidence': nativeEvidence,
    });

    return result.data as Map<String, dynamic>;
  }

  /// Purchase a shop item with Obsidian
  static Future<Map<String, dynamic>> purchaseShopItem({
    required String itemId,
    String? idempotencyKey,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final key =
        idempotencyKey ??
        'shop_${itemId}_${DateTime.now().millisecondsSinceEpoch}';

    final result = await _functions
        .httpsCallable('handlePurchaseShopItem')
        .call({'itemId': itemId, 'idempotencyKey': key});

    return result.data as Map<String, dynamic>;
  }
}

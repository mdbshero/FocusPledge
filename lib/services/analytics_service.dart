import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized analytics and crash reporting service
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Firebase Analytics observer for GoRouter navigation tracking
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ── Auth Events ──

  static Future<void> logSignIn({required String method}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  static Future<void> logSignUp({required String method}) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  static Future<void> logSignOut() async {
    await _analytics.logEvent(name: 'sign_out');
  }

  // ── Session Events ──

  static Future<void> logSessionStart({
    required int pledgeAmount,
    required int durationMinutes,
    String? type,
  }) async {
    await _analytics.logEvent(
      name: 'session_start',
      parameters: {
        'pledge_amount': pledgeAmount,
        'duration_minutes': durationMinutes,
        'type': type ?? 'PLEDGE',
      },
    );
  }

  static Future<void> logSessionComplete({
    required String sessionId,
    required String resolution,
    required int durationMinutes,
    required int pledgeAmount,
  }) async {
    await _analytics.logEvent(
      name: 'session_complete',
      parameters: {
        'session_id': sessionId,
        'resolution': resolution,
        'duration_minutes': durationMinutes,
        'pledge_amount': pledgeAmount,
      },
    );
  }

  static Future<void> logSessionHeartbeat({required String sessionId}) async {
    // Only log periodically to avoid event spam — caller should throttle
    await _analytics.logEvent(
      name: 'session_heartbeat',
      parameters: {'session_id': sessionId},
    );
  }

  // ── Purchase Events ──

  static Future<void> logPurchaseStart({
    required String packId,
    required double priceUsd,
    required int credits,
  }) async {
    await _analytics.logEvent(
      name: 'purchase_start',
      parameters: {
        'pack_id': packId,
        'price_usd': priceUsd,
        'credits': credits,
      },
    );
  }

  static Future<void> logPurchaseComplete({
    required String packId,
    required double priceUsd,
    required int credits,
  }) async {
    await _analytics.logPurchase(
      currency: 'USD',
      value: priceUsd,
      items: [
        AnalyticsEventItem(
          itemId: packId,
          itemName: packId,
          quantity: credits,
          price: priceUsd,
        ),
      ],
    );
  }

  static Future<void> logPurchaseCancelled({required String packId}) async {
    await _analytics.logEvent(
      name: 'purchase_cancelled',
      parameters: {'pack_id': packId},
    );
  }

  // ── Redemption Events ──

  static Future<void> logRedemptionStart({required int durationMinutes}) async {
    await _analytics.logEvent(
      name: 'redemption_start',
      parameters: {'duration_minutes': durationMinutes},
    );
  }

  static Future<void> logRedemptionComplete({
    required String resolution,
  }) async {
    await _analytics.logEvent(
      name: 'redemption_complete',
      parameters: {'resolution': resolution},
    );
  }

  // ── Shop Events ──

  static Future<void> logShopItemViewed({required String itemId}) async {
    await _analytics.logEvent(
      name: 'shop_item_viewed',
      parameters: {'item_id': itemId},
    );
  }

  static Future<void> logShopPurchase({
    required String itemId,
    required int obsidianCost,
  }) async {
    await _analytics.logEvent(
      name: 'shop_purchase',
      parameters: {'item_id': itemId, 'obsidian_cost': obsidianCost},
    );
  }

  // ── Screen Time Events ──

  static Future<void> logScreenTimePermission({required String status}) async {
    await _analytics.logEvent(
      name: 'screen_time_permission',
      parameters: {'status': status},
    );
  }

  static Future<void> logAppPickerPresented() async {
    await _analytics.logEvent(name: 'app_picker_presented');
  }

  // ── Onboarding Events ──

  static Future<void> logOnboardingStep({required int step}) async {
    await _analytics.logEvent(
      name: 'onboarding_step',
      parameters: {'step': step},
    );
  }

  static Future<void> logOnboardingComplete() async {
    await _analytics.logEvent(name: 'onboarding_complete');
  }

  static Future<void> logOnboardingSkipped({required int atStep}) async {
    await _analytics.logEvent(
      name: 'onboarding_skipped',
      parameters: {'at_step': atStep},
    );
  }

  // ── User Properties ──

  static Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
    if (userId != null) {
      _crashlytics.setUserIdentifier(userId);
    }
  }

  // ── Crash Reporting ──

  static Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    debugPrint('🔴 Recording error: $exception');
    await _crashlytics.recordError(
      exception,
      stack,
      reason: reason ?? 'Unknown',
      fatal: fatal,
    );
  }

  static Future<void> log(String message) async {
    _crashlytics.log(message);
  }
}

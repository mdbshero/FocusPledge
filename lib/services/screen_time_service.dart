import 'package:flutter/services.dart';

/// Service for communicating with iOS Screen Time APIs via MethodChannel
class ScreenTimeService {
  static const MethodChannel _channel = MethodChannel('com.focuspledge/screen_time');

  /// Request Screen Time authorization from the user
  /// Returns true if authorized, false otherwise
  Future<bool> requestAuthorization() async {
    try {
      final bool result = await _channel.invokeMethod('requestAuthorization');
      return result;
    } on PlatformException catch (e) {
      print('Error requesting authorization: ${e.message}');
      return false;
    }
  }

  /// Get the current authorization status
  /// Returns authorization status as a string: 'approved', 'denied', or 'notDetermined'
  Future<String> getAuthorizationStatus() async {
    try {
      final String status = await _channel.invokeMethod('getAuthorizationStatus');
      return status;
    } on PlatformException catch (e) {
      print('Error getting authorization status: ${e.message}');
      return 'error';
    }
  }

  /// Present the native app picker for selecting apps to block
  /// Returns true if user made a selection, false if cancelled
  Future<bool> presentAppPicker() async {
    try {
      final bool result = await _channel.invokeMethod('presentAppPicker');
      return result;
    } on PlatformException catch (e) {
      print('Error presenting app picker: ${e.message}');
      return false;
    }
  }

  /// Start a Screen Time monitoring session
  /// [sessionId] - unique identifier for the session
  /// [durationMinutes] - how long the session should last
  /// Returns true if session started successfully
  Future<bool> startSession({
    required String sessionId,
    required int durationMinutes,
  }) async {
    try {
      final bool result = await _channel.invokeMethod('startSession', {
        'sessionId': sessionId,
        'durationMinutes': durationMinutes,
      });
      return result;
    } on PlatformException catch (e) {
      print('Error starting session: ${e.message}');
      return false;
    }
  }

  /// Stop the current active session
  /// [sessionId] - unique identifier for the session to stop
  /// Returns true if session stopped successfully
  Future<bool> stopSession({required String sessionId}) async {
    try {
      final bool result = await _channel.invokeMethod('stopSession', {
        'sessionId': sessionId,
      });
      return result;
    } on PlatformException catch (e) {
      print('Error stopping session: ${e.message}');
      return false;
    }
  }

  /// Check the status of a session (for polling failure detection)
  /// [sessionId] - unique identifier for the session
  /// Returns a map with:
  ///   - 'isActive': bool - whether session is still active
  ///   - 'failed': bool - whether session has failed
  ///   - 'reason': string? - failure reason if failed
  Future<Map<String, dynamic>> checkSessionStatus({
    required String sessionId,
  }) async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'checkSessionStatus',
        {'sessionId': sessionId},
      );
      
      return {
        'isActive': result['isActive'] as bool? ?? false,
        'failed': result['failed'] as bool? ?? false,
        'reason': result['reason'] as String?,
      };
    } on PlatformException catch (e) {
      print('Error checking session status: ${e.message}');
      return {
        'isActive': false,
        'failed': false,
        'reason': null,
      };
    }
  }

  /// Get the current App Group state (for debugging)
  /// Returns a map with app group data
  Future<Map<String, dynamic>> getAppGroupState() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('getAppGroupState');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      print('Error getting app group state: ${e.message}');
      return {};
    }
  }
}

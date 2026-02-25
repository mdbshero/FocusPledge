import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connectivity state enum
enum ConnectivityStatus { online, offline, checking }

/// Provider that tracks network connectivity
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityStatus>((ref) {
      return ConnectivityNotifier();
    });

/// Notifier that periodically checks for network connectivity
class ConnectivityNotifier extends StateNotifier<ConnectivityStatus> {
  Timer? _timer;

  ConnectivityNotifier() : super(ConnectivityStatus.online) {
    _checkConnectivity();
    // Check every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        state = ConnectivityStatus.online;
      } else {
        state = ConnectivityStatus.offline;
      }
    } on SocketException {
      state = ConnectivityStatus.offline;
    } on TimeoutException {
      state = ConnectivityStatus.offline;
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      // Don't change state on unknown errors
    }
  }

  /// Force a connectivity recheck
  Future<void> recheck() async {
    state = ConnectivityStatus.checking;
    await _checkConnectivity();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

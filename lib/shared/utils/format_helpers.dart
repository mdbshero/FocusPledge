import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Duration formatting helpers
class FormatHelpers {
  FormatHelpers._();

  /// Format a duration like "1h 30m" or "45m" or "30s"
  static String duration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }

  /// Format a duration as HH:MM:SS countdown
  static String countdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}'
        ':${minutes.toString().padLeft(2, '0')}'
        ':${seconds.toString().padLeft(2, '0')}';
  }

  /// Format a DateTime as relative time (e.g. "2 hours ago", "Yesterday")
  static String relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat.MMMd().format(dateTime);
  }

  /// Format a DateTime as a short date string (e.g. "Feb 25, 2:30 PM")
  static String shortDateTime(DateTime dateTime) {
    return DateFormat.MMMd().add_jm().format(dateTime);
  }

  /// Returns a color for a session status
  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'ACTIVE':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Returns an icon for a session type
  static IconData sessionTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'REDEMPTION':
        return Icons.restore;
      case 'PLEDGE':
      default:
        return Icons.lock_outline;
    }
  }
}

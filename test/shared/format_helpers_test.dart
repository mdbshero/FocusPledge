import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_pledge/shared/utils/format_helpers.dart';

void main() {
  group('FormatHelpers.duration', () {
    test('formats hours and minutes', () {
      expect(
        FormatHelpers.duration(const Duration(hours: 1, minutes: 30)),
        '1h 30m',
      );
    });

    test('formats hours with zero minutes', () {
      expect(FormatHelpers.duration(const Duration(hours: 2)), '2h 0m');
    });

    test('formats minutes only', () {
      expect(FormatHelpers.duration(const Duration(minutes: 45)), '45m');
    });

    test('formats seconds only', () {
      expect(FormatHelpers.duration(const Duration(seconds: 30)), '30s');
    });

    test('formats zero duration', () {
      expect(FormatHelpers.duration(Duration.zero), '0s');
    });
  });

  group('FormatHelpers.countdown', () {
    test('formats HH:MM:SS', () {
      expect(
        FormatHelpers.countdown(
          const Duration(hours: 1, minutes: 5, seconds: 3),
        ),
        '01:05:03',
      );
    });

    test('formats zero duration', () {
      expect(FormatHelpers.countdown(Duration.zero), '00:00:00');
    });

    test('formats large durations', () {
      expect(
        FormatHelpers.countdown(const Duration(hours: 12, minutes: 30)),
        '12:30:00',
      );
    });

    test('pads single digits', () {
      expect(
        FormatHelpers.countdown(
          const Duration(hours: 0, minutes: 1, seconds: 9),
        ),
        '00:01:09',
      );
    });
  });

  group('FormatHelpers.relativeTime', () {
    test('returns "Just now" for recent times', () {
      final now = DateTime.now();
      expect(FormatHelpers.relativeTime(now), 'Just now');
    });

    test('returns minutes ago', () {
      final time = DateTime.now().subtract(const Duration(minutes: 5));
      expect(FormatHelpers.relativeTime(time), '5m ago');
    });

    test('returns hours ago', () {
      final time = DateTime.now().subtract(const Duration(hours: 3));
      expect(FormatHelpers.relativeTime(time), '3h ago');
    });

    test('returns "Yesterday" for times 1-2 days ago', () {
      final time = DateTime.now().subtract(const Duration(hours: 30));
      expect(FormatHelpers.relativeTime(time), 'Yesterday');
    });

    test('returns days ago within a week', () {
      final time = DateTime.now().subtract(const Duration(days: 5));
      expect(FormatHelpers.relativeTime(time), '5 days ago');
    });

    test('returns formatted date for older times', () {
      final time = DateTime.now().subtract(const Duration(days: 30));
      final result = FormatHelpers.relativeTime(time);
      // Should be a month/day format like "Dec 25"
      expect(result, isNotEmpty);
      expect(result.contains('ago'), isFalse);
    });
  });

  group('FormatHelpers.shortDateTime', () {
    test('formats date and time', () {
      final date = DateTime(2025, 2, 15, 14, 30);
      final result = FormatHelpers.shortDateTime(date);
      expect(result, contains('Feb'));
      expect(result, contains('15'));
    });
  });

  group('FormatHelpers.statusColor', () {
    test('returns green for COMPLETED', () {
      expect(FormatHelpers.statusColor('COMPLETED'), Colors.green);
    });

    test('returns red for FAILED', () {
      expect(FormatHelpers.statusColor('FAILED'), Colors.red);
    });

    test('returns blue for ACTIVE', () {
      expect(FormatHelpers.statusColor('ACTIVE'), Colors.blue);
    });

    test('returns grey for unknown status', () {
      expect(FormatHelpers.statusColor('UNKNOWN'), Colors.grey);
    });

    test('is case insensitive', () {
      expect(FormatHelpers.statusColor('completed'), Colors.green);
      expect(FormatHelpers.statusColor('Failed'), Colors.red);
      expect(FormatHelpers.statusColor('active'), Colors.blue);
    });
  });

  group('FormatHelpers.sessionTypeIcon', () {
    test('returns lock icon for pledge', () {
      expect(FormatHelpers.sessionTypeIcon('PLEDGE'), Icons.lock_outline);
    });

    test('returns restore icon for redemption', () {
      expect(FormatHelpers.sessionTypeIcon('REDEMPTION'), Icons.restore);
    });

    test('returns lock icon as default', () {
      expect(FormatHelpers.sessionTypeIcon('UNKNOWN'), Icons.lock_outline);
    });

    test('is case insensitive', () {
      expect(FormatHelpers.sessionTypeIcon('pledge'), Icons.lock_outline);
      expect(FormatHelpers.sessionTypeIcon('Redemption'), Icons.restore);
    });
  });
}

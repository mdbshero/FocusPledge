import 'package:flutter_test/flutter_test.dart';
import 'package:focus_pledge/models/session.dart';

void main() {
  group('SessionType', () {
    test('toFirestore returns uppercase name', () {
      expect(SessionType.pledge.toFirestore(), 'PLEDGE');
      expect(SessionType.redemption.toFirestore(), 'REDEMPTION');
    });

    test('fromFirestore parses valid values', () {
      expect(SessionType.fromFirestore('PLEDGE'), SessionType.pledge);
      expect(SessionType.fromFirestore('REDEMPTION'), SessionType.redemption);
    });

    test('fromFirestore defaults to pledge for unknown', () {
      expect(SessionType.fromFirestore('UNKNOWN'), SessionType.pledge);
      expect(SessionType.fromFirestore(''), SessionType.pledge);
    });

    test('roundtrips correctly', () {
      for (final type in SessionType.values) {
        expect(SessionType.fromFirestore(type.toFirestore()), type);
      }
    });
  });

  group('SessionStatus', () {
    test('toFirestore returns uppercase name', () {
      expect(SessionStatus.active.toFirestore(), 'ACTIVE');
      expect(SessionStatus.completed.toFirestore(), 'COMPLETED');
      expect(SessionStatus.failed.toFirestore(), 'FAILED');
    });

    test('fromFirestore parses valid values', () {
      expect(SessionStatus.fromFirestore('ACTIVE'), SessionStatus.active);
      expect(
        SessionStatus.fromFirestore('COMPLETED'),
        SessionStatus.completed,
      );
      expect(SessionStatus.fromFirestore('FAILED'), SessionStatus.failed);
    });

    test('fromFirestore defaults to active for unknown', () {
      expect(SessionStatus.fromFirestore('UNKNOWN'), SessionStatus.active);
      expect(SessionStatus.fromFirestore(''), SessionStatus.active);
    });

    test('roundtrips correctly', () {
      for (final status in SessionStatus.values) {
        expect(SessionStatus.fromFirestore(status.toFirestore()), status);
      }
    });
  });

  group('Session', () {
    Session createSession({
      SessionStatus status = SessionStatus.active,
      SessionType type = SessionType.pledge,
      int pledgeAmount = 10,
      int durationMinutes = 30,
      DateTime? startTime,
    }) {
      return Session(
        sessionId: 'test-session-1',
        userId: 'user-1',
        type: type,
        status: status,
        pledgeAmount: pledgeAmount,
        durationMinutes: durationMinutes,
        startTime: startTime ?? DateTime(2025, 1, 1, 12, 0),
      );
    }

    test('constructor creates session with required fields', () {
      final session = createSession();
      expect(session.sessionId, 'test-session-1');
      expect(session.userId, 'user-1');
      expect(session.type, SessionType.pledge);
      expect(session.status, SessionStatus.active);
      expect(session.pledgeAmount, 10);
      expect(session.durationMinutes, 30);
      expect(session.endTime, isNull);
      expect(session.native, isNull);
      expect(session.settlement, isNull);
    });

    test('expectedEndTime calculates correctly', () {
      final start = DateTime(2025, 1, 1, 12, 0);
      final session = createSession(startTime: start, durationMinutes: 45);
      expect(session.expectedEndTime, DateTime(2025, 1, 1, 12, 45));
    });

    test('expectedEndTime works with large durations', () {
      final start = DateTime(2025, 1, 1, 23, 0);
      final session = createSession(startTime: start, durationMinutes: 120);
      expect(session.expectedEndTime, DateTime(2025, 1, 2, 1, 0));
    });

    group('isActive / isCompleted / isFailed', () {
      test('isActive returns true for active sessions', () {
        final session = createSession(status: SessionStatus.active);
        expect(session.isActive, true);
        expect(session.isCompleted, false);
        expect(session.isFailed, false);
      });

      test('isCompleted returns true for completed sessions', () {
        final session = createSession(status: SessionStatus.completed);
        expect(session.isActive, false);
        expect(session.isCompleted, true);
        expect(session.isFailed, false);
      });

      test('isFailed returns true for failed sessions', () {
        final session = createSession(status: SessionStatus.failed);
        expect(session.isActive, false);
        expect(session.isCompleted, false);
        expect(session.isFailed, true);
      });
    });
  });

  group('SessionNative', () {
    test('constructor with no arguments', () {
      const native = SessionNative();
      expect(native.lastCheckedAt, isNull);
      expect(native.failureFlag, isNull);
      expect(native.failureReason, isNull);
    });

    test('constructor with all arguments', () {
      final native = SessionNative(
        lastCheckedAt: DateTime(2025, 1, 1),
        failureFlag: true,
        failureReason: 'Used blocked app',
      );
      expect(native.lastCheckedAt, DateTime(2025, 1, 1));
      expect(native.failureFlag, true);
      expect(native.failureReason, 'Used blocked app');
    });
  });

  group('SessionSettlement', () {
    test('constructor with no arguments', () {
      const settlement = SessionSettlement();
      expect(settlement.resolvedAt, isNull);
      expect(settlement.resolvedBy, isNull);
      expect(settlement.resolution, isNull);
      expect(settlement.idempotencyKey, isNull);
    });

    test('constructor with all arguments', () {
      final settlement = SessionSettlement(
        resolvedAt: DateTime(2025, 1, 1),
        resolvedBy: 'resolveSession',
        resolution: 'SUCCESS',
        idempotencyKey: 'key-123',
      );
      expect(settlement.resolvedAt, DateTime(2025, 1, 1));
      expect(settlement.resolvedBy, 'resolveSession');
      expect(settlement.resolution, 'SUCCESS');
      expect(settlement.idempotencyKey, 'key-123');
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Session type
enum SessionType {
  pledge,
  redemption;

  String toFirestore() => name.toUpperCase();

  static SessionType fromFirestore(String value) {
    return SessionType.values.firstWhere(
      (e) => e.name.toUpperCase() == value,
      orElse: () => SessionType.pledge,
    );
  }
}

/// Session status
enum SessionStatus {
  active,
  completed,
  failed;

  String toFirestore() => name.toUpperCase();

  static SessionStatus fromFirestore(String value) {
    return SessionStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value,
      orElse: () => SessionStatus.active,
    );
  }
}

/// Pledge/Redemption session model
class Session {
  final String sessionId;
  final String userId;
  final SessionType type;
  final SessionStatus status;
  final int pledgeAmount;
  final int durationMinutes;
  final DateTime startTime;
  final DateTime? endTime;
  final SessionNative? native;
  final SessionSettlement? settlement;

  const Session({
    required this.sessionId,
    required this.userId,
    required this.type,
    required this.status,
    required this.pledgeAmount,
    required this.durationMinutes,
    required this.startTime,
    this.endTime,
    this.native,
    this.settlement,
  });

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Session(
      sessionId: doc.id,
      userId: data['userId'] as String,
      type: SessionType.fromFirestore(data['type'] as String),
      status: SessionStatus.fromFirestore(data['status'] as String),
      pledgeAmount: data['pledgeAmount'] as int,
      durationMinutes: data['durationMinutes'] as int,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      native: data['native'] != null
          ? SessionNative.fromJson(data['native'] as Map<String, dynamic>)
          : null,
      settlement: data['settlement'] != null
          ? SessionSettlement.fromJson(
              data['settlement'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  DateTime get expectedEndTime =>
      startTime.add(Duration(minutes: durationMinutes));

  Duration get remainingTime {
    final now = DateTime.now();
    final endTime = expectedEndTime;
    if (now.isAfter(endTime)) return Duration.zero;
    return endTime.difference(now);
  }

  bool get isActive => status == SessionStatus.active;
  bool get isCompleted => status == SessionStatus.completed;
  bool get isFailed => status == SessionStatus.failed;
}

/// Native session state (Screen Time enforcement data)
class SessionNative {
  final DateTime? lastCheckedAt;
  final bool? failureFlag;
  final String? failureReason;

  const SessionNative({
    this.lastCheckedAt,
    this.failureFlag,
    this.failureReason,
  });

  factory SessionNative.fromJson(Map<String, dynamic> json) {
    return SessionNative(
      lastCheckedAt: json['lastCheckedAt'] != null
          ? (json['lastCheckedAt'] as Timestamp).toDate()
          : null,
      failureFlag: json['failureFlag'] as bool?,
      failureReason: json['failureReason'] as String?,
    );
  }
}

/// Session settlement data
class SessionSettlement {
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolution;
  final String? idempotencyKey;

  const SessionSettlement({
    this.resolvedAt,
    this.resolvedBy,
    this.resolution,
    this.idempotencyKey,
  });

  factory SessionSettlement.fromJson(Map<String, dynamic> json) {
    return SessionSettlement(
      resolvedAt: json['resolvedAt'] != null
          ? (json['resolvedAt'] as Timestamp).toDate()
          : null,
      resolvedBy: json['resolvedBy'] as String?,
      resolution: json['resolution'] as String?,
      idempotencyKey: json['idempotencyKey'] as String?,
    );
  }
}

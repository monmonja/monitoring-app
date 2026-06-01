class WatchLogFields {
  static final List<String> values = [
    id, watchId, timestamp, status, statusCode, errorMessage
  ];

  static const String id = 'id';
  static const String watchId = 'watchId';
  static const String timestamp = 'timestamp';
  static const String status = 'status';
  static const String statusCode = 'statusCode';
  static const String errorMessage = 'errorMessage';
}

class WatchLog {
  final int? id;
  final int watchId;
  final DateTime timestamp;
  final bool status; // true for success (alive), false for failure (dead)
  final int? statusCode;
  final String? errorMessage;

  const WatchLog({
    this.id,
    required this.watchId,
    required this.timestamp,
    required this.status,
    this.statusCode,
    this.errorMessage,
  });

  WatchLog copyWith({
    int? id,
    int? watchId,
    DateTime? timestamp,
    bool? status,
    int? statusCode,
    String? errorMessage,
  }) {
    return WatchLog(
      id: id ?? this.id,
      watchId: watchId ?? this.watchId,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      statusCode: statusCode ?? this.statusCode,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      WatchLogFields.id: id,
      WatchLogFields.watchId: watchId,
      WatchLogFields.timestamp: timestamp.toIso8601String(),
      WatchLogFields.status: status ? 1 : 0,
      WatchLogFields.statusCode: statusCode,
      WatchLogFields.errorMessage: errorMessage,
    };
  }

  static WatchLog fromMap(Map<String, dynamic> map) {
    return WatchLog(
      id: map[WatchLogFields.id] as int?,
      watchId: map[WatchLogFields.watchId] as int,
      timestamp: DateTime.parse(map[WatchLogFields.timestamp] as String),
      status: map[WatchLogFields.status] == 1,
      statusCode: map[WatchLogFields.statusCode] as int?,
      errorMessage: map[WatchLogFields.errorMessage] as String?,
    );
  }
}

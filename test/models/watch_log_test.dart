import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/watch_log.dart';

void main() {
  group('WatchLog model', () {
    test('copyWith updates properties', () {
      final now = DateTime.now();
      final log = WatchLog(
        id: 1,
        watchId: 1,
        timestamp: now,
        status: true,
        statusCode: 200,
        responseTimeMs: 150,
      );

      final updated = log.copyWith(status: false, statusCode: 500);

      expect(updated.id, 1);
      expect(updated.status, false);
      expect(updated.statusCode, 500);
      expect(updated.responseTimeMs, 150);
      expect(updated.timestamp, now);
    });

    test('toMap and fromMap work correctly', () {
      final now = DateTime.now();
      final log = WatchLog(
        id: 1,
        watchId: 1,
        timestamp: now,
        status: true,
        statusCode: 200,
        responseTimeMs: 150,
      );

      final map = log.toMap();
      final fromMap = WatchLog.fromMap(map);

      expect(fromMap.id, log.id);
      expect(fromMap.watchId, log.watchId);
      expect(fromMap.status, log.status);
      expect(fromMap.statusCode, log.statusCode);
      expect(fromMap.timestamp.toIso8601String(), log.timestamp.toIso8601String());
    });
  });
}

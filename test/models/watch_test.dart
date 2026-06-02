import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/watch.dart';

void main() {
  group('Watch model', () {
    test('copyWith updates properties', () {
      final now = DateTime.now();
      final watch = Watch(
        id: 1,
        domainId: 1,
        name: 'Test',
        url: 'https://test.com',
        intervalMinutes: 5,
        expectedStatus: 200,
        lastCheckTime: now,
      );

      final updated = watch.copyWith(name: 'Updated', expectedStatus: 201);

      expect(updated.id, 1);
      expect(updated.name, 'Updated');
      expect(updated.expectedStatus, 201);
      expect(updated.intervalMinutes, 5);
      expect(updated.lastCheckTime, now);
    });

    test('toMap and fromMap work correctly', () {
      final now = DateTime.now();
      final watch = Watch(
        id: 1,
        domainId: 1,
        name: 'Test',
        url: 'https://test.com',
        intervalMinutes: 5,
        expectedStatus: 200,
        lastCheckTime: now,
      );

      final map = watch.toMap();
      final fromMap = Watch.fromMap(map);

      expect(fromMap.id, watch.id);
      expect(fromMap.name, watch.name);
      expect(fromMap.url, watch.url);
      expect(fromMap.lastCheckTime?.toIso8601String(), watch.lastCheckTime?.toIso8601String());
    });
  });
}

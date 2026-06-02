import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/database_helper.dart';
import 'package:app/models/domain.dart';
import 'package:app/models/watch.dart';
import 'package:app/models/watch_log.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Using in-memory database for testing
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper', () {
    test('Can create and read a domain', () async {
      final dbHelper = DatabaseHelper.instance;

      // Clean up before test
      await dbHelper.deleteAll();

      final domain = await dbHelper.createDomain(
        const Domain(name: 'Test Domain', url: 'https://test.com')
      );

      expect(domain.id, isNotNull);

      final readDomain = await dbHelper.readDomain(domain.id!);
      expect(readDomain?.name, 'Test Domain');
      expect(readDomain?.url, 'https://test.com');

      final allDomains = await dbHelper.readAllDomains();
      expect(allDomains.length, 1);

      // Clean up
      await dbHelper.deleteAll();
    });

    test('Can create and read a watch', () async {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.deleteAll();

      final domain = await dbHelper.createDomain(
        const Domain(name: 'Test Domain', url: 'https://test.com')
      );

      final watch = await dbHelper.create(
        Watch(
          domainId: domain.id!,
          name: 'Test Watch',
          url: 'https://test.com/path',
          intervalMinutes: 5,
          expectedStatus: 200,
        )
      );

      expect(watch.id, isNotNull);

      final readWatch = await dbHelper.readWatch(watch.id!);
      expect(readWatch?.name, 'Test Watch');
      expect(readWatch?.domainId, domain.id);

      final domainWatches = await dbHelper.readWatchesForDomain(domain.id!);
      expect(domainWatches.length, 1);
      expect(domainWatches.first.id, watch.id);

      await dbHelper.deleteAll();
    });

    test('Can create and read a watch log', () async {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.deleteAll();

      final domain = await dbHelper.createDomain(
        const Domain(name: 'Test Domain', url: 'https://test.com')
      );

      final watch = await dbHelper.create(
        Watch(
          domainId: domain.id!,
          name: 'Test Watch',
          url: 'https://test.com/path',
          intervalMinutes: 5,
          expectedStatus: 200,
        )
      );

      final now = DateTime.now();

      final log = await dbHelper.createWatchLog(
        WatchLog(
          watchId: watch.id!,
          timestamp: now,
          status: true,
          statusCode: 200,
          responseTimeMs: 120,
        )
      );

      expect(log.id, isNotNull);

      final logs = await dbHelper.readWatchLogs(watch.id!);
      expect(logs.length, 1);
      expect(logs.first.id, log.id);
      expect(logs.first.status, true);
      expect(logs.first.statusCode, 200);
      expect(logs.first.responseTimeMs, 120);

      await dbHelper.deleteAll();
    });
  });
}

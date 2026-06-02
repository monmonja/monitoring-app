import 'package:flutter_test/flutter_test.dart';
import 'package:app/database_helper.dart';
import 'package:app/models/domain.dart';
import 'package:app/models/watch.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Mock Dio setup and Database Operations for Background task emulation', () async {
      // Clean DB
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.deleteAll();

      final mockDio = MockDio();

      // Mock Dio response
      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: 'success',
        ),
      );

      final response = await mockDio.get('https://example.com');
      expect(response.statusCode, 200);
      expect(response.data, 'success');

      // Create a test domain and watch to emulate background logic processing
      final domain = await dbHelper.createDomain(
        const Domain(name: 'Background Test', url: 'https://background.com')
      );

      final watch = await dbHelper.create(
        Watch(
          domainId: domain.id!,
          name: 'Watch 1',
          url: 'https://background.com',
          intervalMinutes: 1,
          expectedStatus: 200,
        )
      );

      // Simulate successful loop update
      await dbHelper.update(watch.copyWith(lastStatus: response.statusCode, lastCheckTime: DateTime.now()));

      final updatedWatch = await dbHelper.readWatch(watch.id!);
      expect(updatedWatch?.lastStatus, 200);
  });
}

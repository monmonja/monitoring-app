import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/main.dart';
import 'package:app/database_helper.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper.instance.deleteAll();
  });

  testWidgets('App navigation works', (WidgetTester tester) async {
    await tester.runAsync(() async {
        await tester.pumpWidget(const MyApp());
        // Wait for async initialization
        await Future.delayed(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Initial state should be Dashboard
        expect(find.text('Dashboard'), findsWidgets);

        // Navigate to Domains
        await tester.tap(find.text('Domains').last, warnIfMissed: false);
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('Domains'), findsWidgets);

        // Navigate to Settings
        await tester.tap(find.text('Settings').last, warnIfMissed: false);
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsWidgets);
    });
  });
}

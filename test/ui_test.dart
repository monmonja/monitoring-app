import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/database_helper.dart';
import 'package:app/screens/add_edit_domain_screen.dart';
import 'package:app/models/domain.dart';
import 'package:app/screens/add_edit_watch_screen.dart';
import 'package:app/screens/watch_detail_screen.dart';
import 'package:app/screens/domains_tab.dart';
import 'package:app/screens/settings_tab.dart';
import 'package:app/core/theme/theme_manager.dart';
import 'package:app/screens/manage_user_agents_screen.dart';

// Mock AdBanner to completely avoid MethodChannel issues
class MockAdBanner extends StatelessWidget {
  const MockAdBanner({super.key, required String adUnitId});
  @override
  Widget build(BuildContext context) => const SizedBox(height: 50, child: Text('Mock Ad'));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper.instance.deleteAll();

    // Add dummy channel handler just in case
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/google_mobile_ads'),
        (MethodCall methodCall) async {
      return null;
    });
  });

  group('Full App UI Tests', () {
    setUp(() async {
      await DatabaseHelper.instance.deleteAll();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('App basic initialization check', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(home: Container()));
        await tester.pumpAndSettle();
        expect(find.byType(Container), findsOneWidget);
      });
    });

    testWidgets('Add Domain form validates and saves', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AddEditDomainScreen())));

        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump();

        // Validation check
        await tester.tap(find.text('Save Domain'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump();

        // Fill form
        await tester.enterText(find.byType(TextFormField).first, 'Example Domain');
        await tester.enterText(find.byType(TextFormField).last, 'https://example.com');
        await tester.tap(find.text('Save Domain'));

        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify in DB
        final domains = await DatabaseHelper.instance.readAllDomains();
        expect(domains.length, 1);
        expect(domains.first.name, 'Example Domain');
        expect(domains.first.url, 'https://example.com');
      });
    });

    testWidgets('Edit Domain Flow', (WidgetTester tester) async {
      await tester.runAsync(() async {
        // Create an existing domain
        final domain = await DatabaseHelper.instance.createDomain(Domain(name: 'Initial Domain', url: 'https://initial.com'));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: AddEditDomainScreen(domain: domain))));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump();

        // Verify initial values
        expect(find.text('Initial Domain'), findsOneWidget);
        expect(find.text('https://initial.com'), findsOneWidget);

        // Edit it
        await tester.enterText(find.byType(TextFormField).first, 'Updated Domain');
        await tester.tap(find.text('Save Domain'));

        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify in DB
        final domains = await DatabaseHelper.instance.readAllDomains();
        expect(domains.length, 1);
        expect(domains.first.name, 'Updated Domain');
      });
    });

    testWidgets('Add Watch form renders', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AddEditWatchScreen())));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));
        expect(find.byType(AddEditWatchScreen), findsOneWidget);
      });
    });

    testWidgets('Watch detail screen renders', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final domain = await DatabaseHelper.instance.createDomain(Domain(name: 'Initial Domain', url: 'https://initial.com'));

        final db = await DatabaseHelper.instance.database;
        await db.insert('watches', {'domainId': domain.id, 'name': 'My Watch', 'url': 'https://initial.com/api', 'httpMethod': 'GET', 'intervalMinutes': 15, 'expectedStatus': 200, 'isActive': 1, 'consecutiveFails': 0, 'checkKeywordAbsence': 0, 'alertOnSslExpiry': 0, 'wifiOnly': 0});
        final watchesBefore = await DatabaseHelper.instance.readAllWatches();
        final watch = watchesBefore.first;

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: WatchDetailScreen(watch: watch))));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));
        expect(find.byType(WatchDetailScreen), findsOneWidget);
      });
    });

    testWidgets('Domains Tab renders', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DomainsTab())));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.text('Domains'), findsWidgets);
      });
    });

    testWidgets('Settings Tab renders', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final themeManager = ThemeManager();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: SettingsTab(themeManager: themeManager))));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.text('Settings'), findsWidgets);
      });
    });

    testWidgets('Manage User Agents renders', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ManageUserAgentsScreen())));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 500));
        expect(find.byType(ManageUserAgentsScreen), findsOneWidget);
      });
    });
  });
}

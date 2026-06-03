import 'package:flutter/material.dart';
import 'main_screen.dart';
import 'background_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeManager _themeManager = ThemeManager();

  @override
  void dispose() {
    _themeManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeManager,
      builder: (context, _) {
        return MaterialApp(
          title: 'Watch App',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeManager.themeMode,
          home: MainScreen(themeManager: _themeManager),
        );
      },
    );
  }
}

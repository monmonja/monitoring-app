import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 60% - Neutrals (backgrounds, surfaces)
  static const Color surfaceLight = Color(0xFFF7F8FA);
  static const Color surfaceDark = Color(0xFF1A1B1E);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2A2B2E);
  static const Color scaffoldLight = Color(0xFFF7F8FA);
  static const Color scaffoldDark = Color(0xFF121316);

  // 30% - Structural (text, borders, dividers)
  static const Color textPrimaryLight = Color(0xFF1A1B1E);
  static const Color textPrimaryDark = Color(0xFFE8E8E8);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF3A3B3E);
  static const Color dividerLight = Color(0xFFE5E7EB);
  static const Color dividerDark = Color(0xFF3A3B3E);

  // 10% - Accent / Semantic (alerts, statuses, indicators)
  static const Color primary = Color(0xFF3182CE);
  static const Color primaryLight = Color(0xFF63A4E0);
  static const Color primaryDark = Color(0xFF1A5A9E);
  static const Color danger = Color(0xFFE53E3E);
  static const Color dangerLight = Color(0xFFFC8181);
  static const Color warning = Color(0xFFDD6B20);
  static const Color warningLight = Color(0xFFF6AD55);
  static const Color success = Color(0xFF38A169);
  static const Color successLight = Color(0xFF68D391);

  // Status helpers
  static Color statusColor(int? statusCode, {int? consecutiveFails}) {
    if (statusCode == null) return Colors.grey;
    if (statusCode >= 200 && statusCode < 300) return success;
    if (consecutiveFails != null && consecutiveFails > 0 && consecutiveFails < 3) return warning;
    return danger;
  }
}

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 60% - Neutrals (backgrounds, surfaces)
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color scaffoldLight = Color(0xFFF8FAFC);
  static const Color scaffoldDark = Color(0xFF0F172A);

  // 30% - Structural (text, borders, dividers)
  // Grayscale: 5-8 shades for text, disabled states, and borders
  static const Color gray50 = Color(0xFFF8FAFC);
  static const Color gray100 = Color(0xFFF1F5F9);
  static const Color gray200 = Color(0xFFE2E8F0);
  static const Color gray300 = Color(0xFFCBD5E1);
  static const Color gray400 = Color(0xFF94A3B8);
  static const Color gray500 = Color(0xFF64748B);
  static const Color gray600 = Color(0xFF475569);
  static const Color gray700 = Color(0xFF334155);
  static const Color gray800 = Color(0xFF1E293B);
  static const Color gray900 = Color(0xFF0F172A);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textDisabledLight = Color(0xFFCBD5E1);
  static const Color textDisabledDark = Color(0xFF475569);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerLight = Color(0xFFE2E8F0);
  static const Color dividerDark = Color(0xFF334155);

  // 10% - Accent / Semantic (alerts, statuses, indicators)
  // Universal across light and dark modes
  static const Color primary = Color(0xFF3B82F6); // Electric Blue (Info)
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color danger = Color(0xFFEF4444); // Coral Red
  static const Color dangerLight = Color(0xFFFCA5A5);
  static const Color warning = Color(0xFFF59E0B); // Amber Orange
  static const Color warningLight = Color(0xFFFCD34D);
  static const Color success = Color(0xFF10B981); // Vibrant Emerald
  static const Color successLight = Color(0xFF6EE7B7);

  // Categorical palette for charts (muted, distinct, max 7)
  static const List<Color> chartColors = [
    Color(0xFF3B82F6), // Electric Blue
    Color(0xFF14B8A6), // Soft Teal
    Color(0xFF8B5CF6), // Muted Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Rose Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF84CC16), // Lime
  ];

  // Status helpers
  static Color statusColor(int? statusCode, {int? consecutiveFails}) {
    if (statusCode == null) return gray400;
    if (statusCode >= 200 && statusCode < 300) return success;
    if (consecutiveFails != null && consecutiveFails > 0 && consecutiveFails < 3) return warning;
    return danger;
  }
}

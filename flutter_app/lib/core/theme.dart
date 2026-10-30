import 'package:flutter/material.dart';

class AppColors {
  static const brand = Color(0xFF10B981); // emerald green
  static const accent = Color(0xFF38BDF8); // cyan
  static const background = Color(0xFF0B1120); // dark obsidian
  static const surface = Color(0xFF0F172A); // dark navy slate
  static const surfaceLight = Color(0xFF1E293B); // lighter slate
  static const ok = Color(0xFF10B981);
  static const warn = Color(0xFFF59E0B);
  static const hotspot = Color(0xFFEF4444);

  // Emergency-only palette: red and black
  static const emergencyRed = Color(0xFFDC2626);
  static const emergencyBlack = Color(0xFF020617);

  static Color forStatus(String status) {
    switch (status) {
      case 'cancelled':
        return const Color(0xFF64748B);
      case 'sent':
        return const Color(0xFFEF4444);
      case 'received':
        return const Color(0xFFF59E0B);
      case 'dispatched':
        return const Color(0xFF38BDF8);
      case 'arrived':
        return const Color(0xFFA855F7);
      case 'resolved':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.dark,
    primary: AppColors.brand,
    secondary: AppColors.accent,
    tertiary: AppColors.warn,
    surface: AppColors.surface,
    onSurface: Colors.white,
    surfaceContainerHighest: AppColors.surfaceLight,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.surface,
    dividerColor: Colors.white.withValues(alpha: 0.08),
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.25), width: 1.2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      isDense: true,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.brand.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF34D399));
        }
        return const IconThemeData(color: Color(0xFF94A3B8));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11);
        }
        return const TextStyle(color: Color(0xFF94A3B8), fontSize: 11);
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        side: const BorderSide(color: AppColors.accent),
        foregroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

class AppColors {
  static const brand = Color(0xFF3BB59A); // mint
  static const accent = Color(0xFF2F3A40); // charcoal
  static const background = Color(0xFFF5F7F7); // soft grey
  static const ok = Color(0xFF2E7D32);
  static const warn = Color(0xFFF9A825);
  static const hotspot = Colors.black;

  // Emergency-only palette: red and black
  static const emergencyRed = Color(0xFFD50000);
  static const emergencyBlack = Color(0xFF0A0A0A);

  static Color forStatus(String status) {
    switch (status) {
      case 'cancelled':
        return Colors.grey;
      case 'sent':
        return const Color(0xFFD32F2F);
      case 'received':
        return const Color(0xFFEF6C00);
      case 'dispatched':
        return const Color(0xFF1565C0);
      case 'arrived':
        return const Color(0xFF6A1B9A);
      case 'resolved':
        return const Color(0xFF2E7D32);
      default:
        return Colors.blueGrey;
    }
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    primary: AppColors.brand,
    secondary: AppColors.accent,
    tertiary: AppColors.accent,
    onSurface: AppColors.accent,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brand, width: 2),
      ),
      isDense: true,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.accent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
  );
}

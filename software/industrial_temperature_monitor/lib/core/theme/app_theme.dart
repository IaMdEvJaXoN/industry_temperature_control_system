import 'package:flutter/material.dart';

// Vantablack / deep charcoal palette. No light theme is defined anywhere
// in this app.
class AppColors {
  static const Color background = Color(0xFF0A0A0C);
  static const Color surface = Color(0xFF141417);
  static const Color surfaceElevated = Color(0xFF1C1C21);
  static const Color border = Color(0xFF2A2A31);

  static const Color accentPrimary = Color(0xFF3DFAFF);
  static const Color accentSecondary = Color(0xFF7B5CFF);

  static const Color heating = Color(0xFFFF6B3D);
  static const Color cooling = Color(0xFF3DAFFF);
  static const Color idle = Color(0xFF6B6B76);

  static const Color alarmCritical = Color(0xFFFF2D4D);

  static const Color textPrimary = Color(0xFFEDEDF2);
  static const Color textSecondary = Color(0xFF9A9AA6);
}

class AppTheme {
  // Deliberately minimal ThemeData: only fields that have been stable
  // across Flutter versions for years (colorScheme, appBarTheme,
  // scaffoldBackgroundColor, inputDecorationTheme). Card/Dialog colors are
  // applied directly on each widget instead of via ThemeData.cardTheme /
  // dialogTheme, because those two fields changed their expected type in
  // recent Flutter releases (CardTheme -> CardThemeData, DialogTheme ->
  // DialogThemeData) and picking the wrong one is a compile error
  // depending on the installed SDK version.
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accentPrimary,
        secondary: AppColors.accentSecondary,
        error: AppColors.alarmCritical,
        onSurface: AppColors.textPrimary,
        onPrimary: Color(0xFF00171A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

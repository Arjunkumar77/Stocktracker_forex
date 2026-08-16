import 'package:flutter/material.dart';

/// Color palette modeled on TradingView's dark theme.
class AppColors {
  static const background = Color(0xFF131722);
  static const surface = Color(0xFF1E222D);
  static const border = Color(0xFF2A2E39);
  static const textPrimary = Color(0xFFD1D4DC);
  static const textSecondary = Color(0xFF787B86);
  static const bullish = Color(0xFF26A69A); // green — price up
  static const bearish = Color(0xFFEF5350); // red — price down
  static const accent = Color(0xFF2962FF);
  static const gold = Color(0xFFFFC107);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        surface: AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
      ),
      splashColor: AppColors.accent.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
    );
  }
}

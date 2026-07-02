import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/constants/constants.dart';

/// ThemeData utama aplikasi (dark mode premium).
abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      surface: AppColors.surface,
      onPrimary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
    ),
    fontFamily: AppTypography.fontBody,
    textTheme: const TextTheme(
      displayLarge: AppTypography.logo,
      headlineMedium: AppTypography.heading,
      titleLarge: AppTypography.title,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.caption,
      labelSmall: AppTypography.badge,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      elevation: 0,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppTypography.heading,
      foregroundColor: AppColors.textPrimary,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.navbarBackground,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
    ),
    useMaterial3: true,
  );
}

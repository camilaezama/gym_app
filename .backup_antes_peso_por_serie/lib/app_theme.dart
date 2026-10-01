import 'package:flutter/material.dart';

/// Todos los colores de la app. Para cambiar la paleta, editar solo esta clase.
class AppColors {
  // Manteca
  static const background = Color(0xFFFFF6DC);

  // Beiges
  static const surface = Color(0xFFF3E7D3);
  static const bottomBar = Color(0xFFE8D9C0);

  // Chocolates / marrones
  static const primary = Color(0xFF5A3418);
  static const secondary = Color(0xFF8B5E3C);
  static const text = Color(0xFF3B2314);
  static const textMuted = Color(0xFF9A7B5F);
  static const border = Color(0xFFCDBBA0);

  // Texto e íconos sobre fondos chocolate
  static const onDark = Color(0xFFFFF6DC);

  static const error = Color(0xFFB3261E);
  static const onError = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onDark,
      primaryContainer: AppColors.surface,
      onPrimaryContainer: AppColors.text,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onDark,
      secondaryContainer: AppColors.secondary,
      onSecondaryContainer: AppColors.onDark,
      outlineVariant: AppColors.border,
      surface: AppColors.background,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      surfaceContainer: AppColors.surface,
      outline: AppColors.border,
      error: AppColors.error,
      onError: AppColors.onError,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: AppColors.bottomBar,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onDark,
      ),
      cardTheme: const CardThemeData(color: AppColors.surface),
      dividerTheme: const DividerThemeData(color: AppColors.border),
    );
  }
}

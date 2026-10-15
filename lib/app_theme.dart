import 'package:flutter/material.dart';

/// Todos los colores de la app. Para cambiar la paleta, editar solo esta clase.
class AppColors {
  // Blanco
  static const background = Color(0xFFFFFFFF);

  // Grises cálidos claros
  static const surface = Color(0xFFEFE9E7);
  static const bottomBar = Color(0xFFD9C9BB);

  // Topos / greige oscuros
  static const primary = Color(0xFF705A4A);
  static const secondary = Color(0xFF9D897A);
  static const text = Color(0xFF3A332F);
  static const textMuted = Color(0xFF8C817A);
  static const border = Color(0xFFD3D0CD);

  // Texto e íconos sobre fondos oscuros
  static const onDark = Color(0xFFFBF9F8);

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

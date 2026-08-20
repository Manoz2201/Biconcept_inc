import 'package:flutter/material.dart';

class AppBreakpoints {
  static const compact = 800.0;
  static const wide = 1100.0;
}

class AppColors {
  static const background = Color(0xFF101218);
  static const sidebar = Color(0xFF161822);
  static const card = Color(0xFF1C2030);
  static const cardHover = Color(0xFF242A3D);
  static const primary = Color(0xFFE8877A);
  static const primarySoft = Color(0xFFF3B3A8);
  static const primaryDim = Color(0x33E8877A);
  static const text = Color(0xFFF5F6FA);
  static const muted = Color(0xFF9AA3B8);
  static const up = Color(0xFF7DCEA0);
  static const down = Color(0xFFE57373);
  static const outline = Color(0xFF2C3348);
  static const drafted = Color(0xFF8B93A7);
  static const completed = Color(0xFF7DCEA0);
  static const finalized = Color(0xFFE8877A);
}

class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      surface: AppColors.background,
      primary: AppColors.primary,
      onPrimary: Color(0xFF1A1010),
      secondary: AppColors.primarySoft,
      onSurface: AppColors.text,
      outline: AppColors.outline,
      error: AppColors.down,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      cardColor: AppColors.card,
      dividerColor: AppColors.outline,
      fontFamily: 'Segoe UI',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: const TextStyle(color: AppColors.muted),
        labelStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.text, fontSize: 12),
        secondaryLabelStyle: const TextStyle(color: Color(0xFF1A1010), fontSize: 12),
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: const Color(0xFF1A1010),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Color(0xFF1A1010),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardHover,
        contentTextStyle: const TextStyle(color: AppColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.sidebar,
        indicatorColor: AppColors.primaryDim,
      ),
    );
  }
}

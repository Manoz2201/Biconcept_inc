import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  const AppTypography._();

  static const fontFamily = 'Manrope';

  static TextTheme textTheme([AppPalette? palette]) {
    final tokens = palette ?? AppColors.palette;
    TextStyle style(double size, FontWeight weight, Color color, {double? letterSpacing, double? height}) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }

    return TextTheme(
      displayLarge: style(32, FontWeight.w700, tokens.textPrimary, letterSpacing: -0.4),
      headlineLarge: style(32, FontWeight.w700, tokens.textPrimary, letterSpacing: -0.4),
      headlineMedium: style(24, FontWeight.w700, tokens.textPrimary, letterSpacing: -0.3),
      headlineSmall: style(20, FontWeight.w600, tokens.textPrimary),
      titleLarge: style(20, FontWeight.w600, tokens.textPrimary),
      titleMedium: style(16, FontWeight.w600, tokens.textPrimary),
      titleSmall: style(14, FontWeight.w600, tokens.textPrimary),
      bodyLarge: style(16, FontWeight.w400, tokens.textPrimary, height: 1.45),
      bodyMedium: style(14, FontWeight.w400, tokens.textPrimary, height: 1.45),
      bodySmall: style(12, FontWeight.w400, tokens.textSecondary, height: 1.4),
      labelLarge: style(14, FontWeight.w600, tokens.onPrimary, letterSpacing: 0.5),
      labelMedium: style(12, FontWeight.w500, tokens.textPrimary),
      labelSmall: style(11, FontWeight.w400, tokens.textSecondary),
    );
  }

  static TextStyle h1([AppPalette? p]) => textTheme(p).headlineLarge!;
  static TextStyle h2([AppPalette? p]) => textTheme(p).headlineMedium!;
  static TextStyle h3([AppPalette? p]) => textTheme(p).headlineSmall!;
  static TextStyle h4([AppPalette? p]) => textTheme(p).titleMedium!;
  static TextStyle bodyLarge([AppPalette? p]) => textTheme(p).bodyLarge!;
  static TextStyle bodyMedium([AppPalette? p]) => textTheme(p).bodyMedium!;
  static TextStyle bodySmall([AppPalette? p]) => textTheme(p).bodySmall!;
  static TextStyle button([AppPalette? p]) =>
      textTheme(p).labelLarge!.copyWith(color: (p ?? AppColors.palette).primaryAccent);
  static TextStyle caption([AppPalette? p]) => textTheme(p).labelSmall!;
  static TextStyle label([AppPalette? p]) => textTheme(p).labelMedium!;
}

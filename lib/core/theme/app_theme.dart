import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter/gestures.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light({Color? primaryOverride}) =>
      _build(AppPalette.light, brightness: Brightness.light, primaryOverride: primaryOverride);

  static ThemeData dark({Color? primaryOverride}) =>
      _build(AppPalette.dark, brightness: Brightness.dark, primaryOverride: primaryOverride);

  static ThemeData fromPalette(AppPalette palette) {
    final dark = palette.backgroundBase.computeLuminance() < 0.45;
    return _build(palette, brightness: dark ? Brightness.dark : Brightness.light);
  }

  static ThemeData _build(AppPalette palette, {required Brightness brightness, Color? primaryOverride}) {
    final accent = primaryOverride ?? palette.primaryAccent;
    final tokens = palette.copyWith(primaryAccent: accent, primaryPressed: primaryOverride == null ? palette.primaryPressed : accent);
    AppColors.bind(tokens);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: tokens.onPrimary,
      secondary: tokens.primarySoftCompat,
      onSecondary: tokens.onPrimary,
      error: tokens.error,
      onError: tokens.onPrimary,
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
      outline: tokens.border,
    );

    final text = AppTypography.textTheme(tokens);
    final radiusXxl = BorderRadius.circular(AppSpacing.radiusXxl);
    final radiusLg = BorderRadius.circular(AppSpacing.radiusLg);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      fontFamily: AppTypography.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.backgroundBase,
      canvasColor: tokens.backgroundBase,
      cardColor: tokens.surface,
      dividerColor: tokens.border,
      textTheme: text,
      primaryTextTheme: text,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.backgroundBase,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: scheme.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: tokens.textPrimary, size: AppSpacing.iconLg),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: tokens.shadowDark,
        shape: RoundedRectangleBorder(borderRadius: radiusXxl),
      ),
      dividerTheme: DividerThemeData(color: tokens.border, thickness: AppSpacing.borderThin, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.backgroundBase,
        hintStyle: text.bodyMedium?.copyWith(color: tokens.textSecondary),
        labelStyle: text.labelMedium,
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: tokens.error),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: radiusLg, borderSide: BorderSide(color: tokens.border)),
        enabledBorder: OutlineInputBorder(borderRadius: radiusLg, borderSide: BorderSide(color: tokens.border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusLg,
          borderSide: BorderSide(color: accent, width: AppSpacing.borderRegular),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radiusLg,
          borderSide: BorderSide(color: tokens.error, width: AppSpacing.borderRegular),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radiusLg,
          borderSide: BorderSide(color: tokens.error, width: AppSpacing.borderRegular),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _primaryButton(tokens, accent)),
      filledButtonTheme: FilledButtonThemeData(style: _primaryButton(tokens, accent)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          backgroundColor: tokens.surface,
          minimumSize: const Size(AppSpacing.touchMin, AppSpacing.touchMin),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: text.labelLarge?.copyWith(color: accent, letterSpacing: 0.5),
          side: BorderSide(color: accent, width: AppSpacing.borderRegular),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(AppSpacing.touchMin, AppSpacing.touchMin),
          textStyle: text.labelLarge?.copyWith(color: accent, letterSpacing: 0.4),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: tokens.onPrimary,
        elevation: 0,
        shape: const CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surface,
        selectedColor: accent,
        labelStyle: text.labelMedium!,
        secondaryLabelStyle: text.labelMedium!.copyWith(color: tokens.onPrimary),
        side: BorderSide(color: tokens.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: radiusXxl),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surface,
        contentTextStyle: text.bodyMedium,
        actionTextColor: accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.surface,
        selectedItemColor: accent,
        unselectedItemColor: tokens.textSecondary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: accent.withValues(alpha: 0.14),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return text.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? accent : tokens.textSecondary,
          );
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent, linearTrackColor: tokens.backgroundBase),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? tokens.onPrimary : tokens.surface),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? accent : tokens.border),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? accent : tokens.surface),
        checkColor: WidgetStateProperty.all(tokens.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
        side: BorderSide(color: tokens.border, width: AppSpacing.borderRegular),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? accent : tokens.textSecondary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: tokens.border,
        thumbColor: tokens.surface,
        overlayColor: accent.withValues(alpha: 0.12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: tokens.textPrimary, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
        textStyle: text.bodySmall?.copyWith(color: tokens.onPrimary),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: tokens.textSecondary,
        textColor: tokens.textPrimary,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        minVerticalPadding: 12,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tokens.onPrimary,
        unselectedLabelColor: tokens.textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ButtonStyle _primaryButton(AppPalette tokens, Color accent) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return tokens.textDisabled;
        if (states.contains(WidgetState.pressed)) return tokens.primaryPressed;
        return accent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return tokens.textPrimary;
        return tokens.onPrimary;
      }),
      minimumSize: const WidgetStatePropertyAll(Size(AppSpacing.touchMin, AppSpacing.touchMin)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
      textStyle: WidgetStatePropertyAll(
        AppTypography.textTheme(tokens).labelLarge?.copyWith(letterSpacing: 0.5),
      ),
      elevation: const WidgetStatePropertyAll(0),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
    );
  }
}

extension on AppPalette {
  Color get primarySoftCompat => Color.lerp(primaryAccent, surface, 0.45) ?? primaryAccent;
}

class AppBreakpoints {
  static const compact = 800.0;
  static const wide = 1100.0;
  static const navClearance = 108.0;
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

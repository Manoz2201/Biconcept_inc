import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.backgroundBase,
    required this.surface,
    required this.primaryAccent,
    required this.primaryPressed,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.error,
    required this.success,
    required this.warning,
    required this.shadowLight,
    required this.shadowDark,
    required this.insetShadow,
    required this.onPrimary,
    required this.overlay,
  });

  final Color backgroundBase;
  final Color surface;
  final Color primaryAccent;
  final Color primaryPressed;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color border;
  final Color error;
  final Color success;
  final Color warning;
  final Color shadowLight;
  final Color shadowDark;
  final Color insetShadow;
  final Color onPrimary;
  final Color overlay;

  /// Warm cream + dark teal, matched to the soft-UI design-system spec.
  static const light = AppPalette(
    backgroundBase: Color(0xFFF7F3EE),
    surface: Color(0xFFFCFAF8),
    primaryAccent: Color(0xFF0B5C5E),
    primaryPressed: Color(0xFF094A4C),
    textPrimary: Color(0xFF2D2A26),
    textSecondary: Color(0xFF7A746E),
    textDisabled: Color(0xFFC4BFB9),
    border: Color(0xFFE6DFD8),
    error: Color(0xFFB83A3A),
    success: Color(0xFF3A7D5C),
    warning: Color(0xFFD48A3A),
    shadowLight: Color(0xCCFFFFFF),
    shadowDark: Color(0x14000000),
    insetShadow: Color(0x1F000000),
    onPrimary: Color(0xFFFFFFFF),
    overlay: Color(0x4D000000),
  );

  static const dark = AppPalette(
    backgroundBase: Color(0xFF1A1A1A),
    surface: Color(0xFF2A2A2A),
    primaryAccent: Color(0xFF4DB6AC),
    primaryPressed: Color(0xFF3A9A91),
    textPrimary: Color(0xFFEAEAEA),
    textSecondary: Color(0xFFB0AAA4),
    textDisabled: Color(0xFF6F6A65),
    border: Color(0xFF3A3A3A),
    error: Color(0xFFE07A7A),
    success: Color(0xFF7BC49A),
    warning: Color(0xFFE0A86A),
    shadowLight: Color(0x1AFFFFFF),
    shadowDark: Color(0x66000000),
    insetShadow: Color(0x99000000),
    onPrimary: Color(0xFF102422),
    overlay: Color(0x99000000),
  );

  static AppPalette of(BuildContext context) {
    return Theme.of(context).extension<AppPalette>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  AppPalette copyWith({
    Color? backgroundBase,
    Color? surface,
    Color? primaryAccent,
    Color? primaryPressed,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? border,
    Color? error,
    Color? success,
    Color? warning,
    Color? shadowLight,
    Color? shadowDark,
    Color? insetShadow,
    Color? onPrimary,
    Color? overlay,
  }) {
    return AppPalette(
      backgroundBase: backgroundBase ?? this.backgroundBase,
      surface: surface ?? this.surface,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      shadowLight: shadowLight ?? this.shadowLight,
      shadowDark: shadowDark ?? this.shadowDark,
      insetShadow: insetShadow ?? this.insetShadow,
      onPrimary: onPrimary ?? this.onPrimary,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      backgroundBase: Color.lerp(backgroundBase, other.backgroundBase, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      shadowLight: Color.lerp(shadowLight, other.shadowLight, t)!,
      shadowDark: Color.lerp(shadowDark, other.shadowDark, t)!,
      insetShadow: Color.lerp(insetShadow, other.insetShadow, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
    );
  }
}

/// Live aliases for the active [AppPalette]. Screens that still read
/// `AppColors.primary` follow the user-selected theme after [bind].
class AppColors {
  const AppColors._();

  static AppPalette _active = AppPalette.light;

  static AppPalette get palette => _active;

  static void bind(AppPalette palette) {
    _active = palette;
  }

  static Color get backgroundBase => _active.backgroundBase;
  static Color get surface => _active.surface;
  static Color get primaryAccent => _active.primaryAccent;
  static Color get primaryHover => _active.primaryPressed;
  static Color get primaryPressed => _active.primaryPressed;
  static Color get textPrimary => _active.textPrimary;
  static Color get textSecondary => _active.textSecondary;
  static Color get textDisabled => _active.textDisabled;
  static Color get border => _active.border;
  static Color get error => _active.error;
  static Color get success => _active.success;
  static Color get warning => _active.warning;
  static Color get shadowLight => _active.shadowLight;
  static Color get shadowDark => _active.shadowDark;
  static Color get insetShadow => _active.insetShadow;
  static Color get onPrimary => _active.onPrimary;
  static Color get tooltip => _active.textPrimary;
  static Color get disabledFill => Color.lerp(_active.backgroundBase, _active.border, 0.65)!;

  static Color get background => _active.backgroundBase;
  static Color get sidebar => Color.lerp(_active.backgroundBase, _active.textPrimary, 0.04)!;
  static Color get card => _active.surface;
  static Color get cardHover => Color.lerp(_active.surface, Colors.white, _active.backgroundBase.computeLuminance() > 0.5 ? 0.45 : 0.06)!;
  static Color get primary => _active.primaryAccent;
  static Color get primarySoft => _active.primaryAccent;
  static Color get primaryDim => _active.primaryAccent.withValues(alpha: 0.10);
  static Color get text => _active.textPrimary;
  static Color get muted => _active.textSecondary;
  static Color get up => _active.success;
  static Color get down => _active.error;
  static Color get outline => _active.border;
  static Color get drafted => Color.lerp(_active.warning, _active.textSecondary, 0.25)!;
  static Color get completed => _active.success;
  static Color get finalized => _active.warning;
}

import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppShadows {
  const AppShadows._();

  static List<BoxShadow> of(AppPalette palette, {required int level, bool inset = false}) {
    if (inset) {
      return [
        BoxShadow(color: palette.insetShadow, offset: const Offset(2, 2), blurRadius: 4, spreadRadius: -1),
      ];
    }
    return switch (level) {
      2 => [
          BoxShadow(color: palette.shadowLight, offset: const Offset(-2, -2), blurRadius: 4),
          BoxShadow(color: palette.shadowDark, offset: const Offset(2, 2), blurRadius: 4),
        ],
      3 => [
          BoxShadow(color: palette.shadowLight, offset: const Offset(-4, -4), blurRadius: 8),
          BoxShadow(color: palette.shadowDark, offset: const Offset(4, 4), blurRadius: 8),
        ],
      4 => [
          BoxShadow(color: palette.shadowLight, offset: const Offset(-6, -6), blurRadius: 16),
          BoxShadow(color: palette.shadowDark, offset: const Offset(6, 6), blurRadius: 16),
        ],
      5 => [
          BoxShadow(color: palette.shadowLight, offset: const Offset(-8, -8), blurRadius: 24),
          BoxShadow(color: palette.shadowDark, offset: const Offset(8, 8), blurRadius: 24),
        ],
      _ => const [],
    };
  }

  static List<BoxShadow> hover([AppPalette? p]) => of(p ?? AppColors.palette, level: 2);
  static List<BoxShadow> raised([AppPalette? p]) => of(p ?? AppColors.palette, level: 3);
  static List<BoxShadow> modal([AppPalette? p]) => of(p ?? AppColors.palette, level: 4);
  static List<BoxShadow> popover([AppPalette? p]) => of(p ?? AppColors.palette, level: 5);
  static List<BoxShadow> inset([AppPalette? p]) => of(p ?? AppColors.palette, level: 1, inset: true);

  static const level1 = <BoxShadow>[];
  static List<BoxShadow> get level2 => hover();
  static List<BoxShadow> get level3 => raised();
  static List<BoxShadow> get level4 => modal();
  static List<BoxShadow> get level5 => popover();
  static List<BoxShadow> get insetShadow => inset();
}

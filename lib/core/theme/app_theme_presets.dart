import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppColorThemePreset {
  const AppColorThemePreset({
    required this.id,
    required this.label,
    required this.tagline,
    required this.swatches,
    this.builtInPalette,
  });

  final String id;
  final String label;
  final String tagline;
  final List<Color> swatches;
  final AppPalette? builtInPalette;

  AppPalette get palette => builtInPalette ?? paletteFromSwatches(swatches);
}

class AppThemePresets {
  const AppThemePresets._();

  static const defaultId = 'biconcept';

  static const biconcept = AppColorThemePreset(
    id: defaultId,
    label: 'Studio Cream',
    tagline: 'Warm ivory walls and dark teal ink',
    swatches: [
      Color(0xFFF7F3EE),
      Color(0xFFFCFAF8),
      Color(0xFF0B5C5E),
      Color(0xFF2D2A26),
    ],
    builtInPalette: AppPalette.light,
  );

  static const all = <AppColorThemePreset>[
    biconcept,
    AppColorThemePreset(
      id: 'palette_1',
      label: 'Harbor Ink',
      tagline: 'Cyan signal over charcoal night',
      swatches: [Color(0xFF00A0D5), Color(0xFF393E46), Color(0xFF222831), Color(0xFFEEEEEE)],
    ),
    AppColorThemePreset(
      id: 'palette_2',
      label: 'Festival Spice',
      tagline: 'Plum, paprika, and gold dusk',
      swatches: [Color(0xFF6A2C70), Color(0xFFB83B5E), Color(0xFFF08A5D), Color(0xFFF9ED69)],
    ),
    AppColorThemePreset(
      id: 'palette_3',
      label: 'Sorbet Garden',
      tagline: 'Mint lawn with a coral punch',
      swatches: [Color(0xFF95E1D3), Color(0xFFEAFFD0), Color(0xFFFCE38A), Color(0xFFF38181)],
    ),
    AppColorThemePreset(
      id: 'palette_4',
      label: 'Neon Arcade',
      tagline: 'Hot pink flash on midnight steel',
      swatches: [Color(0xFFEAEEEE), Color(0xFFFF2E63), Color(0xFF252A34), Color(0xFF08D9D6)],
    ),
    AppColorThemePreset(
      id: 'palette_5',
      label: 'Watermelon Bay',
      tagline: 'Berry splash and harbor teal',
      swatches: [Color(0xFFFC5185), Color(0xFFF5F5F5), Color(0xFF3FC1C9), Color(0xFF364F6B)],
    ),
    AppColorThemePreset(
      id: 'palette_6',
      label: 'Cotton Atelier',
      tagline: 'Lavender, blush, and sky milk',
      swatches: [Color(0xFFFFFDF2), Color(0xFFFCBAD3), Color(0xFFAA96DA), Color(0xFFA8D8EA)],
    ),
    AppColorThemePreset(
      id: 'palette_7',
      label: 'Glacier Whisper',
      tagline: 'Stacked layers of pale aqua',
      swatches: [Color(0xFF71C0CE), Color(0xFFA6E3E9), Color(0xFFCBF1F5), Color(0xFFE3FDFD)],
    ),
    AppColorThemePreset(
      id: 'palette_8',
      label: 'Jade Courtyard',
      tagline: 'Temple pond and mint stone',
      swatches: [Color(0xFF40514E), Color(0xFF11999E), Color(0xFF30E3CA), Color(0xFFE4F9F5)],
    ),
    AppColorThemePreset(
      id: 'palette_9',
      label: 'Rose Quartz',
      tagline: 'Dusty lilac on blush paper',
      swatches: [Color(0xFF8785A2), Color(0xFFF6F6F6), Color(0xFFFFE2E2), Color(0xFFFFC7C7)],
    ),
    AppColorThemePreset(
      id: 'palette_10',
      label: 'Blueprint',
      tagline: 'Navy ink and drafting blue',
      swatches: [Color(0xFF112D4E), Color(0xFF3F72AF), Color(0xFFDBE2EF), Color(0xFFF9F7F7)],
    ),
    AppColorThemePreset(
      id: 'palette_11',
      label: 'Lagoon Library',
      tagline: 'Tide glass and twilight indigo',
      swatches: [Color(0xFFABEDD8), Color(0xFF46CDCF), Color(0xFF3D84A8), Color(0xFF48466D)],
    ),
    AppColorThemePreset(
      id: 'palette_12',
      label: 'Carnival Gold',
      tagline: 'Mustard, magenta, and jade',
      swatches: [Color(0xFFFFDE7D), Color(0xFFF6416C), Color(0xFFF8F3D4), Color(0xFF00B8A9)],
    ),
    AppColorThemePreset(
      id: 'palette_13',
      label: 'Wine Cellar',
      tagline: 'Burgundy velvet after dark',
      swatches: [Color(0xFF533354), Color(0xFF903749), Color(0xFFE84545), Color(0xFF2B2E4A)],
    ),
    AppColorThemePreset(
      id: 'palette_14',
      label: 'Peach Sherbet',
      tagline: 'Sage, peach, and coral cream',
      swatches: [Color(0xFF61C0BF), Color(0xFFBBDED6), Color(0xFFFAE3D9), Color(0xFFFFB6B9)],
    ),
    AppColorThemePreset(
      id: 'palette_15',
      label: 'Velvet Opera',
      tagline: 'Plum stage and a crimson bow',
      swatches: [Color(0xFF311D3F), Color(0xFF522546), Color(0xFF88304E), Color(0xFFE23E57)],
    ),
    AppColorThemePreset(
      id: 'palette_16',
      label: 'Spring Ledger',
      tagline: 'Sky, lime, and blush notes',
      swatches: [Color(0xFFA5DEE5), Color(0xFFE0F9B5), Color(0xFFFEFDCA), Color(0xFFFFCFD0)],
    ),
    AppColorThemePreset(
      id: 'palette_17',
      label: 'Circuit Teal',
      tagline: 'Neon current on graphite',
      swatches: [Color(0xFF14FFEC), Color(0xFF0D7377), Color(0xFF323232), Color(0xFF212121)],
    ),
    AppColorThemePreset(
      id: 'palette_18',
      label: 'Apricot Grove',
      tagline: 'Picnic fruit and garden mint',
      swatches: [Color(0xFFFFAAA5), Color(0xFFFFD3B6), Color(0xFFDCEDC1), Color(0xFFA8E6CF)],
    ),
    AppColorThemePreset(
      id: 'palette_19',
      label: 'Lavender Fog',
      tagline: 'Lilac weather over pale sky',
      swatches: [Color(0xFFCCA8E9), Color(0xFFC3BEF0), Color(0xFFCADEFC), Color(0xFFDEFCF9)],
    ),
    AppColorThemePreset(
      id: 'palette_20',
      label: 'Ash Blush',
      tagline: 'Slate walls and rose dust',
      swatches: [Color(0xFF364149), Color(0xFF444F5A), Color(0xFFF99999), Color(0xFFFFC8C8)],
    ),
  ];

  static AppColorThemePreset byId(String? id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return biconcept;
  }
}

String themeSwatchHex(Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
  return '#${hex.toUpperCase()}';
}

AppPalette paletteFromSwatches(List<Color> swatches) {
  final colors = swatches.isEmpty ? AppThemePresets.biconcept.swatches : swatches;
  final sorted = [...colors]..sort((a, b) => a.computeLuminance().compareTo(b.computeLuminance()));
  final darkest = sorted.first;
  final lightest = sorted.last;
  final avg = colors.fold<double>(0, (sum, color) => sum + color.computeLuminance()) / colors.length;
  final darkUi = avg < 0.42 || (lightest.computeLuminance() < 0.62 && darkest.computeLuminance() < 0.18);

  var accent = colors.first;
  var best = -100.0;
  for (final color in colors) {
    final lum = color.computeLuminance();
    final sat = HSLColor.fromColor(color).saturation;
    var score = sat * 2.2 + (1 - (lum - 0.42).abs() * 1.5);
    if (darkUi && lum > 0.88) score -= 1.2;
    if (!darkUi && lum < 0.08) score -= 0.8;
    if (score > best) {
      best = score;
      accent = color;
    }
  }

  final Color background;
  final Color surface;
  if (darkUi) {
    background = darkest;
    final second = sorted.length > 1 ? sorted[1] : darkest;
    surface = (second.computeLuminance() - background.computeLuminance()).abs() < 0.16
        ? second
        : Color.lerp(background, Colors.white, 0.08)!;
  } else {
    background = lightest;
    final secondLight = sorted.length > 2 ? sorted[sorted.length - 2] : lightest;
    surface = secondLight != accent && secondLight.computeLuminance() > 0.82
        ? secondLight
        : Color.lerp(lightest, Colors.white, 0.28)!;
  }

  final text = darkUi
      ? (lightest.computeLuminance() > 0.55 ? lightest : const Color(0xFFEAEAEA))
      : (darkest.computeLuminance() < 0.42 ? darkest : const Color(0xFF2D2A26));
  final textSecondary = Color.lerp(text, background, 0.38)!;
  final onPrimary = accent.computeLuminance() > 0.55 ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);

  return AppPalette(
    backgroundBase: background,
    surface: surface,
    primaryAccent: accent,
    primaryPressed: Color.lerp(accent, darkUi ? Colors.white : Colors.black, 0.18)!,
    textPrimary: text,
    textSecondary: textSecondary,
    textDisabled: Color.lerp(text, background, 0.62)!,
    border: Color.lerp(background, text, darkUi ? 0.18 : 0.12)!,
    error: darkUi ? const Color(0xFFE07A7A) : const Color(0xFFB83A3A),
    success: darkUi ? const Color(0xFF7BC49A) : const Color(0xFF3A7D5C),
    warning: darkUi ? const Color(0xFFE0A86A) : const Color(0xFFD48A3A),
    shadowLight: darkUi ? const Color(0x1AFFFFFF) : const Color(0xCCFFFFFF),
    shadowDark: darkUi ? const Color(0x66000000) : const Color(0x14000000),
    insetShadow: darkUi ? const Color(0x99000000) : const Color(0x1F000000),
    onPrimary: onPrimary,
    overlay: darkUi ? const Color(0x99000000) : const Color(0x4D000000),
  );
}

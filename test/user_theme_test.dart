import 'package:biconcept/core/theme/app_colors.dart';
import 'package:biconcept/core/theme/app_theme_presets.dart';
import 'package:biconcept/core/theme/user_theme_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog has BiConcept plus the 20 image palettes', () {
    expect(AppThemePresets.all.length, 21);
    expect(AppThemePresets.all.first.id, AppThemePresets.defaultId);
    expect({for (final preset in AppThemePresets.all) preset.id}.length, 21);
    expect(AppThemePresets.all.every((preset) => preset.swatches.length == 4), isTrue);
    expect(AppThemePresets.byId('missing').id, AppThemePresets.defaultId);
    expect(AppThemePresets.byId('palette_12').label, 'Carnival Gold');
    expect(AppThemePresets.all.every((preset) => preset.tagline.isNotEmpty), isTrue);
    expect(themeSwatchHex(const Color(0xFFF6416C)), '#F6416C');
  });

  test('derived palettes keep readable text against the page', () {
    for (final preset in AppThemePresets.all) {
      final palette = preset.palette;
      expect(
        (palette.backgroundBase.computeLuminance() - palette.textPrimary.computeLuminance()).abs(),
        greaterThan(0.25),
        reason: preset.id,
      );
    }
  });

  test('AppColors aliases follow the bound palette', () {
    final carnival = AppThemePresets.byId('palette_12').palette;
    AppColors.bind(carnival);
    expect(AppColors.primary, carnival.primaryAccent);
    expect(AppColors.background, carnival.backgroundBase);
    expect(AppColors.card, carnival.surface);
    expect(AppColors.muted, carnival.textSecondary);
    AppColors.bind(AppPalette.light);
    expect(AppColors.primary, AppPalette.light.primaryAccent);
  });

  test('theme choice is stored per user on the device', () async {
    SharedPreferences.setMockInitialValues({});
    final store = UserThemeStore();

    await store.save(userKey: 'staff-1', presetId: 'palette_4');
    await store.save(userKey: 'client-9', presetId: 'palette_17');

    expect(await store.load('staff-1'), 'palette_4');
    expect(await store.load('client-9'), 'palette_17');
    expect(await store.load(null), 'palette_17');
    expect(await store.load('unknown'), 'palette_17');
  });
}

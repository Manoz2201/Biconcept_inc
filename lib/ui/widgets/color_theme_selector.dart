import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/user_theme_provider.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_feedback.dart';
import '../../theme/app_theme.dart';

class ColorThemeSelector extends ConsumerWidget {
  const ColorThemeSelector({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final selected = AppThemePresets.byId(ref.watch(userThemeProvider));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.palette_outlined, size: 18, color: palette.primaryAccent),
            const SizedBox(width: 8),
            Text(
              'COLOR THEME',
              style: TextStyle(color: palette.primaryAccent, fontSize: 11, letterSpacing: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'pick a palette',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: compact ? 22 : 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Saved on this device for your account. Open a palette to see every color, then apply it.',
          style: TextStyle(color: palette.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        Material(
          color: palette.backgroundBase,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => showColorThemePicker(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected.label,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(selected.tagline, style: TextStyle(color: palette.textSecondary, height: 1.35)),
                          ],
                        ),
                      ),
                      Icon(Icons.grid_view_rounded, color: palette.primaryAccent),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        for (var i = 0; i < selected.swatches.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: selected.swatches[i],
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: AppShadows.raised(palette),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppSecondaryButton(label: 'Browse palettes', onPressed: () => showColorThemePicker(context)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showColorThemePicker(BuildContext context) {
  final palette = AppPalette.of(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: palette.overlay,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondary) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondary, _) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: const ColorThemePickerDialog(),
        ),
      );
    },
  );
}

class ColorThemePickerDialog extends ConsumerStatefulWidget {
  const ColorThemePickerDialog({super.key});

  @override
  ConsumerState<ColorThemePickerDialog> createState() => _ColorThemePickerDialogState();
}

class _ColorThemePickerDialogState extends ConsumerState<ColorThemePickerDialog> {
  late AppColorThemePreset _preview;

  @override
  void initState() {
    super.initState();
    _preview = AppThemePresets.byId(ref.read(userThemeProvider));
  }

  Future<void> _apply() async {
    await ref.read(userThemeProvider.notifier).select(_preview.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppToast(context, message: '${_preview.label} applied', tone: AppToastTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final appliedId = ref.watch(userThemeProvider);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 760 : 520, maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: AppSpacing.radiusAllXxl,
                boxShadow: AppShadows.modal(palette),
              ),
              child: ClipRRect(
                borderRadius: AppSpacing.radiusAllXxl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pick a palette', style: AppTypography.h3(palette)),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap a look to inspect every color, then apply it.',
                                  style: AppTypography.bodySmall(palette).copyWith(color: palette.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                        children: [
                          _PaletteColorCard(preset: _preview),
                          const SizedBox(height: 20),
                          Text(
                            'ALL LOOKS',
                            style: TextStyle(color: palette.textSecondary, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: AppThemePresets.all.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: wide ? 3 : 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: wide ? 1.55 : 1.28,
                            ),
                            itemBuilder: (context, index) {
                              final preset = AppThemePresets.all[index];
                              return _PaletteChoiceTile(
                                preset: preset,
                                inspecting: preset.id == _preview.id,
                                applied: preset.id == appliedId,
                                onTap: () => setState(() => _preview = preset),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppSecondaryButton(
                              label: 'Close',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppPrimaryButton(
                              label: appliedId == _preview.id ? 'Applied' : 'Apply theme',
                              onPressed: appliedId == _preview.id ? null : _apply,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteColorCard extends StatelessWidget {
  const _PaletteColorCard({required this.preset});

  final AppColorThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.backgroundBase,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preset.label,
              style: TextStyle(color: palette.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(preset.tagline, style: TextStyle(color: palette.textSecondary, height: 1.35)),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoUp = constraints.maxWidth < 420;
                final tiles = [
                  for (var i = 0; i < preset.swatches.length; i++)
                    _SwatchTile(color: preset.swatches[i], index: i + 1),
                ];
                if (twoUp) {
                  return Column(
                    children: [
                      Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 8), Expanded(child: tiles[1])]),
                      const SizedBox(height: 8),
                      Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 8), Expanded(child: tiles[3])]),
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SwatchTile extends StatelessWidget {
  const _SwatchTile({required this.color, required this.index});

  final Color color;
  final int index;

  @override
  Widget build(BuildContext context) {
    final onColor = color.computeLuminance() > 0.55 ? const Color(0xFF1A1A1A) : Colors.white;
    return AspectRatio(
      aspectRatio: 1.05,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Color $index',
                style: TextStyle(color: onColor.withValues(alpha: 0.72), fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                themeSwatchHex(color),
                style: TextStyle(
                  color: onColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteChoiceTile extends StatelessWidget {
  const _PaletteChoiceTile({
    required this.preset,
    required this.inspecting,
    required this.applied,
    required this.onTap,
  });

  final AppColorThemePreset preset;
  final bool inspecting;
  final bool applied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: inspecting ? palette.primaryAccent : palette.border,
              width: inspecting ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preset.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (applied) Icon(Icons.check_circle, size: 16, color: palette.primaryAccent),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < preset.swatches.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: preset.swatches[i],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

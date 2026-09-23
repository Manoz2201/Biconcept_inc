import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.suffix,
    this.prefix,
    this.maxLines = 1,
    this.enabled = true,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final Widget? prefix;
  final int maxLines;
  final bool enabled;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTypography.label(palette)),
          const SizedBox(height: AppSpacing.xs),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppSpacing.radiusAllLg,
            boxShadow: AppShadows.inset(palette),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            onChanged: onChanged,
            maxLines: maxLines,
            enabled: enabled,
            autofillHints: autofillHints,
            style: AppTypography.bodyMedium(palette),
            decoration: InputDecoration(
              hintText: hint,
              helperText: helper,
              errorText: errorText,
              prefixIcon: prefix,
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}

class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: AppSpacing.radiusAllSm,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchMin),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? palette.primaryAccent : palette.surface,
                borderRadius: AppSpacing.radiusAllSm,
                border: Border.all(color: value ? palette.primaryAccent : palette.border, width: AppSpacing.borderRegular),
              ),
              child: value ? Icon(Icons.check, size: 16, color: palette.onPrimary) : null,
            ),
            if (label != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Flexible(child: Text(label!, style: AppTypography.bodyMedium(palette))),
            ],
          ],
        ),
      ),
    );
  }
}

class AppRadio<T> extends StatelessWidget {
  const AppRadio({super.key, required this.value, required this.groupValue, required this.onChanged, this.label});

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final selected = value == groupValue;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchMin),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? palette.primaryAccent : palette.border, width: AppSpacing.borderRegular),
              ),
              child: selected
                  ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(color: palette.primaryAccent, shape: BoxShape.circle)))
                  : null,
            ),
            if (label != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(label!, style: AppTypography.bodyMedium(palette)),
            ],
          ],
        ),
      ),
    );
  }
}

class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(value: value, onChanged: onChanged);
  }
}

class AppSlider extends StatelessWidget {
  const AppSlider({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 1});

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    return Slider(value: value, onChanged: onChanged, min: min, max: max);
  }
}

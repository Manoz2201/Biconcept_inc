import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppPrimaryButton extends StatefulWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.loadingLabel = 'Sending...',
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String loadingLabel;
  final IconData? icon;

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton> {
  var _pressed = false;
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final enabled = widget.onPressed != null && !widget.loading;
    final shadows = !enabled
        ? const <BoxShadow>[]
        : _pressed
            ? AppShadows.inset(palette)
            : _hovered
                ? AppShadows.hover(palette)
                : AppShadows.raised(palette);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onPressed?.call();
                }
              : null,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1,
            duration: const Duration(milliseconds: 120),
            child: RepaintBoundary(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                constraints: const BoxConstraints(minHeight: AppSpacing.touchMin, minWidth: AppSpacing.touchMin),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: enabled ? (_pressed ? palette.primaryPressed : palette.primaryAccent) : AppColors.disabledFill,
                  borderRadius: AppSpacing.radiusAllPill,
                  boxShadow: shadows,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.loading) ...[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: palette.onPrimary),
                      ),
                      const SizedBox(width: 10),
                    ] else if (widget.icon != null) ...[
                      Icon(widget.icon, size: AppSpacing.iconMd, color: enabled ? palette.onPrimary : palette.textPrimary),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.loading ? widget.loadingLabel : widget.label,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: enabled ? palette.onPrimary : palette.textSecondary,
                        fontWeight: FontWeight.w600,
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

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({super.key, required this.label, this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchMin),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: AppSpacing.iconMd),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            backgroundColor: palette.surface,
            foregroundColor: palette.primaryAccent,
            side: BorderSide(color: palette.primaryAccent, width: AppSpacing.borderRegular),
            shape: const StadiumBorder(),
          ),
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, this.onPressed, this.tooltip, this.accent = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final button = Semantics(
      button: true,
      label: tooltip ?? 'Icon button',
      child: RepaintBoundary(
        child: Material(
          color: accent ? palette.primaryAccent : palette.surface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onPressed!.call();
                  },
            child: Ink(
              width: AppSpacing.touchMin,
              height: AppSpacing.touchMin,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent ? palette.primaryAccent : palette.surface,
                boxShadow: AppShadows.hover(palette),
              ),
              child: Icon(icon, size: AppSpacing.iconLg, color: accent ? palette.onPrimary : palette.primaryAccent),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class AppTextButton extends StatelessWidget {
  const AppTextButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

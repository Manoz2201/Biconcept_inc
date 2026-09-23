import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

Future<T?> showAppModal<T>({
  required BuildContext context,
  required Widget child,
  String? title,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: AppPalette.of(context).overlay,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondary) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (context, animation, secondary, _) {
      final palette = AppPalette.of(context);
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: RepaintBoundary(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: AppSpacing.radiusAllXxl,
                      boxShadow: AppShadows.modal(palette),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (title != null) ...[
                          Text(title, style: AppTypography.h3(palette)),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

enum AppToastTone { success, info }

void showAppToast(BuildContext context, {required String message, AppToastTone tone = AppToastTone.info}) {
  final palette = AppPalette.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: AppSpacing.radiusAllLg,
          boxShadow: AppShadows.raised(palette),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(tone == AppToastTone.success ? Icons.check_circle_outline : Icons.info_outline, color: tone == AppToastTone.success ? palette.success : palette.primaryAccent),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: AppTypography.bodyMedium(palette))),
            ],
          ),
        ),
      ),
    ),
  );
}

class AppAlertBanner extends StatelessWidget {
  const AppAlertBanner({super.key, required this.message, this.icon = Icons.info_outline});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: palette.primaryAccent, borderRadius: AppSpacing.radiusAllLg),
      child: Row(
        children: [
          Icon(icon, size: AppSpacing.iconLg, color: palette.onPrimary),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTypography.bodyMedium(palette).copyWith(color: palette.onPrimary))),
        ],
      ),
    );
  }
}

class AppLinearProgress extends StatelessWidget {
  const AppLinearProgress({super.key, this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ClipRRect(
      borderRadius: AppSpacing.radiusAllSm,
      child: LinearProgressIndicator(value: value, color: palette.primaryAccent, backgroundColor: palette.backgroundBase, minHeight: 8),
    );
  }
}

class AppSpinner extends StatelessWidget {
  const AppSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _Dot(delay: Duration(milliseconds: 120 * i), color: palette.primaryAccent),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay, required this.color});

  final Duration delay;
  final Color color;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future<void>.delayed(widget.delay),
      builder: (context, snapshot) {
        return FadeTransition(
          opacity: _controller,
          child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
        );
      },
    );
  }
}

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.height = 16, this.width, this.radius = AppSpacing.radiusMd});

  final double height;
  final double? width;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(1 + _controller.value * 2, 0),
              colors: [palette.backgroundBase, palette.surface, palette.backgroundBase],
            ),
          ),
        );
      },
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({super.key, required this.title, this.subtitle, this.icon = Icons.inbox_outlined, this.actionLabel, this.onAction});

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: palette.textSecondary),
          const SizedBox(height: 16),
          Text(title, style: AppTypography.h3(palette), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: AppTypography.bodyMedium(palette).copyWith(color: palette.textSecondary), textAlign: TextAlign.center),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            AppSecondaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

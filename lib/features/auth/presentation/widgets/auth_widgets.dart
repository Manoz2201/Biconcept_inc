import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_data_display.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../models/company_profile.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.backgroundBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              child: AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => _openStudio(context),
                        child: Image.asset(
                          companyLogoAsset,
                          height: 56,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _openStudio(context),
                        child: const Text('Back to studio'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(title, style: AppTypography.h2(palette)),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle!, style: AppTypography.bodyMedium(palette).copyWith(color: palette.textSecondary, height: 1.4)),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    child,
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

void _openStudio(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go('/');
    return;
  }
  Navigator.of(context).maybePop();
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppAlertBanner(message: message, icon: Icons.error_outline),
    );
  }
}

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  static int scoreOf(String password) {
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score.clamp(0, 5);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final score = scoreOf(password);
    final label = switch (score) {
      0 || 1 => 'Weak',
      2 || 3 => 'Okay',
      _ => 'Strong',
    };
    final color = score >= 4 ? palette.success : score >= 2 ? palette.warning : palette.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xs),
        AppLinearProgress(value: password.isEmpty ? 0 : (score / 5)),
        const SizedBox(height: 6),
        Text(
          password.isEmpty ? 'Use 8+ characters with mixed case and a number' : label,
          style: AppTypography.caption(palette).copyWith(color: color),
        ),
      ],
    );
  }
}

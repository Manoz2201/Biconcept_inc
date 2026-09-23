import 'package:flutter/material.dart';
import 'package:flutter_easy_seo/flutter_easy_seo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../core/router/home_location.dart';
import '../../../../models/company_profile.dart';
import '../../../../theme/app_theme.dart';

class PublicShell extends ConsumerWidget {
  const PublicShell({
    super.key,
    required this.child,
    this.title,
    this.description,
    this.immersive = false,
    this.onStartProject,
  });

  final Widget child;
  final String? title;
  final String? description;
  final bool immersive;
  final VoidCallback? onStartProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final signedIn = session.isAuthenticated;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1280;
    final showStart = width >= 640;
    final palette = AppPalette.of(context);
    final onBar = immersive ? const Color(0xFFF7F3EE) : palette.textPrimary;
    final barColor = immersive ? const Color(0xFF1C1916) : palette.surface;

    void startProject() {
      if (onStartProject != null) {
        onStartProject!();
        return;
      }
      context.go('/contact');
    }

    final body = Scaffold(
      backgroundColor: immersive ? const Color(0xFF1C1916) : palette.backgroundBase,
      appBar: AppBar(
        backgroundColor: barColor,
        foregroundColor: onBar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: InkWell(
          onTap: () => context.go('/'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                companyLogoAsset,
                height: 32,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(width: 10),
              Text(
                companyDisplayName,
                style: TextStyle(
                  color: onBar,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (wide) ...[
            _NavLink(label: 'Services', path: '/services', color: onBar),
            _NavLink(label: 'Projects', path: '/portfolio', color: onBar),
            _NavLink(label: 'About', path: '/about', color: onBar),
            _NavLink(label: 'Contact', path: '/contact', color: onBar),
          ] else
            PopupMenuButton<String>(
              icon: Icon(Icons.menu_rounded, color: onBar),
              onSelected: (value) {
                if (value == 'start') {
                  startProject();
                  return;
                }
                context.go(value);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: '/services', child: Text('Services')),
                const PopupMenuItem(value: '/portfolio', child: Text('Projects')),
                const PopupMenuItem(value: '/about', child: Text('About')),
                const PopupMenuItem(value: '/contact', child: Text('Contact')),
                const PopupMenuItem(value: 'start', child: Text('Start a project')),
                PopupMenuItem(
                  value: signedIn ? homeLocationFor(session.user?.role) : '/login',
                  child: Text(signedIn ? 'Open app' : 'Login'),
                ),
                if (!signedIn) const PopupMenuItem(value: '/register', child: Text('Create account')),
              ],
            ),
          if (showStart)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextButton(
                onPressed: startProject,
                child: Text(
                  'Start a project',
                  style: TextStyle(color: onBar, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            child: FilledButton(
              key: const Key('public-login'),
              onPressed: () => context.go(signedIn ? homeLocationFor(session.user?.role) : '/login'),
              style: FilledButton.styleFrom(
                backgroundColor: immersive ? onBar : palette.primaryAccent,
                foregroundColor: immersive ? const Color(0xFF1C1916) : palette.onPrimary,
                minimumSize: const Size(88, 40),
              ),
              child: Text(signedIn ? 'Open app' : 'Login'),
            ),
          ),
        ],
      ),
      body: child,
    );
    if (title == null) return body;
    return EasySEOPage(
      title: title!,
      description: description,
      child: body,
    );
  }
}

Future<void> launchStudioCall(BuildContext context) async {
  final phone = defaultCompanyPhone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri(scheme: 'tel', path: phone);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Call $defaultCompanyPhone')),
  );
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.path, required this.color});

  final String label;
  final String path;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).uri.path;
    final selected = current == path || current.startsWith('$path/');
    return TextButton(
      onPressed: () => context.go(path),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: selected ? 1 : 0.72),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class CatalogAsync<T> extends StatelessWidget {
  const CatalogAsync({super.key, required this.value, required this.builder, this.empty});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$error', style: TextStyle(color: AppColors.down)),
        ),
      ),
      data: (data) {
        if (data is List && data.isEmpty) {
          return empty ??
              Center(
                child: Text('Nothing to show yet', style: TextStyle(color: AppColors.muted)),
              );
        }
        return builder(data);
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'app_nav.dart';
import 'ui_kit.dart';

class AppPortalShell extends StatelessWidget {
  const AppPortalShell({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onSelect,
    required this.destinations,
  });

  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<AppNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.compact;
        final palette = AppPalette.of(context);
        return Scaffold(
          backgroundColor: palette.backgroundBase,
          extendBody: compact,
          body: SafeArea(
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!compact)
                  AppSidebar(
                    index: selectedIndex,
                    onSelect: onSelect,
                    destinations: destinations,
                  ),
                Expanded(child: child),
              ],
            ),
          ),
          bottomNavigationBar: compact
              ? AppBottomNav(
                  selectedIndex: selectedIndex,
                  onSelect: onSelect,
                  destinations: destinations,
                )
              : null,
        );
      },
    );
  }
}

class PortalPageScaffold extends StatelessWidget {
  const PortalPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final pad = compact ? 16.0 : 24.0;
    final palette = AppPalette.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, compact ? 8 : 16, pad, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: compact ? 32 : 40,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: TextStyle(color: palette.textSecondary, fontSize: compact ? 14 : 16, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
    return Scaffold(
      backgroundColor: palette.backgroundBase,
      floatingActionButton: floatingActionButton,
      body: content,
    );
  }
}

class PortalKpiCard extends StatelessWidget {
  const PortalKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.backgroundBase,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: palette.primaryAccent, size: 24),
              ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 16),
            Text(caption!, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class PortalSectionCard extends StatelessWidget {
  const PortalSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.onTap,
  });

  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

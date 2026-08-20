import 'package:flutter/material.dart';

import '../../models/estimate_document.dart';
import '../../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.7)),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: body,
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final EstimateStatus status;
  final bool compact;

  Color get _color => switch (status) {
        EstimateStatus.drafted => AppColors.drafted,
        EstimateStatus.completed => AppColors.completed,
        EstimateStatus.finalized => AppColors.finalized,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.45)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.onTap,
  });

  final String label;
  final String value;
  final double? delta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final up = (delta ?? 0) >= 0;
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 160.0;
          final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 280.0;
          final pad = (height * 0.14).clamp(10.0, 20.0);
          final innerWidth = (width - pad * 2).clamp(1.0, 800.0);
          final gap1 = (height * 0.06).clamp(4.0, 10.0);
          final gap2 = (height * 0.08).clamp(4.0, 18.0);
          return Padding(
            padding: EdgeInsets.all(pad),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: innerWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    SizedBox(height: gap1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                    SizedBox(height: gap2),
                    Row(
                      children: [
                        if (delta != null)
                          Flexible(
                            child: Text(
                              '${up ? '+' : ''}${delta!.toStringAsFixed(1)}% vs last month',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: up ? AppColors.up : AppColors.down,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        const Icon(Icons.north_east_rounded, size: 16, color: AppColors.muted),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.index,
    required this.onSelect,
  });

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'biconcept',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _NavItem(
                      icon: Icons.dashboard_rounded,
                      label: 'dashboard',
                      selected: index == 0,
                      onTap: () => onSelect(0),
                    ),
                    _NavItem(
                      icon: Icons.request_quote_rounded,
                      label: 'estimates',
                      selected: index == 1,
                      onTap: () => onSelect(1),
                    ),
                    _NavItem(
                      icon: Icons.people_alt_rounded,
                      label: 'clients',
                      selected: index == 2,
                      onTap: () => onSelect(2),
                    ),
                    _NavItem(
                      icon: Icons.calendar_month_rounded,
                      label: 'calendar',
                      selected: index == 3,
                      onTap: () => onSelect(3),
                    ),
                    _NavItem(
                      icon: Icons.menu_book_rounded,
                      label: 'rate card',
                      selected: index == 4,
                      onTap: () => onSelect(4),
                    ),
                  ],
                ),
              ),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              label: 'settings',
              selected: index == 5,
              onTap: () => onSelect(5),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  Image.asset(
                    'assets/data/logo.png',
                    width: 64,
                    height: 44,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'BiConcept',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 78,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: selected ? const Color(0xFF1A1010) : AppColors.muted),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.text : AppColors.muted,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.searchHint,
    this.onSearch,
    this.trailing,
    this.compact = false,
    this.muted = false,
  });

  final String title;
  final String? searchHint;
  final ValueChanged<String>? onSearch;
  final Widget? trailing;
  final bool compact;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: muted ? AppColors.muted : AppColors.text,
      fontSize: muted ? (compact ? 16 : 18) : (compact ? 22 : 28),
      fontWeight: FontWeight.w600,
      letterSpacing: muted ? 0 : -0.6,
    );
    final titleText = title.isEmpty
        ? null
        : Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          );
    final searchField = onSearch == null
        ? null
        : TextField(
            key: ValueKey(searchHint),
            onChanged: onSearch,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
              hintText: searchHint ?? 'Search',
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (titleText != null) Expanded(child: titleText),
                if (titleText == null) const Spacer(),
                ?trailing,
              ],
            ),
            if (searchField != null) ...[
              const SizedBox(height: 10),
              searchField,
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
      child: Row(
        children: [
          if (titleText != null) ...[
            Flexible(child: titleText),
            const SizedBox(width: 16),
          ],
          if (searchField != null)
            Flexible(
              flex: 2,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: searchField,
              ),
            ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

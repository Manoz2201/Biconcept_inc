import 'package:flutter/material.dart';

import '../../domain/service_item.dart';
import '../../../../theme/app_theme.dart';
import 'service_card.dart';

class ServiceCatalogBrowser extends StatefulWidget {
  const ServiceCatalogBrowser({
    super.key,
    required this.items,
    required this.onServiceTap,
  });

  final List<ServiceItem> items;
  final ValueChanged<ServiceItem> onServiceTap;

  @override
  State<ServiceCatalogBrowser> createState() => _ServiceCatalogBrowserState();
}

class _ServiceCatalogBrowserState extends State<ServiceCatalogBrowser> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final categories = {for (final item in items) item.category}.where((v) => v.isNotEmpty).toList()..sort();
    final visible = _category == null ? items : items.where((item) => item.category == _category).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CategoryTile(
                label: 'All',
                count: items.length,
                icon: Icons.grid_view_rounded,
                accent: AppColors.primary,
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 10),
                _CategoryTile(
                  label: category,
                  count: items.where((item) => item.category == category).length,
                  icon: catalogCategoryIcon(category),
                  accent: catalogCategoryAccent(category),
                  selected: _category == category,
                  onTap: () => setState(() => _category = category),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _category == null ? '${visible.length} services' : '$_category · ${visible.length}',
          style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1100 ? 3 : width >= 700 ? 2 : 1;
            const gap = 14.0;
            final cardWidth = columns == 1 ? width : (width - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < visible.length; i++)
                  SizedBox(
                    width: cardWidth,
                    child: _Appear(
                      delay: Duration(milliseconds: 40 * (i % 12)),
                      child: ServiceCard(
                        item: visible[i],
                        onTap: () => widget.onServiceTap(visible[i]),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

IconData catalogCategoryIcon(String category) {
  return switch (category) {
    'Architecture' => Icons.architecture,
    'Building' => Icons.foundation_outlined,
    'Renovation' => Icons.handyman_outlined,
    'Interiors' => Icons.chair_outlined,
    'Commercial' => Icons.apartment_outlined,
    'Add-ons' => Icons.auto_awesome_outlined,
    _ => Icons.design_services_outlined,
  };
}

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 148,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: selected ? widget.accent : AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected || _hover ? AppShadows.raised() : AppShadows.hover(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, color: selected ? AppColors.onPrimary : widget.accent, size: 22),
              const SizedBox(height: 12),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.onPrimary : AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.count}',
                style: TextStyle(
                  color: selected ? AppColors.onPrimary.withValues(alpha: 0.8) : AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Appear extends StatefulWidget {
  const _Appear({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> {
  var _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        offset: _visible ? Offset.zero : const Offset(0, 0.06),
        child: widget.child,
      ),
    );
  }
}

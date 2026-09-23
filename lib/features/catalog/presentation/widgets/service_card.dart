import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/service_item.dart';
import '../../../../theme/app_theme.dart';

Color catalogCategoryAccent(String category) {
  return switch (category) {
    'Architecture' => AppColors.primary,
    'Building' => const Color(0xFF5C4A32),
    'Renovation' => AppColors.warning,
    'Interiors' => AppColors.success,
    'Commercial' => const Color(0xFF1F6F71),
    'Add-ons' => AppColors.drafted,
    _ => AppColors.primarySoft,
  };
}

IconData catalogIcon(String? name) {
  return switch (name) {
    'home' => Icons.home_work_outlined,
    'office' => Icons.apartment_outlined,
    'interior' => Icons.chair_outlined,
    'architecture' => Icons.architecture,
    'consult' => Icons.handshake_outlined,
    'light' => Icons.light_outlined,
    'building' => Icons.foundation_outlined,
    'renovation' => Icons.handyman_outlined,
    'kitchen' => Icons.kitchen_outlined,
    _ => Icons.design_services_outlined,
  };
}

class ServiceCard extends StatefulWidget {
  const ServiceCard({super.key, required this.item, this.onTap});

  final ServiceItem item;
  final VoidCallback? onTap;

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> {
  var _hover = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final price = item.startingPrice;
    final accent = catalogCategoryAccent(item.category);
    final active = _hover || _pressed;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                setState(() => _pressed = false);
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : _hover ? 1.02 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: active ? AppColors.cardHover : AppColors.card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _pressed ? AppShadows.inset() : _hover ? AppShadows.modal() : AppShadows.raised(),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 104,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: _hover ? 0.28 : 0.16),
                        AppColors.background.withValues(alpha: 0.4),
                        AppColors.card,
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -18,
                        top: -22,
                        child: AnimatedScale(
                          scale: _hover ? 1.15 : 1,
                          duration: const Duration(milliseconds: 240),
                          child: Icon(catalogIcon(item.icon), size: 96, color: accent.withValues(alpha: 0.14)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _hover ? AppShadows.hover() : AppShadows.inset(),
                              ),
                              child: Icon(catalogIcon(item.icon), color: accent, size: 26),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.card.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                item.category,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.shortDescription,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.muted, height: 1.4, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (price != null)
                            Flexible(
                              child: Text(
                                'From ₹${price.toStringAsFixed(0)}${item.priceUnit == null ? '' : ' / ${item.priceUnit}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: 8),
                          AnimatedOpacity(
                            opacity: _hover ? 1 : 0.72,
                            duration: const Duration(milliseconds: 160),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Explore',
                                  style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 2),
                                AnimatedSlide(
                                  duration: const Duration(milliseconds: 160),
                                  offset: _hover ? const Offset(0.15, 0) : Offset.zero,
                                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: accent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

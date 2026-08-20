import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_theme.dart';

/// Animotion N13 — bottom-nav-active (bounce up with overshoot).
const navActiveCurve = Cubic(0.34, 1.56, 0.64, 1);
const navActiveDuration = Duration(milliseconds: 300);

/// Lucide SVGs from Animotion (`lucide:layout-dashboard`, `file-text`, `users`, `calendar`, `book`, `settings`).
class AppNavIcons {
  static const dashboard =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" height="5" x="14" y="3" rx="1"/><rect width="7" height="9" x="14" y="12" rx="1"/><rect width="7" height="5" x="3" y="16" rx="1"/></svg>';
  static const estimates =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/></svg>';
  static const clients =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><path d="M16 3.128a4 4 0 0 1 0 7.744"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><circle cx="9" cy="7" r="4"/></svg>';
  static const calendar =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 2v3"/><path d="M16 2v3"/><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/></svg>';
  static const rates =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20"/></svg>';
  static const settings =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915"/><circle cx="12" cy="12" r="3"/></svg>';
}

class AppNavDestination {
  const AppNavDestination({
    required this.svg,
    required this.label,
    this.spinWhenSelected = false,
  });

  final String svg;
  final String label;
  final bool spinWhenSelected;
}

const appNavDestinations = <AppNavDestination>[
  AppNavDestination(svg: AppNavIcons.dashboard, label: 'Home'),
  AppNavDestination(svg: AppNavIcons.estimates, label: 'Estimates'),
  AppNavDestination(svg: AppNavIcons.clients, label: 'Clients'),
  AppNavDestination(svg: AppNavIcons.calendar, label: 'Calendar'),
  AppNavDestination(svg: AppNavIcons.rates, label: 'Rates'),
  AppNavDestination(svg: AppNavIcons.settings, label: 'Settings', spinWhenSelected: true),
];

class NavSvgIcon extends StatelessWidget {
  const NavSvgIcon({
    super.key,
    required this.svg,
    required this.color,
    this.size = 22,
  });

  final String svg;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 8 + (bottom > 0 ? bottom : 8)),
      child: Material(
        color: AppColors.sidebar,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.8)),
          ),
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: navActiveDuration,
                    curve: navActiveCurve,
                    alignment: Alignment(
                      appNavDestinations.length == 1
                          ? 0
                          : -1 + (2 * selectedIndex / (appNavDestinations.length - 1)),
                      0,
                    ),
                    child: FractionallySizedBox(
                      widthFactor: 1 / appNavDestinations.length,
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDim,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < appNavDestinations.length; i++)
                        Expanded(
                          child: _BottomNavItem(
                            destination: appNavDestinations[i],
                            selected: selectedIndex == i,
                            onTap: () => onSelect(i),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected ? AppColors.primarySoft : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1,
          duration: const Duration(milliseconds: 140),
          curve: _pressed ? Curves.easeOut : navActiveCurve,
          child: AnimatedSlide(
            offset: selected ? const Offset(0, -0.12) : Offset.zero,
            duration: navActiveDuration,
            curve: navActiveCurve,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedRotation(
                  turns: widget.destination.spinWhenSelected && selected ? 0.12 : 0,
                  duration: const Duration(milliseconds: 400),
                  curve: navActiveCurve,
                  child: AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: navActiveDuration,
                    curve: navActiveCurve,
                    child: NavSvgIcon(svg: widget.destination.svg, color: color, size: 22),
                  ),
                ),
                AnimatedSize(
                  duration: navActiveDuration,
                  curve: Curves.easeInOut,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            widget.destination.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primarySoft,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

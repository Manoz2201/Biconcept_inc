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
  static const projects =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z"/><path d="M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2"/><path d="M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2"/><path d="M10 6h4"/><path d="M10 10h4"/><path d="M10 14h4"/><path d="M10 18h4"/></svg>';
  static const requests =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="8" height="4" x="8" y="2" rx="1" ry="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><path d="M12 11h4"/><path d="M12 16h4"/><path d="M8 11h.01"/><path d="M8 16h.01"/></svg>';
  static const messages =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/></svg>';
  static const profile =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>';
  static const packages =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z"/><path d="M12 22V12"/><polyline points="3.29 7 12 12 20.71 7"/><path d="m7.5 4.27 9 5.15"/></svg>';
  static const bills =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1"/><path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4"/></svg>';
}

class AppNavDestination {
  const AppNavDestination({
    required this.svg,
    required this.label,
    this.sidebarLabel,
    this.spinWhenSelected = false,
  });

  final String svg;
  final String label;
  final String? sidebarLabel;
  final bool spinWhenSelected;

  String get railLabel => sidebarLabel ?? label.toLowerCase();
}

const appNavDestinations = <AppNavDestination>[
  AppNavDestination(svg: AppNavIcons.dashboard, label: 'Home', sidebarLabel: 'dashboard'),
  AppNavDestination(svg: AppNavIcons.estimates, label: 'Estimates', sidebarLabel: 'estimates'),
  AppNavDestination(svg: AppNavIcons.clients, label: 'Clients', sidebarLabel: 'clients'),
  AppNavDestination(svg: AppNavIcons.calendar, label: 'Calendar', sidebarLabel: 'calendar'),
  AppNavDestination(svg: AppNavIcons.rates, label: 'Rates', sidebarLabel: 'rate card'),
  AppNavDestination(svg: AppNavIcons.settings, label: 'Settings', sidebarLabel: 'settings', spinWhenSelected: true),
];

const clientNavDestinations = <AppNavDestination>[
  AppNavDestination(svg: AppNavIcons.dashboard, label: 'Home', sidebarLabel: 'dashboard'),
  AppNavDestination(svg: AppNavIcons.projects, label: 'Projects', sidebarLabel: 'projects'),
  AppNavDestination(svg: AppNavIcons.requests, label: 'Requests', sidebarLabel: 'requests'),
  AppNavDestination(svg: AppNavIcons.estimates, label: 'Quotes', sidebarLabel: 'quotes'),
  AppNavDestination(svg: AppNavIcons.messages, label: 'Messages', sidebarLabel: 'messages'),
  AppNavDestination(svg: AppNavIcons.profile, label: 'Profile', sidebarLabel: 'profile'),
];

const vendorNavDestinations = <AppNavDestination>[
  AppNavDestination(svg: AppNavIcons.dashboard, label: 'Home', sidebarLabel: 'dashboard'),
  AppNavDestination(svg: AppNavIcons.requests, label: 'RFQs', sidebarLabel: 'rfqs'),
  AppNavDestination(svg: AppNavIcons.packages, label: 'POs', sidebarLabel: 'orders'),
  AppNavDestination(svg: AppNavIcons.bills, label: 'Bills', sidebarLabel: 'bills'),
  AppNavDestination(svg: AppNavIcons.profile, label: 'Profile', sidebarLabel: 'profile'),
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
    this.destinations = appNavDestinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<AppNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final items = destinations.isEmpty ? appNavDestinations : destinations;
    final index = selectedIndex.clamp(0, items.length - 1);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final palette = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 8 + (bottom > 0 ? bottom : 8)),
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.raised(palette),
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
                      items.length == 1 ? 0 : -1 + (2 * index / (items.length - 1)),
                      0,
                    ),
                    child: FractionallySizedBox(
                      widthFactor: 1 / items.length,
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 36,
                          decoration: BoxDecoration(
                            color: palette.primaryAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _BottomNavItem(
                            destination: items[i],
                            selected: index == i,
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
    final palette = AppPalette.of(context);
    final color = selected ? palette.onPrimary : palette.textSecondary;
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
                            style: TextStyle(
                              color: palette.onPrimary,
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

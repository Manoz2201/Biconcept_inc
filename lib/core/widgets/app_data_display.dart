import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

typedef AppCard = AppSurfaceCard;

class AppSurfaceCard extends StatefulWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  State<AppSurfaceCard> createState() => _AppSurfaceCardState();
}

class _AppSurfaceCardState extends State<AppSurfaceCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final card = RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: AppSpacing.radiusAllXxl,
          boxShadow: _hovered ? AppShadows.hover(palette) : AppShadows.raised(palette),
        ),
        child: widget.child,
      ),
    );
    if (widget.onTap == null) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: card,
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AppSpacing.radiusAllXxl,
          child: card,
        ),
      ),
    );
  }
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: leading,
          title: Text(title, style: AppTypography.h4(palette)),
          subtitle: subtitle == null ? null : Text(subtitle!, style: AppTypography.bodySmall(palette)),
          trailing: trailing ?? Icon(Icons.chevron_right, color: palette.textSecondary),
        ),
        if (showDivider) Divider(height: 1, color: palette.border),
      ],
    );
  }
}

enum AppBadgeTone { fresh, sale, count, success, warning, neutral }

class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.tone = AppBadgeTone.fresh, this.circular = false});

  final String label;
  final AppBadgeTone tone;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bg = switch (tone) {
      AppBadgeTone.fresh => palette.primaryAccent,
      AppBadgeTone.sale => palette.warning,
      AppBadgeTone.count => palette.error,
      AppBadgeTone.success => palette.success,
      AppBadgeTone.warning => palette.warning,
      AppBadgeTone.neutral => palette.border,
    };
    final fg = tone == AppBadgeTone.neutral ? palette.textPrimary : palette.onPrimary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: circular ? 8 : 10, vertical: circular ? 6 : 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: circular ? BorderRadius.circular(999) : AppSpacing.radiusAllMd,
      ),
      child: Text(label, style: AppTypography.caption(palette).copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.image, this.initials, this.size = 40});

  final ImageProvider? image;
  final String? initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.backgroundBase,
        border: Border.all(color: Colors.white, width: AppSpacing.borderThin),
        boxShadow: AppShadows.hover(palette),
        image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: image == null
          ? Text((initials ?? '?').toUpperCase(), style: AppTypography.label(palette))
          : null,
    );
  }
}

class AppTooltip extends StatelessWidget {
  const AppTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(message: message, child: child);
  }
}

class AppTableHeader extends StatelessWidget {
  const AppTableHeader({super.key, required this.columns, this.sortIndex, this.ascending = true, this.onSort});

  final List<String> columns;
  final int? sortIndex;
  final bool ascending;
  final ValueChanged<int>? onSort;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: palette.surface, borderRadius: AppSpacing.radiusAllLg),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              child: InkWell(
                onTap: onSort == null ? null : () => onSort!(i),
                child: Row(
                  children: [
                    Text(columns[i], style: AppTypography.h4(palette)),
                    if (sortIndex == i)
                      Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: palette.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AppChatBubble extends StatelessWidget {
  const AppChatBubble({super.key, required this.text, required this.mine, this.footer});

  final String text;
  final bool mine;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: mine ? palette.primaryAccent : palette.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppSpacing.radiusXl),
            topRight: const Radius.circular(AppSpacing.radiusXl),
            bottomLeft: Radius.circular(mine ? AppSpacing.radiusXl : AppSpacing.radiusSm),
            bottomRight: Radius.circular(mine ? AppSpacing.radiusSm : AppSpacing.radiusXl),
          ),
          boxShadow: AppShadows.hover(palette),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: AppTypography.bodyMedium(palette).copyWith(color: mine ? palette.onPrimary : palette.textPrimary),
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

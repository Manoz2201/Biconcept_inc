import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';

class AppTabs extends StatelessWidget {
  const AppTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.hover(palette),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: i == index ? palette.primaryAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: AppTypography.label(palette).copyWith(
                      color: i == index ? palette.onPrimary : palette.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AppBreadcrumbs extends StatelessWidget {
  const AppBreadcrumbs({super.key, required this.items, this.onTap});

  final List<String> items;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          InkWell(
            onTap: onTap == null || i == items.length - 1 ? null : () => onTap!(i),
            child: Text(
              items[i],
              style: AppTypography.bodySmall(palette).copyWith(
                color: i == items.length - 1 ? palette.primaryAccent : palette.textSecondary,
                fontWeight: i == items.length - 1 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (i < items.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right, size: 16, color: palette.textSecondary),
            ),
        ],
      ],
    );
  }
}

class AppStepper extends StatelessWidget {
  const AppStepper({super.key, required this.steps, required this.current});

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? palette.primaryAccent : palette.surface,
                  border: Border.all(color: i <= current ? palette.primaryAccent : palette.border),
                  boxShadow: i == current ? AppShadows.hover(palette) : const [],
                ),
                child: Text(
                  '${i + 1}',
                  style: AppTypography.label(palette).copyWith(color: i <= current ? palette.onPrimary : palette.textSecondary),
                ),
              ),
              const SizedBox(height: 6),
              Text(steps[i], style: AppTypography.caption(palette)),
            ],
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 18, left: 8, right: 8),
                height: 2,
                color: i < current ? palette.primaryAccent : palette.border,
              ),
            ),
        ],
      ],
    );
  }
}

class AppPagination extends StatelessWidget {
  const AppPagination({super.key, required this.page, required this.pageCount, required this.onChanged});

  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(onPressed: page > 1 ? () => onChanged(page - 1) : null, child: const Text('Previous')),
        for (var i = 1; i <= pageCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onChanged(i),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == page ? palette.primaryAccent : palette.surface,
                  boxShadow: AppShadows.hover(palette),
                ),
                child: Text(
                  '$i',
                  style: AppTypography.label(palette).copyWith(color: i == page ? palette.onPrimary : palette.textPrimary),
                ),
              ),
            ),
          ),
        TextButton(onPressed: page < pageCount ? () => onChanged(page + 1) : null, child: const Text('Next')),
      ],
    );
  }
}

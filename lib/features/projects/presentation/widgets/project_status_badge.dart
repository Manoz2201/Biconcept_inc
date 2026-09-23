import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/project_status.dart';

class ProjectStatusBadge extends StatelessWidget {
  const ProjectStatusBadge({super.key, required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ProjectStatus.planning => AppColors.muted,
      ProjectStatus.inProgress => AppColors.primary,
      ProjectStatus.onHold => Colors.orange,
      ProjectStatus.review => Colors.amber,
      ProjectStatus.completed => AppColors.completed,
      ProjectStatus.cancelled => AppColors.down,
    };
    return Chip(
      label: Text(status.label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.16),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

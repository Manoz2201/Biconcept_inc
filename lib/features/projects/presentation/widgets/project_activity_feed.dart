import 'package:flutter/material.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/project_activity.dart';

class ProjectActivityFeed extends StatelessWidget {
  const ProjectActivityFeed({super.key, required this.activities});

  final List<ProjectActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Text('No activity yet', style: TextStyle(color: AppColors.muted));
    }
    return Column(
      children: [
        for (final item in activities)
          ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: Text(item.action.replaceAll('_', ' ')),
            subtitle: Text([
              item.actorName,
              if (item.createdAt != null) formatDisplayDate(item.createdAt!),
              if (item.metadata != null) item.metadata!,
            ].join(' · ')),
          ),
      ],
    );
  }
}

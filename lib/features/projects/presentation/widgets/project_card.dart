import 'package:flutter/material.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../domain/milestone.dart';
import '../../domain/project.dart';
import 'project_progress_bar.dart';
import 'project_status_badge.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, this.nextMilestone, this.onTap});

  final Project project;
  final Milestone? nextMilestone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(project.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project.projectNumber, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            ProjectProgressBar(progress: project.progress),
            if (nextMilestone != null) ...[
              const SizedBox(height: 8),
              Text('Next: ${nextMilestone!.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            Text('${formatDisplayDate(project.startDate)} – ${formatDisplayDate(project.endDate)}'),
          ],
        ),
        trailing: ProjectStatusBadge(status: project.status),
        isThreeLine: true,
      ),
    );
  }
}

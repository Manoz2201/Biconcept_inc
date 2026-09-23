import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../theme/app_theme.dart';
import '../../../../../ui/widgets/portal_shell.dart';
import '../../providers/projects_provider.dart';
import '../../widgets/project_card.dart';

class ClientProjectsScreen extends ConsumerWidget {
  const ClientProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectsProvider(const ProjectQuery()));
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return PortalPageScaffold(
      title: 'projects',
      subtitle: 'Live studio work and upcoming milestones.',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text('No projects yet', style: TextStyle(color: AppColors.muted)));
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 4, 16, compact ? AppBreakpoints.navClearance : 32),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final project = items[index];
              final milestones = ref.watch(milestonesProvider(project.id)).valueOrNull ?? const [];
              final next = milestones.where((item) => !item.isComplete).firstOrNull;
              return ProjectCard(
                project: project,
                nextMilestone: next,
                onTap: () => context.go('/client/projects/${project.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:biconcept/features/catalog/presentation/providers/team_provider.dart';
import 'package:biconcept/features/catalog/presentation/widgets/public_shell.dart';
import 'package:biconcept/features/catalog/presentation/widgets/team_member_card.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicTeamProvider);
    return PublicShell(
      title: 'Team | BiConcept',
      description: 'Architects and interior designers at BiConcept, Noida.',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Team', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          CatalogAsync(
            value: async,
            builder: (members) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final member in members)
                  SizedBox(width: 280, child: TeamMemberCard(member: member)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_easy_seo/flutter_easy_seo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:biconcept/features/catalog/presentation/providers/team_provider.dart';
import 'package:biconcept/features/catalog/presentation/widgets/public_shell.dart';
import 'package:biconcept/features/catalog/presentation/widgets/team_member_card.dart';
import 'package:biconcept/models/company_profile.dart';
import 'package:biconcept/theme/app_theme.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(publicTeamProvider);
    return PublicShell(
      title: 'About | BiConcept',
      description: 'Biconcept Architects & Interiors, Sector 59, Noida.',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('About BiConcept', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)).easySeoH1,
          const SizedBox(height: 12),
          const Text(
            'BiConcept is a single-studio practice for architecture and interiors. '
            'We sit in Sector 59, Noida, and take projects from first sketch through a priced estimate and site finish.',
            style: TextStyle(height: 1.5, fontSize: 16),
          ).easySeoP,
          const SizedBox(height: 20),
          const Text('Mission', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)).easySeoH2,
          const SizedBox(height: 8),
          Text(
            'Give clients a clear scope, a fair rate card, and a calm handover — without inflating the drawing set.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ).easySeoP,
          const SizedBox(height: 16),
          const Text('Vision', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)).easySeoH2,
          const SizedBox(height: 8),
          Text(
            'A studio where estimates, drawings, and site decisions stay in one place so the built room matches the quoted one.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ).easySeoP,
          const SizedBox(height: 20),
          Text(defaultCompanyAddress, style: TextStyle(color: AppColors.muted)),
          Text(defaultCompanyPhone, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          const Text('Team', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)).easySeoH2,
          const SizedBox(height: 12),
          CatalogAsync(
            value: team,
            builder: (members) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final member in members.take(4))
                  SizedBox(width: 260, child: TeamMemberCard(member: member)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/team'),
            child: const Text('See everyone'),
          ),
        ],
      ),
    );
  }
}

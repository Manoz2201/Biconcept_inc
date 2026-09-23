import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/appwrite/appwrite_client.dart';
import '../../../../theme/app_theme.dart';
import '../../../../ui/widgets/ui_kit.dart';
import '../../domain/team_member.dart';
import '../providers/services_provider.dart';
import 'portfolio_card.dart';

class TeamMemberCard extends ConsumerWidget {
  const TeamMemberCard({super.key, required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageRepositoryProvider);
    return AppCard(
      child: Column(
        children: [
          ClipOval(
            child: SizedBox(
              width: 96,
              height: 96,
              child: storageImage(
                storage: storage,
                bucketId: AppwriteService.teamPhotosBucket,
                fileId: member.photoId ?? '',
                width: 192,
                height: 192,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(member.role, style: TextStyle(color: AppColors.primarySoft)),
          if (member.bio != null && member.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              member.bio!,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (member.email != null && member.email!.isNotEmpty)
                IconButton(
                  tooltip: member.email,
                  onPressed: () => Clipboard.setData(ClipboardData(text: member.email!)),
                  icon: const Icon(Icons.mail_outline),
                ),
              if (member.linkedin != null && member.linkedin!.isNotEmpty)
                IconButton(
                  tooltip: 'LinkedIn',
                  onPressed: () => Clipboard.setData(ClipboardData(text: member.linkedin!)),
                  icon: const Icon(Icons.link),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/appwrite/appwrite_client.dart';
import '../../../../theme/app_theme.dart';
import '../../../../ui/widgets/ui_kit.dart';
import '../../domain/portfolio_item.dart';
import '../../domain/storage_repository.dart';
import '../providers/services_provider.dart';

class PortfolioCard extends ConsumerWidget {
  const PortfolioCard({super.key, required this.item, this.onTap});

  final PortfolioItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageRepositoryProvider);
    final url = item.coverImageId.isEmpty
        ? null
        : storage.getFilePreviewUrl(
            AppwriteService.portfolioImagesBucket,
            item.coverImageId,
            width: 800,
            height: 560,
          );
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: url == null
                  ? ColoredBox(color: AppColors.cardHover, child: Icon(Icons.photo_outlined))
                  : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: AppColors.cardHover)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  [item.projectType, item.location].where((v) => v != null && v.toString().isNotEmpty).join(' · '),
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget storageImage({
  required StorageRepository storage,
  required String bucketId,
  required String fileId,
  BoxFit fit = BoxFit.cover,
  int? width,
  int? height,
}) {
  if (fileId.isEmpty) {
    return ColoredBox(color: AppColors.cardHover, child: Icon(Icons.person_outline));
  }
  final url = width != null || height != null
      ? storage.getFilePreviewUrl(bucketId, fileId, width: width, height: height)
      : storage.getFileViewUrl(bucketId, fileId);
  return Image.network(
    url,
    fit: fit,
    errorBuilder: (_, _, _) => ColoredBox(color: AppColors.cardHover, child: Icon(Icons.broken_image_outlined)),
  );
}

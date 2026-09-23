import 'package:flutter/material.dart';
import 'package:flutter_easy_seo/flutter_easy_seo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:biconcept/core/appwrite/appwrite_client.dart';
import 'package:biconcept/features/catalog/presentation/providers/portfolio_provider.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/catalog/presentation/widgets/portfolio_card.dart';
import 'package:biconcept/features/catalog/presentation/widgets/public_shell.dart';
import 'package:biconcept/theme/app_theme.dart';

class PortfolioDetailScreen extends ConsumerWidget {
  const PortfolioDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(portfolioBySlugProvider(slug));
    final storage = ref.watch(storageRepositoryProvider);
    return async.when(
      loading: () => const PublicShell(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => PublicShell(
        child: Center(child: Text('$error', style: TextStyle(color: AppColors.down))),
      ),
      data: (item) {
        final images = [item.coverImageId, ...item.galleryImageIds].where((id) => id.isNotEmpty).toList();
        return PublicShell(
          title: '${item.title} | BiConcept',
          description: item.description ?? '${item.projectType} project in ${item.location ?? 'Noida'}',
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (images.isNotEmpty)
                SizedBox(
                  height: 360,
                  child: PageView(
                    children: [
                      for (final id in images)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: storageImage(
                              storage: storage,
                              bucketId: AppwriteService.portfolioImagesBucket,
                              fileId: id,
                              width: 1400,
                              height: 900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Text(item.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)).easySeoH1,
              const SizedBox(height: 8),
              Text(
                [
                  item.projectType,
                  item.location,
                  item.area,
                  if (item.year != null) '${item.year}',
                ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
                style: TextStyle(color: AppColors.muted),
              ),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(item.description!, style: const TextStyle(height: 1.5, fontSize: 16)).easySeoP,
              ],
              if (item.testimonial != null && item.testimonial!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '"${item.testimonial}"${item.clientName == null ? '' : ' — ${item.clientName}'}',
                  style: const TextStyle(fontStyle: FontStyle.italic, height: 1.5),
                ).easySeoP,
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/contact'),
                child: const Text('Start a similar project'),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_easy_seo/flutter_easy_seo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:biconcept/features/auth/presentation/providers/auth_providers.dart';
import 'package:biconcept/features/catalog/presentation/providers/portfolio_provider.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/catalog/presentation/widgets/portfolio_card.dart';
import 'package:biconcept/features/catalog/presentation/widgets/public_shell.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:biconcept/theme/app_theme.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceBySlugProvider(slug));
    final portfolio = ref.watch(publicPortfolioProvider).valueOrNull ?? const [];
    final session = ref.watch(sessionControllerProvider);
    return async.when(
      loading: () => const PublicShell(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => PublicShell(
        child: Center(child: Text('$error', style: TextStyle(color: AppColors.down))),
      ),
      data: (item) {
        final related = portfolio.where((row) => row.projectType == item.category).take(4).toList();
        return PublicShell(
          title: '${item.title} | BiConcept',
          description: item.shortDescription,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(item.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)).easySeoH1,
              const SizedBox(height: 8),
              Text(item.category, style: TextStyle(color: AppColors.primarySoft)),
              const SizedBox(height: 16),
              Text(
                item.longDescription?.trim().isNotEmpty == true ? item.longDescription! : item.shortDescription,
                style: const TextStyle(height: 1.5, fontSize: 16),
              ).easySeoP,
              if (item.startingPrice != null) ...[
                const SizedBox(height: 16),
                Text(
                  'From ₹${item.startingPrice!.toStringAsFixed(0)}${item.priceUnit == null ? '' : ' / ${item.priceUnit}'}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (session.user?.role == UserRole.client) {
                    context.go('/client/requests/new?serviceId=${Uri.encodeComponent(item.id)}');
                    return;
                  }
                  context.go('/contact?serviceId=${Uri.encodeComponent(item.id)}');
                },
                child: Text(session.user?.role == UserRole.client ? 'Request this service' : 'Enquire about this service'),
              ),
              if (related.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text('Related work', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)).easySeoH2,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final row in related)
                      SizedBox(
                        width: 280,
                        child: PortfolioCard(
                          item: row,
                          onTap: () => context.go('/portfolio/${row.slug}'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

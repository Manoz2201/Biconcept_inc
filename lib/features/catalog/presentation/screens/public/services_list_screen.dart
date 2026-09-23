import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/catalog/presentation/widgets/public_shell.dart';
import 'package:biconcept/features/catalog/presentation/widgets/service_catalog_browser.dart';
import 'package:biconcept/theme/app_theme.dart';

class ServicesListScreen extends ConsumerWidget {
  const ServicesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicServicesProvider);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    return PublicShell(
      title: 'Services | BiConcept',
      description: 'Architecture, interiors, and project services from BiConcept in Noida.',
      child: ListView(
        padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 20, compact ? 16 : 28, 48),
        children: [
          Text(
            'services',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 36 : 48,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick the job the way Indian families ask for it — then we respond with a site visit and a quotation.',
            style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 22),
          CatalogAsync(
            value: async,
            builder: (items) => ServiceCatalogBrowser(
              items: items,
              onServiceTap: (item) => context.go('/services/${item.slug}'),
            ),
          ),
        ],
      ),
    );
  }
}

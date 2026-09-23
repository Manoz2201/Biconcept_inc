import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:biconcept/features/catalog/presentation/widgets/enquiry_form.dart';
import 'package:biconcept/features/catalog/presentation/widgets/public_shell.dart';
import 'package:biconcept/models/company_profile.dart';
import 'package:biconcept/theme/app_theme.dart';

class ContactScreen extends ConsumerWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceId = GoRouterState.of(context).uri.queryParameters['serviceId'];
    return PublicShell(
      title: 'Contact | BiConcept',
      description: 'Enquire about an architecture or interior project with BiConcept, Noida.',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Get in touch', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  '$defaultCompanyAddress · $defaultCompanyPhone',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 24),
                EnquiryForm(preselectedServiceId: serviceId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

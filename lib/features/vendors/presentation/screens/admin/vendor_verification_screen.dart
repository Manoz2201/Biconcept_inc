import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/permission_gate.dart';
import '../../../../rbac/domain/permission.dart';
import '../../providers/vendors_provider.dart';
import '../../widgets/vendor_card.dart';

class VendorVerificationScreen extends ConsumerWidget {
  const VendorVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vendorsProvider(const VendorQuery(isVerified: false, isActive: true)));
    return PermissionGate(
      permission: Permission.vendorVerify,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Vendor verification')),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (items.isEmpty) const Text('No unverified vendors'),
              for (final vendor in items)
                Column(
                  children: [
                    VendorCard(vendor: vendor, onTap: () => context.push('/admin/vendors/${vendor.id}')),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () async {
                          await ref.read(vendorRepositoryProvider).verifyVendor(vendor.id);
                          ref.invalidate(vendorsProvider);
                        },
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

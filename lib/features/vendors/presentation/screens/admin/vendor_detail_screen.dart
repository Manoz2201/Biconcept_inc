import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/permission_gate.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../domain/vendor.dart';
import '../../providers/vendors_provider.dart';
import '../../widgets/vendor_category_chips.dart';
import '../../widgets/vendor_rating_widget.dart';
import '../../widgets/vendor_status_badge.dart';

class VendorDetailScreen extends ConsumerWidget {
  const VendorDetailScreen({super.key, required this.vendorId});

  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vendorByIdProvider(vendorId));
    return PermissionGate(
      permission: Permission.vendorView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: async.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
        data: (vendor) => DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: Text(vendor.companyName),
              actions: [
                PermissionGate(
                  permission: Permission.vendorEdit,
                  child: IconButton(
                    onPressed: () => context.push('/admin/vendors/${vendor.id}/edit'),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Rates'),
                  Tab(text: 'Projects'),
                  Tab(text: 'Bills'),
                  Tab(text: 'Ratings'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _Overview(vendor: vendor),
                _Rates(vendorId: vendor.id),
                _Projects(vendorId: vendor.id),
                _Bills(vendorId: vendor.id),
                _Ratings(vendor: vendor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.vendor});
  final Vendor vendor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [VendorStatusBadge(vendor: vendor), const SizedBox(width: 12), VendorRatingWidget(rating: vendor.rating, total: vendor.totalRatings)]),
        const SizedBox(height: 12),
        Text(vendor.contactPerson),
        Text(vendor.email),
        Text(vendor.phone),
        Text('${vendor.address}, ${vendor.city}, ${vendor.state} ${vendor.pincode}'),
        if (vendor.gstin != null) Text('GSTIN ${vendor.gstin}'),
        if (vendor.ifscCode != null) Text('IFSC ${vendor.ifscCode}'),
        VendorCategoryChips(categories: vendor.categories),
        if (vendor.notes != null) Text(vendor.notes!),
        Text('KYC files: ${vendor.kycDocuments.length}'),
        const SizedBox(height: 16),
        PermissionGate(
          permission: Permission.vendorVerify,
          child: vendor.isVerified
              ? const SizedBox.shrink()
              : FilledButton(
                  onPressed: () async {
                    await ref.read(vendorRepositoryProvider).verifyVendor(vendor.id);
                    ref.invalidate(vendorByIdProvider(vendor.id));
                  },
                  child: const Text('Verify'),
                ),
        ),
        PermissionGate(
          permission: Permission.vendorDelete,
          child: TextButton(
            onPressed: () async {
              await ref.read(vendorRepositoryProvider).deactivateVendor(vendor.id);
              ref.invalidate(vendorByIdProvider(vendor.id));
            },
            child: const Text('Deactivate'),
          ),
        ),
      ],
    );
  }
}

class _Rates extends ConsumerWidget {
  const _Rates({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(vendorRatesProvider(vendorId)).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PermissionGate(
          permission: Permission.vendorRateCreate,
          child: FilledButton(
            onPressed: () => context.push('/admin/vendors/$vendorId/rates/new'),
            child: const Text('Add rate'),
          ),
        ),
        for (final item in items)
          ListTile(
            title: Text(item.itemName),
            subtitle: Text('${item.category} · ${item.unit}'),
            trailing: Text(formatMoney(item.rate)),
          ),
      ],
    );
  }
}

class _Projects extends ConsumerWidget {
  const _Projects({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(projectVendorsProvider('')).valueOrNull ?? const [];
    final mine = [for (final item in items) if (item.vendorId == vendorId) item];
    final assigned = ref.watch(vendorsProvider(const VendorQuery())).valueOrNull;
    return FutureBuilder(
      future: ref.read(projectVendorRepositoryProvider).getVendorProjects(vendorId),
      builder: (context, snapshot) {
        final rows = snapshot.data?.dataOrNull ?? const [];
        if (rows.isEmpty && mine.isEmpty) return const Center(child: Text('No project assignments'));
        final show = rows.isEmpty ? mine : rows;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final item in show)
              ListTile(
                title: Text(item.projectId),
                subtitle: Text(item.role ?? item.status.label),
                onTap: () => context.push('/admin/projects/${item.projectId}/vendors'),
              ),
            if (assigned != null) const SizedBox.shrink(),
          ],
        );
      },
    );
  }
}

class _Bills extends ConsumerWidget {
  const _Bills({required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(vendorBillsProvider(BillQuery(vendorId: vendorId))).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final item in items)
          ListTile(
            title: Text(item.billNumber),
            subtitle: Text(item.status.label),
            trailing: Text(formatMoney(item.total)),
            onTap: () => context.push('/admin/vendor-bills/${item.id}?vendorId=$vendorId'),
          ),
      ],
    );
  }
}

class _Ratings extends ConsumerWidget {
  const _Ratings({required this.vendor});
  final Vendor vendor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(vendorRatingsProvider(vendor.id)).valueOrNull ?? const [];
    final avgQ = items.isEmpty ? 0.0 : items.fold<double>(0, (sum, item) => sum + item.qualityScore) / items.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              titlesData: const FlTitlesData(show: false),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: avgQ, color: Colors.teal)]),
              ],
            ),
          ),
        ),
        for (final item in items)
          ListTile(
            title: Text('Overall ${item.overallScore.toStringAsFixed(1)}'),
            subtitle: Text(item.comments ?? item.projectId),
          ),
        PermissionGate(
          permission: Permission.vendorRatingCreate,
          child: FilledButton(
            onPressed: () => _rate(context, ref),
            child: const Text('Add rating'),
          ),
        ),
      ],
    );
  }

  Future<void> _rate(BuildContext context, WidgetRef ref) async {
    final projectId = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Rate vendor'),
          content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Project ID')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save 4/4')),
          ],
        );
      },
    );
    if (projectId == null || projectId.isEmpty) return;
    await ref.read(vendorRatingRepositoryProvider).createVendorRating(
          vendorId: vendor.id,
          projectId: projectId,
          qualityScore: 4,
          timelinessScore: 4,
          communicationScore: 4,
          costScore: 4,
        );
    ref.invalidate(vendorRatingsProvider(vendor.id));
    ref.invalidate(vendorByIdProvider(vendor.id));
  }
}

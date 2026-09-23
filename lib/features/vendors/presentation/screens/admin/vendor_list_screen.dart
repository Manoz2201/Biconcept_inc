import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/permission_gate.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../domain/vendor.dart';
import '../../providers/vendors_provider.dart';
import '../../widgets/vendor_card.dart';

class VendorListScreen extends ConsumerStatefulWidget {
  const VendorListScreen({super.key});

  @override
  ConsumerState<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends ConsumerState<VendorListScreen> {
  final _search = TextEditingController();
  String? _category;
  bool? _verified;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      vendorsProvider(VendorQuery(search: _search.text, category: _category, isVerified: _verified)),
    );
    return PermissionGate(
      permission: Permission.vendorView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vendors'),
          actions: [
            PermissionGate(
              permission: Permission.vendorVerify,
              child: IconButton(
                onPressed: () => context.push('/admin/vendors/verification'),
                icon: const Icon(Icons.verified_outlined),
              ),
            ),
          ],
        ),
        floatingActionButton: PermissionGate(
          permission: Permission.vendorCreate,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/admin/vendors/new'),
            icon: const Icon(Icons.add),
            label: const Text('Add Vendor'),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search company'),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FilterChip(label: const Text('All'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
                  for (final item in kVendorCategories)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(vendorCategoryLabel(item)),
                        selected: _category == item,
                        onSelected: (_) => setState(() => _category = item),
                      ),
                    ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Verified'),
                    selected: _verified == true,
                    onSelected: (value) => setState(() => _verified = value ? true : null),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('$error')),
                data: (items) => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) => VendorCard(
                    vendor: items[index],
                    onTap: () => context.push('/admin/vendors/${items[index].id}'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

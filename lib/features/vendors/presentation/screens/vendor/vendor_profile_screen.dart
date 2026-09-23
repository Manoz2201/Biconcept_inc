import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/widgets/app_buttons.dart';
import '../../../../../core/widgets/permission_gate.dart';
import '../../../../../ui/widgets/color_theme_selector.dart';
import '../../../../../ui/widgets/portal_shell.dart';
import '../../../../rbac/domain/permission.dart';
import '../../providers/vendors_provider.dart';
import '../../widgets/vendor_category_chips.dart';
import '../../widgets/vendor_rating_widget.dart';

class VendorProfileScreen extends ConsumerStatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  ConsumerState<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends ConsumerState<VendorProfileScreen> {
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _bank = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  var _hydrated = false;

  @override
  void dispose() {
    _contact.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    _bank.dispose();
    _account.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myVendorProfileProvider);
    return PermissionGate(
      permission: Permission.vendorPortalAccess,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: async.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
        data: (vendor) {
          if (vendor == null) return const Scaffold(body: Center(child: Text('No vendor profile is linked to this account')));
          if (!_hydrated) {
            _hydrated = true;
            _contact.text = vendor.contactPerson;
            _phone.text = vendor.phone;
            _address.text = vendor.address;
            _city.text = vendor.city;
            _state.text = vendor.state;
            _pincode.text = vendor.pincode;
            _bank.text = vendor.bankName ?? '';
            _account.text = vendor.bankAccountNumber ?? '';
            _ifsc.text = vendor.ifscCode ?? '';
          }
          return PortalPageScaffold(
            title: 'profile',
            subtitle: vendor.companyName,
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const ColorThemeSelector(compact: true),
                const SizedBox(height: 24),
                Text(vendor.companyName, style: Theme.of(context).textTheme.titleLarge),
                Text(vendor.email),
                VendorRatingWidget(rating: vendor.rating, total: vendor.totalRatings),
                VendorCategoryChips(categories: vendor.categories),
                TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact person')),
                TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
                TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
                TextField(controller: _city, decoration: const InputDecoration(labelText: 'City')),
                TextField(controller: _state, decoration: const InputDecoration(labelText: 'State')),
                TextField(controller: _pincode, decoration: const InputDecoration(labelText: 'Pincode')),
                TextField(controller: _bank, decoration: const InputDecoration(labelText: 'Bank')),
                TextField(controller: _account, decoration: const InputDecoration(labelText: 'Account')),
                TextField(controller: _ifsc, decoration: const InputDecoration(labelText: 'IFSC')),
                if (vendor.gstin != null) Text('GSTIN ${vendor.gstin} (locked after verification)'),
                const SizedBox(height: 16),
                AppPrimaryButton(
                  label: 'Save profile',
                  onPressed: () async {
                    await ref.read(vendorRepositoryProvider).updateVendor(vendor.id, {
                      'contactPerson': _contact.text.trim(),
                      'phone': _phone.text.trim(),
                      'address': _address.text.trim(),
                      'city': _city.text.trim(),
                      'state': _state.text.trim(),
                      'pincode': _pincode.text.trim(),
                      'bankName': _bank.text.trim(),
                      'bankAccountNumber': _account.text.trim(),
                      'ifscCode': _ifsc.text.trim().toUpperCase(),
                    });
                    ref.invalidate(myVendorProfileProvider);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class VendorRatesScreen extends ConsumerWidget {
  const VendorRatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(myVendorProfileProvider).valueOrNull;
    final items = vendor == null ? const [] : ref.watch(vendorRatesProvider(vendor.id)).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Rate card')),
      floatingActionButton: vendor == null
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await ref.read(vendorRateRepositoryProvider).createVendorRate(
                      vendorId: vendor.id,
                      category: 'other',
                      itemName: 'New item',
                      unit: 'nos',
                      rate: 0,
                    );
                ref.invalidate(vendorRatesProvider(vendor.id));
              },
              child: const Icon(Icons.add),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in items)
            ListTile(
              title: Text(item.itemName),
              subtitle: Text('${item.unit} · ${item.category}'),
              trailing: Text(item.rate.toStringAsFixed(2)),
            ),
        ],
      ),
    );
  }
}

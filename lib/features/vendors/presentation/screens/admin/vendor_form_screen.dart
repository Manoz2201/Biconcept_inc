import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/permission_gate.dart';
import '../../../../catalog/domain/storage_repository.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../rbac/domain/user_role.dart';
import '../../../../user_management/presentation/providers/user_providers.dart';
import '../../../domain/vendor.dart';
import '../../providers/vendors_provider.dart';
import '../../widgets/vendor_category_chips.dart';

class VendorFormScreen extends ConsumerStatefulWidget {
  const VendorFormScreen({super.key, this.vendorId});

  final String? vendorId;

  @override
  ConsumerState<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends ConsumerState<VendorFormScreen> {
  final _company = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _gstin = TextEditingController();
  final _pan = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _bank = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  final _notes = TextEditingController();
  final _categories = <String>{};
  String? _userId;
  var _busy = false;
  String? _error;
  var _hydrated = false;

  @override
  void dispose() {
    _company.dispose();
    _contact.dispose();
    _email.dispose();
    _phone.dispose();
    _gstin.dispose();
    _pan.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    _bank.dispose();
    _account.dispose();
    _ifsc.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _hydrate(Vendor vendor) {
    if (_hydrated) return;
    _hydrated = true;
    _company.text = vendor.companyName;
    _contact.text = vendor.contactPerson;
    _email.text = vendor.email;
    _phone.text = vendor.phone;
    _gstin.text = vendor.gstin ?? '';
    _pan.text = vendor.panNumber ?? '';
    _address.text = vendor.address;
    _city.text = vendor.city;
    _state.text = vendor.state;
    _pincode.text = vendor.pincode;
    _bank.text = vendor.bankName ?? '';
    _account.text = vendor.bankAccountNumber ?? '';
    _ifsc.text = vendor.ifscCode ?? '';
    _notes.text = vendor.notes ?? '';
    _categories.addAll(vendor.categories);
    _userId = vendor.userId;
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(userListProvider).valueOrNull?.users ?? const [];
    if (widget.vendorId != null) {
      ref.watch(vendorByIdProvider(widget.vendorId!)).whenData(_hydrate);
    }
    return PermissionGate(
      permission: widget.vendorId == null ? Permission.vendorCreate : Permission.vendorEdit,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.vendorId == null ? 'New vendor' : 'Edit vendor')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            TextField(controller: _company, decoration: const InputDecoration(labelText: 'Company name')),
            TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact person')),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), enabled: widget.vendorId == null),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: _gstin, decoration: const InputDecoration(labelText: 'GSTIN')),
            TextField(controller: _pan, decoration: const InputDecoration(labelText: 'PAN')),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
            TextField(controller: _city, decoration: const InputDecoration(labelText: 'City')),
            TextField(controller: _state, decoration: const InputDecoration(labelText: 'State')),
            TextField(controller: _pincode, decoration: const InputDecoration(labelText: 'Pincode')),
            TextField(controller: _bank, decoration: const InputDecoration(labelText: 'Bank name')),
            TextField(controller: _account, decoration: const InputDecoration(labelText: 'Account number')),
            TextField(controller: _ifsc, decoration: const InputDecoration(labelText: 'IFSC')),
            const SizedBox(height: 12),
            const Text('Categories'),
            VendorCategoryChips(
              categories: kVendorCategories,
              selected: _categories,
              onToggle: (value) => setState(() {
                if (_categories.contains(value)) {
                  _categories.remove(value);
                } else {
                  _categories.add(value);
                }
              }),
            ),
            DropdownButtonFormField<String>(
              initialValue: _userId,
              decoration: const InputDecoration(labelText: 'Linked vendor user'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final user in users.where((item) => item.role == UserRole.vendor))
                  DropdownMenuItem(value: user.accountId, child: Text(user.name)),
              ],
              onChanged: (value) => setState(() => _userId = value),
            ),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
            if (widget.vendorId != null)
              TextButton(onPressed: _busy ? null : _kyc, child: const Text('Upload KYC document')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_company.text.trim().isEmpty || _contact.text.trim().isEmpty || _email.text.trim().isEmpty) {
      setState(() => _error = 'Company, contact, and email are required');
      return;
    }
    if (!isValidGstin(_gstin.text.trim()) || !isValidPan(_pan.text.trim()) || !isValidIfsc(_ifsc.text.trim())) {
      setState(() => _error = 'Check GSTIN, PAN, and IFSC formats');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(vendorRepositoryProvider);
    final result = widget.vendorId == null
        ? await repo.createVendor(
            companyName: _company.text,
            contactPerson: _contact.text,
            email: _email.text,
            phone: _phone.text,
            address: _address.text,
            city: _city.text,
            state: _state.text,
            pincode: _pincode.text,
            categories: _categories.toList(),
            gstin: _gstin.text.trim().isEmpty ? null : _gstin.text.trim(),
            panNumber: _pan.text.trim().isEmpty ? null : _pan.text.trim(),
            bankName: _bank.text.trim().isEmpty ? null : _bank.text.trim(),
            bankAccountNumber: _account.text.trim().isEmpty ? null : _account.text.trim(),
            ifscCode: _ifsc.text.trim().isEmpty ? null : _ifsc.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            userId: _userId,
          )
        : await repo.updateVendor(widget.vendorId!, {
            'companyName': _company.text.trim(),
            'contactPerson': _contact.text.trim(),
            'phone': _phone.text.trim(),
            'gstin': _gstin.text.trim().isEmpty ? null : _gstin.text.trim().toUpperCase(),
            'panNumber': _pan.text.trim().isEmpty ? null : _pan.text.trim().toUpperCase(),
            'address': _address.text.trim(),
            'city': _city.text.trim(),
            'state': _state.text.trim(),
            'pincode': _pincode.text.trim(),
            'bankName': _bank.text.trim().isEmpty ? null : _bank.text.trim(),
            'bankAccountNumber': _account.text.trim().isEmpty ? null : _account.text.trim(),
            'ifscCode': _ifsc.text.trim().isEmpty ? null : _ifsc.text.trim().toUpperCase(),
            'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            'categories': _categories.toList(),
            'userId': _userId,
          });
    if (!mounted) return;
    result.when(
      success: (vendor) {
        ref.invalidate(vendorsProvider);
        ref.invalidate(vendorByIdProvider(vendor.id));
        context.go('/admin/vendors/${vendor.id}');
      },
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }

  Future<void> _kyc() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.single;
    if (file?.bytes == null || widget.vendorId == null) return;
    setState(() => _busy = true);
    final result = await ref.read(vendorRepositoryProvider).uploadKycDocument(
          widget.vendorId!,
          UploadBytes(bytes: file!.bytes!, filename: file.name),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.isFailure ? result.errorOrNull?.userMessage : null;
    });
    ref.invalidate(vendorByIdProvider(widget.vendorId!));
  }
}

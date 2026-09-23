import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/permission_gate.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../domain/vendor.dart';
import '../../providers/vendors_provider.dart';

class VendorRateFormScreen extends ConsumerStatefulWidget {
  const VendorRateFormScreen({super.key, required this.vendorId});

  final String vendorId;

  @override
  ConsumerState<VendorRateFormScreen> createState() => _VendorRateFormScreenState();
}

class _VendorRateFormScreenState extends ConsumerState<VendorRateFormScreen> {
  final _name = TextEditingController();
  final _unit = TextEditingController(text: 'nos');
  final _rate = TextEditingController();
  final _description = TextEditingController();
  String _category = kVendorCategories.first;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _rate.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.vendorRateCreate,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Vendor rate')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final item in kVendorCategories)
                  DropdownMenuItem(value: item, child: Text(vendorCategoryLabel(item))),
              ],
              onChanged: (value) => setState(() => _category = value ?? _category),
            ),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Item name')),
            TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit')),
            TextField(controller: _rate, decoration: const InputDecoration(labelText: 'Rate'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final rate = double.tryParse(_rate.text);
    if (_name.text.trim().isEmpty || rate == null) {
      setState(() => _error = 'Item name and rate are required');
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(vendorRateRepositoryProvider).createVendorRate(
          vendorId: widget.vendorId,
          category: _category,
          itemName: _name.text,
          unit: _unit.text,
          rate: rate,
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(vendorRatesProvider(widget.vendorId));
        context.pop();
      },
      failure: (error) => setState(() {
        _busy = false;
        _error = error.userMessage;
      }),
    );
  }
}

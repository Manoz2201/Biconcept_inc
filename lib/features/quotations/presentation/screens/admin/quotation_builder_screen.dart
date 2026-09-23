import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/permission_gate.dart';
import '../../../../../data/app_notifications.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../service_requests/presentation/providers/service_requests_provider.dart';
import '../../../domain/quotation.dart';
import '../../providers/quotations_provider.dart';
import '../../widgets/line_items_editor.dart';
import '../../widgets/quotation_preview.dart';

class QuotationBuilderScreen extends ConsumerStatefulWidget {
  const QuotationBuilderScreen({super.key, this.quotationId, this.requestId});

  final String? quotationId;
  final String? requestId;

  @override
  ConsumerState<QuotationBuilderScreen> createState() => _QuotationBuilderScreenState();
}

class _QuotationBuilderScreenState extends ConsumerState<QuotationBuilderScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _tax = TextEditingController(text: '18');
  var _items = <QuotationLineItem>[
    const QuotationLineItem(description: '', quantity: 1, unitPrice: 0),
  ];
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  String? _requestId;
  String? _clientId;
  var _preview = false;
  var _busy = false;
  String? _error;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _requestId = widget.requestId;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _tax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(serviceRequestsProvider(const ServiceRequestQuery())).valueOrNull ?? const [];
    if (widget.quotationId != null && !_loaded) {
      ref.listen(quotationByIdProvider(widget.quotationId!), (previous, next) {
        next.whenData(_hydrate);
      });
      final existing = ref.watch(quotationByIdProvider(widget.quotationId!)).valueOrNull;
      if (existing != null) _hydrate(existing);
    }
    if (_requestId != null && _clientId == null) {
      final match = requests.where((row) => row.id == _requestId).firstOrNull;
      _clientId = match?.clientId;
    }
    final taxRate = double.tryParse(_tax.text) ?? 18;
    final totals = QuotationTotals.fromItems(_items, taxRate: taxRate);
    final preview = Quotation(
      id: widget.quotationId ?? 'preview',
      serviceRequestId: _requestId ?? '',
      clientId: _clientId ?? '',
      quotationNumber: 'PREVIEW',
      title: _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim(),
      items: _items,
      subtotal: totals.subtotal,
      taxRate: taxRate,
      taxAmount: totals.taxAmount,
      total: totals.total,
      validUntil: _validUntil,
      status: QuotationStatus.draft,
      internalNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    return PermissionGate(
      permission: widget.quotationId == null ? Permission.quotationCreate : Permission.quotationEdit,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quotationId == null ? 'New quotation' : 'Edit quotation'),
          actions: [
            TextButton(
              onPressed: () => setState(() => _preview = !_preview),
              child: Text(_preview ? 'Edit' : 'Preview'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_error != null) Text(_error!, style: TextStyle(color: AppColors.down)),
            if (_preview)
              QuotationPreview(quotation: preview)
            else ...[
              DropdownButtonFormField<String>(
                initialValue: requests.any((row) => row.id == _requestId) ? _requestId : null,
                decoration: const InputDecoration(labelText: 'Service request'),
                items: [
                  for (final request in requests)
                    DropdownMenuItem(value: request.id, child: Text(request.title)),
                ],
                onChanged: (value) {
                  final match = requests.where((row) => row.id == value).firstOrNull;
                  setState(() {
                    _requestId = value;
                    _clientId = match?.clientId;
                    if (_title.text.isEmpty) _title.text = match?.title ?? '';
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 16),
              LineItemsEditor(items: _items, onChanged: (items) => setState(() => _items = items)),
              const SizedBox(height: 12),
              TextField(
                controller: _tax,
                decoration: const InputDecoration(labelText: 'GST %'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Valid until'),
                subtitle: Text(_validUntil.toLocal().toString().split(' ').first),
                onTap: _pickDate,
              ),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Internal notes'),
              ),
              const SizedBox(height: 12),
              Text('Subtotal ${preview.subtotal.toStringAsFixed(2)}', key: const Key('quotation-subtotal')),
              Text('Total ${preview.total.toStringAsFixed(2)}'),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : () => _save(send: false), child: const Text('Save as Draft')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _busy ? null : () => _save(send: true), child: const Text('Send to Client')),
          ],
        ),
      ),
    );
  }

  void _hydrate(Quotation quote) {
    if (_loaded) return;
    _loaded = true;
    _title.text = quote.title;
    _notes.text = quote.internalNotes ?? '';
    _tax.text = quote.taxRate.toString();
    _items = quote.items.isEmpty ? _items : quote.items;
    _validUntil = quote.validUntil;
    _requestId = quote.serviceRequestId;
    _clientId = quote.clientId;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _validUntil,
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  Future<void> _save({required bool send}) async {
    final filled = _items.where((item) => item.description.trim().isNotEmpty && item.quantity > 0).toList();
    if (filled.isEmpty || _title.text.trim().isEmpty || _requestId == null || _clientId == null) {
      setState(() => _error = 'Add a title, request, and at least one complete line item');
      return;
    }
    if (!_validUntil.isAfter(DateTime.now())) {
      setState(() => _error = 'Valid until must be in the future');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(quotationRepositoryProvider);
    final taxRate = double.tryParse(_tax.text) ?? 18;
    var id = widget.quotationId;
    if (id == null) {
      final created = await repo.createQuotation(
        serviceRequestId: _requestId!,
        clientId: _clientId!,
        title: _title.text.trim(),
        items: filled,
        taxRate: taxRate,
        validUntil: _validUntil,
        internalNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (created.isFailure) {
        setState(() {
          _busy = false;
          _error = created.errorOrNull?.userMessage;
        });
        return;
      }
      id = created.dataOrNull!.id;
    } else {
      final updated = await repo.updateQuotation(id, {
        'title': _title.text.trim(),
        'items': filled,
        'taxRate': taxRate,
        'validUntil': _validUntil,
        'internalNotes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (updated.isFailure) {
        setState(() {
          _busy = false;
          _error = updated.errorOrNull?.userMessage;
        });
        return;
      }
    }
    if (send) {
      final sent = await repo.sendQuotation(id);
      if (sent.isSuccess) {
        await AppNotifications.instance.showImmediate(
          title: 'Quotation sent',
          body: 'The client can review the quotation now.',
        );
      }
    }
    ref.invalidate(quotationsProvider);
    ref.invalidate(serviceRequestsProvider);
    if (mounted) context.go('/admin/quotations/$id');
  }
}

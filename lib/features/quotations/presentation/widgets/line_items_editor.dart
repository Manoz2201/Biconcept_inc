import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/quotation.dart';

class LineItemsEditor extends StatelessWidget {
  const LineItemsEditor({super.key, required this.items, required this.onChanged});

  final List<QuotationLineItem> items;
  final ValueChanged<List<QuotationLineItem>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          // ignore: deprecated_member_use
          onReorder: (oldIndex, newIndex) {
            final next = [...items];
            if (newIndex > oldIndex) newIndex -= 1;
            final item = next.removeAt(oldIndex);
            next.insert(newIndex, item);
            onChanged(next);
          },
          itemBuilder: (context, index) {
            final item = items[index];
            return Padding(
              key: ValueKey('line-$index-${item.description}'),
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      initialValue: item.description,
                      decoration: const InputDecoration(labelText: 'Description'),
                      onChanged: (value) => _replace(index, description: value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: item.quantity == 0 ? '' : item.quantity.toString(),
                      decoration: const InputDecoration(labelText: 'Qty'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      onChanged: (value) => _replace(index, quantity: double.tryParse(value) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: item.unitPrice == 0 ? '' : item.unitPrice.toString(),
                      decoration: const InputDecoration(labelText: 'Rate'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      onChanged: (value) => _replace(index, unitPrice: double.tryParse(value) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(formatMoney(item.total), style: TextStyle(color: AppColors.muted)),
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(context, index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          },
        ),
        OutlinedButton.icon(
          key: const Key('line-item-add'),
          onPressed: () => onChanged([...items, const QuotationLineItem(description: '', quantity: 1, unitPrice: 0)]),
          icon: const Icon(Icons.add),
          label: const Text('Add line'),
        ),
      ],
    );
  }

  void _replace(int index, {String? description, double? quantity, double? unitPrice}) {
    final current = items[index];
    final next = [...items];
    next[index] = QuotationLineItem(
      description: description ?? current.description,
      quantity: quantity ?? current.quantity,
      unitPrice: unitPrice ?? current.unitPrice,
    );
    onChanged(next);
  }

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove line?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      final next = [...items]..removeAt(index);
      onChanged(next);
    }
  }
}

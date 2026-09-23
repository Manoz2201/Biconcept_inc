import 'package:flutter/material.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/quotation.dart';

class QuotationPreview extends StatelessWidget {
  const QuotationPreview({super.key, required this.quotation});

  final Quotation quotation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(quotation.quotationNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(quotation.title),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.4),
                3: FlexColumnWidth(1.4),
              },
              children: [
                TableRow(
                  children: [
                    Text('Description', style: TextStyle(color: AppColors.muted)),
                    Text('Qty', style: TextStyle(color: AppColors.muted)),
                    Text('Rate', style: TextStyle(color: AppColors.muted)),
                    Text('Total', style: TextStyle(color: AppColors.muted)),
                  ],
                ),
                for (final item in quotation.items)
                  TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text(item.description)),
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text('${item.quantity}')),
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text(formatMoney(item.unitPrice))),
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text(formatMoney(item.total))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Subtotal  ${formatMoney(quotation.subtotal)}', key: const Key('quotation-subtotal')),
                  Text('GST ${quotation.taxRate.toStringAsFixed(0)}%  ${formatMoney(quotation.taxAmount)}'),
                  Text(
                    'Total  ${formatMoney(quotation.total)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

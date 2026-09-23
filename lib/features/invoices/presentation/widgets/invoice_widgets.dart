import 'package:flutter/material.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/invoice.dart';

class InvoiceStatusBadge extends StatelessWidget {
  const InvoiceStatusBadge({super.key, required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      InvoiceStatus.paid => AppColors.up,
      InvoiceStatus.overdue || InvoiceStatus.voided || InvoiceStatus.cancelled => AppColors.down,
      InvoiceStatus.partiallyPaid => AppColors.primary,
      _ => AppColors.muted,
    };
    return Chip(
      label: Text(status.label),
      backgroundColor: color.withValues(alpha: 0.16),
      side: BorderSide(color: color),
    );
  }
}

class InvoiceCard extends StatelessWidget {
  const InvoiceCard({super.key, required this.invoice, this.clientName, this.onTap});

  final Invoice invoice;
  final String? clientName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('${invoice.invoiceNumber} · ${clientName ?? invoice.clientId}'),
      subtitle: Text('${invoice.displayStatus.label} · ${formatDisplayDate(invoice.invoiceDate)} · due ${formatDisplayDate(invoice.dueDate)}'),
      trailing: Text(formatMoney(invoice.grandTotal)),
      onTap: onTap,
    );
  }
}

class GstBreakdownWidget extends StatelessWidget {
  const GstBreakdownWidget({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('HSN')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Rate')),
              DataColumn(label: Text('Taxable')),
              DataColumn(label: Text('CGST')),
              DataColumn(label: Text('SGST')),
              DataColumn(label: Text('IGST')),
              DataColumn(label: Text('Total')),
            ],
            rows: [
              for (final item in invoice.items)
                DataRow(
                  cells: [
                    DataCell(Text(item.description)),
                    DataCell(Text(item.hsnSac)),
                    DataCell(Text(item.quantity.toString())),
                    DataCell(Text(formatMoney(item.rate))),
                    DataCell(Text(formatMoney(item.taxableValue))),
                    DataCell(Text(formatMoney(item.cgst))),
                    DataCell(Text(formatMoney(item.sgst))),
                    DataCell(Text(formatMoney(item.igst))),
                    DataCell(Text(formatMoney(item.total))),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Subtotal ${formatMoney(invoice.subtotal)}'),
        Text('CGST ${formatMoney(invoice.totalCgst)} · SGST ${formatMoney(invoice.totalSgst)} · IGST ${formatMoney(invoice.totalIgst)}'),
        if (invoice.roundOff != 0) Text('Round off ${formatMoney(invoice.roundOff)}'),
        Text('Grand total ${formatMoney(invoice.grandTotal)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(invoice.amountInWords, style: TextStyle(color: AppColors.muted)),
      ],
    );
  }
}

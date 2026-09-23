import 'package:flutter/material.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../domain/quotation.dart';
import 'quotation_status_badge.dart';

class QuotationCard extends StatelessWidget {
  const QuotationCard({super.key, required this.quotation, this.onTap, this.clientName});

  final Quotation quotation;
  final VoidCallback? onTap;
  final String? clientName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${quotation.quotationNumber} · ${quotation.title}'),
        subtitle: Text(
          [
            if (clientName != null && clientName!.isNotEmpty) clientName!,
            formatMoney(quotation.total),
            'Valid ${formatDisplayDate(quotation.validUntil)}',
          ].join(' · '),
        ),
        trailing: QuotationStatusBadge(status: quotation.effectiveStatus),
        onTap: onTap,
      ),
    );
  }
}

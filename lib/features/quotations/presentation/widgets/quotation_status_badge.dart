import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/quotation.dart';

class QuotationStatusBadge extends StatelessWidget {
  const QuotationStatusBadge({super.key, required this.status});

  final QuotationStatus status;

  Color get _color => switch (status) {
        QuotationStatus.draft => AppColors.muted,
        QuotationStatus.sent => AppColors.primarySoft,
        QuotationStatus.viewed => const Color(0xFF8AB4F8),
        QuotationStatus.approved => AppColors.up,
        QuotationStatus.rejected => AppColors.down,
        QuotationStatus.revisionRequested => AppColors.primary,
        QuotationStatus.expired => AppColors.finalized,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.45)),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../domain/enquiry.dart';
import '../../../../theme/app_theme.dart';

class EnquiryStatusBadge extends StatelessWidget {
  const EnquiryStatusBadge({super.key, required this.status});

  final EnquiryStatus status;

  Color get _color => switch (status) {
        EnquiryStatus.newLead => AppColors.primarySoft,
        EnquiryStatus.contacted => const Color(0xFF8AB4F8),
        EnquiryStatus.qualified => AppColors.up,
        EnquiryStatus.converted => AppColors.completed,
        EnquiryStatus.closed => AppColors.muted,
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

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/service_request.dart';

class ServiceRequestStatusBadge extends StatelessWidget {
  const ServiceRequestStatusBadge({super.key, required this.status});

  final ServiceRequestStatus status;

  Color get _color => switch (status) {
        ServiceRequestStatus.draft => AppColors.muted,
        ServiceRequestStatus.submitted => AppColors.primarySoft,
        ServiceRequestStatus.underReview => const Color(0xFF8AB4F8),
        ServiceRequestStatus.quoted => AppColors.primary,
        ServiceRequestStatus.approved => AppColors.up,
        ServiceRequestStatus.rejected => AppColors.down,
        ServiceRequestStatus.converted => AppColors.completed,
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

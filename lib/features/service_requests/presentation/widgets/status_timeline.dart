import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/service_request.dart';

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.status});

  final ServiceRequestStatus status;

  static const _steps = [
    ServiceRequestStatus.draft,
    ServiceRequestStatus.submitted,
    ServiceRequestStatus.underReview,
    ServiceRequestStatus.quoted,
    ServiceRequestStatus.approved,
  ];

  @override
  Widget build(BuildContext context) {
    final current = status == ServiceRequestStatus.rejected
        ? ServiceRequestStatus.quoted
        : status == ServiceRequestStatus.converted
            ? ServiceRequestStatus.approved
            : status;
    final index = _steps.indexOf(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++)
          Row(
            children: [
              Icon(
                i <= index ? Icons.check_circle : Icons.radio_button_unchecked,
                color: i <= index ? AppColors.up : AppColors.muted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _steps[i].label,
                style: TextStyle(
                  color: i <= index ? AppColors.text : AppColors.muted,
                  fontWeight: i == index ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        if (status == ServiceRequestStatus.rejected)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Rejected', style: TextStyle(color: AppColors.down)),
          ),
        if (status == ServiceRequestStatus.converted)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Converted to project', style: TextStyle(color: AppColors.completed)),
          ),
      ],
    );
  }
}

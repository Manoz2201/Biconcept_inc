import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/vendor.dart';

class VendorStatusBadge extends StatelessWidget {
  const VendorStatusBadge({super.key, required this.vendor});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    final label = !vendor.isActive
        ? 'Inactive'
        : vendor.isVerified
            ? 'Verified'
            : 'Unverified';
    final color = !vendor.isActive
        ? AppColors.muted
        : vendor.isVerified
            ? AppColors.up
            : AppColors.primary;
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.16),
      side: BorderSide(color: color),
    );
  }
}

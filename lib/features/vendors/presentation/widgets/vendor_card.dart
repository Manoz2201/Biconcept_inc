import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../domain/vendor.dart';
import 'vendor_category_chips.dart';
import 'vendor_rating_widget.dart';
import 'vendor_status_badge.dart';

class VendorCard extends StatelessWidget {
  const VendorCard({super.key, required this.vendor, this.onTap});

  final Vendor vendor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(vendor.companyName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vendor.contactPerson, style: TextStyle(color: AppColors.muted)),
            VendorCategoryChips(categories: vendor.categories),
            VendorRatingWidget(rating: vendor.rating, total: vendor.totalRatings),
          ],
        ),
        trailing: VendorStatusBadge(vendor: vendor),
        isThreeLine: true,
      ),
    );
  }
}

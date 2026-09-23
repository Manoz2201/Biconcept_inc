import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class VendorRatingWidget extends StatelessWidget {
  const VendorRatingWidget({super.key, required this.rating, this.total = 0});

  final double rating;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.star, size: 16, color: rating > 0 ? AppColors.primary : AppColors.muted),
        const SizedBox(width: 4),
        Text(rating.toStringAsFixed(1)),
        if (total > 0) Text(' ($total)', style: TextStyle(color: AppColors.muted)),
      ],
    );
  }
}

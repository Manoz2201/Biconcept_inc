import 'package:flutter/material.dart';

import '../../domain/vendor.dart';

class VendorCategoryChips extends StatelessWidget {
  const VendorCategoryChips({super.key, required this.categories, this.selected, this.onToggle});

  final List<String> categories;
  final Set<String>? selected;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final item in categories)
          onToggle == null
              ? Chip(label: Text(vendorCategoryLabel(item)))
              : FilterChip(
                  label: Text(vendorCategoryLabel(item)),
                  selected: selected?.contains(item) ?? false,
                  onSelected: (_) => onToggle!(item),
                ),
      ],
    );
  }
}

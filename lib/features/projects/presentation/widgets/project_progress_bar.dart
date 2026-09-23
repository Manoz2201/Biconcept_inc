import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class ProjectProgressBar extends StatelessWidget {
  const ProjectProgressBar({super.key, required this.progress, this.label});

  final int progress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final value = (progress.clamp(0, 100)) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label ?? '$progress%', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          color: AppColors.primary,
          backgroundColor: AppColors.outline,
        ),
      ],
    );
  }
}

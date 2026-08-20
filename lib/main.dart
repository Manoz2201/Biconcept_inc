import 'package:flutter/material.dart';

import 'ui/home_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const BiconceptApp());
}

class BiconceptApp extends StatelessWidget {
  const BiconceptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiConcept',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const EstimateHomePage(),
    );
  }
}

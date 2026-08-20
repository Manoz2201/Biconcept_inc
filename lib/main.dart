import 'dart:async';

import 'package:flutter/material.dart';

import 'data/appwrite_live.dart';
import 'data/schedule_service.dart';
import 'ui/home_page.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installAppwriteLiveSync();
  unawaited(ScheduleService.instance.start());
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

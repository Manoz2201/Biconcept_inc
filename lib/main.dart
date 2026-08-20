import 'dart:async';

import 'package:flutter/material.dart';

import 'data/appwrite_live.dart';
import 'data/schedule.dart';
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
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.deferToChild,
          child: MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const EstimateHomePage(),
    );
  }
}

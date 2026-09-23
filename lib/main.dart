import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easy_seo/flutter_easy_seo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/chat/data/local/open_chat_database.dart';
import 'features/chat/presentation/providers/chat_provider.dart';
import 'data/appwrite_live.dart';
import 'data/schedule.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EasySEOManager.instance.init(
    baseUrl: 'https://biconcept.in',
    siteName: 'BiConcept',
    siteDescription: 'Architecture and interiors in Noida.',
    enableInteractiveMode: false,
    showResultDialog: false,
    enableLiveOutput: kIsWeb,
    pages: const [
      '/',
      '/services',
      '/services/:slug',
      '/portfolio',
      '/portfolio/:slug',
      '/team',
      '/about',
      '/contact',
    ],
  );
  installAppwriteLiveSync();
  unawaited(ScheduleService.instance.start());
  final chatDb = await openChatDatabase();
  runApp(
    ProviderScope(
      overrides: [chatDatabaseProvider.overrideWithValue(chatDb)],
      child: const BiconceptApp(),
    ),
  );
}

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easy_seo/flutter_easy_seo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'features/auth/domain/deep_link_payload.dart';
import 'features/chat/sync/chat_bootstrap.dart';
import 'features/platform/presentation/providers/platform_providers.dart';
import 'theme/app_theme.dart';

class BiconceptApp extends ConsumerStatefulWidget {
  const BiconceptApp({super.key});

  @override
  ConsumerState<BiconceptApp> createState() => _BiconceptAppState();
}

class _BiconceptAppState extends ConsumerState<BiconceptApp> {
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    final appLinks = AppLinks();
    appLinks.getInitialLink().then(_openDeepLink);
    _links = appLinks.uriLinkStream.listen(_openDeepLink);
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  void _openDeepLink(Uri? uri) {
    if (uri == null) return;
    final crm = _crmDeepLink(uri);
    if (crm != null) {
      ref.read(appRouterProvider).go(crm);
      return;
    }
    final payload = DeepLinkPayload.tryParse(uri);
    if (payload == null) return;
    final router = ref.read(appRouterProvider);
    final params = <String, String>{
      if (payload.userId != null) 'userId': payload.userId!,
      if (payload.secret != null) 'secret': payload.secret!,
      if (payload.membershipId != null) 'membershipId': payload.membershipId!,
      if (payload.teamId != null) 'teamId': payload.teamId!,
      if (payload.email != null) 'email': payload.email!,
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    final path = switch (payload.kind) {
      DeepLinkKind.verify => '/verify-email',
      DeepLinkKind.invite => '/register',
      DeepLinkKind.resetPassword => '/reset-password',
    };
    if (!payload.isValid) return;
    router.go('$path?$query');
  }

  String? _crmDeepLink(Uri uri) {
    final host = uri.host.toLowerCase();
    final segments = [if (host.isNotEmpty && host != 'www') host, ...uri.pathSegments.where((part) => part.isNotEmpty)];
    if (segments.isEmpty) return null;
    return switch (segments.first) {
      'invoices' when segments.length > 1 => '/admin/invoices/${segments[1]}',
      'payment-schedules' || 'payment_schedules' when segments.length > 1 => '/admin/payment-schedules/${segments[1]}',
      'tasks' when segments.length > 1 => '/admin/projects',
      'projects' when segments.length > 1 => '/admin/projects/${segments[1]}',
      'messages' || 'chat' when segments.length > 1 => '/chat/${segments[1]}',
      'notifications' => '/notifications',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final theme = ref.watch(themeFromBrandingProvider);
    EasySEOManager.instance.pathProvider = (context) =>
        GoRouter.maybeOf(context)?.routerDelegate.currentConfiguration.uri.path;
    final darkTheme = ref.watch(darkThemeFromBrandingProvider);
    return MaterialApp.router(
      title: 'BiConcept',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        AppColors.bind(AppPalette.of(context));
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.deferToChild,
          child: MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
            ),
            child: ChatBootstrap(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}


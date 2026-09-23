import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:biconcept/core/router/home_location.dart';
import 'package:biconcept/features/auth/presentation/providers/auth_providers.dart';
import 'package:biconcept/features/catalog/domain/portfolio_item.dart';
import 'package:biconcept/features/catalog/presentation/providers/portfolio_provider.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/catalog/presentation/widgets/public_shell.dart';
import 'package:biconcept/features/catalog/presentation/widgets/studio_landing.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _servicesKey = GlobalKey();
  final _requirementsKey = GlobalKey();

  Future<void> _scrollTo(GlobalKey key, {required String fallback}) async {
    final target = key.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
        alignment: 0.04,
      );
      return;
    }
    if (!mounted) return;
    context.go(fallback);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(publicServicesProvider);
    final featured = ref.watch(featuredPortfolioProvider);
    final allPortfolio = ref.watch(publicPortfolioProvider);
    final session = ref.watch(sessionControllerProvider);
    final projects = _projects(featured.valueOrNull, allPortfolio.valueOrNull);
    final cover = landingCoverUrl(
      featured: projects,
      preview: (bucketId, fileId, {int? width, int? height}) {
        return ref.read(storageRepositoryProvider).getFilePreviewUrl(
              bucketId,
              fileId,
              width: width,
              height: height,
            );
      },
    );

    return PublicShell(
      title: 'BiConcept | Architecture & Interiors, Noida',
      description: 'Residential and commercial interiors from first sketch through handover.',
      immersive: true,
      onStartProject: () => _scrollTo(_requirementsKey, fallback: '/contact'),
      child: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LandingHero(
              coverUrl: cover,
              onStartProject: () => _scrollTo(_requirementsKey, fallback: '/contact'),
              onViewServices: () => _scrollTo(_servicesKey, fallback: '/services'),
            ),
            LandingProjects(items: projects),
            const LandingComposition(),
            KeyedSubtree(
              key: _servicesKey,
              child: LandingServices(items: services.valueOrNull ?? const []),
            ),
            const LandingProcess(),
            const LandingAbout(),
            const LandingFaq(),
            KeyedSubtree(
              key: _requirementsKey,
              child: LandingRequirements(
                signedIn: session.isAuthenticated,
                appPath: homeLocationFor(session.user?.role),
              ),
            ),
            const LandingFooter(),
          ],
        ),
      ),
    );
  }

  List<PortfolioItem> _projects(List<PortfolioItem>? featured, List<PortfolioItem>? all) {
    if (featured != null && featured.isNotEmpty) return featured.take(6).toList();
    if (all != null && all.isNotEmpty) return all.take(6).toList();
    return const [];
  }
}

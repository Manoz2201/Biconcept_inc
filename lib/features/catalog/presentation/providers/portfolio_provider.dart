import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/portfolio_item.dart';
import 'services_provider.dart';

final publicPortfolioProvider = FutureProvider<List<PortfolioItem>>((ref) async {
  final result = await ref.watch(catalogRepositoryProvider).getPortfolioItems();
  return result.when(
    success: (items) => items,
    failure: (error) => throw Exception(error.userMessage),
  );
});

final featuredPortfolioProvider = FutureProvider<List<PortfolioItem>>((ref) async {
  final result = await ref.watch(catalogRepositoryProvider).getPortfolioItems(featuredOnly: true);
  return result.when(
    success: (items) => items,
    failure: (error) => throw Exception(error.userMessage),
  );
});

final adminPortfolioProvider = FutureProvider<List<PortfolioItem>>((ref) async {
  final result = await ref.watch(catalogRepositoryProvider).getPortfolioItems(activeOnly: false);
  return result.when(
    success: (items) => items,
    failure: (error) => throw Exception(error.userMessage),
  );
});

final portfolioBySlugProvider = FutureProvider.family<PortfolioItem, String>((ref, slug) async {
  final result = await ref.watch(catalogRepositoryProvider).getPortfolioBySlug(slug);
  return result.when(
    success: (item) => item,
    failure: (error) => throw Exception(error.userMessage),
  );
});

final portfolioByIdProvider = FutureProvider.family<PortfolioItem, String>((ref, id) async {
  final result = await ref.watch(catalogRepositoryProvider).getPortfolioById(id);
  return result.when(
    success: (item) => item,
    failure: (error) => throw Exception(error.userMessage),
  );
});

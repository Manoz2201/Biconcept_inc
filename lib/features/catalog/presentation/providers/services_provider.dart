import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/catalog_repository_impl.dart';
import '../../data/storage_repository.dart';
import '../../domain/catalog_repository.dart';
import '../../domain/service_item.dart';
import '../../domain/storage_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepositoryImpl(
    actorId: () => ref.read(sessionControllerProvider).user?.accountId ?? 'public',
  );
});

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepositoryImpl();
});

final publicServicesProvider = FutureProvider<List<ServiceItem>>((ref) async {
  final result = await ref.watch(catalogRepositoryProvider).getServices();
  return result.when(
    success: (items) => items,
    failure: (error) => throw Exception(error.userMessage),
  );
});

final adminServicesProvider = FutureProvider<List<ServiceItem>>((ref) async {
  final result = await ref.watch(catalogRepositoryProvider).getServices(activeOnly: false);
  return result.when(
    success: (items) => items,
    failure: (error) => throw Exception(error.userMessage),
  );
});

final serviceBySlugProvider = FutureProvider.family<ServiceItem, String>((ref, slug) async {
  final result = await ref.watch(catalogRepositoryProvider).getServiceBySlug(slug);
  return result.when(
    success: (item) => item,
    failure: (error) => throw Exception(error.userMessage),
  );
});

final serviceByIdProvider = FutureProvider.family<ServiceItem, String>((ref, id) async {
  final result = await ref.watch(catalogRepositoryProvider).getServiceById(id);
  return result.when(
    success: (item) => item,
    failure: (error) => throw Exception(error.userMessage),
  );
});

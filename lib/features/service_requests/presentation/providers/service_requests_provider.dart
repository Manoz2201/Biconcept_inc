import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/appwrite/appwrite_client.dart';
import '../../../../core/config/env.dart';
import '../../../rbac/domain/user_role.dart';
import '../../data/service_request_repository_impl.dart';
import '../../domain/service_request.dart';
import '../../domain/service_request_repository.dart';

final serviceRequestRepositoryProvider = Provider<ServiceRequestRepository>((ref) {
  return ServiceRequestRepositoryImpl(
    actorId: () => ref.read(sessionControllerProvider).user?.accountId ?? 'unknown',
  );
});

class ServiceRequestQuery {
  const ServiceRequestQuery({this.clientId, this.status, this.assignedTo, this.search = ''});

  final String? clientId;
  final ServiceRequestStatus? status;
  final String? assignedTo;
  final String search;

  @override
  bool operator ==(Object other) =>
      other is ServiceRequestQuery &&
      other.clientId == clientId &&
      other.status == status &&
      other.assignedTo == assignedTo &&
      other.search == search;

  @override
  int get hashCode => Object.hash(clientId, status, assignedTo, search);
}

final serviceRequestsProvider =
    FutureProvider.family<List<ServiceRequest>, ServiceRequestQuery>((ref, query) async {
  final session = ref.watch(sessionControllerProvider);
  final role = session.user?.role;
  final scopedClientId = role == UserRole.client ? session.user?.accountId : query.clientId;
  final result = await ref.watch(serviceRequestRepositoryProvider).getServiceRequests(
        clientId: scopedClientId,
        status: query.status,
        assignedTo: query.assignedTo,
      );
  final items = result.when(
    success: (rows) => rows,
    failure: (error) => throw Exception(error.userMessage),
  );
  final q = query.search.trim().toLowerCase();
  if (q.isEmpty) return items;
  return items
      .where((row) => row.title.toLowerCase().contains(q) || row.clientId.toLowerCase().contains(q))
      .toList();
});

final serviceRequestByIdProvider = FutureProvider.family<ServiceRequest, String>((ref, id) async {
  final result = await ref.watch(serviceRequestRepositoryProvider).getServiceRequestById(id);
  return result.when(
    success: (item) => item,
    failure: (error) => throw Exception(error.userMessage),
  );
});

final realtimeEnabledProvider = Provider<bool>((ref) {
  return !kIsWeb && const bool.fromEnvironment('FLUTTER_TEST') == false;
});

String messagesRealtimeChannel() =>
    'databases.${Env.databaseId}.tables.${AppwriteService.messagesCol}.rows';

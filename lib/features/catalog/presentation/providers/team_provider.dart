import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/team_member.dart';
import 'services_provider.dart';

final publicTeamProvider = FutureProvider<List<TeamMember>>((ref) async {
  final result = await ref.watch(catalogRepositoryProvider).getTeamMembers();
  return result.when(
    success: (items) => items,
    failure: (error) => throw Exception(error.userMessage),
  );
});

final adminTeamProvider = FutureProvider<List<TeamMember>>((ref) async {
  final result = await ref.watch(catalogRepositoryProvider).getTeamMembers(activeOnly: false);
  return result.when(
    success: (items) => items,
    failure: (error) => throw Exception(error.userMessage),
  );
});

final teamMemberByIdProvider = FutureProvider.family<TeamMember, String>((ref, id) async {
  final result = await ref.watch(catalogRepositoryProvider).getTeamMemberById(id);
  return result.when(
    success: (item) => item,
    failure: (error) => throw Exception(error.userMessage),
  );
});

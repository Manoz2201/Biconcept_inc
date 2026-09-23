import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../rbac/domain/user_role.dart';
import '../../data/user_repository_impl.dart';
import '../../domain/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(
    actorId: () => ref.read(sessionControllerProvider).user?.accountId ?? 'unknown',
  );
});

class UserListQuery {
  const UserListQuery({
    this.search = '',
    this.role,
    this.isActive,
  });

  final String search;
  final UserRole? role;
  final bool? isActive;
}

class UserList extends AsyncNotifier<UserPage> {
  UserListQuery query = const UserListQuery();

  @override
  Future<UserPage> build() => _load();

  Future<UserPage> _load({String? cursor}) async {
    final result = await ref.read(userRepositoryProvider).list(
          search: query.search.isEmpty ? null : query.search,
          role: query.role,
          isActive: query.isActive,
          cursor: cursor,
        );
    return result.when(
      success: (page) => page,
      failure: (error) => throw Exception(error.userMessage),
    );
  }

  Future<void> apply(UserListQuery next) async {
    query = next;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final userListProvider = AsyncNotifierProvider<UserList, UserPage>(UserList.new);

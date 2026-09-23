import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/enquiry_repository_impl.dart';
import '../../domain/enquiry.dart';
import '../../domain/enquiry_repository.dart';
import '../enquiry_cooldown.dart';

final enquiryCooldownProvider = Provider<EnquiryCooldown>((ref) => EnquiryCooldown());

final enquiryRepositoryProvider = Provider<EnquiryRepository>((ref) {
  return EnquiryRepositoryImpl(
    actorId: () => ref.read(sessionControllerProvider).user?.accountId ?? 'public',
  );
});

class EnquiryListQuery {
  const EnquiryListQuery({this.status, this.assignedTo, this.search = ''});

  final EnquiryStatus? status;
  final String? assignedTo;
  final String search;
}

class EnquiryList extends AsyncNotifier<List<Enquiry>> {
  EnquiryListQuery query = const EnquiryListQuery();

  @override
  Future<List<Enquiry>> build() => _load();

  Future<List<Enquiry>> _load() async {
    final result = await ref.read(enquiryRepositoryProvider).getEnquiries(
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
        .where(
          (row) =>
              row.name.toLowerCase().contains(q) ||
              row.email.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> apply(EnquiryListQuery next) async {
    query = next;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final enquiryListProvider = AsyncNotifierProvider<EnquiryList, List<Enquiry>>(EnquiryList.new);

final enquiryByIdProvider = FutureProvider.family<Enquiry, String>((ref, id) async {
  final result = await ref.watch(enquiryRepositoryProvider).getEnquiryById(id);
  return result.when(
    success: (item) => item,
    failure: (error) => throw Exception(error.userMessage),
  );
});

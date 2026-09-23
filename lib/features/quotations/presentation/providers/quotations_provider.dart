import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../rbac/domain/user_role.dart';
import '../../data/quotation_pdf_service.dart';
import '../../data/quotation_repository_impl.dart';
import '../../domain/quotation.dart';
import '../../domain/quotation_repository.dart';

final quotationRepositoryProvider = Provider<QuotationRepository>((ref) {
  return QuotationRepositoryImpl(
    actorId: () => ref.read(sessionControllerProvider).user?.accountId ?? 'unknown',
  );
});

final quotationPdfServiceProvider = Provider<QuotationPdfService>((ref) => QuotationPdfService());

class QuotationQuery {
  const QuotationQuery({this.clientId, this.serviceRequestId, this.status, this.search = ''});

  final String? clientId;
  final String? serviceRequestId;
  final QuotationStatus? status;
  final String search;

  @override
  bool operator ==(Object other) =>
      other is QuotationQuery &&
      other.clientId == clientId &&
      other.serviceRequestId == serviceRequestId &&
      other.status == status &&
      other.search == search;

  @override
  int get hashCode => Object.hash(clientId, serviceRequestId, status, search);
}

final quotationsProvider = FutureProvider.family<List<Quotation>, QuotationQuery>((ref, query) async {
  final session = ref.watch(sessionControllerProvider);
  final role = session.user?.role;
  final scopedClientId = role == UserRole.client ? session.user?.accountId : query.clientId;
  final result = await ref.watch(quotationRepositoryProvider).getQuotations(
        clientId: scopedClientId,
        serviceRequestId: query.serviceRequestId,
        status: query.status,
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
            row.quotationNumber.toLowerCase().contains(q) ||
            row.title.toLowerCase().contains(q) ||
            row.clientId.toLowerCase().contains(q),
      )
      .toList();
});

final quotationByIdProvider = FutureProvider.family<Quotation, String>((ref, id) async {
  final result = await ref.watch(quotationRepositoryProvider).getQuotationById(id);
  return result.when(
    success: (item) => item,
    failure: (error) => throw Exception(error.userMessage),
  );
});

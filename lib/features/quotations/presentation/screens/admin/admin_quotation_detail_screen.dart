import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/permission_gate.dart';
import '../../../../../data/app_notifications.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../user_management/presentation/providers/user_providers.dart';
import '../../../domain/quotation.dart';
import '../../providers/quotations_provider.dart';
import '../../widgets/quotation_preview.dart';
import '../../widgets/quotation_status_badge.dart';

class AdminQuotationDetailScreen extends ConsumerWidget {
  const AdminQuotationDetailScreen({super.key, required this.quotationId});

  final String quotationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(quotationByIdProvider(quotationId));
    final users = ref.watch(userListProvider).valueOrNull?.users ?? [];
    return PermissionGate(
      permission: Permission.quotationView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quotation'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin/quotations')),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (quote) {
            final client = users.where((user) => user.accountId == quote.clientId).firstOrNull;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Text(quote.quotationNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    QuotationStatusBadge(status: quote.effectiveStatus),
                  ],
                ),
                Text(client?.name ?? quote.clientId, style: TextStyle(color: AppColors.muted)),
                Text('Valid until ${formatDisplayDate(quote.validUntil)}'),
                if (quote.revisionNumber > 0) Text('Revision ${quote.revisionNumber}'),
                const SizedBox(height: 16),
                QuotationPreview(quotation: quote),
                if (quote.clientNotes != null && quote.clientNotes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Client notes: ${quote.clientNotes}'),
                  ),
                if (quote.internalNotes != null && quote.internalNotes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Internal notes: ${quote.internalNotes}', style: TextStyle(color: AppColors.muted)),
                  ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    final user = client ?? ref.read(sessionControllerProvider).user;
                    if (user == null) return;
                    await ref.read(quotationPdfServiceProvider).sharePdf(quote, user);
                  },
                  child: const Text('Download PDF'),
                ),
                if (quote.status == QuotationStatus.sent || quote.status == QuotationStatus.viewed)
                  PermissionGate(
                    permission: Permission.quotationSend,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: () => AppNotifications.instance.showImmediate(
                          title: 'Reminder sent',
                          body: 'Follow up on ${quote.quotationNumber}',
                        ),
                        child: const Text('Send reminder'),
                      ),
                    ),
                  ),
                if (quote.status == QuotationStatus.revisionRequested)
                  PermissionGate(
                    permission: Permission.quotationCreate,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton(
                        onPressed: () async {
                          final result = await ref.read(quotationRepositoryProvider).createRevision(quote.id);
                          if (result.dataOrNull != null && context.mounted) {
                            context.go('/admin/quotations/${result.dataOrNull!.id}/edit');
                          }
                        },
                        child: const Text('Create revision'),
                      ),
                    ),
                  ),
                if (quote.status == QuotationStatus.draft)
                  PermissionGate(
                    permission: Permission.quotationEdit,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton(
                        onPressed: () => context.go('/admin/quotations/${quote.id}/edit'),
                        child: const Text('Edit draft'),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

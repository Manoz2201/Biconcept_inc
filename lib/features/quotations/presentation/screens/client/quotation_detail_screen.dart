import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../data/app_notifications.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../domain/quotation.dart';
import '../../providers/quotations_provider.dart';
import '../../widgets/quotation_preview.dart';
import '../../widgets/quotation_status_badge.dart';

class QuotationDetailScreen extends ConsumerStatefulWidget {
  const QuotationDetailScreen({super.key, required this.quotationId});

  final String quotationId;

  @override
  ConsumerState<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends ConsumerState<QuotationDetailScreen> {
  var _viewed = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quotationByIdProvider(widget.quotationId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotation'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/client/quotations')),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (quote) {
          if (!_viewed && quote.status == QuotationStatus.sent) {
            _viewed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await ref.read(quotationRepositoryProvider).markViewed(quote.id);
              ref.invalidate(quotationByIdProvider(widget.quotationId));
            });
          }
          final actionable = quote.status == QuotationStatus.sent || quote.status == QuotationStatus.viewed;
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
              Text('Valid until ${formatDisplayDate(quote.validUntil)}', style: TextStyle(color: AppColors.muted)),
              if (quote.revisionNumber > 0) Text('Revision ${quote.revisionNumber}'),
              const SizedBox(height: 16),
              QuotationPreview(quotation: quote),
              if (quote.clientNotes != null && quote.clientNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Your notes: ${quote.clientNotes}'),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  final user = ref.read(sessionControllerProvider).user;
                  if (user == null) return;
                  await ref.read(quotationPdfServiceProvider).sharePdf(quote, user);
                },
                child: const Text('Download PDF'),
              ),
              if (actionable) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: () => _respond(true), child: const Text('Approve Quotation')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _requestChanges, child: const Text('Request Changes')),
                const SizedBox(height: 8),
                TextButton(onPressed: () => _respond(false), child: const Text('Reject')),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _respond(bool approved, {String? notes}) async {
    if (approved) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Approve quotation?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
          ],
        ),
      );
      if (ok != true) return;
    } else if (notes == null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject quotation?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reject')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final result = await ref.read(quotationRepositoryProvider).clientRespond(
          widget.quotationId,
          approved: approved,
          notes: notes,
        );
    if (result.isSuccess) {
      await AppNotifications.instance.showImmediate(
        title: approved ? 'Quotation approved' : 'Quotation updated',
        body: approved ? 'We will start project setup shortly.' : 'The studio has been notified.',
      );
    }
    ref.invalidate(quotationByIdProvider(widget.quotationId));
    ref.invalidate(quotationsProvider);
  }

  Future<void> _requestChanges() async {
    final notes = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request changes'),
        content: TextField(controller: notes, decoration: const InputDecoration(labelText: 'What should change?'), maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, notes.text.trim()), child: const Text('Send')),
        ],
      ),
    );
    notes.dispose();
    if (submitted == null || submitted.isEmpty) return;
    await _respond(false, notes: submitted);
  }
}

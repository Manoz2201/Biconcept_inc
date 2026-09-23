import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../ui/widgets/portal_shell.dart';
import '../../../domain/quotation.dart';
import '../../providers/quotations_provider.dart';
import '../../widgets/quotation_card.dart';

class ClientQuotationsScreen extends ConsumerStatefulWidget {
  const ClientQuotationsScreen({super.key});

  @override
  ConsumerState<ClientQuotationsScreen> createState() => _ClientQuotationsScreenState();
}

class _ClientQuotationsScreenState extends ConsumerState<ClientQuotationsScreen> {
  QuotationStatus? _status;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quotationsProvider(QuotationQuery(status: _status)));
    return PortalPageScaffold(
      title: 'quotes',
      subtitle: 'Review studio quotations and respond in one place.',
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Pending'),
                  selected: _status == QuotationStatus.sent || _status == QuotationStatus.viewed,
                  onSelected: (_) => setState(() => _status = QuotationStatus.sent),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Approved'),
                  selected: _status == QuotationStatus.approved,
                  onSelected: (_) => setState(() => _status = QuotationStatus.approved),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Rejected'),
                  selected: _status == QuotationStatus.rejected,
                  onSelected: (_) => setState(() => _status = QuotationStatus.rejected),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Expired'),
                  selected: _status == QuotationStatus.expired,
                  onSelected: (_) => setState(() => _status = QuotationStatus.expired),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (items) {
                if (items.isEmpty) return const Center(child: Text('No quotations yet'));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return QuotationCard(
                      quotation: item,
                      onTap: () => context.go('/client/quotations/${item.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

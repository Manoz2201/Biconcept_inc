import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/app_buttons.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../ui/widgets/portal_shell.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../../catalog/presentation/providers/services_provider.dart';
import '../../../../catalog/presentation/widgets/service_catalog_browser.dart';
import '../../../../messaging/presentation/providers/messages_provider.dart';
import '../../../../quotations/domain/quotation.dart';
import '../../../../quotations/presentation/providers/quotations_provider.dart';
import '../../../../quotations/presentation/widgets/quotation_status_badge.dart';
import '../../providers/service_requests_provider.dart';
import '../../widgets/service_request_status_badge.dart';

class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionControllerProvider).user?.name ?? 'there';
    final requests = ref.watch(serviceRequestsProvider(const ServiceRequestQuery()));
    final quotations = ref.watch(
      quotationsProvider(const QuotationQuery(status: QuotationStatus.sent)),
    );
    final viewed = ref.watch(
      quotationsProvider(const QuotationQuery(status: QuotationStatus.viewed)),
    );
    final inbox = ref.watch(clientInboxProvider);
    final services = ref.watch(publicServicesProvider);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final pad = compact ? 16.0 : 24.0;
    final requestItems = requests.valueOrNull ?? const [];
    final pendingQuotes = <Quotation>[
      ...quotations.valueOrNull ?? const <Quotation>[],
      ...viewed.valueOrNull ?? const <Quotation>[],
    ];
    final unread = (inbox.valueOrNull ?? const []).where((thread) => thread.unread > 0).toList();

    return PortalPageScaffold(
      title: 'home',
      subtitle: 'Hello, $name. Choose a service — we will review and send a quotation.',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(serviceRequestsProvider);
          ref.invalidate(quotationsProvider);
          ref.invalidate(clientInboxProvider);
          ref.invalidate(publicServicesProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 4, pad, compact ? AppBreakpoints.navClearance : 32),
          children: [
            if (requestItems.isNotEmpty || pendingQuotes.isNotEmpty) ...[
              _KpiRow(
                compact: compact,
                requestCount: requestItems.length,
                quoteCount: pendingQuotes.length,
                unreadCount: unread.fold<int>(0, (sum, thread) => sum + thread.unread),
              ),
              const SizedBox(height: 16),
              if (requestItems.isNotEmpty)
                PortalSectionCard(
                  title: 'Active requests',
                  child: Column(
                    children: [
                      for (final item in requestItems.take(3))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.title, style: TextStyle(color: AppColors.text)),
                          trailing: ServiceRequestStatusBadge(status: item.status),
                          onTap: () => context.go('/client/requests/${item.id}'),
                        ),
                    ],
                  ),
                ),
              if (pendingQuotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PendingQuotes(pending: pendingQuotes),
              ],
              if (unread.isNotEmpty) ...[
                const SizedBox(height: 12),
                PortalSectionCard(
                  title: 'Recent messages',
                  child: Column(
                    children: [
                      for (final thread in unread.take(3))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(thread.request.title, style: TextStyle(color: AppColors.text)),
                          subtitle: Text(thread.last?.message ?? '', style: TextStyle(color: AppColors.muted)),
                          trailing: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            child: Text('${thread.unread}', style: const TextStyle(fontSize: 11)),
                          ),
                          onTap: () => context.go('/client/requests/${thread.request.id}'),
                        ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 8),
            Text(
              'services',
              style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
            ),
            const SizedBox(height: 12),
            services.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text('$error', style: TextStyle(color: AppColors.down)),
              data: (items) => ServiceCatalogBrowser(
                items: items,
                onServiceTap: (item) => context.go('/client/requests/new?serviceId=${Uri.encodeComponent(item.id)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.compact,
    required this.requestCount,
    required this.quoteCount,
    required this.unreadCount,
  });

  final bool compact;
  final int requestCount;
  final int quoteCount;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final cards = [
      PortalKpiCard(
        label: 'Active requests',
        value: '$requestCount',
        icon: Icons.assignment_outlined,
        caption: 'Open service requests',
        onTap: () => context.go('/client/requests'),
      ),
      PortalKpiCard(
        label: 'Pending quotes',
        value: '$quoteCount',
        icon: Icons.request_quote_outlined,
        caption: 'Awaiting your review',
        onTap: () => context.go('/client/quotations'),
      ),
      PortalKpiCard(
        label: 'Unread messages',
        value: '$unreadCount',
        icon: Icons.chat_outlined,
        caption: 'New replies from the studio',
        onTap: () => context.go('/client/chat'),
      ),
    ];
    if (compact) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            cards[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _PendingQuotes extends StatelessWidget {
  const _PendingQuotes({required this.pending});

  final List<Quotation> pending;

  @override
  Widget build(BuildContext context) {
    return PortalSectionCard(
      title: 'Pending quotations',
      child: Column(
        children: [
          for (final quote in pending)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(quote.quotationNumber, style: TextStyle(color: AppColors.text)),
              subtitle: Text(formatMoney(quote.total), style: TextStyle(color: AppColors.muted)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QuotationStatusBadge(status: quote.effectiveStatus),
                  const SizedBox(width: 8),
                  AppTextButton(
                    label: 'Review',
                    onPressed: () => context.go('/client/quotations/${quote.id}'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

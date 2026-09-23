import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../core/widgets/app_buttons.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../ui/widgets/portal_shell.dart';
import '../../../../purchase_orders/domain/purchase_order.dart';
import '../../../../rfqs/domain/rfq.dart';
import '../../../../vendor_bills/domain/vendor_bill.dart';
import '../../providers/vendors_provider.dart';

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(myVendorProfileProvider).valueOrNull;
    final vendorId = vendor?.id;
    final pos = vendorId == null
        ? const <PurchaseOrder>[]
        : ref.watch(purchaseOrdersProvider(PoQuery(vendorId: vendorId))).valueOrNull ?? const [];
    final bills = vendorId == null
        ? const <VendorBill>[]
        : ref.watch(vendorBillsProvider(BillQuery(vendorId: vendorId))).valueOrNull ?? const [];
    final rfqs = ref.watch(rfqsProvider(const RfqQuery())).valueOrNull ?? const [];
    final payments = ref.watch(vendorPaymentsProvider(vendorId)).valueOrNull ?? const [];
    final unpaid = [for (final bill in bills) if (bill.paymentStatus != PaymentStatusFlag.paid) bill];
    final activePos = pos.where((item) => !item.status.isTerminal).toList();
    final openRfqs = rfqs.where((item) => item.status.isOpen || item.status == RFQStatus.sent).toList();
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final pad = compact ? 16.0 : 24.0;

    return PortalPageScaffold(
      title: 'dashboard',
      subtitle: 'Hello, ${vendor?.companyName ?? 'Vendor'}. Pipeline of RFQs, orders, and bills.',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myVendorProfileProvider);
          ref.invalidate(purchaseOrdersProvider);
          ref.invalidate(vendorBillsProvider);
          ref.invalidate(rfqsProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 4, pad, compact ? AppBreakpoints.navClearance : 32),
          children: [
            _KpiRow(
              compact: compact,
              poCount: activePos.length,
              rfqCount: openRfqs.length,
              unpaidLabel: unpaid.isEmpty ? '0' : formatMoney(unpaid.fold<double>(0, (sum, item) => sum + item.remaining)),
              paymentCount: payments.take(3).length,
            ),
            const SizedBox(height: 16),
            if (activePos.isNotEmpty)
              PortalSectionCard(
                title: 'Active purchase orders',
                child: Column(
                  children: [
                    for (final item in activePos.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.poNumber, style: TextStyle(color: AppColors.text)),
                        subtitle: Text(item.status.label, style: TextStyle(color: AppColors.muted)),
                        onTap: () => context.go('/vendor/pos'),
                      ),
                  ],
                ),
              ),
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 12),
              PortalSectionCard(
                title: 'Recent payments',
                child: Column(
                  children: [
                    for (final item in payments.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(formatMoney(item.amount), style: TextStyle(color: AppColors.text)),
                        subtitle: Text(item.status.label, style: TextStyle(color: AppColors.muted)),
                        onTap: () => context.go('/vendor/payments'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppPrimaryButton(label: 'View RFQs', onPressed: () => context.go('/vendor/rfqs')),
                AppSecondaryButton(label: 'Submit bill', onPressed: () => context.go('/vendor/bills/new')),
                AppSecondaryButton(label: 'My profile', onPressed: () => context.go('/vendor/profile')),
              ],
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
    required this.poCount,
    required this.rfqCount,
    required this.unpaidLabel,
    required this.paymentCount,
  });

  final bool compact;
  final int poCount;
  final int rfqCount;
  final String unpaidLabel;
  final int paymentCount;

  @override
  Widget build(BuildContext context) {
    final cards = [
      PortalKpiCard(
        label: 'Active POs',
        value: '$poCount',
        icon: Icons.receipt_long_outlined,
        caption: 'Orders in progress',
        onTap: () => context.go('/vendor/pos'),
      ),
      PortalKpiCard(
        label: 'Open RFQs',
        value: '$rfqCount',
        icon: Icons.request_quote_outlined,
        caption: 'Invites waiting on you',
        onTap: () => context.go('/vendor/rfqs'),
      ),
      PortalKpiCard(
        label: 'Unpaid bills',
        value: unpaidLabel,
        icon: Icons.payments_outlined,
        caption: 'Outstanding to collect',
        onTap: () => context.go('/vendor/bills'),
      ),
      PortalKpiCard(
        label: 'Recent payments',
        value: '$paymentCount',
        icon: Icons.account_balance_wallet_outlined,
        caption: 'Latest receipts',
        onTap: () => context.go('/vendor/payments'),
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }
}

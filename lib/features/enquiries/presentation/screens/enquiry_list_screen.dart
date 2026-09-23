import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../../theme/app_theme.dart';
import '../../../catalog/presentation/providers/services_provider.dart';
import '../../../rbac/domain/permission.dart';
import '../../domain/enquiry.dart';
import '../providers/enquiries_provider.dart';
import '../widgets/enquiry_status_badge.dart';

class EnquiryListScreen extends ConsumerStatefulWidget {
  const EnquiryListScreen({super.key});

  @override
  ConsumerState<EnquiryListScreen> createState() => _EnquiryListScreenState();
}

class _EnquiryListScreenState extends ConsumerState<EnquiryListScreen> {
  final _search = TextEditingController();
  EnquiryStatus? _status;
  DateTimeRange? _range;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(enquiryListProvider);
    final services = {
      for (final item in ref.watch(publicServicesProvider).valueOrNull ?? []) item.id: item.title,
    };
    return PermissionGate(
      permission: Permission.enquiryView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enquiries'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/app'),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search name or email',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) => _apply(),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All statuses'),
                    selected: _status == null,
                    onSelected: (_) {
                      setState(() => _status = null);
                      _apply();
                    },
                  ),
                  const SizedBox(width: 8),
                  for (final status in EnquiryStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(status.label),
                        selected: _status == status,
                        onSelected: (_) {
                          setState(() => _status = status);
                          _apply();
                        },
                      ),
                    ),
                  TextButton(
                    onPressed: _pickRange,
                    child: Text(_range == null ? 'Date range' : '${_range!.start.month}/${_range!.start.day}–${_range!.end.month}/${_range!.end.day}'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('$error', style: TextStyle(color: AppColors.down))),
                data: (items) {
                  final filtered = items.where((item) {
                    if (_range == null || item.createdAt == null) return true;
                    final created = item.createdAt!;
                    return !created.isBefore(_range!.start) && !created.isAfter(_range!.end.add(const Duration(days: 1)));
                  }).toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      key: Key('enquiry-empty'),
                      child: Text('No enquiries yet'),
                    );
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          [
                            item.email,
                            if (item.phone != null && item.phone!.trim().isNotEmpty) item.phone,
                            if (item.source == 'client_portal') 'Client request',
                            if (item.serviceId != null) services[item.serviceId!] ?? item.serviceId,
                            if (item.createdAt != null) item.createdAt!.toLocal().toString().split('.').first,
                          ].join(' · '),
                        ),
                        trailing: EnquiryStatusBadge(status: item.status),
                        onTap: () => context.push('/admin/enquiries/${item.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    setState(() => _range = picked);
  }

  void _apply() {
    ref.read(enquiryListProvider.notifier).apply(
          EnquiryListQuery(status: _status, search: _search.text),
        );
  }
}

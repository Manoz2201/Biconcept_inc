import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/permission_gate.dart';
import '../../../../theme/app_theme.dart';
import '../../../rbac/domain/permission.dart';
import '../../../service_requests/presentation/providers/service_requests_provider.dart';
import '../../../user_management/presentation/providers/user_providers.dart';
import '../../domain/enquiry.dart';
import '../providers/enquiries_provider.dart';
import '../widgets/enquiry_status_badge.dart';

class EnquiryDetailScreen extends ConsumerStatefulWidget {
  const EnquiryDetailScreen({super.key, required this.enquiryId});

  final String enquiryId;

  @override
  ConsumerState<EnquiryDetailScreen> createState() => _EnquiryDetailScreenState();
}

class _EnquiryDetailScreenState extends ConsumerState<EnquiryDetailScreen> {
  final _note = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(enquiryByIdProvider(widget.enquiryId));
    final staff = ref.watch(userListProvider).valueOrNull?.users ?? [];
    return PermissionGate(
      permission: Permission.enquiryView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enquiry'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin/enquiries'),
          ),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (enquiry) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null) Text(_error!, style: TextStyle(color: AppColors.down)),
                Text(enquiry.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                Text(enquiry.email, style: TextStyle(color: AppColors.muted)),
                if (enquiry.phone != null) Text(enquiry.phone!, style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                EnquiryStatusBadge(status: enquiry.status),
                const SizedBox(height: 16),
                Text(enquiry.message, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 20),
                PermissionGate(
                  permission: Permission.enquiryManage,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<EnquiryStatus>(
                        initialValue: enquiry.status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          for (final status in EnquiryStatus.values)
                            DropdownMenuItem(value: status, child: Text(status.label)),
                        ],
                        onChanged: _busy ? null : (value) => _status(value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: staff.any((user) => user.accountId == enquiry.assignedTo)
                            ? enquiry.assignedTo
                            : null,
                        decoration: const InputDecoration(labelText: 'Assign to'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('Unassigned')),
                          for (final user in staff.where((user) => user.role.isStaff))
                            DropdownMenuItem(value: user.accountId, child: Text(user.name)),
                        ],
                        onChanged: _busy ? null : (value) => _assign(value),
                      ),
                      const SizedBox(height: 16),
                      const Text('Notes', style: TextStyle(fontWeight: FontWeight.w700)),
                      if (enquiry.notes != null && enquiry.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(enquiry.notes!, style: TextStyle(height: 1.4, color: AppColors.muted)),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _note,
                        decoration: const InputDecoration(labelText: 'Add a note'),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _busy ? null : _addNote, child: const Text('Save note')),
                      if (enquiry.status == EnquiryStatus.qualified)
                        PermissionGate(
                          permission: Permission.enquiryConvert,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: FilledButton(
                              onPressed: _busy ? null : () => _convert(enquiry),
                              child: const Text('Convert to Service Request'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Activity', style: TextStyle(fontWeight: FontWeight.w700)),
                FutureBuilder(
                  future: ref.read(enquiryRepositoryProvider).listEnquiryAudit(widget.enquiryId),
                  builder: (context, snapshot) {
                    final events = snapshot.data?.dataOrNull ?? const [];
                    if (events.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('No recorded changes yet'),
                      );
                    }
                    return Column(
                      children: [
                        for (final event in events)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(event.action),
                            subtitle: Text(event.timestamp.toLocal().toString().split('.').first),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _status(EnquiryStatus? status) async {
    if (status == null) return;
    setState(() => _busy = true);
    final result = await ref.read(enquiryRepositoryProvider).updateEnquiryStatus(widget.enquiryId, status);
    _after(result.isFailure ? result.errorOrNull?.userMessage : null);
  }

  Future<void> _assign(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    setState(() => _busy = true);
    final result = await ref.read(enquiryRepositoryProvider).assignEnquiry(widget.enquiryId, userId);
    _after(result.isFailure ? result.errorOrNull?.userMessage : null);
  }

  Future<void> _addNote() async {
    final note = _note.text.trim();
    if (note.isEmpty) return;
    setState(() => _busy = true);
    final result = await ref.read(enquiryRepositoryProvider).addEnquiryNote(widget.enquiryId, note);
    if (result.isSuccess) _note.clear();
    _after(result.isFailure ? result.errorOrNull?.userMessage : null);
  }

  Future<void> _convert(Enquiry enquiry) async {
    final title = TextEditingController(text: enquiry.name);
    final description = TextEditingController(text: enquiry.message);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to service request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: description, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Convert')),
        ],
      ),
    );
    final nextTitle = title.text.trim();
    final nextDescription = description.text.trim();
    title.dispose();
    description.dispose();
    if (confirmed != true) return;
    setState(() => _busy = true);
    final result = await ref.read(serviceRequestRepositoryProvider).convertFromEnquiry(enquiry.id);
    if (result.isFailure) {
      _after(result.errorOrNull?.userMessage);
      return;
    }
    final created = result.dataOrNull!;
    if (nextTitle.isNotEmpty || nextDescription.isNotEmpty) {
      await ref.read(serviceRequestRepositoryProvider).updateServiceRequest(created.id, {
        if (nextTitle.isNotEmpty) 'title': nextTitle,
        if (nextDescription.isNotEmpty) 'description': nextDescription,
      });
    }
    if (!mounted) return;
    context.go('/admin/requests/${created.id}');
  }

  void _after(String? error) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    ref.invalidate(enquiryByIdProvider(widget.enquiryId));
    ref.invalidate(enquiryListProvider);
  }
}

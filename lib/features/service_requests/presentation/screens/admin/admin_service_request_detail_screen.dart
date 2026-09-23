import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/permission_gate.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../catalog/presentation/providers/services_provider.dart';
import '../../../../messaging/presentation/widgets/message_thread.dart';
import '../../../../projects/presentation/providers/projects_provider.dart';
import '../../../../rbac/domain/permission.dart';
import '../../../../user_management/presentation/providers/user_providers.dart';
import '../../../domain/service_request.dart';
import '../../providers/service_requests_provider.dart';
import '../../widgets/service_request_status_badge.dart';
import '../../widgets/status_timeline.dart';

class AdminServiceRequestDetailScreen extends ConsumerStatefulWidget {
  const AdminServiceRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<AdminServiceRequestDetailScreen> createState() => _AdminServiceRequestDetailScreenState();
}

class _AdminServiceRequestDetailScreenState extends ConsumerState<AdminServiceRequestDetailScreen> {
  var _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(serviceRequestByIdProvider(widget.requestId));
    final staff = ref.watch(userListProvider).valueOrNull?.users ?? [];
    final clients = staff; // names resolved from users list
    return PermissionGate(
      permission: Permission.serviceRequestView,
      fallback: const Scaffold(body: Center(child: Text('No access'))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Service request'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin/requests')),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (request) {
            final client = clients.where((user) => user.accountId == request.clientId).firstOrNull;
            final services = ref.watch(publicServicesProvider).valueOrNull ?? const [];
            final service = request.serviceId == null
                ? null
                : services.where((item) => item.id == request.serviceId || item.slug == request.serviceId).firstOrNull;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null) Text(_error!, style: TextStyle(color: AppColors.down)),
                Text(request.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                if (service != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text('${service.category} · ${service.title}', style: TextStyle(color: AppColors.primary)),
                  ),
                ServiceRequestStatusBadge(status: request.status),
                const SizedBox(height: 12),
                StatusTimeline(status: request.status),
                const SizedBox(height: 12),
                Text(request.description, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: Text(client?.name ?? request.clientId),
                    subtitle: Text([client?.email, client?.phone].whereType<String>().join(' · ')),
                  ),
                ),
                const SizedBox(height: 12),
                PermissionGate(
                  permission: Permission.serviceRequestEdit,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: staff.any((user) => user.accountId == request.assignedTo)
                            ? request.assignedTo
                            : null,
                        decoration: const InputDecoration(labelText: 'Assign to'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('Unassigned')),
                          for (final user in staff.where((user) => user.role.isStaff))
                            DropdownMenuItem(value: user.accountId, child: Text(user.name)),
                        ],
                        onChanged: _busy ? null : (value) => _assign(value),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (request.status == ServiceRequestStatus.draft)
                            FilledButton(onPressed: _busy ? null : () => _status(ServiceRequestStatus.submitted), child: const Text('Submit')),
                          if (request.status == ServiceRequestStatus.submitted)
                            FilledButton(onPressed: _busy ? null : () => _status(ServiceRequestStatus.underReview), child: const Text('Start Review')),
                          if (request.status == ServiceRequestStatus.underReview)
                            FilledButton(
                              onPressed: () => context.push('/admin/quotations/new?requestId=${request.id}'),
                              child: const Text('Create Quotation'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (request.status == ServiceRequestStatus.approved)
                  PermissionGate(
                    permission: Permission.projectConvert,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _convert(request),
                        icon: const Icon(Icons.handshake_outlined),
                        label: const Text('Convert to Project'),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                const Text('Messages', style: TextStyle(fontWeight: FontWeight.w700)),
                MessageThread(serviceRequestId: widget.requestId),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _status(ServiceRequestStatus status) async {
    setState(() => _busy = true);
    final result = await ref.read(serviceRequestRepositoryProvider).updateServiceRequest(
          widget.requestId,
          {'status': status.value},
        );
    _after(result.isFailure ? result.errorOrNull?.userMessage : null);
  }

  Future<void> _assign(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    setState(() => _busy = true);
    final result = await ref.read(serviceRequestRepositoryProvider).assignTo(widget.requestId, userId);
    _after(result.isFailure ? result.errorOrNull?.userMessage : null);
  }

  Future<void> _convert(ServiceRequest request) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to project'),
        content: Text(
          'Create a project from "${request.title}". Start date is today and the end date is 90 days out. Budget comes from the approved quotation when one exists.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Convert')),
        ],
      ),
    );
    if (go != true) return;
    setState(() => _busy = true);
    final result = await ref.read(projectRepositoryProvider).convertFromServiceRequest(request.id);
    if (!mounted) return;
    result.when(
      success: (project) {
        ref.invalidate(serviceRequestByIdProvider(request.id));
        context.go('/admin/projects/${project.id}');
      },
      failure: (error) => _after(error.userMessage),
    );
  }

  void _after(String? error) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    ref.invalidate(serviceRequestByIdProvider(widget.requestId));
    ref.invalidate(serviceRequestsProvider);
  }
}

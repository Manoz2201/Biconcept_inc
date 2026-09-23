import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../theme/app_theme.dart';
import '../../../../../ui/widgets/portal_shell.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../../catalog/domain/service_item.dart';
import '../../../../catalog/domain/storage_repository.dart';
import '../../../../catalog/presentation/providers/services_provider.dart';
import '../../../domain/service_request.dart';
import '../../providers/service_requests_provider.dart';

class ServiceRequestFormScreen extends ConsumerStatefulWidget {
  const ServiceRequestFormScreen({super.key});

  @override
  ConsumerState<ServiceRequestFormScreen> createState() => _ServiceRequestFormScreenState();
}

class _ServiceRequestFormScreenState extends ConsumerState<ServiceRequestFormScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _serviceId;
  String? _category;
  ServiceRequestPriority _priority = ServiceRequestPriority.medium;
  final _files = <UploadBytes>[];
  var _busy = false;
  var _prefilled = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final query = GoRouterState.of(context).uri.queryParameters;
    final raw = query['serviceId'] ?? query['slug'];
    if (raw == null || raw.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyService(raw));
  }

  Future<void> _applyService(String raw) async {
    final services = await ref.read(publicServicesProvider.future);
    final match = services.where((item) => item.id == raw || item.slug == raw).firstOrNull;
    if (match == null || !mounted) return;
    setState(() {
      _serviceId = match.id;
      _category = match.category;
      if (_title.text.trim().isEmpty) _title.text = match.title;
      if (_description.text.trim().isEmpty) {
        _description.text =
            'I want ${match.title}.\n\n${match.shortDescription}\n\nSite / flat details:\nBudget range:\nPreferred start:';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(publicServicesProvider).valueOrNull ?? const <ServiceItem>[];
    final categories = {for (final item in services) item.category}.where((item) => item.isNotEmpty).toList()
      ..sort();
    final visible = _category == null ? services : services.where((item) => item.category == _category).toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom + 88;
    return PortalPageScaffold(
      title: 'new request',
      subtitle: 'Tell the studio what you need. They will review and send a quotation.',
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, bottomInset),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: AppColors.down)),
            ),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 16),
          const Text('Service category', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
              for (final category in categories)
                FilterChip(
                  label: Text(category, overflow: TextOverflow.ellipsis),
                  selected: _category == category,
                  onSelected: (_) => setState(() {
                    _category = category;
                    final inCategory = services.where((item) => item.category == category);
                    if (_serviceId != null && !inCategory.any((item) => item.id == _serviceId)) {
                      _serviceId = null;
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey(_serviceId),
            isExpanded: true,
            initialValue: visible.any((item) => item.id == _serviceId) ? _serviceId : null,
            decoration: const InputDecoration(labelText: 'Related service'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('None / not sure', overflow: TextOverflow.ellipsis)),
              for (final service in visible)
                DropdownMenuItem(
                  value: service.id,
                  child: Text(
                    '${service.category} · ${service.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              setState(() => _serviceId = value);
              if (value != null) _applyService(value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ServiceRequestPriority>(
            isExpanded: true,
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: [
              for (final priority in ServiceRequestPriority.values)
                DropdownMenuItem(value: priority, child: Text(priority.label, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) => setState(() => _priority = value ?? ServiceRequestPriority.medium),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.attach_file),
            label: Text(_files.isEmpty ? 'Attach files' : '${_files.length} file(s)'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Submit request')),
        ],
      ),
    );
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
    if (result == null) return;
    setState(() {
      for (final file in result.files) {
        if (file.bytes == null) continue;
        _files.add(UploadBytes(bytes: file.bytes!, filename: file.name));
      }
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final description = _description.text.trim();
    if (title.isEmpty || description.isEmpty) {
      setState(() => _error = 'Title and description are required');
      return;
    }
    final user = ref.read(sessionControllerProvider).user;
    final clientId = user?.accountId;
    if (clientId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final created = await ref.read(serviceRequestRepositoryProvider).createServiceRequest(
          clientId: clientId,
          title: title,
          description: description,
          serviceId: _serviceId,
          priority: _priority,
          clientName: user?.name,
          clientEmail: user?.email,
          clientPhone: user?.phone,
        );
    if (created.isFailure) {
      setState(() {
        _busy = false;
        _error = created.errorOrNull?.userMessage;
      });
      return;
    }
    var request = created.dataOrNull!;
    for (final file in _files) {
      final uploaded = await ref.read(serviceRequestRepositoryProvider).uploadAttachment(request.id, file);
      request = uploaded.dataOrNull ?? request;
    }
    ref.invalidate(serviceRequestsProvider);
    if (mounted) context.go('/client/requests/${request.id}');
  }
}

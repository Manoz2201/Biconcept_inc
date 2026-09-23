import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/appwrite/row_permissions.dart';
import '../../../catalog/presentation/providers/services_provider.dart';
import '../../domain/service_request.dart';
import 'service_request_status_badge.dart';

class ServiceRequestCard extends ConsumerWidget {
  const ServiceRequestCard({super.key, required this.request, this.onTap, this.clientName});

  final ServiceRequest request;
  final VoidCallback? onTap;
  final String? clientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(publicServicesProvider).valueOrNull ?? const [];
    final serviceTitle = request.serviceId == null
        ? null
        : services.where((item) => item.id == request.serviceId || item.slug == request.serviceId).firstOrNull?.title;
    return Card(
      child: ListTile(
        title: Text(request.title),
        subtitle: Text(
          [
            if (clientName != null && clientName!.isNotEmpty) clientName!,
            ?serviceTitle,
            if (request.createdAt != null) formatDisplayDate(request.createdAt!),
          ].join(' · '),
        ),
        trailing: ServiceRequestStatusBadge(status: request.status),
        onTap: onTap,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/appwrite/appwrite_client.dart';
import '../../../../../core/appwrite/row_permissions.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../catalog/presentation/providers/services_provider.dart';
import '../../../../messaging/presentation/widgets/message_thread.dart';
import '../../../../quotations/presentation/providers/quotations_provider.dart';
import '../../../../quotations/presentation/widgets/quotation_card.dart';
import '../../../../user_management/presentation/providers/user_providers.dart';
import '../../../domain/service_request.dart';
import '../../providers/service_requests_provider.dart';
import '../../widgets/status_timeline.dart';

class ServiceRequestDetailScreen extends ConsumerWidget {
  const ServiceRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceRequestByIdProvider(requestId));
    final quotes = ref.watch(quotationsProvider(QuotationQuery(serviceRequestId: requestId)));
    final staff = ref.watch(userListProvider).valueOrNull?.users ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/client/requests')),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (request) {
          final assigned = staff.where((user) => user.accountId == request.assignedTo).firstOrNull;
          final services = ref.watch(publicServicesProvider).valueOrNull ?? const [];
          final service = request.serviceId == null
              ? null
              : services.where((item) => item.id == request.serviceId || item.slug == request.serviceId).firstOrNull;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(request.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              if (service != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${service.category} · ${service.title}', style: TextStyle(color: AppColors.primary)),
                ),
              if (request.createdAt != null)
                Text(formatDisplayDate(request.createdAt!), style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              StatusTimeline(status: request.status),
              const SizedBox(height: 16),
              Text(request.description, style: const TextStyle(height: 1.5)),
              if (request.attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Attachments', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final id in request.attachments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file),
                    title: Text(id),
                    onTap: () {
                      final url = ref.read(storageRepositoryProvider).getFileViewUrl(
                            AppwriteService.clientUploadsBucket,
                            id,
                          );
                      launchUrl(Uri.parse(url));
                    },
                  ),
              ],
              if (assigned != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: Text(assigned.name),
                    subtitle: Text(assigned.role.label),
                  ),
                ),
              ],
              quotes.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (items) {
                  if (items.isEmpty || request.status != ServiceRequestStatus.quoted) {
                    return const SizedBox.shrink();
                  }
                  final quote = items.first;
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: QuotationCard(
                      quotation: quote,
                      onTap: () => context.go('/client/quotations/${quote.id}'),
                    ),
                  );
                },
              ),
              if (request.status == ServiceRequestStatus.approved)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.apartment_outlined),
                      title: const Text('Ready for a project'),
                      subtitle: const Text('The studio will convert this request into a live project'),
                      onTap: () => context.go('/client/projects'),
                    ),
                  ),
                ),
              if (request.status == ServiceRequestStatus.converted)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.apartment_outlined),
                      title: const Text('Converted to a project'),
                      onTap: () => context.go('/client/projects'),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text('Messages', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              MessageThread(serviceRequestId: requestId),
            ],
          );
        },
      ),
    );
  }
}

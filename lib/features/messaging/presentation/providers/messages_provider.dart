import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/appwrite/appwrite_client.dart';
import '../../../rbac/domain/user_role.dart';
import '../../../service_requests/domain/service_request.dart';
import '../../../service_requests/presentation/providers/service_requests_provider.dart';
import '../../data/message_repository_impl.dart';
import '../../domain/message_repository.dart';
import '../../domain/service_request_message.dart';

String messageRoleFor(UserRole role) => switch (role) {
      UserRole.client => 'client',
      UserRole.architect => 'architect',
      _ => 'admin',
    };

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return MessageRepositoryImpl(
    actorId: () => session.user?.accountId ?? 'unknown',
    actorName: () => session.user?.name ?? 'User',
    actorRole: () => messageRoleFor(session.user?.role ?? UserRole.client),
  );
});

final messagesProvider = FutureProvider.family<List<ServiceRequestMessage>, String>((ref, requestId) async {
  _bindRealtime(ref, requestId);
  final result = await ref.watch(messageRepositoryProvider).getMessages(requestId);
  return result.when(
    success: (rows) => rows,
    failure: (error) => throw Exception(error.userMessage),
  );
});

final unreadCountProvider = FutureProvider.family<int, String>((ref, requestId) async {
  final result = await ref.watch(messageRepositoryProvider).getUnreadCount(requestId);
  return result.when(
    success: (count) => count,
    failure: (error) => throw Exception(error.userMessage),
  );
});

class InboxThread {
  const InboxThread({required this.request, this.last, this.unread = 0});

  final ServiceRequest request;
  final ServiceRequestMessage? last;
  final int unread;
}

final clientInboxProvider = FutureProvider<List<InboxThread>>((ref) async {
  final requests = await ref.watch(serviceRequestsProvider(const ServiceRequestQuery()).future);
  final repo = ref.watch(messageRepositoryProvider);
  final threads = <InboxThread>[];
  for (final request in requests) {
    final messages = await repo.getMessages(request.id);
    final unread = await repo.getUnreadCount(request.id);
    threads.add(
      InboxThread(
        request: request,
        last: messages.dataOrNull?.isEmpty == false ? messages.dataOrNull!.last : null,
        unread: unread.dataOrNull ?? 0,
      ),
    );
  }
  threads.sort((a, b) {
    final aTime = a.last?.createdAt ?? a.request.updatedAt ?? a.request.createdAt;
    final bTime = b.last?.createdAt ?? b.request.updatedAt ?? b.request.createdAt;
    return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(aTime ?? DateTime.fromMillisecondsSinceEpoch(0));
  });
  return threads;
});

void _bindRealtime(Ref ref, String requestId) {
  const inTest = bool.fromEnvironment('FLUTTER_TEST');
  if (inTest) return;
  try {
    final realtime = Realtime(AppwriteService.client);
    final subscription = realtime.subscribe([messagesRealtimeChannel()]);
    final sub = subscription.stream.listen((_) {
      ref.invalidate(messagesProvider(requestId));
      ref.invalidate(unreadCountProvider(requestId));
    });
    ref.onDispose(() {
      sub.cancel();
      subscription.close();
    });
  } catch (_) {}
}

class MessageCooldown {
  MessageCooldown({this.duration = const Duration(seconds: 5)});

  final Duration duration;
  DateTime? _last;

  Duration? remaining() {
    final last = _last;
    if (last == null) return null;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= duration) return null;
    return duration - elapsed;
  }

  void markSent() => _last = DateTime.now();
}

final messageCooldownProvider = Provider<MessageCooldown>((ref) => MessageCooldown());

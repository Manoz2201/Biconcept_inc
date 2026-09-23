import 'package:biconcept/features/auth/domain/session_state.dart';
import 'package:biconcept/features/auth/domain/user.dart';
import 'package:biconcept/features/auth/presentation/providers/auth_providers.dart';
import 'package:biconcept/features/chat/data/local/database.dart';
import 'package:biconcept/features/chat/domain/message.dart';
import 'package:biconcept/features/chat/domain/message_status.dart';
import 'package:biconcept/features/chat/presentation/providers/chat_provider.dart';
import 'package:biconcept/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:biconcept/features/chat/presentation/widgets/message_bubble.dart';
import 'package:biconcept/features/chat/presentation/widgets/message_status_icon.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaffSession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      isAuthenticated: true,
      user: User(
        id: '2',
        accountId: 'staff-1',
        name: 'Manoj',
        email: 'manoj@biconcept.in',
        role: UserRole.admin,
      ),
    );
  }
}

void main() {
  testWidgets('list screen renders conversations from the local DB', (tester) async {
    final db = ChatDatabase();
    await db.upsertConversation(
      Conversation(
        id: 'a_b',
        peerId: 'b',
        peerName: 'Bo',
        lastMessage: 'See you tomorrow',
        lastAt: DateTime.now(),
        unreadCount: 2,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatDatabaseProvider.overrideWithValue(db),
          sessionControllerProvider.overrideWith(_StaffSession.new),
        ],
        child: const MaterialApp(home: ChatListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Bo'), findsOneWidget);
    expect(find.text('See you tomorrow'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('failed bubble shows retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatMessageBubble(
          mine: true,
          onRetry: () => retried = true,
          message: ChatMessage(
            localId: 'x',
            conversationId: 'a_b',
            senderId: 'a',
            receiverId: 'b',
            body: 'Did not send',
            status: MessageStatus.failed,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
      ),
    );
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
    expect(find.byType(MessageStatusIcon), findsOneWidget);
  });
}

import 'package:biconcept/core/errors/app_exception.dart';
import 'package:biconcept/core/result/app_result.dart';
import 'package:biconcept/features/auth/domain/session_state.dart';
import 'package:biconcept/features/auth/domain/user.dart';
import 'package:biconcept/features/auth/presentation/providers/auth_providers.dart';
import 'package:biconcept/features/catalog/domain/built_in_services.dart';
import 'package:biconcept/features/catalog/domain/storage_repository.dart';
import 'package:biconcept/features/catalog/presentation/providers/services_provider.dart';
import 'package:biconcept/features/messaging/domain/message_repository.dart';
import 'package:biconcept/features/messaging/domain/service_request_message.dart';
import 'package:biconcept/features/messaging/presentation/providers/messages_provider.dart';
import 'package:biconcept/features/quotations/domain/quotation.dart';
import 'package:biconcept/features/quotations/domain/quotation_repository.dart';
import 'package:biconcept/features/quotations/presentation/providers/quotations_provider.dart';
import 'package:biconcept/features/quotations/presentation/screens/admin/quotation_builder_screen.dart';
import 'package:biconcept/features/quotations/presentation/widgets/quotation_status_badge.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:biconcept/features/service_requests/domain/service_request.dart';
import 'package:biconcept/features/service_requests/domain/service_request_repository.dart';
import 'package:biconcept/features/service_requests/presentation/providers/service_requests_provider.dart';
import 'package:biconcept/features/service_requests/presentation/screens/client/client_dashboard_screen.dart';
import 'package:biconcept/features/service_requests/presentation/widgets/service_request_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ClientSession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      isAuthenticated: true,
      user: User(
        id: '1',
        accountId: 'client-1',
        name: 'Asha',
        email: 'asha@example.com',
        role: UserRole.client,
      ),
    );
  }
}

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

class _EmptyRequests implements ServiceRequestRepository {
  @override
  Future<AppResult<List<ServiceRequest>>> getServiceRequests({
    String? clientId,
    ServiceRequestStatus? status,
    String? assignedTo,
  }) async =>
      const Success([]);

  @override
  Future<AppResult<ServiceRequest>> getServiceRequestById(String id) async =>
      Failure(const AppError(message: 'missing'));

  @override
  Future<AppResult<ServiceRequest>> createServiceRequest({
    required String clientId,
    required String title,
    required String description,
    String? serviceId,
    String? enquiryId,
    List<String>? attachments,
    ServiceRequestPriority? priority,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
  }) async =>
      Failure(const AppError(message: 'unused'));

  @override
  Future<AppResult<ServiceRequest>> updateServiceRequest(String id, Map<String, dynamic> data) async =>
      Failure(const AppError(message: 'unused'));

  @override
  Future<AppResult<ServiceRequest>> assignTo(String id, String userId) async =>
      Failure(const AppError(message: 'unused'));

  @override
  Future<AppResult<ServiceRequest>> convertFromEnquiry(String enquiryId) async =>
      Failure(const AppError(message: 'unused'));

  @override
  Future<AppResult<ServiceRequest>> uploadAttachment(String requestId, UploadBytes file) async =>
      Failure(const AppError(message: 'unused'));
}

class _EmptyQuotes implements QuotationRepository {
  @override
  Future<AppResult<List<Quotation>>> getQuotations({
    String? clientId,
    String? serviceRequestId,
    QuotationStatus? status,
  }) async =>
      const Success([]);

  @override
  Future<AppResult<Quotation>> getQuotationById(String id) async => Failure(const AppError(message: 'missing'));

  @override
  Future<AppResult<Quotation>> createQuotation({
    required String serviceRequestId,
    required String clientId,
    required String title,
    required List<QuotationLineItem> items,
    double taxRate = 18,
    required DateTime validUntil,
    String? internalNotes,
  }) async =>
      Failure(const AppError(message: 'unused'));

  @override
  Future<AppResult<Quotation>> updateQuotation(String id, Map<String, dynamic> data) async =>
      Failure(const AppError(message: 'unused'));

  @override
  Future<AppResult<Quotation>> sendQuotation(String id) async => Failure(const AppError(message: 'unused'));

  @override
  Future<AppResult<Quotation>> markViewed(String id) async => Failure(const AppError(message: 'unused'));

  @override
  Future<AppResult<Quotation>> clientRespond(String id, {required bool approved, String? notes}) async =>
      Failure(const AppError(message: 'unused'));

  @override
  Future<AppResult<Quotation>> createRevision(String id) async => Failure(const AppError(message: 'unused'));
}

class _EmptyMessages implements MessageRepository {
  @override
  Future<AppResult<List<ServiceRequestMessage>>> getMessages(String serviceRequestId) async => const Success([]);

  @override
  Future<AppResult<ServiceRequestMessage>> sendMessage(
    String serviceRequestId,
    String message, {
    List<UploadBytes>? attachments,
  }) async =>
      Failure(const AppError(message: 'unused'));

  @override
  Future<AppResult<void>> markAsRead(String messageId) async => const Success(null);

  @override
  Future<AppResult<int>> getUnreadCount(String serviceRequestId) async => const Success(0);
}

void main() {
  testWidgets('client dashboard empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_ClientSession.new),
          serviceRequestRepositoryProvider.overrideWithValue(_EmptyRequests()),
          quotationRepositoryProvider.overrideWithValue(_EmptyQuotes()),
          messageRepositoryProvider.overrideWithValue(_EmptyMessages()),
          publicServicesProvider.overrideWith((ref) async => builtInServices),
        ],
        child: const MaterialApp(home: ClientDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Explore Our Services'), findsNothing);
    expect(find.text('services'), findsOneWidget);
  });

  testWidgets('quotation builder live totals', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_StaffSession.new),
          serviceRequestRepositoryProvider.overrideWithValue(_EmptyRequests()),
          quotationRepositoryProvider.overrideWithValue(_EmptyQuotes()),
        ],
        child: const MaterialApp(home: QuotationBuilderScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('line-item-add')), findsOneWidget);
    expect(find.byKey(const Key('quotation-subtotal')), findsOneWidget);
  });

  testWidgets('status badges render labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ServiceRequestStatusBadge(status: ServiceRequestStatus.quoted),
              QuotationStatusBadge(status: QuotationStatus.revisionRequested),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Quoted'), findsOneWidget);
    expect(find.text('Revision requested'), findsOneWidget);
  });
}

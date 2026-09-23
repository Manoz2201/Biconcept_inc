import 'package:biconcept/features/ai_assistant/domain/ai_models.dart';
import 'package:biconcept/features/enquiries/domain/enquiry.dart';
import 'package:biconcept/features/intelligence/data/intelligence_workspace.dart';
import 'package:biconcept/features/intelligence/domain/intelligence_math.dart';
import 'package:biconcept/features/projects/domain/project.dart';
import 'package:biconcept/features/projects/domain/project_status.dart';
import 'package:biconcept/features/rbac/domain/permission.dart';
import 'package:biconcept/features/rbac/domain/role_permissions.dart';
import 'package:biconcept/features/rbac/domain/user_role.dart';
import 'package:biconcept/features/voice/domain/voice_config.dart';
import 'package:biconcept/features/whatsapp/domain/whatsapp_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invoice and receipt OCR parse Indian fields', () {
    const text = '''
Invoice No: INV-2026-009
Date: 12/04/2026
GSTIN: 33AABCU9603R1ZM
Grand Total: ₹1,25,500.50
''';
    final invoice = parseInvoiceText(text);
    expect(invoice['invoiceNumber'], 'INV-2026-009');
    expect(invoice['invoiceDate'], '12/04/2026');
    expect(invoice['vendorGstin'], '33AABCU9603R1ZM');
    expect(invoice['grandTotal'], 125500.50);

    final receipt = parseReceiptText('Merchant: Site Hardware\nDate: 12/04/2026\nTotal: 2,000');
    expect(receipt['merchantName'], 'Site Hardware');
    expect(receipt['amount'], 2000);
  });

  test('overlap search ranks the matching document first', () {
    final ranked = rankDocuments('unpaid villa invoice', [
      const VectorDocument(id: '1', tenantId: 'a', sourceType: 'invoice', sourceId: 'i1', text: 'Paid office invoice'),
      const VectorDocument(id: '2', tenantId: 'a', sourceType: 'invoice', sourceId: 'i2', text: 'Unpaid villa invoice Chennai'),
    ]);
    expect(ranked.first.sourceId, 'i2');
    expect(ranked.first.similarity, greaterThan(ranked.last.similarity));
  });

  test('lead score and priority bands', () {
    final high = scoreLead(const Enquiry(
      id: 'e1',
      name: 'Asha',
      email: 'a@b.co',
      serviceId: 'svc',
      message: 'Urgent villa in Chennai with budget ₹80 lakh this month. Need drawings and site visits.',
      status: EnquiryStatus.qualified,
    ));
    expect(high['total']!, greaterThan(70));
    expect(leadPriority(high['total']!), 'high');
    expect(leadPriority(55), 'medium');
    expect(leadPriority(10), 'low');
  });

  test('project risk and health respond to overrun and delay', () {
    final now = DateTime.utc(2026, 4, 1);
    final late = Project(
      id: 'p1',
      projectNumber: 'PRJ-1',
      clientId: 'c1',
      title: 'Villa',
      status: ProjectStatus.inProgress,
      startDate: now.subtract(const Duration(days: 90)),
      endDate: now.subtract(const Duration(days: 5)),
      budget: 100000,
      spent: 95000,
      progress: 20,
    );
    final risk = projectRisk(late);
    expect(risk.riskLevel, 'high');
    expect(risk.predictedDelayDays, greaterThan(0));
    final health = projectHealth(late);
    expect(health.schedule, lessThan(60));
  });

  test('linear forecast continues the slope', () {
    final next = linearForecast(const [10, 20, 30], 2);
    expect(next.first, closeTo(40, 0.001));
    expect(next.last, closeTo(50, 0.001));
  });

  test('rate limiter enforces a window per key', () {
    final limiter = RateLimiter();
    expect(limiter.canProceed('ai:a', maxCalls: 2, window: const Duration(days: 1)), isTrue);
    expect(limiter.canProceed('ai:a', maxCalls: 2, window: const Duration(days: 1)), isTrue);
    expect(limiter.canProceed('ai:a', maxCalls: 2, window: const Duration(days: 1)), isFalse);
    expect(limiter.canProceed('ai:b', maxCalls: 2, window: const Duration(days: 1)), isTrue);
  });

  test('plan limits scale AI OCR and WhatsApp', () {
    expect(dailyAiLimit('basic'), 100);
    expect(dailyAiLimit('pro'), 1000);
    expect(monthlyOcrLimit('basic'), 50);
    expect(monthlyWhatsappLimit('enterprise'), 100000);
  });

  test('workspace isolates rows by currentTenantId', () {
    final ws = IntelligenceWorkspace(
      currentTenantId: 'firm_a',
      embeddings: const [
        VectorDocument(id: '1', tenantId: 'firm_a', sourceType: 'note', sourceId: '1', text: 'keep'),
        VectorDocument(id: '2', tenantId: 'firm_b', sourceType: 'note', sourceId: '2', text: 'leak'),
      ],
    );
    final scoped = ws.embeddings.where((item) => item.tenantId == ws.currentTenantId).toList();
    expect(scoped.length, 1);
    expect(scoped.single.text, 'keep');
    expect(IntelligenceWorkspace.decode(ws.encode()).currentTenantId, 'firm_a');
  });

  test('WhatsApp config stores only non-secret hints', () {
    final config = WhatsAppConfig.fromJson({
      'phoneNumberId': '123',
      'webhookUrl': 'https://example.com/hook',
      'accessToken': 'secret',
    });
    expect(config.phoneNumberId, '123');
    expect(config.toJson().containsKey('accessToken'), isFalse);
  });

  test('caption analysis estimates progress and safety', () {
    final labels = analyzeCaption('concrete foundation no notes');
    expect(labels.labels, contains('foundation'));
    expect(labels.progress, 25);
    expect(labels.safety, isNotEmpty);
  });

  test('assistant reply steers invoice questions', () {
    expect(assistantReply('show unpaid invoices').toLowerCase(), contains('invoice'));
  });

  test('natural language unpaid invoice filter', () {
    final result = parseNaturalLanguage(
      'Show me all unpaid invoices over 50000',
      invoices: const [
        {'id': '1', 'status': 'sent', 'amount': '80000', 'label': 'INV-1'},
        {'id': '2', 'status': 'paid', 'amount': '90000', 'label': 'INV-2'},
        {'id': '3', 'status': 'sent', 'amount': '1000', 'label': 'INV-3'},
      ],
      projects: const [],
    );
    expect(result.entity, 'invoice');
    expect(result.rows.map((row) => row['id']), ['1']);
  });

  test('phase 9 role mapping', () {
    expect(hasPermission(UserRole.architect, Permission.aiQuotationSuggest), isTrue);
    expect(hasPermission(UserRole.architect, Permission.aiLeadScore), isFalse);
    expect(hasPermission(UserRole.accountant, Permission.ocrVerify), isTrue);
    expect(hasPermission(UserRole.accountant, Permission.sitePhotoUpload), isFalse);
    expect(hasPermission(UserRole.admin, Permission.tenantView), isTrue);
    expect(hasPermission(UserRole.admin, Permission.tenantCreate), isFalse);
    expect(hasPermission(UserRole.superAdmin, Permission.multiFirmDashboard), isTrue);
    expect(hasPermission(UserRole.client, Permission.aiSemanticSearch), isTrue);
    expect(hasPermission(UserRole.vendor, Permission.whatsappView), isTrue);
    expect(kRolePermissions[UserRole.superAdmin], containsAll(Permission.values));
  });
}

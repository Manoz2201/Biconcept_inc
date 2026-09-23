import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/result/app_result.dart';
import '../../../data/app_notifications.dart';
import '../../auth/data/audit_repository.dart';
import '../../credit_notes/domain/credit_note.dart';
import '../../credit_notes/domain/credit_note_repository.dart';
import '../../debit_notes/domain/debit_note.dart';
import '../../debit_notes/domain/debit_note_repository.dart';
import '../../gst/data/finance_workspace_store.dart';
import '../../gst/domain/gst_math.dart';
import '../../gst/domain/gst_settings.dart';
import '../../ledger/domain/ledger_entry.dart';
import '../../payments/domain/payment.dart';
import '../../payments/domain/payment_repository.dart';
import '../../vendors/domain/line_items.dart';
import '../domain/invoice.dart';
import '../domain/invoice_repository.dart';
import 'invoice_pdf_service.dart';
import 'invoice_workspace.dart';
import 'invoice_workspace_store.dart';

class InvoiceRepositoryImpl
    implements InvoiceRepository, PaymentRepository, CreditNoteRepository, DebitNoteRepository {
  InvoiceRepositoryImpl({
    TablesDB? tables,
    Functions? functions,
    AuditRepository? audit,
    InvoiceWorkspaceStore? invoices,
    FinanceWorkspaceStore? finance,
    InvoicePdfBuilder? pdf,
    String? databaseId,
    String Function()? actorId,
  })  : _tables = tables ?? AppwriteService.tables,
        _functions = functions ?? AppwriteService.functions,
        _audit = audit ?? AuditRepository(),
        _invoices = invoices ?? InvoiceWorkspaceStore(tables: tables ?? AppwriteService.tables, databaseId: databaseId),
        _finance = finance ?? FinanceWorkspaceStore(tables: tables ?? AppwriteService.tables, databaseId: databaseId),
        _pdf = pdf ?? InvoicePdfBuilder(),
        _databaseId = databaseId ?? AppwriteService.dbId,
        _actorId = actorId ?? (() => 'unknown');

  final TablesDB _tables;
  final Functions _functions;
  final AuditRepository _audit;
  final InvoiceWorkspaceStore _invoices;
  final FinanceWorkspaceStore _finance;
  final InvoicePdfBuilder _pdf;
  final String _databaseId;
  final String Function() _actorId;

  @override
  Future<AppResult<List<Invoice>>> getInvoices({
    String? clientId,
    InvoiceStatus? status,
    DateTime? from,
    DateTime? to,
    String? projectId,
  }) {
    return AppwriteService.guard(() async {
      final queryStatus = status == InvoiceStatus.overdue ? InvoiceStatus.issued.value : status?.value;
      final rows = await _invoices.list(clientId: clientId, status: queryStatus, projectId: projectId);
      return [
        for (final row in rows)
          if (_inRange(row.invoice.invoiceDate, from, to) &&
              (status != InvoiceStatus.overdue || row.invoice.displayStatus == InvoiceStatus.overdue))
            row.invoice,
      ];
    });
  }

  @override
  Future<AppResult<Invoice>> getInvoiceById(String id) {
    return AppwriteService.guard(() async => (await _invoices.getById(id)).invoice);
  }

  @override
  Future<AppResult<Invoice>> createInvoice({
    required String clientId,
    required DateTime invoiceDate,
    required DateTime dueDate,
    required String placeOfSupply,
    required String placeOfSupplyCode,
    required List<InvoiceItem> items,
    String? projectId,
    String? quotationId,
    String? notes,
    String? termsAndConditions,
    String? bankDetails,
  }) {
    return AppwriteService.guard(() async {
      if (items.isEmpty) throw AppwriteException('Add at least one line item', 400);
      final finance = await _finance.ensure();
      _assertFyOpen(finance.settings, invoiceDate);
      final interState = isInterStateSupply(finance.settings.firmStateCode, placeOfSupplyCode);
      final priced = [
        for (final item in items)
          InvoiceItem.priced(
            description: item.description,
            hsnSac: item.hsnSac,
            quantity: item.quantity,
            unit: item.unit,
            rate: item.rate,
            taxRate: item.taxRate,
            cessRate: item.cess == 0 || item.taxableValue == 0 ? 0 : item.cess / item.taxableValue * 100,
            interState: interState,
          ),
      ];
      final totals = invoiceTotalsFromLines([
        for (final item in priced)
          GstLineTotals(
            taxableValue: item.taxableValue,
            cgst: item.cgst,
            sgst: item.sgst,
            igst: item.igst,
            cess: item.cess,
            total: item.total,
          ),
      ]);
      final number = await _nextNumber(finance.settings.invoicePrefix, invoiceDate, AppwriteService.generateInvoiceNumberFn);
      final now = DateTime.now().toUtc();
      final row = await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteService.invoicesCol,
        rowId: ID.unique(),
        data: {
          'invoiceNumber': number,
          'clientId': clientId,
          'projectId': ?projectId,
          'quotationId': ?quotationId,
          'invoiceDate': invoiceDate.toUtc().toIso8601String(),
          'dueDate': dueDate.toUtc().toIso8601String(),
          'placeOfSupply': placeOfSupply,
          'placeOfSupplyCode': placeOfSupplyCode,
          'isInterState': interState,
          'itemsJson': encodeJsonList([for (final item in priced) item.toJson()]),
          'subtotal': totals.subtotal,
          'totalCgst': totals.totalCgst,
          'totalSgst': totals.totalSgst,
          'totalIgst': totals.totalIgst,
          'totalCess': totals.totalCess,
          'roundOff': totals.roundOff,
          'grandTotal': totals.grandTotal,
          'amountInWords': amountInIndianWords(totals.grandTotal),
          'status': InvoiceStatus.draft.value,
          'paidAmount': 0,
          'balanceAmount': totals.grandTotal,
          'notes': ?notes,
          'termsAndConditions': ?termsAndConditions,
          'bankDetails': ?bankDetails,
          'createdBy': _actorId(),
          'workspaceJson': InvoiceWorkspace().encode(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        permissions: invoiceRowPermissions(clientId),
      );
      await _audit.log(userId: _actorId(), action: 'invoice_created', metadata: {'id': row.$id, 'invoiceNumber': number});
      return Invoice.fromRow(row.$id, row.data);
    });
  }

  @override
  Future<AppResult<Invoice>> updateInvoice(
    String id,
    List<InvoiceItem> items, {
    String? notes,
    String? termsAndConditions,
    String? bankDetails,
    DateTime? dueDate,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _invoices.getById(id);
      if (snap.invoice.status != InvoiceStatus.draft) {
        throw AppwriteException('Issued invoices cannot be edited. Use a credit note.', 400);
      }
      final finance = await _finance.ensure();
      final interState = isInterStateSupply(finance.settings.firmStateCode, snap.invoice.placeOfSupplyCode);
      final priced = [
        for (final item in items)
          InvoiceItem.priced(
            description: item.description,
            hsnSac: item.hsnSac,
            quantity: item.quantity,
            unit: item.unit,
            rate: item.rate,
            taxRate: item.taxRate,
            interState: interState,
          ),
      ];
      final totals = invoiceTotalsFromLines([
        for (final item in priced)
          GstLineTotals(
            taxableValue: item.taxableValue,
            cgst: item.cgst,
            sgst: item.sgst,
            igst: item.igst,
            cess: item.cess,
            total: item.total,
          ),
      ]);
      final row = await _invoices.saveWorkspace(
        id,
        snap.workspace,
        invoicePatch: {
          'itemsJson': encodeJsonList([for (final item in priced) item.toJson()]),
          'subtotal': totals.subtotal,
          'totalCgst': totals.totalCgst,
          'totalSgst': totals.totalSgst,
          'totalIgst': totals.totalIgst,
          'totalCess': totals.totalCess,
          'roundOff': totals.roundOff,
          'grandTotal': totals.grandTotal,
          'amountInWords': amountInIndianWords(totals.grandTotal),
          'balanceAmount': totals.grandTotal,
          'notes': ?notes,
          'termsAndConditions': ?termsAndConditions,
          'bankDetails': ?bankDetails,
          if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
        },
        permissions: invoiceRowPermissions(snap.invoice.clientId),
      );
      return row.invoice;
    });
  }

  @override
  Future<AppResult<Invoice>> issueInvoice(String id) {
    return AppwriteService.guard(() async {
      final snap = await _invoices.getById(id);
      if (snap.invoice.status != InvoiceStatus.draft) throw AppwriteException('Only drafts can be issued', 400);
      final now = DateTime.now().toUtc();
      final saved = await _invoices.saveWorkspace(
        id,
        snap.workspace,
        invoicePatch: {
          'status': InvoiceStatus.issued.value,
          'issuedAt': now.toIso8601String(),
        },
        permissions: invoiceRowPermissions(snap.invoice.clientId),
      );
      await _appendLedger(
        accountType: AccountType.client,
        accountId: snap.invoice.clientId,
        description: 'Invoice ${snap.invoice.invoiceNumber}',
        debitAmount: snap.invoice.grandTotal,
        referenceType: 'invoice',
        referenceId: id,
      );
      await _audit.log(userId: _actorId(), action: 'invoice_issued', metadata: {'id': id});
      await AppNotifications.instance.showImmediate(title: 'Invoice issued', body: snap.invoice.invoiceNumber);
      return saved.invoice;
    });
  }

  @override
  Future<AppResult<Invoice>> voidInvoice(String id, String reason) {
    return AppwriteService.guard(() async {
      final snap = await _invoices.getById(id);
      if (snap.invoice.paidAmount > 0) throw AppwriteException('Cannot void an invoice with payments', 400);
      final saved = await _invoices.saveWorkspace(
        id,
        snap.workspace,
        invoicePatch: {
          'status': InvoiceStatus.voided.value,
          'cancelledAt': DateTime.now().toUtc().toIso8601String(),
          'cancelReason': reason,
        },
        permissions: invoiceRowPermissions(snap.invoice.clientId),
      );
      if (snap.invoice.status == InvoiceStatus.issued) {
        await _appendLedger(
          accountType: AccountType.client,
          accountId: snap.invoice.clientId,
          description: 'Void ${snap.invoice.invoiceNumber}',
          creditAmount: snap.invoice.grandTotal,
          referenceType: 'invoice',
          referenceId: id,
        );
      }
      await _audit.log(userId: _actorId(), action: 'invoice_voided', metadata: {'id': id, 'reason': reason});
      return saved.invoice;
    });
  }

  @override
  Future<AppResult<Invoice>> updatePaymentStatus(String invoiceId) {
    return AppwriteService.guard(() async => _refreshInvoicePayments(await _invoices.getById(invoiceId)));
  }

  Invoice _refreshInvoicePayments(InvoiceSnapshot snap) {
    final paid = snap.workspace.payments
        .where((item) => item.status == ClientPaymentStatus.completed)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final credits = snap.workspace.creditNotes
        .where((item) => item.status == CreditNoteStatus.issued || item.status == CreditNoteStatus.applied)
        .fold<double>(0, (sum, item) => sum + item.grandTotal);
    final debits = snap.workspace.debitNotes
        .where((item) => item.status == DebitNoteStatus.issued || item.status == DebitNoteStatus.applied)
        .fold<double>(0, (sum, item) => sum + item.grandTotal);
    final due = snap.invoice.grandTotal - credits + debits;
    final balance = (due - paid).clamp(0, due).toDouble();
    InvoiceStatus status = snap.invoice.status;
    if (status != InvoiceStatus.voided && status != InvoiceStatus.cancelled && status != InvoiceStatus.draft) {
      if (paid <= 0) {
        status = InvoiceStatus.issued;
      } else if (paid >= due) {
        status = InvoiceStatus.paid;
      } else {
        status = InvoiceStatus.partiallyPaid;
      }
    }
    return Invoice.fromRow(snap.invoice.id, {
      ...snap.row.data,
      'paidAmount': paid,
      'balanceAmount': balance,
      'status': status.value,
    });
  }

  Future<Invoice> _persistPaymentStatus(InvoiceSnapshot snap) async {
    final next = _refreshInvoicePayments(snap);
    final saved = await _invoices.saveWorkspace(
      snap.invoice.id,
      snap.workspace,
      invoicePatch: {
        'paidAmount': next.paidAmount,
        'balanceAmount': next.outstanding,
        'status': next.status.value,
      },
      permissions: invoiceRowPermissions(snap.invoice.clientId),
    );
    return saved.invoice;
  }

  @override
  Future<AppResult<Uint8List>> generatePdf(String id) {
    return AppwriteService.guard(() async {
      final snap = await _invoices.getById(id);
      final finance = await _finance.ensure();
      return _pdf.generatePdf(
        snap.invoice,
        firmName: finance.settings.firmName,
        firmGstin: finance.settings.firmGstin,
      );
    });
  }

  @override
  Future<AppResult<void>> sharePdf(String id) {
    return AppwriteService.guard(() async {
      final snap = await _invoices.getById(id);
      final finance = await _finance.ensure();
      await _pdf.sharePdf(
        snap.invoice,
        firmName: finance.settings.firmName,
        firmGstin: finance.settings.firmGstin,
      );
    });
  }

  @override
  String exportInvoicesToCsv(List<Invoice> invoices) {
    final rows = [
      'invoiceNumber,clientId,invoiceDate,dueDate,status,subtotal,cgst,sgst,igst,grandTotal,paidAmount',
      for (final item in invoices)
        [
          item.invoiceNumber,
          item.clientId,
          item.invoiceDate.toIso8601String(),
          item.dueDate.toIso8601String(),
          item.displayStatus.value,
          item.subtotal.toStringAsFixed(2),
          item.totalCgst.toStringAsFixed(2),
          item.totalSgst.toStringAsFixed(2),
          item.totalIgst.toStringAsFixed(2),
          item.grandTotal.toStringAsFixed(2),
          item.paidAmount.toStringAsFixed(2),
        ].join(','),
    ];
    return rows.join('\n');
  }

  @override
  Future<AppResult<List<Payment>>> getPayments({
    String? invoiceId,
    String? clientId,
    ClientPaymentStatus? status,
    DateTime? from,
    DateTime? to,
  }) {
    return AppwriteService.guard(() async {
      final rows = await _invoices.list(clientId: clientId, projectId: null);
      return [
        for (final row in rows)
          if (invoiceId == null || row.invoice.id == invoiceId)
            for (final payment in row.workspace.payments)
              if ((status == null || payment.status == status) && _inRange(payment.paymentDate, from, to)) payment,
      ];
    });
  }

  @override
  Future<AppResult<Payment>> getPaymentById(String id) {
    return AppwriteService.guard(() async {
      final host = await _invoices.findPaymentHost(id);
      if (host == null) throw AppwriteException('Payment not found', 404);
      return host.workspace.payments.firstWhere((item) => item.id == id);
    });
  }

  @override
  Future<AppResult<Payment>> createPayment({
    String? invoiceId,
    String? clientId,
    String? projectId,
    required double amount,
    required DateTime paymentDate,
    required PaymentMethod paymentMethod,
    String? referenceNumber,
    String? notes,
    bool completeImmediately = true,
  }) {
    return AppwriteService.guard(() async {
      if (invoiceId == null || invoiceId.isEmpty) throw AppwriteException('Select an invoice', 400);
      if (amount <= 0) throw AppwriteException('Amount must be greater than zero', 400);
      final snap = await _invoices.getById(invoiceId);
      final current = _refreshInvoicePayments(snap);
      if (amount - current.outstanding > 0.009) throw AppwriteException('Payment cannot exceed invoice balance', 400);
      final number = await _nextNumber('PAY', paymentDate, '');
      final now = DateTime.now().toUtc();
      final payment = Payment(
        id: ID.unique(),
        paymentNumber: number,
        invoiceId: invoiceId,
        clientId: clientId ?? snap.invoice.clientId,
        projectId: projectId ?? snap.invoice.projectId,
        amount: amount,
        paymentDate: paymentDate,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        status: completeImmediately ? ClientPaymentStatus.completed : ClientPaymentStatus.pending,
        receiptNumber: completeImmediately ? number.replaceFirst('PAY', 'RCT') : null,
        notes: notes,
        processedBy: _actorId(),
        createdAt: now,
        updatedAt: now,
      );
      snap.workspace.payments.add(payment);
      await _persistPaymentStatus(snap);
      await _audit.log(userId: _actorId(), action: 'payment_created', metadata: {'id': payment.id, 'invoiceId': invoiceId});
      if (completeImmediately) {
        await _appendLedger(
          accountType: AccountType.client,
          accountId: snap.invoice.clientId,
          description: 'Payment ${payment.paymentNumber}',
          creditAmount: amount,
          referenceType: 'payment',
          referenceId: payment.id,
        );
        await _audit.log(userId: _actorId(), action: 'payment_completed', metadata: {'id': payment.id});
        await AppNotifications.instance.showImmediate(title: 'Payment recorded', body: formatMoney(amount));
      }
      return payment;
    });
  }

  @override
  Future<AppResult<Payment>> completePayment(String id) {
    return AppwriteService.guard(() async {
      final host = await _invoices.findPaymentHost(id);
      if (host == null) throw AppwriteException('Payment not found', 404);
      final index = host.workspace.payments.indexWhere((item) => item.id == id);
      final current = host.workspace.payments[index];
      final next = Payment(
        id: current.id,
        paymentNumber: current.paymentNumber,
        invoiceId: current.invoiceId,
        clientId: current.clientId,
        projectId: current.projectId,
        amount: current.amount,
        paymentDate: current.paymentDate,
        paymentMethod: current.paymentMethod,
        referenceNumber: current.referenceNumber,
        gatewayOrderId: current.gatewayOrderId,
        gatewayPaymentId: current.gatewayPaymentId,
        gatewaySignature: current.gatewaySignature,
        status: ClientPaymentStatus.completed,
        receiptNumber: current.receiptNumber ?? current.paymentNumber.replaceFirst('PAY', 'RCT'),
        notes: current.notes,
        processedBy: current.processedBy,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.payments[index] = next;
      await _persistPaymentStatus(host);
      await _appendLedger(
        accountType: AccountType.client,
        accountId: host.invoice.clientId,
        description: 'Payment ${next.paymentNumber}',
        creditAmount: next.amount,
        referenceType: 'payment',
        referenceId: id,
      );
      await _audit.log(userId: _actorId(), action: 'payment_completed', metadata: {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<Payment>> failPayment(String id, String reason) {
    return AppwriteService.guard(() async {
      final host = await _invoices.findPaymentHost(id);
      if (host == null) throw AppwriteException('Payment not found', 404);
      final index = host.workspace.payments.indexWhere((item) => item.id == id);
      final current = host.workspace.payments[index];
      final next = Payment(
        id: current.id,
        paymentNumber: current.paymentNumber,
        invoiceId: current.invoiceId,
        clientId: current.clientId,
        projectId: current.projectId,
        amount: current.amount,
        paymentDate: current.paymentDate,
        paymentMethod: current.paymentMethod,
        referenceNumber: current.referenceNumber,
        status: ClientPaymentStatus.failed,
        notes: reason,
        processedBy: current.processedBy,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.payments[index] = next;
      await _invoices.saveWorkspace(host.invoice.id, host.workspace, permissions: invoiceRowPermissions(host.invoice.clientId));
      await _audit.log(userId: _actorId(), action: 'payment_failed', metadata: {'id': id, 'reason': reason});
      return next;
    });
  }

  @override
  Future<AppResult<Payment>> refundPayment(String id, double refundAmount, String reason) {
    return AppwriteService.guard(() async {
      final host = await _invoices.findPaymentHost(id);
      if (host == null) throw AppwriteException('Payment not found', 404);
      final payment = host.workspace.payments.firstWhere((item) => item.id == id);
      await createCreditNote(
        invoiceId: host.invoice.id,
        reason: reason,
        items: [
          InvoiceItem.priced(
            description: 'Refund ${payment.paymentNumber}',
            hsnSac: host.invoice.items.isEmpty ? '9983' : host.invoice.items.first.hsnSac,
            quantity: 1,
            unit: 'nos',
            rate: refundAmount,
            taxRate: 0,
            interState: host.invoice.isInterState,
          ),
        ],
      );
      final issued = host.workspace.creditNotes.last;
      await issueCreditNote(issued.id);
      final index = host.workspace.payments.indexWhere((item) => item.id == id);
      final current = (await _invoices.getById(host.invoice.id)).workspace.payments[index];
      final next = Payment(
        id: current.id,
        paymentNumber: current.paymentNumber,
        invoiceId: current.invoiceId,
        clientId: current.clientId,
        projectId: current.projectId,
        amount: current.amount,
        paymentDate: current.paymentDate,
        paymentMethod: current.paymentMethod,
        referenceNumber: current.referenceNumber,
        status: ClientPaymentStatus.refunded,
        notes: reason,
        processedBy: current.processedBy,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      final refreshed = await _invoices.getById(host.invoice.id);
      refreshed.workspace.payments[index] = next;
      await _persistPaymentStatus(refreshed);
      await _audit.log(userId: _actorId(), action: 'payment_refunded', metadata: {'id': id, 'amount': refundAmount});
      return next;
    });
  }

  @override
  Future<AppResult<Uint8List>> generateReceipt(String paymentId) {
    return AppwriteService.guard(() async {
      final host = await _invoices.findPaymentHost(paymentId);
      if (host == null) throw AppwriteException('Payment not found', 404);
      final payment = host.workspace.payments.firstWhere((item) => item.id == paymentId);
      return _pdf.generateReceipt(host.invoice, payment);
    });
  }

  @override
  Future<AppResult<void>> shareReceipt(String paymentId) {
    return AppwriteService.guard(() async {
      final bytes = await generateReceipt(paymentId);
      final data = bytes.dataOrNull;
      if (data == null) throw AppwriteException('Could not build receipt', 500);
      final host = await _invoices.findPaymentHost(paymentId);
      await _pdf.shareBytes(data, '${host?.workspace.payments.firstWhere((item) => item.id == paymentId).paymentNumber ?? 'receipt'}.pdf');
    });
  }

  @override
  Future<AppResult<List<CreditNote>>> getCreditNotes({String? invoiceId, String? clientId, CreditNoteStatus? status}) {
    return AppwriteService.guard(() async {
      final rows = await _invoices.list(clientId: clientId);
      return [
        for (final row in rows)
          if (invoiceId == null || row.invoice.id == invoiceId)
            for (final note in row.workspace.creditNotes)
              if (status == null || note.status == status) note,
      ];
    });
  }

  @override
  Future<AppResult<CreditNote>> createCreditNote({
    required String invoiceId,
    required String reason,
    required List<InvoiceItem> items,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _invoices.getById(invoiceId);
      final finance = await _finance.ensure();
      final priced = [
        for (final item in items)
          InvoiceItem.priced(
            description: item.description,
            hsnSac: item.hsnSac,
            quantity: item.quantity,
            unit: item.unit,
            rate: item.rate,
            taxRate: item.taxRate,
            interState: snap.invoice.isInterState,
          ),
      ];
      final totals = invoiceTotalsFromLines([
        for (final item in priced)
          GstLineTotals(
            taxableValue: item.taxableValue,
            cgst: item.cgst,
            sgst: item.sgst,
            igst: item.igst,
            cess: item.cess,
            total: item.total,
          ),
      ]);
      final now = DateTime.now().toUtc();
      final note = CreditNote(
        id: ID.unique(),
        creditNoteNumber: await _nextNumber(finance.settings.creditNotePrefix, now, AppwriteService.generateCreditNoteNumberFn),
        invoiceId: invoiceId,
        clientId: snap.invoice.clientId,
        creditNoteDate: now,
        reason: reason,
        items: priced,
        subtotal: totals.subtotal,
        totalCgst: totals.totalCgst,
        totalSgst: totals.totalSgst,
        totalIgst: totals.totalIgst,
        grandTotal: totals.grandTotal,
        status: CreditNoteStatus.draft,
        createdBy: _actorId(),
        createdAt: now,
        updatedAt: now,
      );
      snap.workspace.creditNotes.add(note);
      await _invoices.saveWorkspace(invoiceId, snap.workspace, permissions: invoiceRowPermissions(snap.invoice.clientId));
      await _audit.log(userId: _actorId(), action: 'credit_note_created', metadata: {'id': note.id, 'invoiceId': invoiceId});
      return note;
    });
  }

  @override
  Future<AppResult<CreditNote>> issueCreditNote(String id) {
    return AppwriteService.guard(() async {
      final host = await _invoices.findCreditHost(id);
      if (host == null) throw AppwriteException('Credit note not found', 404);
      final index = host.workspace.creditNotes.indexWhere((item) => item.id == id);
      final current = host.workspace.creditNotes[index];
      final next = CreditNote(
        id: current.id,
        creditNoteNumber: current.creditNoteNumber,
        invoiceId: current.invoiceId,
        clientId: current.clientId,
        creditNoteDate: current.creditNoteDate,
        reason: current.reason,
        items: current.items,
        subtotal: current.subtotal,
        totalCgst: current.totalCgst,
        totalSgst: current.totalSgst,
        totalIgst: current.totalIgst,
        grandTotal: current.grandTotal,
        status: CreditNoteStatus.issued,
        createdBy: current.createdBy,
        issuedAt: DateTime.now().toUtc(),
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.creditNotes[index] = next;
      await _persistPaymentStatus(host);
      await _appendLedger(
        accountType: AccountType.client,
        accountId: host.invoice.clientId,
        description: 'Credit note ${next.creditNoteNumber}',
        creditAmount: next.grandTotal,
        referenceType: 'credit_note',
        referenceId: id,
      );
      await _audit.log(userId: _actorId(), action: 'credit_note_issued', metadata: {'id': id});
      await AppNotifications.instance.showImmediate(title: 'Credit note issued', body: next.creditNoteNumber);
      return next;
    });
  }

  @override
  Future<AppResult<CreditNote>> applyCreditNote(String id) {
    return AppwriteService.guard(() async {
      final host = await _invoices.findCreditHost(id);
      if (host == null) throw AppwriteException('Credit note not found', 404);
      final index = host.workspace.creditNotes.indexWhere((item) => item.id == id);
      final current = host.workspace.creditNotes[index];
      final next = CreditNote(
        id: current.id,
        creditNoteNumber: current.creditNoteNumber,
        invoiceId: current.invoiceId,
        clientId: current.clientId,
        creditNoteDate: current.creditNoteDate,
        reason: current.reason,
        items: current.items,
        subtotal: current.subtotal,
        totalCgst: current.totalCgst,
        totalSgst: current.totalSgst,
        totalIgst: current.totalIgst,
        grandTotal: current.grandTotal,
        status: CreditNoteStatus.applied,
        createdBy: current.createdBy,
        issuedAt: current.issuedAt,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.creditNotes[index] = next;
      await _invoices.saveWorkspace(host.invoice.id, host.workspace, permissions: invoiceRowPermissions(host.invoice.clientId));
      await _audit.log(userId: _actorId(), action: 'credit_note_applied', metadata: {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<CreditNote>> voidCreditNote(String id) {
    return AppwriteService.guard(() async {
      final host = await _invoices.findCreditHost(id);
      if (host == null) throw AppwriteException('Credit note not found', 404);
      final index = host.workspace.creditNotes.indexWhere((item) => item.id == id);
      final current = host.workspace.creditNotes[index];
      final next = CreditNote(
        id: current.id,
        creditNoteNumber: current.creditNoteNumber,
        invoiceId: current.invoiceId,
        clientId: current.clientId,
        creditNoteDate: current.creditNoteDate,
        reason: current.reason,
        items: current.items,
        subtotal: current.subtotal,
        totalCgst: current.totalCgst,
        totalSgst: current.totalSgst,
        totalIgst: current.totalIgst,
        grandTotal: current.grandTotal,
        status: CreditNoteStatus.voided,
        createdBy: current.createdBy,
        issuedAt: current.issuedAt,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.creditNotes[index] = next;
      await _persistPaymentStatus(host);
      if (current.status == CreditNoteStatus.issued || current.status == CreditNoteStatus.applied) {
        await _appendLedger(
          accountType: AccountType.client,
          accountId: host.invoice.clientId,
          description: 'Void credit note ${current.creditNoteNumber}',
          debitAmount: current.grandTotal,
          referenceType: 'credit_note',
          referenceId: id,
        );
      }
      await _audit.log(userId: _actorId(), action: 'credit_note_voided', metadata: {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<List<DebitNote>>> getDebitNotes({String? invoiceId, String? clientId, DebitNoteStatus? status}) {
    return AppwriteService.guard(() async {
      final rows = await _invoices.list(clientId: clientId);
      return [
        for (final row in rows)
          if (invoiceId == null || row.invoice.id == invoiceId)
            for (final note in row.workspace.debitNotes)
              if (status == null || note.status == status) note,
      ];
    });
  }

  @override
  Future<AppResult<DebitNote>> createDebitNote({
    required String invoiceId,
    required String reason,
    required List<InvoiceItem> items,
  }) {
    return AppwriteService.guard(() async {
      final snap = await _invoices.getById(invoiceId);
      final finance = await _finance.ensure();
      final priced = [
        for (final item in items)
          InvoiceItem.priced(
            description: item.description,
            hsnSac: item.hsnSac,
            quantity: item.quantity,
            unit: item.unit,
            rate: item.rate,
            taxRate: item.taxRate,
            interState: snap.invoice.isInterState,
          ),
      ];
      final totals = invoiceTotalsFromLines([
        for (final item in priced)
          GstLineTotals(
            taxableValue: item.taxableValue,
            cgst: item.cgst,
            sgst: item.sgst,
            igst: item.igst,
            cess: item.cess,
            total: item.total,
          ),
      ]);
      final now = DateTime.now().toUtc();
      final note = DebitNote(
        id: ID.unique(),
        debitNoteNumber: await _nextNumber(finance.settings.debitNotePrefix, now, AppwriteService.generateDebitNoteNumberFn),
        invoiceId: invoiceId,
        clientId: snap.invoice.clientId,
        debitNoteDate: now,
        reason: reason,
        items: priced,
        subtotal: totals.subtotal,
        totalCgst: totals.totalCgst,
        totalSgst: totals.totalSgst,
        totalIgst: totals.totalIgst,
        grandTotal: totals.grandTotal,
        status: DebitNoteStatus.draft,
        createdBy: _actorId(),
        createdAt: now,
        updatedAt: now,
      );
      snap.workspace.debitNotes.add(note);
      await _invoices.saveWorkspace(invoiceId, snap.workspace, permissions: invoiceRowPermissions(snap.invoice.clientId));
      await _audit.log(userId: _actorId(), action: 'debit_note_created', metadata: {'id': note.id});
      return note;
    });
  }

  @override
  Future<AppResult<DebitNote>> issueDebitNote(String id) {
    return AppwriteService.guard(() async {
      final host = await _invoices.findDebitHost(id);
      if (host == null) throw AppwriteException('Debit note not found', 404);
      final index = host.workspace.debitNotes.indexWhere((item) => item.id == id);
      final current = host.workspace.debitNotes[index];
      final next = DebitNote(
        id: current.id,
        debitNoteNumber: current.debitNoteNumber,
        invoiceId: current.invoiceId,
        clientId: current.clientId,
        debitNoteDate: current.debitNoteDate,
        reason: current.reason,
        items: current.items,
        subtotal: current.subtotal,
        totalCgst: current.totalCgst,
        totalSgst: current.totalSgst,
        totalIgst: current.totalIgst,
        grandTotal: current.grandTotal,
        status: DebitNoteStatus.issued,
        createdBy: current.createdBy,
        issuedAt: DateTime.now().toUtc(),
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.debitNotes[index] = next;
      await _persistPaymentStatus(host);
      await _appendLedger(
        accountType: AccountType.client,
        accountId: host.invoice.clientId,
        description: 'Debit note ${next.debitNoteNumber}',
        debitAmount: next.grandTotal,
        referenceType: 'debit_note',
        referenceId: id,
      );
      await _audit.log(userId: _actorId(), action: 'debit_note_issued', metadata: {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<DebitNote>> applyDebitNote(String id) {
    return AppwriteService.guard(() async {
      final host = await _invoices.findDebitHost(id);
      if (host == null) throw AppwriteException('Debit note not found', 404);
      final index = host.workspace.debitNotes.indexWhere((item) => item.id == id);
      final current = host.workspace.debitNotes[index];
      final next = DebitNote(
        id: current.id,
        debitNoteNumber: current.debitNoteNumber,
        invoiceId: current.invoiceId,
        clientId: current.clientId,
        debitNoteDate: current.debitNoteDate,
        reason: current.reason,
        items: current.items,
        subtotal: current.subtotal,
        totalCgst: current.totalCgst,
        totalSgst: current.totalSgst,
        totalIgst: current.totalIgst,
        grandTotal: current.grandTotal,
        status: DebitNoteStatus.applied,
        createdBy: current.createdBy,
        issuedAt: current.issuedAt,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.debitNotes[index] = next;
      await _invoices.saveWorkspace(host.invoice.id, host.workspace, permissions: invoiceRowPermissions(host.invoice.clientId));
      await _audit.log(userId: _actorId(), action: 'debit_note_applied', metadata: {'id': id});
      return next;
    });
  }

  @override
  Future<AppResult<DebitNote>> voidDebitNote(String id) {
    return AppwriteService.guard(() async {
      final host = await _invoices.findDebitHost(id);
      if (host == null) throw AppwriteException('Debit note not found', 404);
      final index = host.workspace.debitNotes.indexWhere((item) => item.id == id);
      final current = host.workspace.debitNotes[index];
      final next = DebitNote(
        id: current.id,
        debitNoteNumber: current.debitNoteNumber,
        invoiceId: current.invoiceId,
        clientId: current.clientId,
        debitNoteDate: current.debitNoteDate,
        reason: current.reason,
        items: current.items,
        subtotal: current.subtotal,
        totalCgst: current.totalCgst,
        totalSgst: current.totalSgst,
        totalIgst: current.totalIgst,
        grandTotal: current.grandTotal,
        status: DebitNoteStatus.voided,
        createdBy: current.createdBy,
        issuedAt: current.issuedAt,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      host.workspace.debitNotes[index] = next;
      await _persistPaymentStatus(host);
      await _audit.log(userId: _actorId(), action: 'debit_note_voided', metadata: {'id': id});
      return next;
    });
  }

  Future<String> _nextNumber(String prefix, DateTime date, String functionId) async {
    if (functionId.isNotEmpty) {
      try {
        final execution = await _functions.createExecution(functionId: functionId);
        final match = RegExp('$prefix/\\d{4}-\\d{2}/\\d+').firstMatch(execution.responseBody);
        if (match != null) return match.group(0)!;
      } catch (_) {}
    }
    final finance = await _finance.ensure();
    final fy = financialYearLabel(date, startMonth: finance.settings.financialYearStart);
    _assertFyOpen(finance.settings, date);
    final key = '$prefix:$fy';
    final next = (finance.workspace.series[key] ?? 0) + 1;
    finance.workspace.series[key] = next;
    await _finance.save(finance.workspace);
    return formatSeriesNumber(prefix, fy, next);
  }

  Future<void> _appendLedger({
    required AccountType accountType,
    String? accountId,
    required String description,
    double debitAmount = 0,
    double creditAmount = 0,
    String? referenceType,
    String? referenceId,
  }) async {
    final finance = await _finance.ensure();
    final now = DateTime.now().toUtc();
    final fy = financialYearLabel(now, startMonth: finance.settings.financialYearStart);
    final matching = finance.workspace.ledger.where((item) => item.accountType == accountType && item.accountId == accountId);
    final last = matching.isEmpty ? 0.0 : matching.last.balance;
    final key = 'LED:$fy';
    final next = (finance.workspace.series[key] ?? 0) + 1;
    finance.workspace.series[key] = next;
    finance.workspace.ledger.add(
      LedgerEntry(
        id: ID.unique(),
        entryNumber: formatSeriesNumber('LED', fy, next),
        entryDate: now,
        accountType: accountType,
        accountId: accountId,
        description: description,
        debitAmount: debitAmount,
        creditAmount: creditAmount,
        balance: last + debitAmount - creditAmount,
        referenceType: referenceType,
        referenceId: referenceId,
        financialYear: fy,
        createdAt: now,
      ),
    );
    await _finance.save(finance.workspace);
    await _audit.log(userId: _actorId(), action: 'ledger_entry_created', metadata: {'referenceType': ?referenceType, 'referenceId': ?referenceId});
  }

  void _assertFyOpen(GSTSettings settings, DateTime date) {
    final fy = financialYearLabel(date, startMonth: settings.financialYearStart);
    if (settings.fyLockedYears.contains(fy)) {
      throw AppwriteException('Financial year $fy is closed', 400);
    }
  }

  bool _inRange(DateTime value, DateTime? from, DateTime? to) {
    if (from != null && value.isBefore(from)) return false;
    if (to != null && value.isAfter(to)) return false;
    return true;
  }
}

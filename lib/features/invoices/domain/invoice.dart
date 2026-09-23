import '../../gst/domain/gst_math.dart';
import '../../vendors/domain/line_items.dart';

enum InvoiceStatus {
  draft('draft', 'Draft'),
  issued('issued', 'Issued'),
  partiallyPaid('partially_paid', 'Partially paid'),
  paid('paid', 'Paid'),
  overdue('overdue', 'Overdue'),
  cancelled('cancelled', 'Cancelled'),
  voided('void', 'Void');

  const InvoiceStatus(this.value, this.label);
  final String value;
  final String label;

  static InvoiceStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => InvoiceStatus.draft,
      );

  String toAppwriteString() => value;
}

class InvoiceItem {
  const InvoiceItem({
    required this.description,
    required this.hsnSac,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.taxableValue,
    required this.taxRate,
    required this.cgst,
    required this.sgst,
    required this.igst,
    this.cess = 0,
    required this.total,
  });

  final String description;
  final String hsnSac;
  final double quantity;
  final String unit;
  final double rate;
  final double taxableValue;
  final double taxRate;
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;
  final double total;

  factory InvoiceItem.priced({
    required String description,
    required String hsnSac,
    required double quantity,
    required String unit,
    required double rate,
    required double taxRate,
    double cessRate = 0,
    required bool interState,
  }) {
    final line = calculateGstLine(
      quantity: quantity,
      rate: rate,
      taxRate: taxRate,
      cessRate: cessRate,
      interState: interState,
    );
    return InvoiceItem(
      description: description,
      hsnSac: hsnSac,
      quantity: quantity,
      unit: unit,
      rate: rate,
      taxableValue: line.taxableValue,
      taxRate: taxRate,
      cgst: line.cgst,
      sgst: line.sgst,
      igst: line.igst,
      cess: line.cess,
      total: line.total,
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'hsnSac': hsnSac,
        'quantity': quantity,
        'unit': unit,
        'rate': rate,
        'taxableValue': taxableValue,
        'taxRate': taxRate,
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'cess': cess,
        'total': total,
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> data) => InvoiceItem(
        description: data['description']?.toString() ?? '',
        hsnSac: data['hsnSac']?.toString() ?? '',
        quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
        unit: data['unit']?.toString() ?? 'nos',
        rate: (data['rate'] as num?)?.toDouble() ?? 0,
        taxableValue: (data['taxableValue'] as num?)?.toDouble() ?? 0,
        taxRate: (data['taxRate'] as num?)?.toDouble() ?? 0,
        cgst: (data['cgst'] as num?)?.toDouble() ?? 0,
        sgst: (data['sgst'] as num?)?.toDouble() ?? 0,
        igst: (data['igst'] as num?)?.toDouble() ?? 0,
        cess: (data['cess'] as num?)?.toDouble() ?? 0,
        total: (data['total'] as num?)?.toDouble() ?? 0,
      );
}

List<InvoiceItem> invoiceItemsFrom(Object? raw) {
  final decoded = decodeJsonList(raw);
  if (decoded is! List) return const [];
  return [
    for (final item in decoded)
      if (item is Map) InvoiceItem.fromJson(Map<String, dynamic>.from(item)),
  ];
}

class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.clientId,
    this.projectId,
    this.quotationId,
    required this.invoiceDate,
    required this.dueDate,
    required this.placeOfSupply,
    required this.placeOfSupplyCode,
    required this.isInterState,
    required this.items,
    required this.subtotal,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    this.totalCess = 0,
    this.roundOff = 0,
    required this.grandTotal,
    required this.amountInWords,
    required this.status,
    this.paidAmount = 0,
    this.balanceAmount,
    this.notes,
    this.termsAndConditions,
    this.bankDetails,
    this.eInvoiceIrn,
    this.eInvoiceQrCode,
    required this.createdBy,
    this.issuedAt,
    this.cancelledAt,
    this.cancelReason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String invoiceNumber;
  final String clientId;
  final String? projectId;
  final String? quotationId;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final String placeOfSupply;
  final String placeOfSupplyCode;
  final bool isInterState;
  final List<InvoiceItem> items;
  final double subtotal;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;
  final double roundOff;
  final double grandTotal;
  final String amountInWords;
  final InvoiceStatus status;
  final double paidAmount;
  final double? balanceAmount;
  final String? notes;
  final String? termsAndConditions;
  final String? bankDetails;
  final String? eInvoiceIrn;
  final String? eInvoiceQrCode;
  final String createdBy;
  final DateTime? issuedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get outstanding => balanceAmount ?? (grandTotal - paidAmount);

  InvoiceStatus get displayStatus {
    if (status == InvoiceStatus.issued && dueDate.isBefore(DateTime.now())) {
      return InvoiceStatus.overdue;
    }
    return status;
  }

  factory Invoice.fromRow(String id, Map<String, dynamic> data) {
    return Invoice(
      id: id,
      invoiceNumber: data['invoiceNumber']?.toString() ?? '',
      clientId: data['clientId']?.toString() ?? '',
      projectId: data['projectId']?.toString(),
      quotationId: data['quotationId']?.toString(),
      invoiceDate: DateTime.tryParse(data['invoiceDate']?.toString() ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(data['dueDate']?.toString() ?? '') ?? DateTime.now(),
      placeOfSupply: data['placeOfSupply']?.toString() ?? '',
      placeOfSupplyCode: data['placeOfSupplyCode']?.toString() ?? '',
      isInterState: data['isInterState'] == true,
      items: invoiceItemsFrom(data['itemsJson'] ?? data['items']),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      totalCgst: (data['totalCgst'] as num?)?.toDouble() ?? 0,
      totalSgst: (data['totalSgst'] as num?)?.toDouble() ?? 0,
      totalIgst: (data['totalIgst'] as num?)?.toDouble() ?? 0,
      totalCess: (data['totalCess'] as num?)?.toDouble() ?? 0,
      roundOff: (data['roundOff'] as num?)?.toDouble() ?? 0,
      grandTotal: (data['grandTotal'] as num?)?.toDouble() ?? 0,
      amountInWords: data['amountInWords']?.toString() ?? '',
      status: InvoiceStatus.fromString(data['status']?.toString() ?? 'draft'),
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      balanceAmount: (data['balanceAmount'] as num?)?.toDouble(),
      notes: data['notes']?.toString(),
      termsAndConditions: data['termsAndConditions']?.toString(),
      bankDetails: data['bankDetails']?.toString(),
      eInvoiceIrn: data['eInvoiceIrn']?.toString(),
      eInvoiceQrCode: data['eInvoiceQrCode']?.toString(),
      createdBy: data['createdBy']?.toString() ?? '',
      issuedAt: DateTime.tryParse(data['issuedAt']?.toString() ?? ''),
      cancelledAt: DateTime.tryParse(data['cancelledAt']?.toString() ?? ''),
      cancelReason: data['cancelReason']?.toString(),
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }
}

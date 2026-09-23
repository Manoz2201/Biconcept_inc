import '../../gst/domain/gst_math.dart';
import '../../invoices/domain/invoice.dart';
import '../../tds/domain/tds_deduction.dart';
import 'itc_ledger_entry.dart';
import 'reconciliation_result.dart';

const kGstTdsThreshold = 250000.0;
const kEwayBillThreshold = 50000.0;
const kEinvoiceTurnoverThreshold = 50000000.0;
const kGstr9cTurnoverThreshold = 50000000.0;
const kIrnCancelHours = 24;
const kEwayBillCancelHours = 24;
const kEwayBillMaxAgeDays = 180;
const kRule37Days = 180;

String gstPeriodFromDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}';
}

String gstQuarterFromDate(DateTime date) {
  final month = date.toLocal().month;
  if (month >= 4 && month <= 6) return 'Q1';
  if (month >= 7 && month <= 9) return 'Q2';
  if (month >= 10 && month <= 12) return 'Q3';
  return 'Q4';
}

DateTime financialYearStart(String financialYear, {int startMonth = 4}) {
  final startYear = int.tryParse(financialYear.split('-').first) ?? DateTime.now().year;
  return DateTime(startYear, startMonth, 1);
}

DateTime financialYearEnd(String financialYear, {int startMonth = 4}) {
  final start = financialYearStart(financialYear, startMonth: startMonth);
  return DateTime(start.year + 1, startMonth, 1).subtract(const Duration(days: 1));
}

bool dateInPeriod(DateTime date, String period) {
  return gstPeriodFromDate(date) == period;
}

bool dateInFinancialYear(DateTime date, String financialYear, {int startMonth = 4}) {
  return financialYearLabel(date, startMonth: startMonth) == financialYear;
}

double money(double value) => (value * 100).roundToDouble() / 100;

TdsRateResult tdsRateFor({
  required TdsSection section,
  required TdsDeducteeType deducteeType,
  Tds194JKind? kind194j,
  Tds194IKind? kind194i,
}) {
  switch (section) {
    case TdsSection.section194C:
      final individual = deducteeType == TdsDeducteeType.individual || deducteeType == TdsDeducteeType.huf;
      return TdsRateResult(rate: individual ? 1 : 2, singleLimit: 30000, annualLimit: 100000);
    case TdsSection.section194J:
      return TdsRateResult(rate: kind194j == Tds194JKind.technical ? 2 : 10, annualLimit: 50000);
    case TdsSection.section194I:
      return TdsRateResult(rate: kind194i == Tds194IKind.plantMachinery ? 2 : 10, annualLimit: 240000);
    case TdsSection.section194A:
      return const TdsRateResult(rate: 10, annualLimit: 10000);
    case TdsSection.section194H:
      return const TdsRateResult(rate: 2, annualLimit: 20000);
    case TdsSection.section194O:
      return const TdsRateResult(rate: 0.1, annualLimit: 500000);
  }
}

class TdsRateResult {
  const TdsRateResult({required this.rate, this.singleLimit, this.annualLimit});

  final double rate;
  final double? singleLimit;
  final double? annualLimit;
}

class TdsComputation {
  const TdsComputation({
    required this.rate,
    required this.tdsAmount,
    required this.netPayable,
    required this.thresholdLimit,
    required this.thresholdCrossed,
  });

  final double rate;
  final double tdsAmount;
  final double netPayable;
  final double? thresholdLimit;
  final bool thresholdCrossed;
}

TdsComputation computeTds({
  required TdsSection section,
  required TdsDeducteeType deducteeType,
  required double grossAmount,
  double annualGross = 0,
  Tds194JKind? kind194j,
  Tds194IKind? kind194i,
}) {
  final rule = tdsRateFor(section: section, deducteeType: deducteeType, kind194j: kind194j, kind194i: kind194i);
  final crossedSingle = rule.singleLimit != null && grossAmount >= rule.singleLimit!;
  final crossedAnnual = rule.annualLimit != null && (annualGross + grossAmount) >= rule.annualLimit!;
  final crossed = crossedSingle || crossedAnnual;
  final tdsAmount = crossed ? money(grossAmount * rule.rate / 100) : 0.0;
  return TdsComputation(
    rate: rule.rate,
    tdsAmount: tdsAmount,
    netPayable: money(grossAmount - tdsAmount),
    thresholdLimit: rule.singleLimit ?? rule.annualLimit,
    thresholdCrossed: crossed,
  );
}

class GstTdsComputation {
  const GstTdsComputation({
    required this.applicable,
    required this.isInterState,
    required this.cgstTds,
    required this.sgstTds,
    required this.igstTds,
    required this.totalTds,
    required this.tdsRate,
  });

  final bool applicable;
  final bool isInterState;
  final double cgstTds;
  final double sgstTds;
  final double igstTds;
  final double totalTds;
  final double tdsRate;
}

GstTdsComputation computeGstTds({
  required double taxableValue,
  required double contractValue,
  required bool interState,
}) {
  if (contractValue <= kGstTdsThreshold) {
    return GstTdsComputation(
      applicable: false,
      isInterState: interState,
      cgstTds: 0,
      sgstTds: 0,
      igstTds: 0,
      totalTds: 0,
      tdsRate: 2,
    );
  }
  final cgst = interState ? 0.0 : money(taxableValue * 0.01);
  final sgst = interState ? 0.0 : money(taxableValue * 0.01);
  final igst = interState ? money(taxableValue * 0.02) : 0.0;
  return GstTdsComputation(
    applicable: true,
    isInterState: interState,
    cgstTds: cgst,
    sgstTds: sgst,
    igstTds: igst,
    totalTds: money(cgst + sgst + igst),
    tdsRate: 2,
  );
}

int ewayBillValidityDays({required int distanceKm, required bool overDimensional}) {
  if (distanceKm <= 0) return 1;
  final perDay = overDimensional ? 20 : 200;
  final days = (distanceKm / perDay).ceil();
  return days < 1 ? 1 : days;
}

DateTime ewayBillValidUntil(DateTime from, {required int distanceKm, required bool overDimensional}) {
  return from.add(Duration(days: ewayBillValidityDays(distanceKm: distanceKm, overDimensional: overDimensional)));
}

bool ewayBillRequired(double consignmentValue) => consignmentValue > kEwayBillThreshold;

bool ewayBillGoodsTooOld(DateTime invoiceDate, [DateTime? now]) {
  final today = now ?? DateTime.now();
  return today.difference(invoiceDate).inDays > kEwayBillMaxAgeDays;
}

bool withinHours(DateTime from, int hours, [DateTime? now]) {
  return (now ?? DateTime.now()).difference(from).inHours < hours;
}

class Gstr2bLine {
  const Gstr2bLine({
    required this.supplierGstin,
    required this.supplierName,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
    this.cess = 0,
  });

  final String supplierGstin;
  final String supplierName;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;

  double get totalTax => money(cgst + sgst + igst + cess);
}

class PurchaseRegisterLine {
  const PurchaseRegisterLine({
    required this.billId,
    required this.supplierGstin,
    required this.supplierName,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.taxableValue,
    required this.taxAmount,
  });

  final String billId;
  final String supplierGstin;
  final String supplierName;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double taxableValue;
  final double taxAmount;
}

String matchKey(String gstin, String invoiceNumber) =>
    '${gstin.trim().toUpperCase()}_${invoiceNumber.trim().toUpperCase()}';

List<Gstr2bLine> parseGstr2bJson(Object? raw) {
  if (raw is! Map) {
    if (raw is List) {
      return [
        for (final item in raw)
          if (item is Map) _lineFromMap(Map<String, dynamic>.from(item)),
      ];
    }
    return const [];
  }
  final data = Map<String, dynamic>.from(raw);
  final lines = <Gstr2bLine>[];
  void addB2b(Object? block) {
    if (block is! List) return;
    for (final supplier in block) {
      if (supplier is! Map) continue;
      final gstin = supplier['ctin']?.toString() ?? supplier['supplierGstin']?.toString() ?? '';
      final name = supplier['trdnm']?.toString() ?? supplier['supplierName']?.toString() ?? gstin;
      final invoices = supplier['inv'];
      if (invoices is! List) continue;
      for (final invoice in invoices) {
        if (invoice is! Map) continue;
        var taxable = 0.0;
        var cgst = 0.0;
        var sgst = 0.0;
        var igst = 0.0;
        var cess = 0.0;
        final items = invoice['itms'];
        if (items is List) {
          for (final item in items) {
            if (item is! Map) continue;
            final det = item['itm_det'] is Map ? Map<String, dynamic>.from(item['itm_det'] as Map) : item;
            taxable += (det['txval'] as num?)?.toDouble() ?? 0;
            cgst += (det['camt'] as num?)?.toDouble() ?? 0;
            sgst += (det['samt'] as num?)?.toDouble() ?? 0;
            igst += (det['iamt'] as num?)?.toDouble() ?? 0;
            cess += (det['csamt'] as num?)?.toDouble() ?? (det['cess'] as num?)?.toDouble() ?? 0;
          }
        } else {
          taxable = (invoice['txval'] as num?)?.toDouble() ?? (invoice['taxableValue'] as num?)?.toDouble() ?? 0;
          cgst = (invoice['camt'] as num?)?.toDouble() ?? 0;
          sgst = (invoice['samt'] as num?)?.toDouble() ?? 0;
          igst = (invoice['iamt'] as num?)?.toDouble() ?? 0;
        }
        lines.add(
          Gstr2bLine(
            supplierGstin: gstin,
            supplierName: name,
            invoiceNumber: invoice['inum']?.toString() ?? invoice['invoiceNumber']?.toString() ?? '',
            invoiceDate: _parseGstDate(invoice['idt'] ?? invoice['invoiceDate']),
            taxableValue: money(taxable),
            cgst: money(cgst),
            sgst: money(sgst),
            igst: money(igst),
            cess: money(cess),
          ),
        );
      }
    }
  }

  addB2b(data['b2b']);
  final docdata = data['data'] ?? data['docdata'];
  if (docdata is Map) addB2b(docdata['b2b']);
  if (data['entries'] is List) {
    for (final item in data['entries'] as List) {
      if (item is Map) lines.add(_lineFromMap(Map<String, dynamic>.from(item)));
    }
  }
  return lines;
}

Gstr2bLine _lineFromMap(Map<String, dynamic> data) => Gstr2bLine(
      supplierGstin: data['supplierGstin']?.toString() ?? data['ctin']?.toString() ?? '',
      supplierName: data['supplierName']?.toString() ?? '',
      invoiceNumber: data['invoiceNumber']?.toString() ?? data['inum']?.toString() ?? '',
      invoiceDate: _parseGstDate(data['invoiceDate'] ?? data['idt']),
      taxableValue: (data['taxableValue'] as num?)?.toDouble() ?? (data['txval'] as num?)?.toDouble() ?? 0,
      cgst: (data['cgst'] as num?)?.toDouble() ?? (data['camt'] as num?)?.toDouble() ?? 0,
      sgst: (data['sgst'] as num?)?.toDouble() ?? (data['samt'] as num?)?.toDouble() ?? 0,
      igst: (data['igst'] as num?)?.toDouble() ?? (data['iamt'] as num?)?.toDouble() ?? 0,
      cess: (data['cess'] as num?)?.toDouble() ?? 0,
    );

DateTime _parseGstDate(Object? raw) {
  final text = raw?.toString() ?? '';
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso;
  final parts = text.split(RegExp(r'[-/]'));
  if (parts.length == 3) {
    final d = int.tryParse(parts[0]) ?? 1;
    final m = int.tryParse(parts[1]) ?? 1;
    final y = int.tryParse(parts[2]) ?? DateTime.now().year;
    if (parts[0].length == 4) return DateTime(d, m, y);
    return DateTime(y, m, d);
  }
  return DateTime.now();
}

class Gstr2bMatchBundle {
  const Gstr2bMatchBundle({
    required this.result,
    required this.entries,
  });

  final ReconciliationResult result;
  final List<ITCLedgerEntry> entries;
}

Gstr2bMatchBundle classifyGstr2bMatches({
  required String financialYear,
  required String period,
  required String importId,
  required List<Gstr2bLine> gstr2b,
  required List<PurchaseRegisterLine> books,
  DateTime? now,
}) {
  final created = now ?? DateTime.now().toUtc();
  final twoB = {for (final line in gstr2b) matchKey(line.supplierGstin, line.invoiceNumber): line};
  final register = {for (final line in books) matchKey(line.supplierGstin, line.invoiceNumber): line};
  final entries = <ITCLedgerEntry>[];
  var exact = 0;
  var suggested = 0;
  var mismatched = 0;
  var missingBooks = 0;
  var missingTwoB = 0;

  ITCLedgerEntry fromTwoB(Gstr2bLine line, MatchStatus status, {String? billId, String? reason}) {
    final tax = line.totalTax;
    return ITCLedgerEntry(
      id: 'itc-${line.supplierGstin}-${line.invoiceNumber}-$period'.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_'),
      financialYear: financialYear,
      period: period,
      gstr2bId: importId,
      supplierGstin: line.supplierGstin,
      supplierName: line.supplierName,
      invoiceNumber: line.invoiceNumber,
      invoiceDate: line.invoiceDate,
      taxableValue: line.taxableValue,
      cgstAmount: line.cgst,
      sgstAmount: line.sgst,
      igstAmount: line.igst,
      cessAmount: line.cess,
      totalTax: tax,
      itcEligible: tax,
      itcStatus: status == MatchStatus.exactMatch || status == MatchStatus.matched ? ITCStatus.eligible : ITCStatus.pending,
      matchedBillId: billId,
      matchStatus: status,
      mismatchReason: reason,
      createdAt: created,
      updatedAt: created,
    );
  }

  for (final entry in twoB.entries) {
    final book = register[entry.key];
    if (book == null) {
      missingBooks++;
      entries.add(fromTwoB(entry.value, MatchStatus.missingInBooks, reason: 'Present in GSTR-2B, missing in books'));
      continue;
    }
    final diff = (entry.value.taxableValue - book.taxableValue).abs();
    if (diff < 1) {
      exact++;
      entries.add(fromTwoB(entry.value, MatchStatus.exactMatch, billId: book.billId));
    } else if (diff < 100) {
      suggested++;
      entries.add(fromTwoB(entry.value, MatchStatus.suggestedMatch, billId: book.billId, reason: 'Taxable difference ${money(diff)}'));
    } else {
      mismatched++;
      entries.add(fromTwoB(entry.value, MatchStatus.mismatched, billId: book.billId, reason: 'Taxable difference ${money(diff)}'));
    }
  }
  for (final entry in register.entries) {
    if (twoB.containsKey(entry.key)) continue;
    missingTwoB++;
    final bill = entry.value;
    entries.add(
      ITCLedgerEntry(
        id: 'itc-books-${bill.billId}',
        financialYear: financialYear,
        period: period,
        gstr2bId: importId,
        supplierGstin: bill.supplierGstin,
        supplierName: bill.supplierName,
        invoiceNumber: bill.invoiceNumber,
        invoiceDate: bill.invoiceDate,
        taxableValue: bill.taxableValue,
        cgstAmount: 0,
        sgstAmount: 0,
        igstAmount: 0,
        totalTax: bill.taxAmount,
        itcEligible: 0,
        itcStatus: ITCStatus.pending,
        matchedBillId: bill.billId,
        matchStatus: MatchStatus.missingIn2b,
        mismatchReason: 'Present in books, missing in GSTR-2B',
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  return Gstr2bMatchBundle(
    result: ReconciliationResult(
      exactMatches: exact,
      suggestedMatches: suggested,
      mismatched: mismatched,
      missingIn2b: missingTwoB,
      missingInBooks: missingBooks,
      totalProcessed: gstr2b.length + missingTwoB,
    ),
    entries: entries,
  );
}

Map<String, Object?> buildIrpPayload({
  required Invoice invoice,
  required String sellerGstin,
  required String sellerName,
  required String sellerAddress,
  required String sellerCity,
  required String sellerPincode,
  required String sellerStateCode,
  required String buyerGstin,
  required String buyerName,
  required String buyerAddress,
  required String buyerCity,
  required String buyerPincode,
  required String buyerStateCode,
}) {
  String ddMmYyyy(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  return {
    'Version': '1.1',
    'TranDtls': {'TaxSch': 'GST', 'SupTyp': 'B2B', 'RegRev': 'N'},
    'DocDtls': {'Typ': 'INV', 'No': invoice.invoiceNumber, 'Dt': ddMmYyyy(invoice.invoiceDate)},
    'SellerDtls': {
      'Gstin': sellerGstin,
      'LglNm': sellerName,
      'TrdNm': sellerName,
      'Addr1': sellerAddress,
      'Loc': sellerCity,
      'Pin': int.tryParse(sellerPincode) ?? 0,
      'Stcd': sellerStateCode,
    },
    'BuyerDtls': {
      'Gstin': buyerGstin,
      'LglNm': buyerName,
      'TrdNm': buyerName,
      'Pos': invoice.placeOfSupplyCode,
      'Addr1': buyerAddress,
      'Loc': buyerCity,
      'Pin': int.tryParse(buyerPincode) ?? 0,
      'Stcd': buyerStateCode,
    },
    'ItemList': [
      for (var i = 0; i < invoice.items.length; i++)
        {
          'SlNo': '${i + 1}',
          'PrdDesc': invoice.items[i].description,
          'IsServc': 'Y',
          'HsnCd': invoice.items[i].hsnSac,
          'Qty': invoice.items[i].quantity,
          'Unit': invoice.items[i].unit,
          'UnitPrice': invoice.items[i].rate,
          'TotAmt': invoice.items[i].taxableValue,
          'AssAmt': invoice.items[i].taxableValue,
          'GstRt': invoice.items[i].taxRate,
          'CgstAmt': invoice.items[i].cgst,
          'SgstAmt': invoice.items[i].sgst,
          'IgstAmt': invoice.items[i].igst,
          'CesAmt': invoice.items[i].cess,
          'TotItemVal': invoice.items[i].total,
        },
    ],
    'ValDtls': {
      'AssVal': invoice.subtotal,
      'CgstVal': invoice.totalCgst,
      'SgstVal': invoice.totalSgst,
      'IgstVal': invoice.totalIgst,
      'CesVal': invoice.totalCess,
      'RndOffAmt': invoice.roundOff,
      'TotInvVal': invoice.grandTotal,
    },
  };
}

List<MonthlyPoint> projectSeries({
  required List<MonthlyPoint> history,
  required int months,
  required double monthlyGrowth,
}) {
  if (history.isEmpty) {
    return [
      for (var i = 1; i <= months; i++) MonthlyPoint(period: 'M$i', amount: 0),
    ];
  }
  var last = history.last.amount;
  final start = _parsePeriod(history.last.period) ?? DateTime.now();
  return [
    for (var i = 1; i <= months; i++)
      MonthlyPoint(
        period: gstPeriodFromDate(DateTime(start.year, start.month + i, 1)),
        amount: money(last = last * (1 + monthlyGrowth)),
      ),
  ];
}

DateTime? _parsePeriod(String period) {
  final parts = period.split('-');
  if (parts.length < 2) return null;
  return DateTime(int.tryParse(parts[0]) ?? DateTime.now().year, int.tryParse(parts[1]) ?? 1, 1);
}

class MonthlyPoint {
  const MonthlyPoint({required this.period, required this.amount});

  final String period;
  final double amount;

  Map<String, dynamic> toJson() => {'period': period, 'amount': amount};

  factory MonthlyPoint.fromJson(Map<String, dynamic> data) => MonthlyPoint(
        period: data['period']?.toString() ?? '',
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
      );
}

class ComplianceDue {
  const ComplianceDue({
    required this.date,
    required this.label,
    required this.kind,
  });

  final DateTime date;
  final String label;
  final String kind;
}

List<ComplianceDue> complianceDuesForMonth(DateTime month) {
  final next = DateTime(month.year, month.month + 1, 1);
  return [
    ComplianceDue(date: DateTime(next.year, next.month, 7), label: 'TDS deposit', kind: 'tds'),
    ComplianceDue(date: DateTime(next.year, next.month, 10), label: 'GST TDS / GSTR-7', kind: 'gst_tds'),
    ComplianceDue(date: DateTime(next.year, next.month, 11), label: 'GSTR-1', kind: 'gstr1'),
    ComplianceDue(date: DateTime(next.year, next.month, 20), label: 'GSTR-3B', kind: 'gstr3b'),
    ComplianceDue(date: DateTime(month.year, 12, 31), label: 'GSTR-9', kind: 'gstr9'),
  ];
}

String csvEscape(Iterable<Object?> cells) =>
    cells.map((cell) => '"${cell?.toString().replaceAll('"', '""') ?? ''}"').join(',');

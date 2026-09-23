const kGstStates = {
  '01': 'Jammu and Kashmir',
  '02': 'Himachal Pradesh',
  '03': 'Punjab',
  '04': 'Chandigarh',
  '05': 'Uttarakhand',
  '06': 'Haryana',
  '07': 'Delhi',
  '08': 'Rajasthan',
  '09': 'Uttar Pradesh',
  '10': 'Bihar',
  '11': 'Sikkim',
  '12': 'Arunachal Pradesh',
  '13': 'Nagaland',
  '14': 'Manipur',
  '15': 'Mizoram',
  '16': 'Tripura',
  '17': 'Meghalaya',
  '18': 'Assam',
  '19': 'West Bengal',
  '20': 'Jharkhand',
  '21': 'Odisha',
  '22': 'Chhattisgarh',
  '23': 'Madhya Pradesh',
  '24': 'Gujarat',
  '27': 'Maharashtra',
  '29': 'Karnataka',
  '30': 'Goa',
  '32': 'Kerala',
  '33': 'Tamil Nadu',
  '34': 'Puducherry',
  '36': 'Telangana',
  '37': 'Andhra Pradesh',
};

String gstStateName(String code) => kGstStates[code] ?? code;

String financialYearLabel(DateTime date, {int startMonth = 4}) {
  final startYear = date.month >= startMonth ? date.year : date.year - 1;
  final end = (startYear + 1) % 100;
  return '$startYear-${end.toString().padLeft(2, '0')}';
}

String formatSeriesNumber(String prefix, String financialYear, int sequence) {
  return '$prefix/$financialYear/${sequence.toString().padLeft(4, '0')}';
}

bool isInterStateSupply(String firmStateCode, String placeOfSupplyCode) =>
    firmStateCode.trim() != placeOfSupplyCode.trim();

class GstLineTotals {
  const GstLineTotals({
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
    required this.total,
  });

  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;
  final double total;
}

GstLineTotals calculateGstLine({
  required double quantity,
  required double rate,
  required double taxRate,
  double cessRate = 0,
  required bool interState,
}) {
  final taxableValue = quantity * rate;
  final cgst = interState ? 0.0 : taxableValue * taxRate / 200;
  final sgst = interState ? 0.0 : taxableValue * taxRate / 200;
  final igst = interState ? taxableValue * taxRate / 100 : 0.0;
  final cess = taxableValue * cessRate / 100;
  return GstLineTotals(
    taxableValue: taxableValue,
    cgst: cgst,
    sgst: sgst,
    igst: igst,
    cess: cess,
    total: taxableValue + cgst + sgst + igst + cess,
  );
}

class InvoiceTotals {
  const InvoiceTotals({
    required this.subtotal,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalCess,
    required this.roundOff,
    required this.grandTotal,
  });

  final double subtotal;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;
  final double roundOff;
  final double grandTotal;
}

InvoiceTotals invoiceTotalsFromLines(Iterable<GstLineTotals> lines) {
  final subtotal = lines.fold<double>(0, (sum, line) => sum + line.taxableValue);
  final totalCgst = lines.fold<double>(0, (sum, line) => sum + line.cgst);
  final totalSgst = lines.fold<double>(0, (sum, line) => sum + line.sgst);
  final totalIgst = lines.fold<double>(0, (sum, line) => sum + line.igst);
  final totalCess = lines.fold<double>(0, (sum, line) => sum + line.cess);
  final raw = subtotal + totalCgst + totalSgst + totalIgst + totalCess;
  final rounded = raw.roundToDouble();
  return InvoiceTotals(
    subtotal: subtotal,
    totalCgst: totalCgst,
    totalSgst: totalSgst,
    totalIgst: totalIgst,
    totalCess: totalCess,
    roundOff: rounded - raw,
    grandTotal: rounded,
  );
}

const _ones = [
  '',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
  'Thirteen',
  'Fourteen',
  'Fifteen',
  'Sixteen',
  'Seventeen',
  'Eighteen',
  'Nineteen',
];

const _tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

String _twoDigit(int value) {
  if (value < 20) return _ones[value];
  final ten = _tens[value ~/ 10];
  final one = _ones[value % 10];
  return one.isEmpty ? ten : '$ten $one';
}

String _chunk(int value) {
  if (value == 0) return '';
  if (value < 100) return _twoDigit(value);
  return '${_ones[value ~/ 100]} Hundred${value % 100 == 0 ? '' : ' ${_twoDigit(value % 100)}'}';
}

String amountInIndianWords(double amount) {
  if (amount < 0) return 'Minus ${amountInIndianWords(-amount)}';
  final rupees = amount.floor();
  final paise = ((amount - rupees) * 100).round();
  if (rupees == 0 && paise == 0) return 'Zero Rupees Only';

  final crore = rupees ~/ 10000000;
  final lakh = (rupees % 10000000) ~/ 100000;
  final thousand = (rupees % 100000) ~/ 1000;
  final remainder = rupees % 1000;
  final parts = <String>[
    if (crore > 0) '${_chunk(crore)} Crore',
    if (lakh > 0) '${_chunk(lakh)} Lakh',
    if (thousand > 0) '${_chunk(thousand)} Thousand',
    if (remainder > 0) _chunk(remainder),
  ];
  final rupeeText = parts.isEmpty ? 'Zero Rupees' : '${parts.join(' ')} Rupees';
  if (paise == 0) return '$rupeeText Only';
  return '$rupeeText and ${_twoDigit(paise)} Paise Only';
}

enum AgeingBucket {
  current('current', 'Current'),
  days30('1-30', '1-30 days'),
  days60('31-60', '31-60 days'),
  days90('61-90', '61-90 days'),
  days90Plus('90+', '90+ days');

  const AgeingBucket(this.value, this.label);
  final String value;
  final String label;
}

AgeingBucket ageingBucket(int daysOverdue) {
  if (daysOverdue <= 0) return AgeingBucket.current;
  if (daysOverdue <= 30) return AgeingBucket.days30;
  if (daysOverdue <= 60) return AgeingBucket.days60;
  if (daysOverdue <= 90) return AgeingBucket.days90;
  return AgeingBucket.days90Plus;
}

int daysOverdue(DateTime dueDate, [DateTime? now]) {
  final today = DateTime.fromMillisecondsSinceEpoch(
    (now ?? DateTime.now()).millisecondsSinceEpoch,
    isUtc: true,
  );
  final due = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
  final start = DateTime.utc(today.year, today.month, today.day);
  return start.difference(due).inDays;
}

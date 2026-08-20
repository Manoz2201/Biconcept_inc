String inr(num? value) {
  if (value == null) return '—';
  final digits = value.round().abs().toString();
  final buffer = StringBuffer(value < 0 ? '-₹' : '₹');
  if (digits.length <= 3) {
    buffer.write(digits);
    return buffer.toString();
  }
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  buffer.write(groups.join(','));
  buffer.write(',$last3');
  return buffer.toString();
}

double? parseNumber(String? value) {
  if (value == null) return null;
  final cleaned = value.replaceAll(',', '').trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

String inrCompact(num? value) {
  if (value == null) return '—';
  final abs = value.abs();
  if (abs >= 10000000) {
    return '${value < 0 ? '-' : ''}₹${(abs / 10000000).toStringAsFixed(2)} Cr';
  }
  if (abs >= 100000) {
    return '${value < 0 ? '-' : ''}₹${(abs / 100000).toStringAsFixed(2)} L';
  }
  return inr(value);
}

String formatQty(double? value) {
  if (value == null) return '';
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}

String indianGrouped(num? value, {int? decimals}) {
  if (value == null) return '';
  final negative = value < 0;
  final abs = value.abs();
  final places = decimals ?? (abs == abs.roundToDouble() ? 0 : 2);
  final fixed = abs.toStringAsFixed(places);
  final parts = fixed.split('.');
  final grouped = _groupIndian(parts[0]);
  final fraction = parts.length > 1 && places > 0 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}$grouped$fraction';
}

String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${groups.join(',')},$last3';
}

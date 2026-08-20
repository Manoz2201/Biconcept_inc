/// Parses ISO dates and phrases like "tomorrow", "in 3 days", "next Friday".
DateTime? parseWhen(String raw, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final original = raw.trim();
  if (original.isEmpty) return null;

  final iso = DateTime.tryParse(original);
  if (iso != null) return _atTenIfDateOnly(iso, original);

  final text = original.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final dmy = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(text);
  if (dmy != null) {
    final day = int.parse(dmy.group(1)!);
    final month = int.parse(dmy.group(2)!);
    var year = int.parse(dmy.group(3)!);
    if (year < 100) year += 2000;
    return DateTime(year, month, day, 10);
  }

  if (text == 'today' || text == 'tonight') {
    return DateTime(clock.year, clock.month, clock.day, 10);
  }
  if (text == 'tomorrow') {
    final day = clock.add(const Duration(days: 1));
    return DateTime(day.year, day.month, day.day, 10);
  }
  if (text == 'day after tomorrow' || text == 'the day after tomorrow') {
    final day = clock.add(const Duration(days: 2));
    return DateTime(day.year, day.month, day.day, 10);
  }

  final inAmount = RegExp(r'^(?:in\s+)?(\d+)\s+(day|days|week|weeks)$').firstMatch(text);
  if (inAmount != null) {
    final count = int.parse(inAmount.group(1)!);
    final unit = inAmount.group(2)!;
    final days = unit.startsWith('week') ? count * 7 : count;
    final day = clock.add(Duration(days: days));
    return DateTime(day.year, day.month, day.day, 10);
  }

  final weekday = _weekdayIndex(text.replaceFirst(RegExp(r'^next\s+'), ''));
  if (weekday != null && (text.startsWith('next ') || _weekdayIndex(text) != null)) {
    var delta = (weekday - clock.weekday + 7) % 7;
    if (delta == 0) delta = 7;
    final day = clock.add(Duration(days: delta));
    return DateTime(day.year, day.month, day.day, 10);
  }

  return null;
}

DateTime _atTenIfDateOnly(DateTime value, String raw) {
  final hasTime = raw.contains('T') || RegExp(r'\d{1,2}:\d{2}').hasMatch(raw);
  if (hasTime) return value;
  return DateTime(value.year, value.month, value.day, 10);
}

int? _weekdayIndex(String text) {
  return switch (text) {
    'monday' || 'mon' => DateTime.monday,
    'tuesday' || 'tue' || 'tues' => DateTime.tuesday,
    'wednesday' || 'wed' => DateTime.wednesday,
    'thursday' || 'thu' || 'thurs' => DateTime.thursday,
    'friday' || 'fri' => DateTime.friday,
    'saturday' || 'sat' => DateTime.saturday,
    'sunday' || 'sun' => DateTime.sunday,
    _ => null,
  };
}

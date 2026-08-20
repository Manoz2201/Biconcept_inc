import 'package:biconcept/util/when.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 21, 15, 30); // Friday

  test('parseWhen reads ISO, Indian dates, and relative phrases', () {
    expect(parseWhen('2026-08-25', now: now), DateTime(2026, 8, 25, 10));
    expect(parseWhen('25/08/2026', now: now), DateTime(2026, 8, 25, 10));
    expect(parseWhen('tomorrow', now: now), DateTime(2026, 8, 22, 10));
    expect(parseWhen('in 3 days', now: now), DateTime(2026, 8, 24, 10));
    expect(parseWhen('in 1 week', now: now), DateTime(2026, 8, 28, 10));
    expect(parseWhen('next monday', now: now), DateTime(2026, 8, 24, 10));
    expect(parseWhen('today', now: now), DateTime(2026, 8, 21, 10));
    expect(parseWhen(''), isNull);
    expect(parseWhen('someday'), isNull);
  });
}

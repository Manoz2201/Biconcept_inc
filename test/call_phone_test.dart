import 'package:biconcept/util/call_phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizePhoneNumber keeps plus and digits', () {
    expect(sanitizePhoneNumber('+91 8178869148'), '+918178869148');
    expect(sanitizePhoneNumber('(011) 4000-1200'), '01140001200');
    expect(sanitizePhoneNumber('  '), '');
  });
}

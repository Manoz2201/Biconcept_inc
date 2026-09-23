import 'package:biconcept/features/catalog/domain/slug.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogSlug lowercases and strips punctuation', () {
    expect(catalogSlug('  Living Room / Dining! '), 'living-room-dining');
    expect(catalogSlug('@@@'), 'item');
  });

  test('uniqueSlug appends a counter when the base exists', () {
    expect(uniqueSlug('kitchen', {'kitchen', 'kitchen-2'}), 'kitchen-3');
    expect(uniqueSlug('kitchen', {}), 'kitchen');
  });
}

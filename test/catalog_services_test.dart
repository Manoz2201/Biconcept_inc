import 'package:flutter_test/flutter_test.dart';

import 'package:biconcept/features/catalog/domain/built_in_services.dart';

void main() {
  test('built-in services have unique slugs and ids', () {
    final slugs = {for (final item in builtInServices) item.slug};
    final ids = {for (final item in builtInServices) item.id};
    expect(slugs.length, builtInServices.length);
    expect(ids.length, builtInServices.length);
    expect(builtInServices.every((item) => item.category.isNotEmpty), isTrue);
    expect(builtInServiceByIdOrSlug('kitchen-renovation')?.title, 'Kitchen renovation');
  });

  test('merge keeps remote row and fills missing built-in services', () {
    final remote = [builtInServices.first];
    final merged = mergeCatalogServices(remote);
    expect(merged.length, builtInServices.length);
    expect(merged.where((item) => item.slug == remote.first.slug).length, 1);
  });
}

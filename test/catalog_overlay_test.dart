import 'package:biconcept/models/estimate_models.dart';
import 'package:flutter_test/flutter_test.dart';

EstimateCatalog _emptyCatalog() {
  return EstimateCatalog(
    defaults: EstimateDefaults.fromJson(<String, dynamic>{}),
    workTypes: [],
    areas: [],
    rateCard: [],
    quotations: [],
  );
}

void main() {
  test('user can add area, work type and scope and overlay round-trips', () {
    final catalog = _emptyCatalog();
    final area = catalog.addArea(name: 'Server room', typicalWorkTypes: ['Electrical']);
    expect(area.userAdded, isTrue);
    expect(area.id, 'area_server_room');

    final type = catalog.addWorkType(name: 'Signage', serialNo: 20);
    expect(type.serialNo, 20);
    expect(type.userAdded, isTrue);

    final scope = catalog.addScope(
      workTypeId: type.id,
      name: 'Acrylic letters',
      unit: 'pcs',
      suggestedRate: 2500,
      typicalAreas: ['Server room'],
    );
    expect(scope.userAdded, isTrue);
    expect(scope.suggestedRate, 2500);
    expect(catalog.rateCard, isNotEmpty);
    expect(catalog.rateCard.single.workScope, 'Acrylic letters');

    final restored = _emptyCatalog()..applyOverlay(catalog.overlayJson());
    expect(restored.areas.single.name, 'Server room');
    expect(restored.workTypes.single.name, 'Signage');
    expect(restored.allScopes().single.name, 'Acrylic letters');
  });

  test('duplicate names reuse the existing catalog item', () {
    final catalog = _emptyCatalog();
    final first = catalog.addArea(name: 'Cabin');
    final second = catalog.addArea(name: 'cabin');
    expect(identical(first, second), isTrue);
    expect(catalog.areas, hasLength(1));
  });

  test('editing unit and unit price persists through cache overlay', () {
    final catalog = EstimateCatalog(
      defaults: EstimateDefaults.fromJson(<String, dynamic>{}),
      workTypes: [
        WorkTypeSummary(
          id: 'wt_flooring',
          serialNo: 3,
          name: 'Flooring',
          areas: [],
          scopes: [
            WorkScope(
              id: 'ws_tile',
              workTypeId: 'wt_flooring',
              workType: 'Flooring',
              name: 'Vitrified tiles',
              description: 'vitrified',
              unit: 'sqft',
              suggestedRate: 150,
              minRate: 120,
              maxRate: 180,
              sampleCount: 2,
              typicalAreas: [],
              aliases: [],
              makes: [],
              samples: [],
            ),
          ],
        ),
      ],
      areas: [],
      rateCard: [],
      quotations: [],
    );
    catalog.rebuildRateCard();
    catalog.updateScope(scopeId: 'ws_tile', unit: 'pcs', suggestedRate: 210);

    expect(catalog.scopeById('ws_tile')!.unit, 'pcs');
    expect(catalog.scopeById('ws_tile')!.suggestedRate, 210);
    expect(catalog.scopeById('ws_tile')!.userEdited, isTrue);
    expect(catalog.rateCard.single.suggestedRate, 210);
    expect(catalog.rateCard.single.unit, 'pcs');

    final restored = EstimateCatalog(
      defaults: EstimateDefaults.fromJson(<String, dynamic>{}),
      workTypes: [
        WorkTypeSummary(
          id: 'wt_flooring',
          serialNo: 3,
          name: 'Flooring',
          areas: [],
          scopes: [
            WorkScope(
              id: 'ws_tile',
              workTypeId: 'wt_flooring',
              workType: 'Flooring',
              name: 'Vitrified tiles',
              description: 'vitrified',
              unit: 'sqft',
              suggestedRate: 150,
              minRate: 120,
              maxRate: 180,
              sampleCount: 2,
              typicalAreas: [],
              aliases: [],
              makes: [],
              samples: [],
            ),
          ],
        ),
      ],
      areas: [],
      rateCard: [],
      quotations: [],
    )..applyOverlay(catalog.overlayJson());

    expect(restored.scopeById('ws_tile')!.unit, 'pcs');
    expect(restored.scopeById('ws_tile')!.suggestedRate, 210);
  });
}

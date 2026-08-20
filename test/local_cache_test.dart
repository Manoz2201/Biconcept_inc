import 'dart:io';

import 'package:biconcept/data/local_cache.dart';
import 'package:biconcept/models/company_profile.dart';
import 'package:biconcept/models/estimate_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local cache persists catalog overlay and prefs across reload', () async {
    final dir = await Directory.systemTemp.createTemp('biconcept_cache_');
    addTearDown(() async {
      LocalCache.instance.overrideDirectory = null;
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    LocalCache.instance.overrideDirectory = dir;

    final catalog = EstimateCatalog(
      defaults: EstimateDefaults.fromJson(<String, dynamic>{}),
      workTypes: [],
      areas: [],
      rateCard: [],
      quotations: [],
    );
    catalog.addWorkType(name: 'Signage', serialNo: 20);
    catalog.addScope(workTypeId: 'wt_signage', name: 'Acrylic letters', unit: 'pcs', suggestedRate: 2500);
    catalog.addArea(name: 'Server room');

    await LocalCache.instance.saveCatalogOverlay(catalog.overlayJson());
    await LocalCache.instance.updatePrefs((prefs) {
      prefs.brand = 'Biconcept Architects & Interiors';
      prefs.gstPercent = 18;
      LocalCache.instance.rememberId(prefs.recentWorkTypeIds, 'wt_signage');
    });

    LocalCache.instance.overrideDirectory = dir;
    final restoredOverlay = await LocalCache.instance.loadCatalogOverlay();
    final restored = EstimateCatalog(
      defaults: EstimateDefaults.fromJson(<String, dynamic>{}),
      workTypes: [],
      areas: [],
      rateCard: [],
      quotations: [],
    )..applyOverlay(restoredOverlay);

    expect(restored.workTypes.single.name, 'Signage');
    expect(restored.allScopes().single.name, 'Acrylic letters');
    expect(restored.areas.single.name, 'Server room');

    LocalCache.instance.clearMemory();
    final prefs = await LocalCache.instance.loadPrefs();
    expect(prefs.recentWorkTypeIds, contains('wt_signage'));
    expect(prefs.gstPercent, 18);
    expect(prefs.companyAddress, defaultCompanyAddress);
    expect(prefs.companyPhone, defaultCompanyPhone);
  });
}

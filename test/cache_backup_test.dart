import 'dart:io';

import 'package:biconcept/data/cache_backup.dart';
import 'package:biconcept/data/local_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LocalCache backup CSV round-trips prefs and catalog overlay', () async {
    final dir = await Directory.systemTemp.createTemp('biconcept-backup');
    addTearDown(() async {
      LocalCache.instance.overrideDirectory = null;
      LocalCache.instance.clearMemory();
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    LocalCache.instance.overrideDirectory = dir;
    LocalCache.instance.clearMemory();

    await LocalCache.instance.savePrefs(
      AppPrefsCache(
        brand: 'BiConcept Test',
        companyAddress: 'D-41, Second Floor, Noida',
        companyPhone: '+91 8178869148',
        lastClient: 'OM CRE',
        lastProject: 'Noida, Sector 27',
        recentAreaNames: ['Reception', 'Cabin'],
      ),
    );
    await LocalCache.instance.saveCatalogOverlay({
      'areas': [
        {'id': 'area_test', 'name': 'Test Area', 'userAdded': true},
      ],
      'workTypes': [],
      'scopes': [
        {
          'id': 'scope_test',
          'workTypeId': 'civil',
          'name': 'Test scope',
          'unit': 'sqft',
          'userEdited': true,
        },
      ],
    });

    final snapshot = await loadCacheBackup();
    final csv = encodeCacheBackupCsv(prefs: snapshot.prefs, overlay: snapshot.overlay);
    expect(csv, contains(backupCsvFormat));
    expect(csv, contains('OM CRE'));
    expect(csv, contains('Test Area'));

    LocalCache.instance.clearMemory();
    await LocalCache.instance.savePrefs(AppPrefsCache(brand: 'Other'));
    await LocalCache.instance.saveCatalogOverlay({'areas': [], 'workTypes': [], 'scopes': []});

    await restoreCacheBackup(decodeCacheBackupCsv(csv));
    LocalCache.instance.clearMemory();

    final restored = await LocalCache.instance.loadPrefs();
    expect(restored.brand, 'BiConcept Test');
    expect(restored.lastClient, 'OM CRE');
    expect(restored.recentAreaNames, ['Reception', 'Cabin']);

    final overlay = await LocalCache.instance.loadCatalogOverlay();
    expect((overlay['areas'] as List).single['name'], 'Test Area');
    expect((overlay['scopes'] as List).single['name'], 'Test scope');
  });
}

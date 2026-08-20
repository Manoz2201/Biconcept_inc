import 'package:biconcept/data/appwrite_backend.dart';
import 'package:biconcept/data/appwrite_sync.dart';
import 'package:biconcept/data/local_cache.dart';
import 'package:biconcept/models/client_record.dart';
import 'package:biconcept/models/estimate_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeAppwriteEndpoint strips trailing slashes', () {
    expect(
      normalizeAppwriteEndpoint('https://fra.cloud.appwrite.io/v1/'),
      'https://fra.cloud.appwrite.io/v1',
    );
  });

  test('appwriteRowId sanitizes and truncates ids', () {
    expect(appwriteRowId('1734567890123'), '1734567890123');
    expect(appwriteRowId('_oops'), 'r_oops');
    expect(appwriteRowId('a b/c'), 'a_b_c');
    expect(appwriteRowId('x' * 40).length, 36);
  });

  test('client row round-trips through payload JSON', () {
    final client = ClientRecord(
      id: 'c1',
      name: 'Asha',
      phone: '8178869148',
      project: 'Villa',
      stage: CrmStage.quotation,
      updatedAt: DateTime.utc(2026, 8, 20, 6, 30),
    );
    final restored = clientFromAppwriteRow(clientToAppwriteRow(client));
    expect(restored.id, 'c1');
    expect(restored.name, 'Asha');
    expect(restored.phone, '8178869148');
    expect(restored.stage, CrmStage.quotation);
  });

  test('clientFromAppwriteRow keeps payload id even when row id differs', () {
    final restored = clientFromAppwriteRow(
      {
        'payload': {
          'id': 'c1',
          'name': 'Asha',
        },
      },
      rowId: 'other-row',
    );
    expect(restored.id, 'c1');
  });

  test('clientFromAppwriteRow uses row id when payload has no id', () {
    final restored = clientFromAppwriteRow(
      {
        'payload': {
          'name': 'Asha',
        },
      },
      rowId: 'row-1',
    );
    expect(restored.id, 'row-1');
    expect(restored.name, 'Asha');
  });

  test('estimate row round-trips through payload JSON', () {
    final draft = EstimateDraft(
      id: 'e1',
      client: 'Asha',
      project: 'Villa',
      status: EstimateStatus.completed,
      updatedAt: DateTime.utc(2026, 8, 20),
    );
    final restored = estimateFromAppwriteRow(estimateToAppwriteRow(draft));
    expect(restored.id, 'e1');
    expect(restored.client, 'Asha');
    expect(restored.status, EstimateStatus.completed);
  });

  test('AppwriteCloudSettings is configured only with endpoint, project and key', () {
    expect(const AppwriteCloudSettings().isConfigured, isFalse);
    expect(
      const AppwriteCloudSettings(apiKey: 'key').isConfigured,
      isTrue,
    );
  });

  test('Appwrite backend pins the project database without Settings fields', () {
    expect(AppwriteBackend.endpoint, AppwriteCloudSettings.defaultEndpoint);
    expect(AppwriteBackend.projectId, appwriteProjectIdDefault);
    expect(AppwriteBackend.databaseId, appwriteDatabaseIdDefault);
    expect(
      AppwriteBackend.settings(apiKey: 'key').isConfigured,
      isTrue,
    );
  });

  test('mergeCatalogOverlays keeps the newer item by id', () {
    final merged = mergeCatalogOverlays(
      {
        'areas': [
          {'id': 'a1', 'name': 'Local', 'updatedAt': '2026-08-20T12:00:00.000Z'},
        ],
        'workTypes': [],
        'scopes': [],
      },
      {
        'areas': [
          {'id': 'a1', 'name': 'Remote', 'updatedAt': '2026-08-01T12:00:00.000Z'},
          {'id': 'a2', 'name': 'Extra', 'updatedAt': '2026-08-18T12:00:00.000Z'},
        ],
        'workTypes': [],
        'scopes': [],
      },
    );
    final areas = (merged['areas'] as List).cast<Map<String, dynamic>>();
    expect(areas.map((item) => item['id']), containsAll(['a1', 'a2']));
    expect(areas.firstWhere((item) => item['id'] == 'a1')['name'], 'Local');
  });

  test('company prefs round-trip through the Appwrite company row', () {
    final prefs = AppPrefsCache(
      brand: 'BiConcept',
      companyAddress: 'Noida',
      companyPhone: '+91 8178869148',
      gstPercent: 18,
      hvacGstPercent: 28,
      savedAt: DateTime.utc(2026, 8, 21, 2),
    );
    final restored = companyFromAppwriteRow(companyToAppwriteRow(prefs));
    expect(restored.brand, 'BiConcept');
    expect(restored.companyAddress, 'Noida');
    expect(restored.companyPhone, '+91 8178869148');
    expect(restored.gstPercent, 18);
    expect(restored.hvacGstPercent, 28);
  });

  test('mergeCompanyPrefs keeps the newer savedAt', () {
    final older = AppPrefsCache(brand: 'Old', savedAt: DateTime.utc(2026, 1, 1));
    final newer = AppPrefsCache(brand: 'New', savedAt: DateTime.utc(2026, 8, 20));
    expect(mergeCompanyPrefs(older, newer).brand, 'New');
    expect(mergeCompanyPrefs(newer, older).brand, 'New');
  });
}

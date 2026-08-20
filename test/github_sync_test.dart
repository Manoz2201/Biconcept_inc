import 'package:biconcept/data/github_sync.dart';
import 'package:biconcept/models/client_record.dart';
import 'package:biconcept/models/estimate_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseGitHubRepo accepts slug and github URLs', () {
    expect(parseGitHubRepo('acme/biconcept-data')?.slug, 'acme/biconcept-data');
    expect(parseGitHubRepo('https://github.com/acme/biconcept-data.git')?.slug, 'acme/biconcept-data');
    expect(parseGitHubRepo('git@github.com:acme/biconcept-data.git')?.slug, 'acme/biconcept-data');
    expect(parseGitHubRepo('only-name'), isNull);
  });

  test('mergeCloudSnapshots keeps the newer client and estimate by id', () {
    final older = ClientRecord(id: 'c1', name: 'Old', updatedAt: DateTime(2026, 1, 1));
    final newer = ClientRecord(id: 'c1', name: 'New', updatedAt: DateTime(2026, 8, 19));
    final extra = ClientRecord(id: 'c2', name: 'Phone', updatedAt: DateTime(2026, 8, 18));
    final localDraft = EstimateDraft(id: 'e1', client: 'Local', updatedAt: DateTime(2026, 8, 19));
    final remoteDraft = EstimateDraft(id: 'e1', client: 'Remote', updatedAt: DateTime(2026, 8, 1));

    final merged = mergeCloudSnapshots(
      CloudSnapshot(clients: [older], estimates: [localDraft]),
      CloudSnapshot(clients: [newer, extra], estimates: [remoteDraft]),
    );

    expect(merged.clients.map((item) => item.id), containsAll(['c1', 'c2']));
    expect(merged.clients.firstWhere((item) => item.id == 'c1').name, 'New');
    expect(merged.estimates.single.client, 'Local');
  });
}

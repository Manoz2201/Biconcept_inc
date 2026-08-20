import 'dart:io';

import 'package:biconcept/data/client_store.dart';
import 'package:biconcept/models/client_record.dart';
import 'package:biconcept/models/estimate_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saving an edited client overwrites that id instead of creating another', () async {
    final dir = await Directory.systemTemp.createTemp('biconcept_clients');
    addTearDown(() => dir.delete(recursive: true));
    final store = ClientStore()..overrideDirectory = dir;
    final client = ClientRecord(id: 'c1', name: 'Asha', phone: '111');
    await store.save(client, syncToCloud: false);

    client.phone = '999';
    client.project = 'Villa';
    await store.save(client, syncToCloud: false);

    final listed = await store.list();
    expect(listed, hasLength(1));
    expect(listed.single.id, 'c1');
    expect(listed.single.phone, '999');
    expect(listed.single.project, 'Villa');
  });

  test('syncFromEstimates does not add a second client for the same name', () async {
    final dir = await Directory.systemTemp.createTemp('biconcept_clients');
    addTearDown(() => dir.delete(recursive: true));
    final store = ClientStore()..overrideDirectory = dir;
    await store.save(ClientRecord(id: 'c1', name: 'Asha', phone: '111'), syncToCloud: false);

    await store.syncFromEstimates([
      EstimateDraft(id: 'e1', client: 'Asha', project: 'Villa'),
      EstimateDraft(id: 'e2', client: 'asha', project: 'Office'),
    ]);

    final listed = await store.list();
    expect(listed, hasLength(1));
    expect(listed.single.id, 'c1');
    expect(listed.single.project, 'Villa');
  });
}

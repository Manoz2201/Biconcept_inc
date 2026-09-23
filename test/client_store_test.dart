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

  test('mergeRemoteLeads adds a portal lead once by email', () async {
    final dir = await Directory.systemTemp.createTemp('biconcept_clients');
    addTearDown(() => dir.delete(recursive: true));
    final store = ClientStore()..overrideDirectory = dir;
    await store.save(ClientRecord(id: 'c1', name: 'Asha', email: 'asha@example.com'), syncToCloud: false);

    final added = await store.mergeRemoteLeads([
      ClientRecord(
        id: 'lead_1',
        name: 'Asha Kumar',
        email: 'asha@example.com',
        phone: '9876543210',
        project: 'Villa',
        source: 'client_portal',
      ),
      ClientRecord(
        id: 'lead_2',
        name: 'Ravi',
        email: 'ravi@example.com',
        phone: '9123456789',
        source: 'client_portal',
      ),
    ]);

    final listed = await store.list();
    expect(added, 1);
    expect(listed, hasLength(2));
    expect(listed.where((item) => item.email == 'asha@example.com').single.phone, '9876543210');
    expect(listed.any((item) => item.email == 'ravi@example.com'), isTrue);
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

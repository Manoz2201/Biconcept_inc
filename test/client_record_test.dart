import 'package:biconcept/data/crm_lead_sync.dart';
import 'package:biconcept/models/client_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client CRM record round-trips details, follow-ups and stage', () {
    final client = ClientRecord(
      name: 'OM CRE',
      phone: '+91 8178869148',
      project: 'Noida Sector 27',
      source: 'Referral',
      stage: CrmStage.quotation,
      followUps: [
        ClientFollowUp(
          kind: 'Visit',
          note: 'Site measured',
          nextFollow: DateTime(2026, 8, 25),
        ),
      ],
    );

    final restored = ClientRecord.fromJson(client.toJson());
    expect(restored.id, client.id);
    expect(restored.name, 'OM CRE');
    expect(restored.phone, '+91 8178869148');
    expect(restored.stage, CrmStage.quotation);
    expect(restored.followUps, hasLength(1));
    expect(restored.followUps.single.kind, 'Visit');
    expect(restored.nextFollow, DateTime(2026, 8, 25));
  });

  test('fromJson keeps an existing id and accepts \$id as fallback', () {
    final fromId = ClientRecord.fromJson({'id': 'keep-me', 'name': 'Asha'});
    expect(fromId.id, 'keep-me');
    final fromDollar = ClientRecord.fromJson({r'$id': 'row-1', 'name': 'Asha'});
    expect(fromDollar.id, 'row-1');
  });

  test('portal lead maps onto a CRM lead with a stable id', () {
    final lead = clientRecordFromPortal(
      accountId: 'acc_1',
      name: 'Asha',
      email: 'asha@example.com',
      phone: '9876543210',
      title: 'Villa plan',
      description: 'Need a 3BHK layout',
    );
    expect(lead.id, 'lead_acc_1');
    expect(lead.stage, CrmStage.lead);
    expect(lead.source, 'client_portal');
    expect(lead.project, 'Villa plan');
  });
}

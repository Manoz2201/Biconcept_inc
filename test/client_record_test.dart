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
    expect(restored.name, 'OM CRE');
    expect(restored.phone, '+91 8178869148');
    expect(restored.stage, CrmStage.quotation);
    expect(restored.followUps, hasLength(1));
    expect(restored.followUps.single.kind, 'Visit');
    expect(restored.nextFollow, DateTime(2026, 8, 25));
  });
}

import 'package:biconcept/models/company_profile.dart';
import 'package:biconcept/models/estimate_document.dart';
import 'package:biconcept/models/estimate_models.dart';
import 'package:biconcept/models/terms_and_conditions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('amount is quantity times unit rate and GST splits HVAC', () {
    final draft = EstimateDraft(
      client: 'Test',
      gstPercent: 18,
      hvacGstPercent: 28,
      lines: [
        EstimateLine(
          id: 'a',
          workTypeId: 'wt_flooring',
          workType: 'Flooring',
          serialNo: 3,
          scopeId: 'ws_tile',
          name: 'Tiles',
          description: 'vitrified',
          unit: 'sqft',
          quantity: 100,
          quantityConfirmed: true,
          unitRate: 150,
        ),
        EstimateLine(
          id: 'b',
          workTypeId: 'wt_hvac',
          workType: 'HVAC',
          serialNo: 10,
          scopeId: 'ws_ahu',
          name: 'AHU supply and installation',
          description: 'AHU',
          unit: 'sqft',
          quantity: 10,
          quantityConfirmed: true,
          unitRate: 325,
        ),
      ],
    );

    expect(draft.lines.first.price, 15000);
    expect(draft.lines.first.amount, 15000);
    expect(draft.totals.otherTaxable, 15000);
    expect(draft.totals.hvacTaxable, 3250);
    expect(draft.totals.gst18, 2700);
    expect(draft.totals.gst28, 910);
    expect(draft.totals.grandTotal, 21860);
  });

  test('status aliases map final and complete correctly', () {
    expect(EstimateStatus.fromName('final').label, 'Finalized');
    expect(EstimateStatus.fromName('completed').label, 'Completed');
    expect(EstimateStatus.fromName(null), EstimateStatus.drafted);

    final draft = EstimateDraft(client: 'A', status: EstimateStatus.finalized);
    final restored = EstimateDraft.fromJson(draft.toJson());
    expect(restored.status, EstimateStatus.finalized);
  });

  test('fromScope uses entered quantity to calculate amount', () {
    const type = WorkTypeSummary(
      id: 'wt_flooring',
      serialNo: 3,
      name: 'Flooring',
      areas: ['Office'],
      scopes: [],
    );
    const scope = WorkScope(
      id: 'ws_tile',
      workTypeId: 'wt_flooring',
      workType: 'Flooring',
      code: 'A',
      name: 'Vitrified tiling',
      description: 'vitrified',
      unit: 'sqft',
      suggestedRate: 150,
      minRate: 120,
      maxRate: 180,
      sampleCount: 0,
      typicalAreas: ['Office'],
      aliases: [],
      makes: [],
      samples: [],
    );

    final line = EstimateLine.fromScope(type: type, scope: scope, area: 'Office', quantity: 40);
    expect(line.quantity, 40);
    expect(line.quantityConfirmed, isTrue);
    expect(line.unitRate, 150);
    expect(line.amount, 6000);

    final draft = EstimateDraft(client: 'Test', lines: [line]);
    draft.removeLine(line.id);
    expect(draft.lines, isEmpty);
    draft.addLine(line);
    expect(draft.lines, hasLength(1));
  });

  test('terms and conditions use Excel clauses and round-trip on save', () {
    final draft = EstimateDraft(
      client: 'DEV X',
      termsAndConditions: standardInteriorTerms,
    );
    expect(draft.effectiveTerms, hasLength(6));
    expect(draft.effectiveTerms.first, contains('30% Advance'));
    expect(draft.effectiveTerms[4], contains('28% GST'));

    final restored = EstimateDraft.fromJson(draft.toJson());
    expect(restored.effectiveTerms, draft.effectiveTerms);

    final legacy = EstimateDraft(
      client: 'Old',
      paymentTerms: const ['30% Advance', '5% at finishing'],
      notes: const ['Extra items charged separately after approval'],
      exclusions: const ['TV', 'curtains'],
    );
    expect(legacy.effectiveTerms.first, startsWith('Payment needed to be done in phases'));
    expect(legacy.effectiveTerms.last, contains('TV'));
    expect(legacy.effectiveTerms, isNot(equals(standardInteriorTerms)));
  });

  test('net price applies discount to unit rate times qty', () {
    final line = EstimateLine(
      id: 'd',
      workTypeId: 'wt_flooring',
      workType: 'Flooring',
      serialNo: 3,
      scopeId: 'ws_tile',
      name: 'Tiles',
      description: 'vitrified',
      unit: 'sqft',
      quantity: 10,
      quantityConfirmed: true,
      unitRate: 200,
      discountPercent: 10,
    );
    expect(line.price, 2000);
    expect(line.netPrice, 1800);
    expect(line.amount, 1800);

    final restored = EstimateLine.fromJson(line.toJson());
    expect(restored.discountPercent, 10);
    expect(restored.netPrice, 1800);
  });

  test('company address falls back to the office on Excel quotations', () {
    expect(resolveCompanyAddress(), defaultCompanyAddress);
    expect(
      resolveCompanyAddress(prefsAddress: 'C-25, Second Floor, Sector-58, Noida- 201301'),
      'C-25, Second Floor, Sector-58, Noida- 201301',
    );
    expect(
      resolveCompanyAddress(draftAddress: 'Unit 12, Noida'),
      'Unit 12, Noida',
    );
  });

  test('company contact line sits under the address', () {
    expect(resolveCompanyPhone(), defaultCompanyPhone);
    expect(companyContactLine(defaultCompanyPhone), 'Contact no. : +91 8178869148');
    expect(resolveCompanyPhone(prefsPhone: '+91 9999999999'), '+91 9999999999');
  });

  test('estimate type defaults and round-trips including custom labels', () {
    final draft = EstimateDraft(client: 'A');
    expect(draft.estimateType, defaultEstimateType);
    expect(draft.estimateTypeHeading, 'INTERIOR ESTIMATE');

    draft.setEstimateType('Construction TurnKey Estimate');
    expect(draft.estimateTypeHeading, 'CONSTRUCTION TURNKEY ESTIMATE');

    draft.setEstimateType('  Facade lighting  ');
    final restored = EstimateDraft.fromJson(draft.toJson());
    expect(restored.estimateType, 'Facade lighting');
    expect(normalizeEstimateType(''), defaultEstimateType);
  });
}

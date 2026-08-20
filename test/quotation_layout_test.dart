import 'package:biconcept/export/quotation_layout.dart';
import 'package:biconcept/export/quotation_pdf.dart';
import 'package:biconcept/models/company_profile.dart';
import 'package:biconcept/models/estimate_document.dart';
import 'package:biconcept/util/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quotation grouping builds work-type totals like the template', () {
    final draft = EstimateDraft(
      client: 'DEV X',
      project: 'JASK NOIDA',
      gstPercent: 18,
      hvacGstPercent: 18,
      lines: [
        EstimateLine(
          id: '1',
          workTypeId: 'wt_dismantling',
          workType: 'Dismantling and Debris',
          serialNo: 1,
          scopeId: 'a',
          workScopeCode: 'A',
          name: 'Dismantling existing partitions',
          description: 'as/Site Visit',
          unit: 'lumpsum',
          quantity: 1,
          quantityConfirmed: true,
          unitRate: 20000,
        ),
        EstimateLine(
          id: '2',
          workTypeId: 'wt_furniture',
          workType: 'Furniture',
          serialNo: 6,
          area: 'Meeting Rooms',
          areaCode: '6A',
          scopeId: 't',
          workScopeCode: 'A',
          name: "Meeting table",
          description: 'laminate finish',
          unit: 'pcs',
          quantity: 1,
          quantityConfirmed: true,
          unitRate: 26000,
        ),
        EstimateLine(
          id: '3',
          workTypeId: 'wt_furniture',
          workType: 'Furniture',
          serialNo: 6,
          area: 'Manager Cabin',
          areaCode: '6B',
          scopeId: 'c',
          workScopeCode: 'B',
          name: 'Cabin chair',
          description: '',
          unit: 'pcs',
          quantity: 1,
          quantityConfirmed: true,
          unitRate: 7500,
        ),
      ],
    );

    final sections = groupQuotation(draft);
    expect(sections, hasLength(2));
    expect(sections[0].total, 20000);
    expect(sections[1].workType, 'Furniture');
    expect(sections[1].blocks, hasLength(2));
    expect(sections[1].total, 33500);
    expect(unitLabel('sqft'), 'per sqft');
    expect(indianGrouped(630330, decimals: 2), '6,30,330.00');
    expect(scopeTitle(draft.lines.first), 'Dismantling existing partitions');
    expect(scopeDetails(draft.lines.first), 'as/Site Visit');
  });

  test('same work type is one heading even when scopes are interleaved', () {
    final draft = EstimateDraft(
      client: 'OM CRE',
      lines: [
        EstimateLine(
          id: '1',
          workTypeId: 'wt_civil',
          workType: 'Civil Work',
          serialNo: 2,
          scopeId: 'a',
          name: 'Brick work',
          description: '',
          unit: 'sqft',
          quantity: 1,
          quantityConfirmed: true,
          unitRate: 10,
        ),
        EstimateLine(
          id: '2',
          workTypeId: 'wt_floor',
          workType: 'Flooring',
          serialNo: 3,
          scopeId: 'a',
          name: 'Tiles',
          description: '',
          unit: 'sqft',
          quantity: 1,
          quantityConfirmed: true,
          unitRate: 20,
        ),
        EstimateLine(
          id: '3',
          workTypeId: 'wt_civil',
          workType: 'Civil Work',
          serialNo: 2,
          scopeId: 'b',
          name: 'Plaster',
          description: '',
          unit: 'sqft',
          quantity: 1,
          quantityConfirmed: true,
          unitRate: 15,
        ),
      ],
    );

    final sections = groupQuotation(draft);
    expect(sections, hasLength(2));
    expect(sections[0].workType, 'Civil Work');
    expect(sections[0].lines, hasLength(2));
    expect(sections[1].workType, 'Flooring');
    expect(sections[1].lines, hasLength(1));
    expect(sections[0].lines.map((line) => line.name), ['Brick work', 'Plaster']);
  });

  test('work types and totals are numbered 1, 2, 3 even if catalog serials skip', () {
    final draft = EstimateDraft(
      client: 'OM CRE',
      lines: [
        EstimateLine(
          id: '2',
          workTypeId: 'wt_furniture',
          workType: 'Furniture',
          serialNo: 6,
          scopeId: 'a',
          name: 'Table',
          description: '',
          unit: 'pcs',
          quantity: 1,
          quantityConfirmed: true,
          unitRate: 1000,
        ),
        EstimateLine(
          id: '1',
          workTypeId: 'wt_dismantling',
          workType: 'Dismantling and Debris',
          serialNo: 1,
          scopeId: 'a',
          name: 'Debris',
          description: '',
          unit: 'lumpsum',
          quantity: 1,
          quantityConfirmed: true,
          unitRate: 2000,
        ),
      ],
    );

    final sections = groupQuotation(draft);
    expect(sections.map((section) => section.serialNo), [1, 2]);
    expect(sections.map((section) => section.workType), ['Dismantling and Debris', 'Furniture']);
  });

  test('scopes under a work type are numbered A, B, C in series', () {
    final draft = EstimateDraft(
      client: 'OM CRE',
      lines: [
        EstimateLine(
          id: '1',
          workTypeId: 'wt_civil',
          workType: 'Civil Work',
          serialNo: 2,
          scopeId: 'c',
          workScopeCode: 'F',
          name: 'Plaster',
          description: '',
          unit: 'sqft',
        ),
        EstimateLine(
          id: '2',
          workTypeId: 'wt_civil',
          workType: 'Civil Work',
          serialNo: 2,
          scopeId: 'a',
          workScopeCode: 'C',
          name: 'Brick work',
          description: '',
          unit: 'sqft',
        ),
        EstimateLine(
          id: '3',
          workTypeId: 'wt_civil',
          workType: 'Civil Work',
          serialNo: 2,
          scopeId: 'b',
          workScopeCode: 'G',
          name: 'PCC',
          description: '',
          unit: 'sqft',
        ),
      ],
    );
    draft.normalizeScopeSeries();
    expect(draft.lines.map((line) => line.workScopeCode), ['A', 'B', 'C']);
    expect(draft.lines.map((line) => line.name), ['Brick work', 'Plaster', 'PCC']);
  });

  test('pdf quotation includes logo and template sections', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final draft = EstimateDraft(
      client: 'DEV X',
      project: 'JASK NOIDA',
      companyAddress: defaultCompanyAddress,
      companyPhone: defaultCompanyPhone,
      gstPercent: 18,
      hvacGstPercent: 18,
      paymentTerms: const ['30% Advance', '5% at finishing'],
      notes: const ['Extra items charged separately after approval'],
      lines: [
        EstimateLine(
          id: '1',
          workTypeId: 'wt_dismantling',
          workType: 'Dismantling and Debris',
          serialNo: 1,
          scopeId: 'a',
          workScopeCode: 'A',
          name: 'Dismantling existing partitions',
          description: 'as/Site Visit',
          unit: 'lumpsum',
          quantity: 1,
          quantityConfirmed: true,
          unitRate: 20000,
        ),
      ],
    );
    final bytes = await QuotationPdf().buildBytes(draft);
    expect(bytes.length, greaterThan(8000));
  });
}

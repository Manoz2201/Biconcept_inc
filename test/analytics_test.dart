import 'package:biconcept/data/analytics.dart';
import 'package:biconcept/models/estimate_document.dart';
import 'package:flutter_test/flutter_test.dart';

EstimateDraft _draft({
  required String client,
  required EstimateStatus status,
  required double amount,
  DateTime? date,
}) {
  return EstimateDraft(
    client: client,
    status: status,
    date: date ?? DateTime(2026, 8, 1),
    gstPercent: 0,
    hvacGstPercent: 0,
    lines: [
      EstimateLine(
        id: client,
        workTypeId: 'wt_flooring',
        workType: 'Flooring',
        serialNo: 1,
        scopeId: 'ws_tile',
        name: 'Tiles',
        description: '',
        unit: 'sqft',
        quantity: 1,
        quantityConfirmed: true,
        unitRate: amount,
      ),
    ],
  );
}

void main() {
  test('analytics splits status counts and pipeline value', () {
    final analytics = EstimateAnalytics.from([
      _draft(client: 'A', status: EstimateStatus.drafted, amount: 100),
      _draft(client: 'B', status: EstimateStatus.completed, amount: 200),
      _draft(client: 'C', status: EstimateStatus.finalized, amount: 400),
    ]);

    expect(analytics.total, 3);
    expect(analytics.drafted, 1);
    expect(analytics.completed, 1);
    expect(analytics.finalized, 1);
    expect(analytics.pipelineValue, 700);
    expect(analytics.finalizedValue, 400);
    expect(analytics.byWorkType.single.name, 'Flooring');
    expect(analytics.monthly, hasLength(12));
    expect(analytics.ytdWon, 1);
    expect(analytics.thisWeekCount, greaterThanOrEqualTo(0));
  });
}

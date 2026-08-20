import '../models/estimate_document.dart';

class WorkTypeShare {
  const WorkTypeShare({required this.name, required this.amount});

  final String name;
  final double amount;
}

class MonthPoint {
  const MonthPoint({required this.label, required this.count, required this.value});

  final String label;
  final int count;
  final double value;
}

class EstimateAnalytics {
  const EstimateAnalytics({
    required this.total,
    required this.drafted,
    required this.completed,
    required this.finalized,
    required this.pipelineValue,
    required this.finalizedValue,
    required this.completedValue,
    required this.thisMonthValue,
    required this.lastMonthValue,
    required this.thisMonthCount,
    required this.lastMonthCount,
    required this.thisWeekCount,
    required this.ytdWon,
    required this.thisQuarterWon,
    required this.lastQuarterWon,
    required this.byWorkType,
    required this.monthly,
  });

  final int total;
  final int drafted;
  final int completed;
  final int finalized;
  final double pipelineValue;
  final double finalizedValue;
  final double completedValue;
  final double thisMonthValue;
  final double lastMonthValue;
  final int thisMonthCount;
  final int lastMonthCount;
  final int thisWeekCount;
  final int ytdWon;
  final int thisQuarterWon;
  final int lastQuarterWon;
  final List<WorkTypeShare> byWorkType;
  final List<MonthPoint> monthly;

  double get wonValue => completedValue + finalizedValue;

  double valueDelta() {
    if (lastMonthValue == 0) return thisMonthValue == 0 ? 0 : 100;
    return ((thisMonthValue - lastMonthValue) / lastMonthValue) * 100;
  }

  double countDelta() {
    if (lastMonthCount == 0) return thisMonthCount == 0 ? 0 : 100;
    return ((thisMonthCount - lastMonthCount) / lastMonthCount) * 100;
  }

  int quarterWonDelta() => thisQuarterWon - lastQuarterWon;

  factory EstimateAnalytics.from(List<EstimateDraft> drafts) {
    var drafted = 0;
    var completed = 0;
    var finalized = 0;
    var pipeline = 0.0;
    var finalizedValue = 0.0;
    var completedValue = 0.0;
    final byType = <String, double>{};

    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month);
    final lastMonthStart = DateTime(now.year, now.month - 1);
    var thisMonthValue = 0.0;
    var lastMonthValue = 0.0;
    var thisMonthCount = 0;
    var lastMonthCount = 0;
    var thisWeekCount = 0;
    var ytdWon = 0;
    var thisQuarterWon = 0;
    var lastQuarterWon = 0;
    final weekStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    final thisQuarter = ((now.month - 1) ~/ 3) + 1;
    final lastQuarter = thisQuarter == 1 ? 4 : thisQuarter - 1;
    final lastQuarterYear = thisQuarter == 1 ? now.year - 1 : now.year;

    final months = <DateTime>[
      for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    final monthCounts = List<int>.filled(12, 0);
    final monthValues = List<double>.filled(12, 0);

    int monthIndex(DateTime date) {
      for (var i = 0; i < months.length; i++) {
        if (months[i].year == date.year && months[i].month == date.month) return i;
      }
      return -1;
    }

    for (final draft in drafts) {
      final total = draft.totals.grandTotal;
      pipeline += total;
      switch (draft.status) {
        case EstimateStatus.drafted:
          drafted += 1;
        case EstimateStatus.completed:
          completed += 1;
          completedValue += total;
        case EstimateStatus.finalized:
          finalized += 1;
          finalizedValue += total;
      }

      final stamp = draft.date;
      if (!stamp.isBefore(thisMonthStart)) {
        thisMonthValue += total;
        thisMonthCount += 1;
      } else if (!stamp.isBefore(lastMonthStart)) {
        lastMonthValue += total;
        lastMonthCount += 1;
      }
      if (!stamp.isBefore(weekStart)) thisWeekCount += 1;
      if (draft.status == EstimateStatus.finalized && stamp.year == now.year) ytdWon += 1;
      final stampQuarter = ((stamp.month - 1) ~/ 3) + 1;
      if (draft.status == EstimateStatus.finalized) {
        if (stamp.year == now.year && stampQuarter == thisQuarter) thisQuarterWon += 1;
        if (stamp.year == lastQuarterYear && stampQuarter == lastQuarter) lastQuarterWon += 1;
      }

      final idx = monthIndex(stamp);
      if (idx >= 0) {
        monthCounts[idx] += 1;
        monthValues[idx] += total;
      }

      for (final line in draft.lines) {
        byType[line.workType] = (byType[line.workType] ?? 0) + line.amount;
      }
    }

    final shares = [
      for (final entry in byType.entries) WorkTypeShare(name: entry.key, amount: entry.value),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthly = [
      for (var i = 0; i < months.length; i++)
        MonthPoint(
          label: labels[months[i].month - 1],
          count: monthCounts[i],
          value: monthValues[i],
        ),
    ];

    return EstimateAnalytics(
      total: drafts.length,
      drafted: drafted,
      completed: completed,
      finalized: finalized,
      pipelineValue: pipeline,
      finalizedValue: finalizedValue,
      completedValue: completedValue,
      thisMonthValue: thisMonthValue,
      lastMonthValue: lastMonthValue,
      thisMonthCount: thisMonthCount,
      lastMonthCount: lastMonthCount,
      thisWeekCount: thisWeekCount,
      ytdWon: ytdWon,
      thisQuarterWon: thisQuarterWon,
      lastQuarterWon: lastQuarterWon,
      byWorkType: shares.take(8).toList(),
      monthly: monthly,
    );
  }
}

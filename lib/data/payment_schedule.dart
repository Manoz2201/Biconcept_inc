import '../models/office_models.dart';

double roundMoney(double value) => (value * 100).round() / 100;

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// Builds dated payment installments from estimate T&C percentages and the
/// quotation grand total. Dates start from [start] (usually the estimate date).
List<PaymentInstallment> buildPaymentSchedule({
  required List<String> terms,
  required double grandTotal,
  required DateTime start,
  String estimateId = '',
  String client = '',
  String project = '',
}) {
  final origin = dateOnly(start);
  final percents = _percentsFromTerms(terms);
  if (percents.isEmpty) {
    return [
      PaymentInstallment(
        id: 'pay_${estimateId}_1',
        estimateId: estimateId,
        client: client,
        project: project,
        index: 1,
        percent: 100,
        label: 'Full payment',
        dueOffsetDays: 0,
        amount: roundMoney(grandTotal),
        dueAt: origin,
      ),
    ];
  }

  final clause = _paymentClause(terms).toLowerCase();
  final everyDays = _firstInt(RegExp(r'every\s+(\d+)\s+days').firstMatch(clause)) ?? 20;
  final initialDays = _firstInt(RegExp(r'within initial\s+(\d+)\s+days').firstMatch(clause)) ?? everyDays;
  final hasDelivery = clause.contains('delivery');
  final hasFinishing = clause.contains('finish');

  final offsets = <int>[];
  var day = 0;
  for (var i = 0; i < percents.length; i++) {
    if (i == 0) {
      day = 0;
    } else if (i == 1 && hasDelivery) {
      day = initialDays;
    } else if (hasFinishing && i == percents.length - 1) {
      day += everyDays;
    } else {
      day += everyDays;
    }
    offsets.add(day);
  }

  final plans = <PaymentInstallment>[];
  var allocated = 0.0;
  for (var i = 0; i < percents.length; i++) {
    final isLast = i == percents.length - 1;
    final amount = isLast
        ? roundMoney(grandTotal - allocated)
        : roundMoney(grandTotal * percents[i] / 100);
    allocated += amount;
    plans.add(
      PaymentInstallment(
        id: 'pay_${estimateId}_${i + 1}',
        estimateId: estimateId,
        client: client,
        project: project,
        index: i + 1,
        percent: percents[i],
        label: _labelFor(i, percents.length, hasDelivery: hasDelivery, hasFinishing: hasFinishing),
        dueOffsetDays: offsets[i],
        amount: amount,
        dueAt: origin.add(Duration(days: offsets[i])),
      ),
    );
  }
  return plans;
}

String _paymentClause(List<String> terms) {
  for (final term in terms) {
    final lower = term.toLowerCase();
    if (lower.contains('payment') && term.contains('%')) return term;
  }
  for (final term in terms) {
    if (term.contains('%')) return term;
  }
  return '';
}

List<double> _percentsFromTerms(List<String> terms) {
  final clause = _paymentClause(terms);
  return [
    for (final match in RegExp(r'(\d+(?:\.\d+)?)\s*%').allMatches(clause)) double.parse(match.group(1)!),
  ];
}

int? _firstInt(RegExpMatch? match) => int.tryParse(match?.group(1) ?? '');

String _labelFor(
  int index,
  int count, {
  required bool hasDelivery,
  required bool hasFinishing,
}) {
  if (index == 0) return 'Advance';
  if (index == 1 && hasDelivery) return 'Material delivery';
  if (hasFinishing && index == count - 1) return 'Finishing';
  return 'Progress ${index - (hasDelivery ? 1 : 0)}';
}

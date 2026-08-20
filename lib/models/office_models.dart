enum CalendarKind { meeting, followUp, collect, pay }

enum MoneyFlow { receive, send }

String projectAccountKey(String client, String project) {
  return '${client.trim().toLowerCase()}|${project.trim().toLowerCase()}';
}

class PaymentInstallment {
  PaymentInstallment({
    required this.id,
    required this.estimateId,
    required this.client,
    required this.project,
    required this.index,
    required this.percent,
    required this.label,
    required this.dueOffsetDays,
    required this.amount,
    required this.dueAt,
    this.collected = 0,
  });

  final String id;
  final String estimateId;
  final String client;
  final String project;
  final int index;
  final double percent;
  final String label;
  final int dueOffsetDays;
  final double amount;
  DateTime dueAt;
  double collected;

  double get outstanding => ((amount - collected) * 100).round() / 100;

  bool get isPaid => outstanding <= 0.009;

  Map<String, dynamic> toJson() => {
        'id': id,
        'estimateId': estimateId,
        'client': client,
        'project': project,
        'index': index,
        'percent': percent,
        'label': label,
        'dueOffsetDays': dueOffsetDays,
        'amount': amount,
        'dueAt': dueAt.toIso8601String(),
        'collected': collected,
      };

  factory PaymentInstallment.fromJson(Map<String, dynamic> json) {
    return PaymentInstallment(
      id: json['id']?.toString() ?? '',
      estimateId: json['estimateId']?.toString() ?? '',
      client: json['client']?.toString() ?? '',
      project: json['project']?.toString() ?? '',
      index: (json['index'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
      label: json['label']?.toString() ?? 'Payment',
      dueOffsetDays: (json['dueOffsetDays'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      dueAt: DateTime.tryParse(json['dueAt']?.toString() ?? '') ?? DateTime.now(),
      collected: (json['collected'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CalendarEvent {
  CalendarEvent({
    String? id,
    required this.kind,
    required this.start,
    this.end,
    this.title = '',
    this.client = '',
    this.project = '',
    this.estimateId,
    this.installmentId,
    this.notes = '',
    this.notify = true,
    this.done = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  CalendarKind kind;
  DateTime start;
  DateTime? end;
  String title;
  String client;
  String project;
  String? estimateId;
  String? installmentId;
  String notes;
  bool notify;
  bool done;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'title': title,
        'client': client,
        'project': project,
        'estimateId': estimateId,
        'installmentId': installmentId,
        'notes': notes,
        'notify': notify,
        'done': done,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id']?.toString(),
      kind: CalendarKind.values.firstWhere(
        (item) => item.name == json['kind']?.toString(),
        orElse: () => CalendarKind.meeting,
      ),
      start: DateTime.tryParse(json['start']?.toString() ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(json['end']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      client: json['client']?.toString() ?? '',
      project: json['project']?.toString() ?? '',
      estimateId: json['estimateId']?.toString(),
      installmentId: json['installmentId']?.toString(),
      notes: json['notes']?.toString() ?? '',
      notify: json['notify'] != false,
      done: json['done'] == true,
    );
  }
}

class PaymentEntry {
  PaymentEntry({
    String? id,
    required this.flow,
    required this.amount,
    required this.date,
    this.client = '',
    this.project = '',
    this.estimateId,
    this.installmentId,
    this.method = 'UPI',
    this.party = '',
    this.note = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final MoneyFlow flow;
  final double amount;
  final DateTime date;
  final String client;
  final String project;
  final String? estimateId;
  final String? installmentId;
  final String method;
  final String party;
  final String note;

  String get accountKey => projectAccountKey(client, project);

  Map<String, dynamic> toJson() => {
        'id': id,
        'flow': flow.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'client': client,
        'project': project,
        'estimateId': estimateId,
        'installmentId': installmentId,
        'method': method,
        'party': party,
        'note': note,
      };

  factory PaymentEntry.fromJson(Map<String, dynamic> json) {
    return PaymentEntry(
      id: json['id']?.toString(),
      flow: json['flow']?.toString() == MoneyFlow.send.name ? MoneyFlow.send : MoneyFlow.receive,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      client: json['client']?.toString() ?? '',
      project: json['project']?.toString() ?? '',
      estimateId: json['estimateId']?.toString(),
      installmentId: json['installmentId']?.toString(),
      method: json['method']?.toString() ?? 'UPI',
      party: json['party']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }
}

class ProjectAccount {
  const ProjectAccount({
    required this.client,
    required this.project,
    required this.installments,
    required this.entries,
  });

  final String client;
  final String project;
  final List<PaymentInstallment> installments;
  final List<PaymentEntry> entries;

  String get key => projectAccountKey(client, project);

  double get scheduled => installments.fold(0, (sum, item) => sum + item.amount);
  double get received =>
      entries.where((item) => item.flow == MoneyFlow.receive).fold(0, (sum, item) => sum + item.amount);
  double get sent =>
      entries.where((item) => item.flow == MoneyFlow.send).fold(0, (sum, item) => sum + item.amount);
  double get outstanding => ((scheduled - received) * 100).round() / 100;
  double get balance => ((received - sent) * 100).round() / 100;
}

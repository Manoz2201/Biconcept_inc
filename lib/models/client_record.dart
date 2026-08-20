enum CrmStage {
  lead,
  contacted,
  siteVisit,
  quotation,
  negotiation,
  won,
  lost;

  String get label => switch (this) {
        lead => 'Lead',
        contacted => 'Contacted',
        siteVisit => 'Site visit',
        quotation => 'Quotation',
        negotiation => 'Negotiation',
        won => 'Won',
        lost => 'Lost',
      };

  static CrmStage fromName(String? value) {
    return CrmStage.values.firstWhere(
      (stage) => stage.name == value,
      orElse: () => CrmStage.lead,
    );
  }
}

class ClientFollowUp {
  ClientFollowUp({
    String? id,
    DateTime? date,
    this.nextFollow,
    this.kind = 'Call',
    this.note = '',
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        date = date ?? DateTime.now();

  final String id;
  DateTime date;
  DateTime? nextFollow;
  String kind;
  String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'nextFollow': nextFollow?.toIso8601String(),
        'kind': kind,
        'note': note,
      };

  factory ClientFollowUp.fromJson(Map<String, dynamic> json) {
    return ClientFollowUp(
      id: json['id']?.toString(),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      nextFollow: DateTime.tryParse(json['nextFollow']?.toString() ?? ''),
      kind: json['kind']?.toString() ?? 'Call',
      note: json['note']?.toString() ?? '',
    );
  }
}

class ClientRecord {
  ClientRecord({
    String? id,
    this.name = '',
    this.phone = '',
    this.email = '',
    this.company = '',
    this.project = '',
    this.address = '',
    this.source = '',
    this.stage = CrmStage.lead,
    this.notes = '',
    List<ClientFollowUp>? followUps,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        followUps = followUps ?? <ClientFollowUp>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  String phone;
  String email;
  String company;
  String project;
  String address;
  String source;
  CrmStage stage;
  String notes;
  List<ClientFollowUp> followUps;
  DateTime createdAt;
  DateTime updatedAt;

  DateTime? get nextFollow {
    final upcoming = followUps
        .map((item) => item.nextFollow)
        .whereType<DateTime>()
        .where((date) => !date.isBefore(DateTime.now().subtract(const Duration(days: 1))))
        .toList()
      ..sort();
    if (upcoming.isNotEmpty) return upcoming.first;
    final all = followUps.map((item) => item.nextFollow).whereType<DateTime>().toList()..sort();
    return all.isEmpty ? null : all.last;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'company': company,
        'project': project,
        'address': address,
        'source': source,
        'stage': stage.name,
        'notes': notes,
        'followUps': [for (final item in followUps) item.toJson()],
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ClientRecord.fromJson(Map<String, dynamic> json) {
    return ClientRecord(
      id: clientIdFromJson(json),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      project: json['project']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      stage: CrmStage.fromName(json['stage']?.toString()),
      notes: json['notes']?.toString() ?? '',
      followUps: [
        for (final item in json['followUps'] as List? ?? const [])
          if (item is Map) ClientFollowUp.fromJson(Map<String, dynamic>.from(item)),
      ],
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

String? clientIdFromJson(Map<dynamic, dynamic> json) {
  for (final key in ['id', r'$id']) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return null;
}

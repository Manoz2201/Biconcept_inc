import 'package:flutter/foundation.dart';

import 'estimate_models.dart';
import 'terms_and_conditions.dart';

enum LineSource { catalog, agent, user, custom }

enum EstimateStatus {
  drafted,
  completed,
  finalized;

  String get label => switch (this) {
        drafted => 'Drafted',
        completed => 'Completed',
        finalized => 'Finalized',
      };

  static EstimateStatus fromName(String? value) {
    switch (value?.toLowerCase()) {
      case 'completed':
      case 'complete':
        return EstimateStatus.completed;
      case 'finalized':
      case 'final':
        return EstimateStatus.finalized;
      default:
        return EstimateStatus.drafted;
    }
  }
}

const defaultEstimateType = 'Interior Estimate';
const presetEstimateTypes = [
  'Interior Estimate',
  'Design',
  'Construction TurnKey Estimate',
];

String normalizeEstimateType(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? defaultEstimateType : trimmed;
}

class EstimateTotals {
  const EstimateTotals({
    required this.otherTaxable,
    required this.hvacTaxable,
    required this.gst18,
    required this.gst28,
    required this.grandTotal,
  });

  final double otherTaxable;
  final double hvacTaxable;
  final double gst18;
  final double gst28;

  double get subtotal => otherTaxable + hvacTaxable;
  double get gst => gst18 + gst28;
  final double grandTotal;
}

class EstimateLine {
  EstimateLine({
    required this.id,
    required this.workTypeId,
    required this.workType,
    required this.serialNo,
    required this.scopeId,
    required this.name,
    required this.description,
    required this.unit,
    this.area,
    this.areaCode,
    this.workScopeCode,
    this.quantity,
    this.suggestedQuantity,
    this.quantityConfirmed = false,
    this.unitRate,
    this.source = LineSource.catalog,
    this.custom = false,
    this.agentReason,
  });

  final String id;
  String workTypeId;
  String workType;
  int serialNo;
  String? area;
  String? areaCode;
  String scopeId;
  String? workScopeCode;
  String name;
  String description;
  String unit;
  double? quantity;
  double? suggestedQuantity;
  bool quantityConfirmed;
  double? unitRate;
  LineSource source;
  bool custom;
  String? agentReason;

  double? get effectiveQuantity => quantityConfirmed ? quantity : (quantity ?? suggestedQuantity);

  double get amount {
    final qty = effectiveQuantity;
    final rate = unitRate;
    if (qty == null || rate == null) return 0;
    return qty * rate;
  }

  bool get isHvac => workType.toLowerCase() == 'hvac' || name.toLowerCase().contains('ahu');

  Map<String, dynamic> toJson() => {
        'id': id,
        'workTypeId': workTypeId,
        'workType': workType,
        'serialNo': serialNo,
        'area': area,
        'areaCode': areaCode,
        'scopeId': scopeId,
        'workScopeCode': workScopeCode,
        'name': name,
        'description': description,
        'unit': unit,
        'quantity': quantity,
        'suggestedQuantity': suggestedQuantity,
        'quantityConfirmed': quantityConfirmed,
        'unitRate': unitRate,
        'source': source.name,
        'custom': custom,
        'agentReason': agentReason,
      };

  factory EstimateLine.fromJson(Map<String, dynamic> json) {
    return EstimateLine(
      id: json['id']?.toString() ?? '',
      workTypeId: json['workTypeId']?.toString() ?? '',
      workType: json['workType']?.toString() ?? '',
      serialNo: (json['serialNo'] as num?)?.toInt() ?? 0,
      area: json['area']?.toString(),
      areaCode: json['areaCode']?.toString(),
      scopeId: json['scopeId']?.toString() ?? '',
      workScopeCode: json['workScopeCode']?.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble(),
      suggestedQuantity: (json['suggestedQuantity'] as num?)?.toDouble(),
      quantityConfirmed: json['quantityConfirmed'] == true,
      unitRate: (json['unitRate'] as num?)?.toDouble(),
      source: LineSource.values.firstWhere(
        (value) => value.name == json['source'],
        orElse: () => LineSource.catalog,
      ),
      custom: json['custom'] == true,
      agentReason: json['agentReason']?.toString(),
    );
  }

  factory EstimateLine.fromScope({
    required WorkTypeSummary type,
    required WorkScope scope,
    String? area,
    String? areaCode,
    String? lineId,
    double? quantity,
  }) {
    return EstimateLine(
      id: lineId ??
          '${type.id}_${scope.id}_${area ?? 'na'}_${DateTime.now().microsecondsSinceEpoch}',
      workTypeId: type.id,
      workType: type.name,
      serialNo: type.serialNo,
      area: area,
      areaCode: areaCode,
      scopeId: scope.id,
      workScopeCode: scope.code,
      name: scope.name,
      description: scope.description,
      unit: scope.unit,
      quantity: quantity,
      suggestedQuantity: quantity,
      quantityConfirmed: quantity != null,
      unitRate: scope.suggestedRate,
      source: scope.userAdded ? LineSource.custom : LineSource.catalog,
      custom: scope.userAdded,
    );
  }
}

class LineProposal {
  const LineProposal({
    required this.lineId,
    this.quantity,
    this.unitRate,
    this.description,
    this.confidence,
    this.reason,
    this.applyQuantity = false,
  });

  final String lineId;
  final double? quantity;
  final double? unitRate;
  final String? description;
  final String? confidence;
  final String? reason;
  final bool applyQuantity;
}

class EstimateDraft extends ChangeNotifier {
  EstimateDraft({
    String? id,
    this.client = '',
    this.project = '',
    DateTime? date,
    this.carpetArea,
    this.brand = 'Biconcept Architects & Interiors',
    this.companyAddress = '',
    this.companyPhone = '',
    this.estimateType = defaultEstimateType,
    List<EstimateLine>? lines,
    List<String>? paymentTerms,
    List<String>? exclusions,
    List<String>? notes,
    List<String>? termsAndConditions,
    this.gstPercent = 18,
    this.hvacGstPercent = 28,
    this.status = EstimateStatus.drafted,
    DateTime? updatedAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        date = date ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        lines = lines ?? <EstimateLine>[],
        paymentTerms = paymentTerms ?? <String>[],
        exclusions = exclusions ?? <String>[],
        notes = notes ?? <String>[],
        termsAndConditions = termsAndConditions ?? <String>[];

  String id;
  String client;
  String project;
  DateTime date;
  DateTime updatedAt;
  EstimateStatus status;
  double? carpetArea;
  String brand;
  String companyAddress;
  String companyPhone;
  String estimateType;
  final List<EstimateLine> lines;
  List<String> paymentTerms;
  List<String> exclusions;
  List<String> notes;
  List<String> termsAndConditions;
  double gstPercent;
  double hvacGstPercent;

  EstimateTotals get totals {
    var other = 0.0;
    var hvac = 0.0;
    for (final line in lines) {
      if (line.isHvac) {
        hvac += line.amount;
      } else {
        other += line.amount;
      }
    }
    final gst18 = _round2(other * (gstPercent / 100));
    final gst28 = _round2(hvac * (hvacGstPercent / 100));
    return EstimateTotals(
      otherTaxable: _round2(other),
      hvacTaxable: _round2(hvac),
      gst18: gst18,
      gst28: gst28,
      grandTotal: _round2(other + hvac + gst18 + gst28),
    );
  }

  void replaceLines(List<EstimateLine> next) {
    lines
      ..clear()
      ..addAll(next);
    _assignCodes();
    notifyListeners();
  }

  void addLine(EstimateLine line) {
    lines.add(line);
    _assignCodes();
    notifyListeners();
  }

  void removeLine(String lineId) {
    lines.removeWhere((line) => line.id == lineId);
    _assignCodes();
    notifyListeners();
  }

  void updateLine(String lineId, void Function(EstimateLine line) update, {bool notify = true}) {
    final line = lines.cast<EstimateLine?>().firstWhere(
          (item) => item?.id == lineId,
          orElse: () => null,
        );
    if (line == null) return;
    update(line);
    if (notify) notifyListeners();
  }

  void applyProposal(LineProposal proposal, {required WorkScope? scope}) {
    updateLine(proposal.lineId, (line) {
      if (proposal.description != null && proposal.description!.trim().isNotEmpty) {
        line.description = proposal.description!.trim();
      }
      if (proposal.unitRate != null) {
        var rate = proposal.unitRate!;
        if (scope != null) {
          if (scope.minRate != null && rate < scope.minRate!) rate = scope.minRate!;
          if (scope.maxRate != null && rate > scope.maxRate!) rate = scope.maxRate!;
        }
        line.unitRate = rate;
      }
      if (proposal.quantity != null) {
        line.suggestedQuantity = proposal.quantity;
        if (proposal.applyQuantity) {
          line.quantity = proposal.quantity;
          line.quantityConfirmed = false;
        }
      }
      if (proposal.reason != null) line.agentReason = proposal.reason;
      line.source = LineSource.agent;
    });
  }

  void confirmQuantity(String lineId) {
    updateLine(lineId, (line) {
      line.quantity ??= line.suggestedQuantity;
      line.quantityConfirmed = line.quantity != null;
      if (line.quantityConfirmed) line.source = LineSource.user;
    });
  }

  List<String> get effectiveTerms => effectiveTermsAndConditions(
        termsAndConditions: termsAndConditions,
        paymentTerms: paymentTerms,
        exclusions: exclusions,
        notes: notes,
      );

  void setTermsAndConditions(Iterable<String> value) {
    termsAndConditions = sanitizeTerms(value);
    markChanged();
  }

  void markChanged() {
    updatedAt = DateTime.now();
    notifyListeners();
  }

  void confirmAllQuantities() {
    for (final line in lines) {
      line.quantity ??= line.suggestedQuantity;
      if (line.quantity != null) {
        line.quantityConfirmed = true;
        line.source = LineSource.user;
      }
    }
    notifyListeners();
  }

  String get estimateTypeHeading => normalizeEstimateType(estimateType).toUpperCase();

  void setEstimateType(String value) {
    estimateType = normalizeEstimateType(value);
    markChanged();
  }

  void setStatus(EstimateStatus value) {
    status = value;
    updatedAt = DateTime.now();
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'client': client,
        'project': project,
        'date': date.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'status': status.name,
        'carpetArea': carpetArea,
        'brand': brand,
        'companyAddress': companyAddress,
        'companyPhone': companyPhone,
        'estimateType': estimateType,
        'gstPercent': gstPercent,
        'hvacGstPercent': hvacGstPercent,
        'paymentTerms': paymentTerms,
        'exclusions': exclusions,
        'notes': notes,
        'termsAndConditions': termsAndConditions,
        'lines': [for (final line in lines) line.toJson()],
      };

  factory EstimateDraft.fromJson(Map<String, dynamic> json) {
    return EstimateDraft(
      id: json['id']?.toString(),
      client: json['client']?.toString() ?? '',
      project: json['project']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.now(),
      status: EstimateStatus.fromName(json['status']?.toString()),
      carpetArea: (json['carpetArea'] as num?)?.toDouble(),
      brand: json['brand']?.toString() ?? 'Biconcept Architects & Interiors',
      companyAddress: json['companyAddress']?.toString() ?? '',
      companyPhone: json['companyPhone']?.toString() ?? '',
      estimateType: normalizeEstimateType(json['estimateType']?.toString()),
      gstPercent: (json['gstPercent'] as num?)?.toDouble() ?? 18,
      hvacGstPercent: (json['hvacGstPercent'] as num?)?.toDouble() ?? 28,
      paymentTerms: [
        for (final item in json['paymentTerms'] as List? ?? const []) item.toString(),
      ],
      exclusions: [
        for (final item in json['exclusions'] as List? ?? const []) item.toString(),
      ],
      notes: [
        for (final item in json['notes'] as List? ?? const []) item.toString(),
      ],
      termsAndConditions: [
        for (final item in json['termsAndConditions'] as List? ?? const []) item.toString(),
      ],
      lines: [
        for (final item in json['lines'] as List? ?? const [])
          if (item is Map) EstimateLine.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  void normalizeScopeSeries({bool notify = false}) {
    _assignCodes();
    if (notify) notifyListeners();
  }

  void _assignCodes() {
    final typeOrder = <String>[];
    final grouped = <String, List<EstimateLine>>{};
    for (final line in lines) {
      final key = line.workTypeId.isNotEmpty ? line.workTypeId : 'name:${line.workType}';
      if (!grouped.containsKey(key)) {
        typeOrder.add(key);
        grouped[key] = [];
      }
      grouped[key]!.add(line);
    }
    typeOrder.sort((a, b) {
      final left = grouped[a]!.first;
      final right = grouped[b]!.first;
      final bySerial = left.serialNo.compareTo(right.serialNo);
      if (bySerial != 0) return bySerial;
      return left.workType.toLowerCase().compareTo(right.workType.toLowerCase());
    });

    final sorted = <EstimateLine>[];
    var areaSeq = 0;
    final areaIndex = <String, int>{};
    for (final key in typeOrder) {
      final group = grouped[key]!;
      group.sort(compareEstimateLines);
      for (var i = 0; i < group.length; i++) {
        final line = group[i];
        line.workScopeCode = estimateScopeLetter(i);
        if (line.workType.toLowerCase() == 'furniture' && line.area != null) {
          final areaKey = line.area!;
          if (!areaIndex.containsKey(areaKey)) {
            areaIndex[areaKey] = areaSeq;
            areaSeq += 1;
          }
          line.areaCode = '${line.serialNo}${String.fromCharCode(65 + areaIndex[areaKey]!)}';
        }
        sorted.add(line);
      }
    }
    lines
      ..clear()
      ..addAll(sorted);
  }
}

double _round2(double value) => (value * 100).roundToDouble() / 100;

int compareEstimateLines(EstimateLine a, EstimateLine b) {
  final byCode = _scopeCodeRank(a.workScopeCode).compareTo(_scopeCodeRank(b.workScopeCode));
  if (byCode != 0) return byCode;
  final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  if (byName != 0) return byName;
  return (a.area ?? '').toLowerCase().compareTo((b.area ?? '').toLowerCase());
}

int _scopeCodeRank(String? code) {
  final value = (code ?? '').trim().toUpperCase();
  if (value.isEmpty) return 1 << 20;
  var rank = 0;
  for (final unit in value.codeUnits) {
    if (unit < 65 || unit > 90) return (1 << 20) + value.hashCode.abs() % 100000;
    rank = rank * 26 + (unit - 64);
  }
  return rank;
}

String estimateScopeLetter(int index) {
  if (index < 26) return String.fromCharCode(65 + index);
  return '${estimateScopeLetter(index ~/ 26 - 1)}${String.fromCharCode(65 + index % 26)}';
}

double? median(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

double? suggestQuantity({
  required WorkScope scope,
  double? carpetArea,
  String? area,
}) {
  final unit = scope.unit.toLowerCase();
  if (unit == 'lumpsum' || unit.isEmpty) return 1;
  var samples = scope.samples;
  if (area != null) {
    final areaSamples = samples.where((sample) => sample.area == area).toList();
    if (areaSamples.isNotEmpty) samples = areaSamples;
  }
  final quantities = [
    for (final sample in samples)
      if (sample.quantity != null && sample.quantity! > 0) sample.quantity!,
  ];
  final mid = median(quantities);
  const referenceCarpet = 4000.0;
  if (unit == 'sqft' && carpetArea != null && carpetArea > 0) {
    if (mid != null && mid >= 80) {
      return (mid * (carpetArea / referenceCarpet)).roundToDouble();
    }
    return carpetArea.roundToDouble();
  }
  if (mid != null) return mid.roundToDouble();
  if (unit == 'pcs' || unit == 'seat' || unit == 'step') return 1;
  return null;
}

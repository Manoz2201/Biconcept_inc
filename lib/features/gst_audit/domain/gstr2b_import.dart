enum GSTR2BStatus {
  imported('imported', 'Imported'),
  reconciling('reconciling', 'Reconciling'),
  reconciled('reconciled', 'Reconciled'),
  filed('filed', 'Filed');

  const GSTR2BStatus(this.value, this.label);
  final String value;
  final String label;

  static GSTR2BStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => GSTR2BStatus.imported,
      );
}

class GSTR2BImport {
  const GSTR2BImport({
    required this.id,
    required this.financialYear,
    required this.period,
    required this.importDate,
    required this.fileName,
    required this.fileId,
    required this.totalRecords,
    this.matchedRecords = 0,
    this.mismatchedRecords = 0,
    this.missingInBooks = 0,
    this.missingIn2b = 0,
    required this.totalTaxableValue,
    this.totalCgst = 0,
    this.totalSgst = 0,
    this.totalIgst = 0,
    required this.status,
    this.reconciledAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String financialYear;
  final String period;
  final DateTime importDate;
  final String fileName;
  final String fileId;
  final int totalRecords;
  final int matchedRecords;
  final int mismatchedRecords;
  final int missingInBooks;
  final int missingIn2b;
  final double totalTaxableValue;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final GSTR2BStatus status;
  final DateTime? reconciledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'financialYear': financialYear,
        'period': period,
        'importDate': importDate.toIso8601String(),
        'fileName': fileName,
        'fileId': fileId,
        'totalRecords': totalRecords,
        'matchedRecords': matchedRecords,
        'mismatchedRecords': mismatchedRecords,
        'missingInBooks': missingInBooks,
        'missingIn2b': missingIn2b,
        'totalTaxableValue': totalTaxableValue,
        'totalCgst': totalCgst,
        'totalSgst': totalSgst,
        'totalIgst': totalIgst,
        'status': status.value,
        'reconciledAt': ?reconciledAt?.toIso8601String(),
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory GSTR2BImport.fromJson(Map<String, dynamic> data) => GSTR2BImport(
        id: data['id']?.toString() ?? '',
        financialYear: data['financialYear']?.toString() ?? '',
        period: data['period']?.toString() ?? '',
        importDate: DateTime.tryParse(data['importDate']?.toString() ?? '') ?? DateTime.now(),
        fileName: data['fileName']?.toString() ?? '',
        fileId: data['fileId']?.toString() ?? '',
        totalRecords: (data['totalRecords'] as num?)?.toInt() ?? 0,
        matchedRecords: (data['matchedRecords'] as num?)?.toInt() ?? 0,
        mismatchedRecords: (data['mismatchedRecords'] as num?)?.toInt() ?? 0,
        missingInBooks: (data['missingInBooks'] as num?)?.toInt() ?? 0,
        missingIn2b: (data['missingIn2b'] as num?)?.toInt() ?? 0,
        totalTaxableValue: (data['totalTaxableValue'] as num?)?.toDouble() ?? 0,
        totalCgst: (data['totalCgst'] as num?)?.toDouble() ?? 0,
        totalSgst: (data['totalSgst'] as num?)?.toDouble() ?? 0,
        totalIgst: (data['totalIgst'] as num?)?.toDouble() ?? 0,
        status: GSTR2BStatus.fromString(data['status']?.toString()),
        reconciledAt: DateTime.tryParse(data['reconciledAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

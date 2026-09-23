enum BudgetCategory {
  revenue('revenue', 'Revenue'),
  expense('expense', 'Expense'),
  capital('capital', 'Capital');

  const BudgetCategory(this.value, this.label);
  final String value;
  final String label;

  static BudgetCategory fromString(String? raw) => values.firstWhere(
        (item) => item.value == raw || item.name == raw,
        orElse: () => BudgetCategory.expense,
      );
}

enum BudgetStatus {
  draft('draft', 'Draft'),
  approved('approved', 'Approved'),
  active('active', 'Active'),
  closed('closed', 'Closed');

  const BudgetStatus(this.value, this.label);
  final String value;
  final String label;

  static BudgetStatus fromString(String? raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => BudgetStatus.draft,
      );
}

class Budget {
  const Budget({
    required this.id,
    required this.financialYear,
    this.projectId,
    required this.category,
    this.subCategory,
    this.period,
    required this.budgetedAmount,
    this.actualAmount = 0,
    this.variance,
    this.variancePercent,
    this.notes,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String financialYear;
  final String? projectId;
  final BudgetCategory category;
  final String? subCategory;
  final String? period;
  final double budgetedAmount;
  final double actualAmount;
  final double? variance;
  final double? variancePercent;
  final String? notes;
  final BudgetStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'financialYear': financialYear,
        'projectId': ?projectId,
        'category': category.value,
        'subCategory': ?subCategory,
        'period': ?period,
        'budgetedAmount': budgetedAmount,
        'actualAmount': actualAmount,
        'variance': ?variance,
        'variancePercent': ?variancePercent,
        'notes': ?notes,
        'status': status.value,
        'approvedBy': ?approvedBy,
        'approvedAt': ?approvedAt?.toIso8601String(),
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory Budget.fromJson(Map<String, dynamic> data) => Budget(
        id: data['id']?.toString() ?? '',
        financialYear: data['financialYear']?.toString() ?? '',
        projectId: data['projectId']?.toString(),
        category: BudgetCategory.fromString(data['category']?.toString()),
        subCategory: data['subCategory']?.toString(),
        period: data['period']?.toString(),
        budgetedAmount: (data['budgetedAmount'] as num?)?.toDouble() ?? 0,
        actualAmount: (data['actualAmount'] as num?)?.toDouble() ?? 0,
        variance: (data['variance'] as num?)?.toDouble(),
        variancePercent: (data['variancePercent'] as num?)?.toDouble(),
        notes: data['notes']?.toString(),
        status: BudgetStatus.fromString(data['status']?.toString()),
        approvedBy: data['approvedBy']?.toString(),
        approvedAt: DateTime.tryParse(data['approvedAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

class BudgetVsActual {
  const BudgetVsActual({required this.rows, required this.budgeted, required this.actual, required this.variance});

  final List<Budget> rows;
  final double budgeted;
  final double actual;
  final double variance;
}

class VarianceAlert {
  const VarianceAlert({required this.budget, required this.message});

  final Budget budget;
  final String message;
}

enum ForecastType {
  revenue('revenue', 'Revenue'),
  expense('expense', 'Expense'),
  cashflow('cashflow', 'Cashflow'),
  profit('profit', 'Profit');

  const ForecastType(this.value, this.label);
  final String value;
  final String label;

  static ForecastType fromString(String? raw) => values.firstWhere(
        (type) => type.value == raw || type.name == raw,
        orElse: () => ForecastType.revenue,
      );
}

class FinancialForecast {
  const FinancialForecast({
    required this.id,
    required this.financialYear,
    required this.forecastType,
    required this.forecastPeriod,
    required this.forecastData,
    this.assumptions,
    this.confidenceLevel,
    this.baseScenario,
    this.bestCaseScenario,
    this.worstCaseScenario,
    this.notes,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String financialYear;
  final ForecastType forecastType;
  final String forecastPeriod;
  final String forecastData;
  final String? assumptions;
  final String? confidenceLevel;
  final String? baseScenario;
  final String? bestCaseScenario;
  final String? worstCaseScenario;
  final String? notes;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'financialYear': financialYear,
        'forecastType': forecastType.value,
        'forecastPeriod': forecastPeriod,
        'forecastData': forecastData,
        'assumptions': ?assumptions,
        'confidenceLevel': ?confidenceLevel,
        'baseScenario': ?baseScenario,
        'bestCaseScenario': ?bestCaseScenario,
        'worstCaseScenario': ?worstCaseScenario,
        'notes': ?notes,
        'createdBy': createdBy,
        'createdAt': ?createdAt?.toIso8601String(),
        'updatedAt': ?updatedAt?.toIso8601String(),
      };

  factory FinancialForecast.fromJson(Map<String, dynamic> data) => FinancialForecast(
        id: data['id']?.toString() ?? '',
        financialYear: data['financialYear']?.toString() ?? '',
        forecastType: ForecastType.fromString(data['forecastType']?.toString()),
        forecastPeriod: data['forecastPeriod']?.toString() ?? '',
        forecastData: data['forecastData']?.toString() ?? '[]',
        assumptions: data['assumptions']?.toString(),
        confidenceLevel: data['confidenceLevel']?.toString(),
        baseScenario: data['baseScenario']?.toString(),
        bestCaseScenario: data['bestCaseScenario']?.toString(),
        worstCaseScenario: data['worstCaseScenario']?.toString(),
        notes: data['notes']?.toString(),
        createdBy: data['createdBy']?.toString() ?? '',
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );
}

class CashflowProjection {
  const CashflowProjection({
    required this.months,
    required this.rows,
    required this.hasNegativeMonth,
  });

  final int months;
  final List<CashflowProjectionRow> rows;
  final bool hasNegativeMonth;
}

class CashflowProjectionRow {
  const CashflowProjectionRow({
    required this.period,
    required this.cashIn,
    required this.cashOut,
    required this.net,
    required this.closing,
  });

  final String period;
  final double cashIn;
  final double cashOut;
  final double net;
  final double closing;
}

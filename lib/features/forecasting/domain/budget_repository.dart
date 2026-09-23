import '../../../core/result/app_result.dart';
import 'budget.dart';

abstract class BudgetRepository {
  Future<AppResult<List<Budget>>> getBudgets({String? financialYear, String? projectId, BudgetStatus? status});

  Future<AppResult<Budget>> getBudgetById(String id);

  Future<AppResult<Budget>> createBudget({
    required String financialYear,
    required BudgetCategory category,
    required double budgetedAmount,
    String? subCategory,
    String? projectId,
    String? period,
    String? notes,
  });

  Future<AppResult<Budget>> updateBudget(String id, Map<String, dynamic> data);

  Future<AppResult<Budget>> approveBudget(String id, String approverId);

  Future<AppResult<Budget>> activateBudget(String id);

  Future<AppResult<Budget>> closeBudget(String id);

  Future<AppResult<Budget>> updateActuals(String id, double actualAmount);

  Future<AppResult<BudgetVsActual>> getBudgetVsActual(String financialYear);

  Future<AppResult<List<VarianceAlert>>> getVarianceAnalysis(String financialYear);
}

abstract class ForecastRepository {
  Future<AppResult<List<FinancialForecast>>> getForecasts({String? financialYear, ForecastType? forecastType});

  Future<AppResult<FinancialForecast>> getForecastById(String id);

  Future<AppResult<FinancialForecast>> createForecast({
    required String financialYear,
    required ForecastType forecastType,
    required String forecastPeriod,
    required String forecastData,
    String? assumptions,
    String? confidenceLevel,
    String? baseScenario,
    String? bestCaseScenario,
    String? worstCaseScenario,
    String? notes,
  });

  Future<AppResult<FinancialForecast>> updateForecast(String id, Map<String, dynamic> data);

  Future<AppResult<String>> generateRevenueForecast(int months, {double monthlyGrowth = 0.05});

  Future<AppResult<String>> generateExpenseForecast(int months, {double annualInflation = 0.03});

  Future<AppResult<String>> generateCashflowForecast(int months);

  Future<AppResult<String>> generateProfitForecast(int months);

  Future<AppResult<CashflowProjection>> getCashflowProjection(int months);
}

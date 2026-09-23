import '../../../core/result/app_result.dart';
import '../../catalog/domain/storage_repository.dart';
import 'expense.dart';

abstract class ExpenseRepository {
  Future<AppResult<List<Expense>>> getExpenses({
    String? projectId,
    ExpenseCategory? category,
    ExpenseStatus? status,
    DateTime? from,
    DateTime? to,
  });

  Future<AppResult<Expense>> getExpenseById(String id);

  Future<AppResult<Expense>> createExpense({
    required String description,
    required double amount,
    required DateTime expenseDate,
    required ExpenseCategory category,
    String? projectId,
    String? vendorId,
    double gstAmount = 0,
    String? paymentMethod,
    UploadBytes? receipt,
    String? notes,
  });

  Future<AppResult<Expense>> updateExpense(String id, Map<String, dynamic> data);

  Future<AppResult<Expense>> submitExpense(String id);

  Future<AppResult<Expense>> approveExpense(String id, String approverId);

  Future<AppResult<Expense>> rejectExpense(String id, String reason);

  Future<AppResult<Expense>> reimburseExpense(String id);

  Future<AppResult<Map<ExpenseCategory, double>>> getExpenseSummary(DateTime from, DateTime to);
}

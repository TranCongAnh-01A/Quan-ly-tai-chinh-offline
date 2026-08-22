import 'package:isar/isar.dart';

import '../../services/database_service.dart';
import '../models/expense.dart';
import '../models/fixed_expense.dart';

/// Repository cho chi tiêu cố định — CRUD template + execute thanh toán.
///
/// Tại sao tách repo riêng thay vì nhồi vào ExpenseRepository:
///   - FixedExpense và Expense là 2 collection khác nhau
///   - Mỗi repo chỉ chịu trách nhiệm 1 collection (Single Responsibility)
///   - executeFixedExpense() chạm cả 2 collection nhưng logic chính là
///     "chuyển template thành giao dịch" → thuộc về FixedExpenseRepo
class FixedExpenseRepository {
  Isar get _db => DatabaseService.instance;

  /// Thêm template chi tiêu cố định mới.
  Future<void> add(FixedExpense template) async {
    await _db.writeTxn(() => _db.fixedExpenses.put(template));
  }

  /// Cập nhật template.
  Future<void> update(FixedExpense template) async {
    await _db.writeTxn(() => _db.fixedExpenses.put(template));
  }

  /// Xóa template theo ID.
  Future<void> delete(int id) async {
    await _db.writeTxn(() => _db.fixedExpenses.delete(id));
  }

  /// Lấy tất cả template, sắp xếp theo thời gian tạo.
  Future<List<FixedExpense>> getAll() async {
    return _db.fixedExpenses.where().sortByCreatedAt().findAll();
  }

  /// Thực thi thanh toán — clone template thành Expense thật.
  ///
  /// Luồng:
  ///   1. Nhận template FixedExpense
  ///   2. Tạo Expense mới với date = bây giờ, isIncome = false
  ///   3. Ghi vào Isar trong 1 transaction
  ///   4. Isar watcher của ExpenseCubit tự động trigger reload
  Future<void> executeFixedExpense(FixedExpense template, {FundingSource source = FundingSource.cash}) async {
    final expense = Expense()
      ..amount = template.amount
      ..category = template.categoryId
      ..date = DateTime.now()
      ..isIncome = false
      ..note = template.note ?? template.title
      ..createdAt = DateTime.now()
      ..isFixed = true
      ..source = source;

    await _db.writeTxn(() => _db.expenses.put(expense));
  }

  /// Stream theo dõi thay đổi (khi thêm/xóa template).
  Stream<void> watchChanges() {
    return _db.fixedExpenses.watchLazy();
  }
}

import 'package:isar/isar.dart';

import '../../services/database_service.dart';
import '../models/budget.dart';

/// Repository cho hạn mức chi tiêu — CRUD + query theo tháng/danh mục.
///
/// Tại sao tách repo riêng:
///   - Budget là collection độc lập, logic query khác Expense
///   - Giữ ExpenseRepository tập trung vào giao dịch
class BudgetRepository {
  Isar get _db => DatabaseService.instance;

  /// Thêm hoặc cập nhật hạn mức cho danh mục trong tháng/năm.
  ///
  /// Nếu đã tồn tại budget cho categoryId + month + year → update.
  /// Nếu chưa → tạo mới.
  Future<void> upsert(Budget budget) async {
    // Tìm budget trùng danh mục + tháng + năm
    final existing = await _db.budgets
        .filter()
        .categoryIdEqualTo(budget.categoryId)
        .monthEqualTo(budget.month)
        .yearEqualTo(budget.year)
        .findFirst();

    if (existing != null) {
      budget.id = existing.id;
    }

    await _db.writeTxn(() => _db.budgets.put(budget));
  }

  /// Xóa hạn mức theo ID.
  Future<void> delete(int id) async {
    await _db.writeTxn(() => _db.budgets.delete(id));
  }

  /// Lấy tất cả hạn mức của tháng/năm cụ thể.
  Future<List<Budget>> getByMonth(int month, int year) async {
    return _db.budgets
        .filter()
        .monthEqualTo(month)
        .yearEqualTo(year)
        .findAll();
  }

  /// Lấy hạn mức của 1 danh mục trong tháng/năm.
  Future<Budget?> getByCategoryMonth(
    String categoryId,
    int month,
    int year,
  ) async {
    return _db.budgets
        .filter()
        .categoryIdEqualTo(categoryId)
        .monthEqualTo(month)
        .yearEqualTo(year)
        .findFirst();
  }

  /// Stream theo dõi thay đổi.
  Stream<void> watchChanges() {
    return _db.budgets.watchLazy();
  }
}

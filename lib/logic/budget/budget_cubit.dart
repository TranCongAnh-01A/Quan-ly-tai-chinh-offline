import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/budget.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/expense_repository.dart';
import 'budget_state.dart';

/// Cubit quản lý hạn mức chi tiêu.
///
/// Luồng:
///   1. loadBudgets(month, year) → query tất cả Budget + tính spending
///   2. Expense watcher → auto-reload khi có giao dịch mới
///   3. checkBudgetWarning(categoryId, amount, date: ...) → kiểm tra trước khi lưu
class BudgetCubit extends Cubit<BudgetState> {
  final BudgetRepository _budgetRepo;
  final ExpenseRepository _expenseRepo;
  StreamSubscription? _expenseWatcher;
  StreamSubscription? _budgetWatcher;

  int _currentMonth = DateTime.now().month;
  int _currentYear = DateTime.now().year;

  BudgetCubit({
    BudgetRepository? budgetRepository,
    ExpenseRepository? expenseRepository,
  })  : _budgetRepo = budgetRepository ?? BudgetRepository(),
        _expenseRepo = expenseRepository ?? ExpenseRepository(),
        super(const BudgetLoading()) {
    // Theo dõi thay đổi expenses → recalculate spending
    _expenseWatcher = _expenseRepo.watchChanges().listen((_) {
      _reload();
    });
    // Theo dõi thay đổi budgets → reload danh sách
    _budgetWatcher = _budgetRepo.watchChanges().listen((_) {
      _reload();
    });
  }

  /// Tải tất cả budget + tính spending cho tháng/năm.
  Future<void> loadBudgets([int? month, int? year]) async {
    try {
      if (month != null) _currentMonth = month;
      if (year != null) _currentYear = year;

      final budgets = await _budgetRepo.getByMonth(
        _currentMonth,
        _currentYear,
      );

      final progresses = <BudgetProgress>[];

      for (final budget in budgets) {
        final spending = await _expenseRepo.getCategorySpending(
          budget.categoryId,
          _currentMonth,
          _currentYear,
        );

        progresses.add(BudgetProgress(
          categoryId: budget.categoryId,
          amountLimit: budget.amountLimit,
          currentSpending: spending,
          budgetId: budget.id,
        ));
      }

      emit(BudgetLoaded(progresses: progresses));
    } catch (e) {
      emit(BudgetError('Lỗi tải hạn mức: $e'));
    }
  }

  /// Thêm/cập nhật hạn mức cho danh mục trong tháng hiện tại.
  Future<void> setBudget({
    required String categoryId,
    required double amountLimit,
  }) async {
    final budget = Budget()
      ..categoryId = categoryId
      ..amountLimit = amountLimit
      ..month = _currentMonth
      ..year = _currentYear;

    await _budgetRepo.upsert(budget);
    // Isar watcher sẽ trigger _reload()
  }

  /// Xóa hạn mức.
  Future<void> removeBudget(int id) async {
    await _budgetRepo.delete(id);
  }

  /// Kiểm tra cảnh báo TRƯỚC khi lưu expense.
  ///
  /// Trả về BudgetProgress nếu danh mục có budget và sẽ vượt ngưỡng,
  /// null nếu không cần cảnh báo.
  /// Kiểm tra cảnh báo hạn mức trước khi lưu giao dịch.
  ///
  /// [date] — ngày của giao dịch sắp lưu. Hạn mức được tra theo tháng/năm của
  /// ngày này, không phải tháng đang hiển thị. Bỏ trống → dùng tháng hiện tại.
  ///
  /// [oldAmount] — số tiền cũ (khi chỉnh sửa giao dịch), truyền 0 nếu thêm mới.
  /// Cần trừ đi để tránh double-count: currentSpending đã bao gồm oldAmount.
  /// [oldCategoryId] và [oldDate] — danh mục/ngày cũ của giao dịch đang sửa.
  /// Chỉ trừ [oldAmount] khi giao dịch cũ nằm trong CÙNG danh mục và CÙNG
  /// tháng đang kiểm tra — nếu không, oldAmount không có trong currentSpending
  /// nên trừ đi sẽ làm cảnh báo tính thiếu.
  Future<BudgetProgress?> checkBudgetWarning(
    String categoryId,
    double amount, {
    DateTime? date,
    double oldAmount = 0,
    String? oldCategoryId,
    DateTime? oldDate,
  }) async {
    final month = date?.month ?? _currentMonth;
    final year = date?.year ?? _currentYear;

    final budget = await _budgetRepo.getByCategoryMonth(
      categoryId,
      month,
      year,
    );

    if (budget == null) return null;

    final currentSpending = await _expenseRepo.getCategorySpending(
      categoryId,
      month,
      year,
    );

    final isSameCategory = oldCategoryId == null || oldCategoryId == categoryId;
    final isSameMonth =
        oldDate == null || (oldDate.month == month && oldDate.year == year);
    final deductible = (isSameCategory && isSameMonth) ? oldAmount : 0.0;

    final afterSpending = currentSpending - deductible + amount;
    final progress = BudgetProgress(
      categoryId: categoryId,
      amountLimit: budget.amountLimit,
      currentSpending: afterSpending,
      budgetId: budget.id,
    );

    // Chỉ cảnh báo nếu sẽ vượt ngưỡng 80%
    if (progress.ratio >= 0.8) return progress;

    return null;
  }

  Future<void> _reload() async {
    await loadBudgets();
  }

  @override
  Future<void> close() {
    _expenseWatcher?.cancel();
    _budgetWatcher?.cancel();
    return super.close();
  }
}

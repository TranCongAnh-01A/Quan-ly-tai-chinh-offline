import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/expense.dart';
import '../../data/repositories/expense_repository.dart';
import 'expense_state.dart';

/// Cubit quản lý state cho tính năng Chi tiêu.
///
/// Luồng hoạt động:
///   1. loadMonth() → query Isar theo tháng → emit ExpenseLoaded
///   2. add/update/delete → ghi Isar → tự động reload
///   3. watchChanges() → stream Isar → auto-refresh khi data thay đổi
class ExpenseCubit extends Cubit<ExpenseState> {
  final ExpenseRepository _repository;
  StreamSubscription? _watchSubscription;

  /// Tháng đang hiển thị (mặc định = tháng hiện tại)
  DateTime _selectedMonth = DateTime.now();

  ExpenseCubit({ExpenseRepository? repository})
      : _repository = repository ?? ExpenseRepository(),
        super(const ExpenseLoading()) {
    // Bắt đầu theo dõi thay đổi từ Isar
    _watchSubscription = _repository.watchChanges().listen((_) {
      _reload();
    });
  }

  /// Tải chi tiêu theo tháng được chọn.
  Future<void> loadMonth([DateTime? month]) async {
    try {
      if (month != null) _selectedMonth = month;

      final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59, 999, 999);

      final expenses = await _repository.getByDateRange(start, end);
      final totalExpense = await _repository.getTotalExpense(start, end);
      final totalIncome = await _repository.getTotalIncome(start, end);

      // Tính số dư lũy kế từ trước đến nay (không bao gồm tháng hiện tại)
      // Dùng Unix epoch (1970) làm mốc — đảm bảo lấy được mọi giao dịch cũ
      final pastStart = DateTime(1970);
      final pastEnd = start.subtract(const Duration(microseconds: 1));
      final pastIncome = await _repository.getTotalIncome(pastStart, pastEnd);
      final pastExpense = await _repository.getTotalExpense(pastStart, pastEnd);
      final carriedOverBalance = pastIncome - pastExpense;
      // Lấy toàn bộ giao dịch từ trước đến cuối tháng hiện tại để tính đúng quỹ
      final allExpensesUpToEnd = await _repository.getByDateRange(pastStart, end);
      double totalCash = 0;
      double totalBank = 0;
      
      for (final e in allExpensesUpToEnd) {
        if (e.isTransfer) {
          if (e.source == FundingSource.cash) {
            // Transfer from Cash -> Bank
            totalCash -= e.amount;
            totalBank += e.amount;
          } else {
            // Transfer from Bank -> Cash
            totalBank -= e.amount;
            totalCash += e.amount;
          }
        } else {
          final amount = e.isIncome ? e.amount : -e.amount;
          if (e.source == FundingSource.cash) {
            totalCash += amount;
          } else {
            totalBank += amount;
          }
        }
      }

      emit(ExpenseLoaded(
        expenses: expenses,
        totalExpense: totalExpense,
        totalIncome: totalIncome,
        totalCash: totalCash,
        totalBank: totalBank,
        carriedOverBalance: carriedOverBalance,
        selectedMonth: _selectedMonth,
      ));
    } catch (e) {
      emit(ExpenseError('Lỗi tải dữ liệu: $e'));
    }
  }

  /// Chuyển sang tháng trước.
  Future<void> previousMonth() async {
    final prev = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    await loadMonth(prev);
  }

  /// Chuyển sang tháng sau.
  Future<void> nextMonth() async {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    await loadMonth(next);
  }

  /// Thêm khoản chi tiêu/thu nhập mới.
  Future<void> addExpense({
    required double amount,
    required String category,
    required DateTime date,
    required bool isIncome,
    bool isTransfer = false,
    FundingSource source = FundingSource.cash,
    String? receiptImagePath,
    String? note,
  }) async {
    final expense = Expense()
      ..amount = amount
      ..category = category
      ..date = date
      ..isIncome = isIncome
      ..isTransfer = isTransfer
      ..source = source
      ..receiptImagePath = receiptImagePath
      ..note = note
      ..createdAt = DateTime.now();

    await _repository.add(expense);
    // Không cần emit thủ công — watchChanges() sẽ trigger _reload()
  }

  /// Cập nhật khoản chi tiêu đã tồn tại.
  Future<void> updateExpense(Expense expense) async {
    await _repository.update(expense);
  }

  /// Xóa khoản chi tiêu theo ID.
  Future<void> deleteExpense(int id) async {
    await _repository.delete(id);
  }

  /// Reload nội bộ — gọi bởi Isar watcher khi data thay đổi.
  Future<void> _reload() async {
    await loadMonth();
  }

  @override
  Future<void> close() {
    _watchSubscription?.cancel();
    return super.close();
  }
}

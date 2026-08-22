import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/receipt_storage.dart';
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

      // Dùng Unix epoch (1970) làm mốc — đảm bảo lấy được mọi giao dịch cũ
      final pastStart = DateTime(1970);

      // Một truy vấn duy nhất cho toàn bộ lịch sử tới hết tháng đang xem, rồi
      // duyệt 1 lượt tính mọi con số. Trước đây chỗ này chạy 6 truy vấn (2 lần
      // quét toàn bộ lịch sử + 4 truy vấn tổng), lặp lại sau MỖI lần ghi DB.
      final allUpToEnd = await _repository.getByDateRange(pastStart, end);

      final expenses = <Expense>[];
      double totalExpense = 0;
      double totalIncome = 0;
      double pastIncome = 0;
      double pastExpense = 0;
      double totalCash = 0;
      double totalBank = 0;

      for (final e in allUpToEnd) {
        // Query đã giới hạn <= end, nên chỉ cần so với mốc đầu tháng
        final isInSelectedMonth = !e.date.isBefore(start);
        if (isInSelectedMonth) expenses.add(e);

        if (e.isTransfer) {
          // Chuyển tiền nội bộ: đổi chỗ giữa 2 quỹ, không phải thu hay chi
          if (e.source == FundingSource.cash) {
            totalCash -= e.amount;
            totalBank += e.amount;
          } else {
            totalBank -= e.amount;
            totalCash += e.amount;
          }
          continue;
        }

        final signedAmount = e.isIncome ? e.amount : -e.amount;
        if (e.source == FundingSource.cash) {
          totalCash += signedAmount;
        } else {
          totalBank += signedAmount;
        }

        if (isInSelectedMonth) {
          if (e.isIncome) {
            totalIncome += e.amount;
          } else {
            totalExpense += e.amount;
          }
        } else {
          if (e.isIncome) {
            pastIncome += e.amount;
          } else {
            pastExpense += e.amount;
          }
        }
      }

      final carriedOverBalance = pastIncome - pastExpense;

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
  ///
  /// Xóa kèm ảnh hóa đơn đính kèm — nếu không, file ảnh ở lại thư mục
  /// documents vĩnh viễn mà không giao dịch nào tham chiếu tới.
  Future<void> deleteExpense(int id) async {
    final existing = await _repository.getById(id);

    await _repository.delete(id);

    if (existing?.receiptImagePath != null) {
      await ReceiptStorage.delete(existing!.receiptImagePath);
    }
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

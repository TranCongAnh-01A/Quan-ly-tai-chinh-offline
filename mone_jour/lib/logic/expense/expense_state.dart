import 'package:equatable/equatable.dart';

import '../../data/models/expense.dart';

/// Các trạng thái có thể có của ExpenseCubit.
///
/// Tại sao dùng sealed class thay enum:
///   - Mỗi state chứa data khác nhau (loading không cần list, loaded cần)
///   - Compiler bắt buộc xử lý tất cả cases trong switch
///   - Type-safe hơn so với dùng 1 class với nullable fields
sealed class ExpenseState extends Equatable {
  const ExpenseState();

  @override
  List<Object?> get props => [];
}

/// Đang tải dữ liệu lần đầu
class ExpenseLoading extends ExpenseState {
  const ExpenseLoading();
}

/// Đã tải xong — chứa danh sách chi tiêu + tổng hợp
class ExpenseLoaded extends ExpenseState {
  final List<Expense> expenses;
  final double totalExpense;
  final double totalIncome;
  final double totalCash;
  final double totalBank;
  final double carriedOverBalance;
  final DateTime selectedMonth;

  const ExpenseLoaded({
    required this.expenses,
    required this.totalExpense,
    required this.totalIncome,
    required this.totalCash,
    required this.totalBank,
    required this.carriedOverBalance,
    required this.selectedMonth,
  });

  /// Balance = Dư đầu kỳ + Thu nhập trong kỳ - Chi tiêu trong kỳ
  double get balance => carriedOverBalance + totalIncome - totalExpense;

  @override
  List<Object?> get props => [
        expenses,
        totalExpense,
        totalIncome,
        totalCash,
        totalBank,
        carriedOverBalance,
        selectedMonth,
      ];
}

/// Lỗi xảy ra khi truy vấn database
class ExpenseError extends ExpenseState {
  final String message;

  const ExpenseError(this.message);

  @override
  List<Object?> get props => [message];
}

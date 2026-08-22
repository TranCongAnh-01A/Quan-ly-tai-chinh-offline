import 'package:equatable/equatable.dart';
import '../../data/models/expense.dart';

enum FilterMode { month, year, custom }

sealed class StatsState extends Equatable {
  const StatsState();

  @override
  List<Object?> get props => [];
}

class StatsInitial extends StatsState {}

class StatsLoading extends StatsState {}

class StatsLoaded extends StatsState {
  final double totalExpense;
  final double totalIncome;
  // Tổng chi tiêu theo category
  final Map<String, double> expensesByCategory;
  // Thu nhập theo category
  final Map<String, double> incomesByCategory;
  
  final FilterMode filterMode;
  
  // Dùng cho mode Month
  final int? month;
  final int? year;

  // Dùng cho mode Custom
  final DateTime? startDate;
  final DateTime? endDate;

  // Danh sách giao dịch để phân trang
  final List<Expense> transactions;

  const StatsLoaded({
    required this.totalExpense,
    required this.totalIncome,
    required this.expensesByCategory,
    required this.incomesByCategory,
    required this.filterMode,
    this.month,
    this.year,
    this.startDate,
    this.endDate,
    required this.transactions,
  });

  @override
  List<Object?> get props => [
        totalExpense,
        totalIncome,
        expensesByCategory,
        incomesByCategory,
        filterMode,
        month,
        year,
        startDate,
        endDate,
        transactions,
      ];
}

class StatsError extends StatsState {
  final String message;

  const StatsError(this.message);

  @override
  List<Object?> get props => [message];
}

import 'package:equatable/equatable.dart';

import '../../data/models/fixed_expense.dart';

/// Các trạng thái của FixedExpenseCubit.
sealed class FixedExpenseState extends Equatable {
  const FixedExpenseState();

  @override
  List<Object?> get props => [];
}

/// Đang tải danh sách template
class FixedExpenseLoading extends FixedExpenseState {
  const FixedExpenseLoading();
}

/// Đã tải — chứa danh sách template chi tiêu cố định
class FixedExpenseLoaded extends FixedExpenseState {
  final List<FixedExpense> templates;

  const FixedExpenseLoaded({required this.templates});

  @override
  List<Object?> get props => [templates];
}

/// Lỗi
class FixedExpenseError extends FixedExpenseState {
  final String message;

  const FixedExpenseError(this.message);

  @override
  List<Object?> get props => [message];
}

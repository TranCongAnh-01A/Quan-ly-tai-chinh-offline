import 'package:equatable/equatable.dart';

/// Trạng thái tiến trình budget 1 danh mục.
///
/// Chứa đủ dữ liệu để UI vẽ progress bar + hiển thị cảnh báo.
class BudgetProgress extends Equatable {
  final String categoryId;
  final double amountLimit;
  final double currentSpending;
  final int budgetId;

  const BudgetProgress({
    required this.categoryId,
    required this.amountLimit,
    required this.currentSpending,
    required this.budgetId,
  });

  /// Tỷ lệ đã chi tiêu (0.0 → 1.0+). Có thể > 1.0 nếu vượt hạn mức.
  double get ratio =>
      amountLimit > 0 ? currentSpending / amountLimit : 0.0;

  /// Phần trăm (0 → 100+)
  int get percentage => (ratio * 100).round();

  /// Số tiền còn lại (âm = đã vượt)
  double get remaining => amountLimit - currentSpending;

  /// Trạng thái ngưỡng cảnh báo
  BudgetStatus get status {
    if (ratio >= 1.0) return BudgetStatus.exceeded;
    if (ratio >= 0.8) return BudgetStatus.warning;
    return BudgetStatus.safe;
  }

  @override
  List<Object?> get props => [categoryId, amountLimit, currentSpending, budgetId];
}

/// Mức độ cảnh báo budget
enum BudgetStatus { safe, warning, exceeded }

/// Các trạng thái của BudgetCubit.
sealed class BudgetState extends Equatable {
  const BudgetState();

  @override
  List<Object?> get props => [];
}

class BudgetLoading extends BudgetState {
  const BudgetLoading();
}

class BudgetLoaded extends BudgetState {
  final List<BudgetProgress> progresses;

  const BudgetLoaded({required this.progresses});

  /// Lấy progress theo categoryId (trả null nếu không set budget).
  BudgetProgress? getByCategory(String categoryId) {
    try {
      return progresses.firstWhere((p) => p.categoryId == categoryId);
    } catch (_) {
      return null;
    }
  }

  /// Danh sách đang cảnh báo hoặc vượt hạn mức.
  List<BudgetProgress> get alerts =>
      progresses.where((p) => p.status != BudgetStatus.safe).toList();

  @override
  List<Object?> get props => [progresses];
}

class BudgetError extends BudgetState {
  final String message;

  const BudgetError(this.message);

  @override
  List<Object?> get props => [message];
}

import '../../data/models/expense.dart';
import 'date_formatter.dart';

/// Gom nhóm danh sách giao dịch theo ngày.
///
/// Tại sao dùng LinkedHashMap thay Map thông thường:
///   - LinkedHashMap giữ nguyên thứ tự chèn
///   - Sort ngày giảm dần TRƯỚC rồi group → key tự động đúng thứ tự
///   - Không cần sort lại sau khi group
///
/// Normalize DateTime bằng dateOnly() (giờ → 00:00:00) để đảm bảo
/// các giao dịch trong cùng 1 ngày chia sẻ cùng key.
Map<DateTime, List<Expense>> groupExpensesByDate(
  List<Expense> expenses,
) {
  final grouped = <DateTime, List<Expense>>{};

  // expenses đã sort theo date DESC từ repository
  for (final expense in expenses) {
    final key = dateOnly(expense.date);
    grouped.putIfAbsent(key, () => []).add(expense);
  }

  return grouped;
}

/// Tính tổng dư thực tế trong ngày (thu nhập - chi tiêu).
double calculateDayBalance(List<Expense> expenses) {
  return expenses.where((e) => !e.isTransfer).fold<double>(
    0.0,
    (sum, e) => sum + (e.isIncome ? e.amount : -e.amount),
  );
}

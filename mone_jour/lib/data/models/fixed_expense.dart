import 'package:isar/isar.dart';

part 'fixed_expense.g.dart';

/// Mẫu chi tiêu cố định — "template" để thanh toán nhanh 1 chạm.
///
/// Tại sao tách riêng thay vì dùng Expense với flag:
///   - FixedExpense là "khuôn mẫu", Expense là "giao dịch thật"
///   - Khuôn mẫu không có ngày, không ảnh hưởng thống kê
///   - Khi thanh toán: clone data từ template → tạo Expense thực
///   - Xóa template không làm mất lịch sử giao dịch đã tạo
@collection
class FixedExpense {
  Id id = Isar.autoIncrement;

  /// Tên khoản chi (VD: "Tiền trọ", "Netflix", "Cà phê sáng")
  late String title;

  /// Số tiền cố định (VND)
  late double amount;

  /// Mã danh mục (liên kết với categories.dart)
  @Index()
  late String categoryId;

  /// Ghi chú mặc định (tùy chọn, sẽ copy sang Expense khi thanh toán)
  String? note;

  /// Thời điểm tạo template
  late DateTime createdAt;
}

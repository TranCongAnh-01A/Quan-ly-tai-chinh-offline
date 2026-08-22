import 'package:isar/isar.dart';

part 'expense.g.dart';

/// Nguồn tiền để chi tiêu
enum FundingSource {
  cash, // Tiền mặt
  bank, // Tài khoản / Thẻ
}

/// Bảng chi tiêu — lưu trữ mỗi giao dịch thu/chi.
///
/// Tại sao dùng Isar Collection thay SQLite Table:
///   - Type-safe: compiler bắt lỗi thay vì runtime crash
///   - Zero-boilerplate: không cần viết SQL migration
///   - Index tự động: full-text search + composite index
@collection
class Expense {
  Id id = Isar.autoIncrement;

  /// Số tiền (VND). Dương = chi tiêu, âm = thu nhập.
  late double amount;

  /// Mã danh mục (ăn uống, di chuyển, mua sắm...)
  @Index()
  late String category;

  /// Ghi chú ngắn cho giao dịch
  String? note;

  /// Ngày giao dịch (không bao gồm giờ)
  /// Composite index [date, isIncome] tối ưu query getTotalExpense/Income
  @Index(composite: [CompositeIndex('isIncome')])
  late DateTime date;

  /// Đánh dấu đây là khoản thu nhập (true) hay chi tiêu (false)
  late bool isIncome;

  /// Thời điểm tạo record
  late DateTime createdAt;

  /// Đánh dấu đây có phải là giao dịch sinh ra từ chi tiêu cố định không
  bool isFixed = false;

  /// Đánh dấu đây có phải là giao dịch chuyển tiền nội bộ không
  bool isTransfer = false;

  /// Nguồn tiền sử dụng (Mặc định là Tiền mặt)
  @enumerated
  FundingSource source = FundingSource.cash;

  /// Đường dẫn lưu ảnh hóa đơn (tùy chọn)
  String? receiptImagePath;
}

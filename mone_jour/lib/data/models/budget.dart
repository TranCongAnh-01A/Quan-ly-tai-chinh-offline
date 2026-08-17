import 'package:isar/isar.dart';

part 'budget.g.dart';

/// Hạn mức chi tiêu theo danh mục theo tháng.
///
/// Tại sao theo dõi theo tháng thay vì chỉ set hạn mức tổng:
///   - Mỗi tháng nhu cầu khác nhau (VD: Tết chi ăn uống nhiều hơn)
///   - Dễ so sánh xu hướng chi tiêu qua các tháng
///   - Composite index [categoryId, month, year] → query O(1)
@collection
class Budget {
  Id id = Isar.autoIncrement;

  /// Mã danh mục (liên kết với categories.dart)
  @Index(composite: [CompositeIndex('month'), CompositeIndex('year')])
  late String categoryId;

  /// Số tiền giới hạn (VND)
  late double amountLimit;

  /// Tháng áp dụng (1-12)
  late int month;

  /// Năm áp dụng
  late int year;
}

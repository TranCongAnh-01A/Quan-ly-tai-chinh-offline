import 'package:isar/isar.dart';

part 'journal.g.dart';

/// Bảng ghi chú — lưu trữ các ghi chú cá nhân của người dùng.
@collection
class Journal {
  Id id = Isar.autoIncrement;

  /// Tiêu đề ghi chú (có thể để trống)
  String? title;

  /// Nội dung ghi chú
  late String content;

  /// Ngày tạo ghi chú
  @Index()
  late DateTime date;
}

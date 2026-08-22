import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models/budget.dart';
import '../data/models/expense.dart';
import '../data/models/fixed_expense.dart';
import '../data/models/journal.dart';

/// Singleton quản lý kết nối Isar Database.
///
/// Tại sao dùng Singleton:
///   - Isar chỉ cho phép 1 instance mở đồng thời trên cùng 1 DB
///   - Mở nhiều instance → crash hoặc data corruption
///   - Singleton đảm bảo toàn app chỉ dùng 1 kết nối duy nhất
class DatabaseService {
  static Isar? _isar;

  /// Khởi tạo Isar database. Gọi 1 lần duy nhất trong main().
  ///
  /// [schemas] đăng ký tất cả Isar collections cần dùng.
  /// Isar tự tạo file database tại thư mục app documents.
  static Future<Isar> initialize() async {
    if (_isar != null && _isar!.isOpen) return _isar!;

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [ExpenseSchema, JournalSchema, FixedExpenseSchema, BudgetSchema],
      directory: dir.path,
      name: 'mone_jour',
    );

    return _isar!;
  }

  /// Trả về instance hiện tại. Ném lỗi nếu chưa initialize.
  static Isar get instance {
    if (_isar == null || !_isar!.isOpen) {
      throw StateError(
        'DatabaseService chưa được khởi tạo. '
        'Gọi DatabaseService.initialize() trong main() trước.',
      );
    }
    return _isar!;
  }
}

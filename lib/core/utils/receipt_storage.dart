import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Quản lý file ảnh hóa đơn trong thư mục documents của app.
///
/// Tại sao chỉ lưu TÊN FILE vào database thay vì đường dẫn tuyệt đối:
///   - Trên iOS, thư mục documents nằm trong container có UUID ngẫu nhiên,
///     UUID này ĐỔI sau mỗi lần cài lại / cập nhật app
///   - Đường dẫn tuyệt đối lưu trong DB sẽ trỏ vào container cũ đã biến mất
///     → toàn bộ ảnh hóa đơn "mất" dù file vẫn còn trên máy
///   - Lưu tên file + ghép với thư mục documents lúc đọc → luôn đúng
///
/// [resolve] cũng nhận đường dẫn tuyệt đối kiểu cũ (chỉ lấy phần tên file),
/// nên các bản ghi đã lưu trước đây tự động đọc được, không cần migration.
class ReceiptStorage {
  ReceiptStorage._();

  static String? _documentsPath;

  /// Cache đường dẫn thư mục documents để [resolve] chạy đồng bộ (dùng được
  /// trực tiếp trong build()). Gọi 1 lần trong main().
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _documentsPath = dir.path;
  }

  @visibleForTesting
  static void setDocumentsPathForTest(String? path) => _documentsPath = path;

  /// Tách tên file khỏi giá trị đã lưu (hỗ trợ cả `/` lẫn `\`).
  static String fileNameOf(String stored) =>
      stored.split(RegExp(r'[/\\]')).last;

  /// Đổi giá trị lưu trong DB thành đường dẫn tuyệt đối để đọc file.
  ///
  /// Trả về null nếu không có ảnh. Nếu chưa [initialize] thì trả nguyên giá
  /// trị cũ để không làm hỏng luồng hiển thị.
  static String? resolve(String? stored) {
    if (stored == null || stored.isEmpty) return null;

    final dir = _documentsPath;
    if (dir == null) return stored;

    return '$dir/${fileNameOf(stored)}';
  }

  /// Copy ảnh vừa chọn vào thư mục documents, trả về TÊN FILE để lưu vào DB.
  static Future<String> save(String sourcePath) async {
    final dir = _documentsPath ?? (await getApplicationDocumentsDirectory()).path;
    final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await File(sourcePath).copy('$dir/$fileName');

    return fileName;
  }

  /// Xóa file ảnh không còn giao dịch nào tham chiếu tới.
  ///
  /// Nuốt lỗi có chủ đích: file rác còn sót lại không đáng để làm hỏng thao
  /// tác xóa giao dịch của người dùng.
  static Future<void> delete(String? stored) async {
    final path = resolve(stored);
    if (path == null) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('ReceiptStorage delete ERROR: $e');
    }
  }
}

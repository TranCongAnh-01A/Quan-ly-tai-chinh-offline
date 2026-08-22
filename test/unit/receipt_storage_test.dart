import 'package:flutter_test/flutter_test.dart';
import 'package:mone_jour/core/utils/receipt_storage.dart';

void main() {
  tearDown(() {
    ReceiptStorage.setDocumentsPathForTest(null);
  });

  group('fileNameOf', () {
    test('tách tên file khỏi đường dẫn POSIX', () {
      expect(
        ReceiptStorage.fileNameOf('/var/mobile/Containers/Data/ABC/Documents/receipt_1.jpg'),
        'receipt_1.jpg',
      );
    });

    test('tách tên file khỏi đường dẫn Windows', () {
      expect(
        ReceiptStorage.fileNameOf(r'C:\Users\a\Documents\receipt_2.jpg'),
        'receipt_2.jpg',
      );
    });

    test('giá trị đã là tên file thì giữ nguyên', () {
      expect(ReceiptStorage.fileNameOf('receipt_3.jpg'), 'receipt_3.jpg');
    });
  });

  group('resolve', () {
    test('ghép tên file với thư mục documents hiện tại', () {
      ReceiptStorage.setDocumentsPathForTest('/data/app/documents');

      expect(
        ReceiptStorage.resolve('receipt_1.jpg'),
        '/data/app/documents/receipt_1.jpg',
      );
    });

    test('bản ghi cũ lưu đường dẫn tuyệt đối vẫn đọc được sau khi container đổi', () {
      // Đây chính là lỗi trên iOS: UUID container đổi sau mỗi lần cài lại,
      // đường dẫn cũ trỏ vào thư mục không còn tồn tại.
      ReceiptStorage.setDocumentsPathForTest(
        '/var/mobile/Containers/Data/Application/NEW-UUID/Documents',
      );

      final resolved = ReceiptStorage.resolve(
        '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/receipt_9.jpg',
      );

      expect(
        resolved,
        '/var/mobile/Containers/Data/Application/NEW-UUID/Documents/receipt_9.jpg',
      );
    });

    test('trả về null khi không có ảnh', () {
      ReceiptStorage.setDocumentsPathForTest('/data/app/documents');

      expect(ReceiptStorage.resolve(null), isNull);
      expect(ReceiptStorage.resolve(''), isNull);
    });

    test('chưa initialize thì trả nguyên giá trị đã lưu', () {
      expect(ReceiptStorage.resolve('receipt_1.jpg'), 'receipt_1.jpg');
    });
  });
}

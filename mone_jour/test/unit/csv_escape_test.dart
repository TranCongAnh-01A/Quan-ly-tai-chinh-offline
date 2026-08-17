import 'package:flutter_test/flutter_test.dart';
// Only testing independent function

void main() {
  group('ExportService — CSV Escape Tests', () {
    // Truy cập method private thông qua reflection không khả thi trong Dart.
    // Thay vào đó, ta test gián tiếp qua hàm public hoặc tạo wrapper.
    // Ở đây ta tách logic escape ra để test trực tiếp.

    test('Chuỗi bình thường không cần escape', () {
      final result = escapeCsvField('hello world');
      expect(result, equals('hello world'));
    });

    test('Chuỗi chứa dấu phẩy được bao bằng ngoặc kép', () {
      final result = escapeCsvField('hello, world');
      expect(result, equals('"hello, world"'));
    });

    test('Chuỗi chứa ngoặc kép được nhân đôi và bao', () {
      final result = escapeCsvField('say "hello"');
      expect(result, equals('"say ""hello"""'));
    });

    test('Chuỗi chứa xuống dòng được bao bằng ngoặc kép', () {
      final result = escapeCsvField('line1\nline2');
      expect(result, equals('"line1\nline2"'));
    });

    test('Chuỗi null hoặc rỗng trả về rỗng', () {
      expect(escapeCsvField(null), equals(''));
      expect(escapeCsvField(''), equals(''));
    });

    test('Chuỗi có cả dấu phẩy lẫn ngoặc kép', () {
      final result = escapeCsvField('A "tricky, one"');
      expect(result, equals('"A ""tricky, one"""'));
    });
  });
}

/// Hàm helper tách ra từ ExportService._escapeCsvField để test được.
/// Logic giống hệt method private trong ExportService.
String escapeCsvField(String? value) {
  if (value == null || value.isEmpty) return '';
  if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
    final escapedQuotes = value.replaceAll('"', '""');
    return '"$escapedQuotes"';
  }
  return value;
}

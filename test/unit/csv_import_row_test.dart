import 'package:flutter_test/flutter_test.dart';
import 'package:mone_jour/data/models/expense.dart';
import 'package:mone_jour/services/import_service.dart';

/// Test cho ImportService.expenseFromCsvRow — phần map 1 dòng expenses.csv
/// thành Expense. Không chạm Isar nên chạy được như unit test thuần.
void main() {
  late ImportService service;

  setUp(() {
    service = ImportService();
  });

  test('Dòng đủ 11 cột được parse đầy đủ', () {
    final e = service.expenseFromCsvRow([
      5,
      50000,
      'food',
      'Ăn trưa',
      '2026-08-20T12:00:00.000',
      false,
      '2026-08-20T12:05:00.000',
      false,
      false,
      1,
      '/data/user/0/app/receipt_1.jpg',
    ]);

    expect(e, isNotNull);
    expect(e!.id, 5);
    expect(e.amount, 50000);
    expect(e.category, 'food');
    expect(e.note, 'Ăn trưa');
    expect(e.isIncome, isFalse);
    expect(e.source, FundingSource.bank);
    // Đường dẫn tuyệt đối trong file cũ được rút về TÊN FILE (xem
    // ReceiptStorage): đường dẫn của máy khác không dùng lại được.
    expect(e.receiptImagePath, 'receipt_1.jpg');
  });

  test('Đường dẫn ảnh kiểu Windows cũng rút về tên file', () {
    final e = service.expenseFromCsvRow([
      6,
      1000,
      'food',
      '',
      '2026-08-05T10:00:00.000',
      false,
      '2026-08-05T10:00:00.000',
      false,
      false,
      0,
      r'C:\Users\a\Documents\receipt_9.jpg',
    ]);

    expect(e!.receiptImagePath, 'receipt_9.jpg');
  });

  test('Dòng 6 cột (bản export cũ) không ném lỗi, dùng giá trị mặc định', () {
    // Regression: trước đây row[10] bị truy cập vô điều kiện → RangeError
    // làm hỏng toàn bộ quá trình import ZIP.
    final e = service.expenseFromCsvRow([
      1,
      20000,
      'coffee',
      '',
      '2026-08-01T09:00:00.000',
      false,
    ]);

    expect(e, isNotNull);
    expect(e!.amount, 20000);
    expect(e.category, 'coffee');
    expect(e.note, isNull);
    expect(e.isFixed, isFalse);
    expect(e.isTransfer, isFalse);
    expect(e.source, FundingSource.cash);
    expect(e.receiptImagePath, isNull);
  });

  test('Dòng 10 cột (thiếu đúng cột receipt) vẫn parse được', () {
    final e = service.expenseFromCsvRow([
      2,
      99000,
      'shopping',
      'Áo',
      '2026-08-05T10:00:00.000',
      false,
      '2026-08-05T10:01:00.000',
      false,
      false,
      1,
    ]);

    expect(e, isNotNull);
    expect(e!.source, FundingSource.bank);
    expect(e.receiptImagePath, isNull);
  });

  test('Dòng thiếu cột bắt buộc trả về null để bỏ qua', () {
    expect(service.expenseFromCsvRow([1, 20000, 'food']), isNull);
    expect(service.expenseFromCsvRow(const []), isNull);
  });

  test('source index ngoài phạm vi enum rơi về cash', () {
    final e = service.expenseFromCsvRow([
      3,
      1000,
      'food',
      '',
      '2026-08-05T10:00:00.000',
      false,
      '2026-08-05T10:00:00.000',
      false,
      false,
      99,
    ]);

    expect(e!.source, FundingSource.cash);
  });
}

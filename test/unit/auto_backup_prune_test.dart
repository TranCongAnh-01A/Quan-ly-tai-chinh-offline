import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mone_jour/services/import_service.dart';

/// Test cho phần dọn file auto-backup — chỉ đụng filesystem, không cần Isar.
void main() {
  late Directory tempDir;
  late ImportService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('monejour_backup_test');
    service = ImportService();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File makeBackup(int timestamp) {
    final file = File('${tempDir.path}/monejour_auto_backup_$timestamp.json');
    file.writeAsStringSync('{}');
    return file;
  }

  test('Giữ lại đúng số bản mới nhất, xóa bản cũ', () async {
    for (var i = 1; i <= 6; i++) {
      makeBackup(1000 + i);
    }

    await service.pruneAutoBackups(tempDir);

    final remaining = tempDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList()
      ..sort();

    expect(remaining.length, ImportService.maxAutoBackups);
    // 3 timestamp lớn nhất được giữ lại
    expect(remaining, [
      'monejour_auto_backup_1004.json',
      'monejour_auto_backup_1005.json',
      'monejour_auto_backup_1006.json',
    ]);
  });

  test('Ít hơn ngưỡng thì không xóa gì', () async {
    makeBackup(2001);
    makeBackup(2002);

    await service.pruneAutoBackups(tempDir);

    expect(tempDir.listSync().whereType<File>().length, 2);
  });

  test('Không đụng tới file khác trong thư mục', () async {
    for (var i = 1; i <= 5; i++) {
      makeBackup(3000 + i);
    }
    File('${tempDir.path}/receipt_1.jpg').writeAsStringSync('anh');
    File('${tempDir.path}/monejour_backup.json').writeAsStringSync('{}');

    await service.pruneAutoBackups(tempDir);

    final names = tempDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();

    expect(names.contains('receipt_1.jpg'), isTrue);
    expect(names.contains('monejour_backup.json'), isTrue);
    expect(
      names.where((n) => n.startsWith('monejour_auto_backup_')).length,
      ImportService.maxAutoBackups,
    );
  });

  test('Thư mục không tồn tại thì không ném lỗi', () async {
    final missing = Directory('${tempDir.path}/khong_ton_tai');

    await service.pruneAutoBackups(missing);
  });
}

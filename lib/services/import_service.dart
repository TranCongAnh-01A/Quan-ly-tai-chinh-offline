import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';
import '../data/models/expense.dart';
import '../data/models/budget.dart';
import '../data/models/fixed_expense.dart';
import '../data/models/journal.dart';
import '../core/utils/receipt_storage.dart';
import '../ui/screens/auth/auth_wrapper.dart';
import 'export_service.dart';

/// Một bản sao lưu tự động nằm trong thư mục riêng của app.
class AutoBackupEntry {
  final File file;
  final DateTime createdAt;
  final int sizeBytes;

  const AutoBackupEntry({
    required this.file,
    required this.createdAt,
    required this.sizeBytes,
  });

  /// Dung lượng dạng dễ đọc: "1,2 MB", "980 KB".
  String get readableSize {
    if (sizeBytes >= 1024 * 1024) {
      final mb = sizeBytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
    }
    if (sizeBytes >= 1024) return '${(sizeBytes / 1024).round()} KB';
    return '$sizeBytes B';
  }
}

class ImportService {
  Isar get _db => DatabaseService.instance;

  /// Số bản auto-backup được giữ lại. Cũ hơn thì xóa.
  static const int maxAutoBackups = 3;

  static const String _autoBackupPrefix = 'monejour_auto_backup_';

  Future<bool> hasAnyData() async {
    final eCount = await _db.expenses.count();
    final bCount = await _db.budgets.count();
    final fCount = await _db.fixedExpenses.count();
    final jCount = await _db.journals.count();
    return (eCount + bCount + fCount + jCount) > 0;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    final str = value.toString().toLowerCase();
    return str == 'true' || str == '1';
  }

  /// Đưa giá trị ảnh hóa đơn về dạng TÊN FILE.
  ///
  /// Backup đời cũ lưu đường dẫn tuyệt đối của máy cũ — giữ nguyên thì dữ liệu
  /// mang theo rác của thiết bị khác (xem ReceiptStorage).
  String? _normalizeReceiptPath(dynamic value) {
    final raw = _parseNullableString(value);
    if (raw == null) return null;
    return ReceiptStorage.fileNameOf(raw);
  }

  String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    if (str.isEmpty || str == 'null') return null;
    return str;
  }

  /// Ghi 1 bản backup trước khi import đè dữ liệu, đồng thời dọn bản cũ.
  ///
  /// Không dọn thì mỗi lần import lại sinh thêm 1 file JSON nằm vĩnh viễn
  /// trong thư mục documents — dữ liệu càng nhiều thì file càng to.
  Future<void> _writeAutoBackup() async {
    if (!await hasAnyData()) return;

    final dir = await getApplicationDocumentsDirectory();
    final backupJson = await ExportService().getAllDataAsJsonString();
    final backupFile = File(
      '${dir.path}/$_autoBackupPrefix${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await backupFile.writeAsString(backupJson);

    await pruneAutoBackups(dir);
  }

  /// Danh sách bản sao lưu tự động, mới nhất trước.
  ///
  /// Các file này nằm trong thư mục riêng của app nên bộ chọn file của hệ
  /// điều hành không thấy — không liệt kê ra thì người dùng không có đường
  /// nào chạm tới, và lưới an toàn coi như không tồn tại.
  Future<List<AutoBackupEntry>> listAutoBackups() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return readAutoBackups(dir);
    } catch (e) {
      debugPrint('List auto backup ERROR: $e');
      return const [];
    }
  }

  @visibleForTesting
  List<AutoBackupEntry> readAutoBackups(Directory dir) {
    if (!dir.existsSync()) return const [];

    final entries = <AutoBackupEntry>[];

    for (final file in dir.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.startsWith(_autoBackupPrefix)) continue;

      final timestamp = int.tryParse(
        name.substring(_autoBackupPrefix.length).replaceAll('.json', ''),
      );
      if (timestamp == null) continue;

      entries.add(AutoBackupEntry(
        file: file,
        createdAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
        sizeBytes: file.lengthSync(),
      ));
    }

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// Khôi phục từ 1 bản sao lưu tự động.
  ///
  /// Dữ liệu hiện tại lại được chụp thêm 1 bản trước khi ghi đè (bên trong
  /// importFromJsonString), nên bấm nhầm vẫn còn đường lùi.
  Future<bool> restoreFromAutoBackup(AutoBackupEntry entry) async {
    try {
      if (!await entry.file.exists()) {
        debugPrint('Bản sao lưu tự động không còn tồn tại');
        return false;
      }

      return await importFromJsonString(await entry.file.readAsString());
    } catch (e) {
      debugPrint('Restore auto backup ERROR: $e');
      return false;
    }
  }

  /// Chỉ giữ lại [maxAutoBackups] bản mới nhất.
  @visibleForTesting
  Future<void> pruneAutoBackups(Directory dir) async {
    try {
      final backups = dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.uri.pathSegments.last.startsWith(_autoBackupPrefix))
          .toList();

      if (backups.length <= maxAutoBackups) return;

      // Tên file chứa timestamp nên sắp theo tên là sắp theo thời gian
      backups.sort((a, b) => b.path.compareTo(a.path));

      for (final old in backups.skip(maxAutoBackups)) {
        await old.delete();
      }
    } catch (e) {
      // Dọn dẹp thất bại không được làm hỏng thao tác import
      debugPrint('Prune auto backup ERROR: $e');
    }
  }

  /// Tên các file CSV mà app hiểu được khi nhập từ ZIP.
  static const Set<String> _knownCsvNames = {
    'expenses.csv',
    'budgets.csv',
    'fixed_expenses.csv',
    'journals.csv',
  };

  /// Zip này là gói backup (có data.json) hay là bộ CSV?
  bool _isBackupArchive(List<int> bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes).files.any((f) =>
          f.isFile &&
          f.name.split('/').last == ExportService.archiveDataEntry);
    } catch (_) {
      return false;
    }
  }

  /// Các bảng dữ liệu mà 1 file backup hợp lệ phải có ít nhất một.
  static const List<String> _backupCollectionKeys = [
    'expenses',
    'budgets',
    'fixedExpenses',
    'journals',
  ];

  /// Kiểm tra nội dung có thực sự là backup của app hay không.
  ///
  /// Khôi phục là thao tác XÓA SẠCH dữ liệu hiện có rồi ghi đè. Trước đây
  /// không kiểm tra gì: chọn nhầm một file JSON bất kỳ là mất trắng dữ liệu,
  /// mà app vẫn báo "Khôi phục thành công".
  ///
  /// Backup đời cũ chưa có `appId` nên vẫn chấp nhận nếu có ít nhất 1 bảng
  /// dữ liệu đúng dạng danh sách.
  @visibleForTesting
  static bool isValidBackup(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return false;

    if (decoded['appId'] == ExportService.backupAppId) return true;

    return _backupCollectionKeys.any((key) => decoded[key] is List);
  }

  /// Thời điểm tạo backup, null nếu là file đời cũ chưa có metadata.
  static DateTime? backupCreatedAt(Map<String, dynamic> data) =>
      DateTime.tryParse(data['exportedAt']?.toString() ?? '');

  /// Map 1 dòng CSV (file expenses.csv) thành Expense.
  ///
  /// Trả về null nếu dòng không đủ các cột bắt buộc (id..isIncome).
  /// Các cột phía sau là tùy chọn: bản export cũ có ít cột hơn bản hiện tại,
  /// nên mọi truy cập index > 5 đều phải kiểm tra độ dài trước.
  @visibleForTesting
  Expense? expenseFromCsvRow(List<dynamic> row) {
    if (row.length < 6) return null;

    final sourceIndex = row.length > 9 ? _parseInt(row[9], 0) : 0;

    return Expense()
      ..id = _parseInt(row[0], Isar.autoIncrement)
      ..amount = _parseDouble(row[1])
      ..category = row[2].toString().isEmpty ? 'other' : row[2].toString()
      ..note = _parseNullableString(row[3])
      ..date = DateTime.tryParse(row[4].toString()) ?? DateTime.now()
      ..isIncome = _parseBool(row[5])
      ..createdAt = row.length > 6
          ? (DateTime.tryParse(row[6].toString()) ?? DateTime.now())
          : DateTime.now()
      ..isFixed = row.length > 7 ? _parseBool(row[7]) : false
      ..isTransfer = row.length > 8 ? _parseBool(row[8]) : false
      ..source = (sourceIndex >= 0 && sourceIndex < FundingSource.values.length)
          ? FundingSource.values[sourceIndex]
          : FundingSource.cash
      ..receiptImagePath =
          row.length > 10 ? _normalizeReceiptPath(row[10]) : null;
  }

  /// Khôi phục từ gói backup .zip (dữ liệu + ảnh hóa đơn).
  ///
  /// Ảnh được giải nén vào thư mục documents TRƯỚC khi ghi dữ liệu: nếu ghi
  /// dữ liệu hỏng thì cùng lắm thừa vài file ảnh, còn nếu làm ngược lại thì
  /// giao dịch trỏ tới ảnh chưa tồn tại.
  Future<bool> importFromArchiveBytes(List<int> bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      final dataEntries = archive.files.where((f) {
        return f.isFile &&
            f.name.split('/').last == ExportService.archiveDataEntry;
      });

      if (dataEntries.isEmpty) {
        debugPrint('Gói backup không có ${ExportService.archiveDataEntry}');
        return false;
      }

      final content = utf8.decode(dataEntries.first.content as List<int>);

      // Kiểm tra nội dung trước khi giải nén ảnh hay động vào database
      if (!isValidBackup(jsonDecode(content))) {
        debugPrint('Gói backup không hợp lệ');
        return false;
      }

      await _restoreReceiptImages(archive);

      return await importFromJsonString(content);
    } catch (e) {
      debugPrint('Import archive ERROR: $e');
      return false;
    }
  }

  /// Giải nén ảnh hóa đơn trong gói backup vào thư mục documents.
  Future<void> _restoreReceiptImages(Archive archive) async {
    final dir = await getApplicationDocumentsDirectory();
    final prefix = '${ExportService.archiveReceiptDir}/';

    for (final entry in archive.files) {
      if (!entry.isFile || !entry.name.startsWith(prefix)) continue;

      // Chỉ lấy tên file, chặn đường dẫn kiểu `../..` trong zip
      final fileName = entry.name.split('/').last;
      if (fileName.isEmpty) continue;

      try {
        await File('${dir.path}/$fileName')
            .writeAsBytes(entry.content as List<int>);
      } catch (e) {
        // Thiếu 1 ảnh không đáng để hỏng cả lần khôi phục
        debugPrint('Restore receipt "$fileName" ERROR: $e');
      }
    }
  }

  /// Import từ chuỗi JSON (Dùng cho Cloud Sync)
  Future<bool> importFromJsonString(String content) async {
    try {
      // Auto Backup trước khi xử lý
      await _writeAutoBackup();

      final decoded = jsonDecode(content);

      // Kiểm tra TRƯỚC khi động vào database — clear() là không thể hoàn tác
      if (!isValidBackup(decoded)) {
        debugPrint('Import bị từ chối: nội dung không phải backup của app');
        return false;
      }

      final data = decoded as Map<String, dynamic>;

      await _db.writeTxn(() async {
        await _db.clear();

        if (data.containsKey('expenses')) {
          final expensesList = data['expenses'] as List<dynamic>;
          for (final item in expensesList) {
            final e = Expense()
              ..id = _parseInt(item['id'], Isar.autoIncrement)
              ..amount = _parseDouble(item['amount'])
              ..category = item['category']?.toString() ?? 'other'
              ..note = item['note']?.toString()
              ..date = DateTime.tryParse(item['date']?.toString() ?? '') ?? DateTime.now()
              ..isIncome = _parseBool(item['isIncome'])
              ..createdAt = DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now()
              ..isFixed = _parseBool(item['isFixed'])
              ..isTransfer = _parseBool(item['isTransfer'])
              ..source = (() {
                final idx = _parseInt(item['source'], 0);
                return (idx >= 0 && idx < FundingSource.values.length)
                    ? FundingSource.values[idx]
                    : FundingSource.cash;
              })()
              ..receiptImagePath =
                  _normalizeReceiptPath(item['receiptImagePath']);
            await _db.expenses.put(e);
          }
        }

        if (data.containsKey('budgets')) {
          final budgetsList = data['budgets'] as List<dynamic>;
          for (final item in budgetsList) {
            final b = Budget()
              ..id = _parseInt(item['id'], Isar.autoIncrement)
              ..categoryId = item['categoryId']?.toString() ?? 'food'
              ..amountLimit = _parseDouble(item['amountLimit'])
              ..month = _parseInt(item['month'], DateTime.now().month)
              ..year = _parseInt(item['year'], DateTime.now().year);
            await _db.budgets.put(b);
          }
        }

        if (data.containsKey('fixedExpenses')) {
          final fixedList = data['fixedExpenses'] as List<dynamic>;
          for (final item in fixedList) {
            final f = FixedExpense()
              ..id = _parseInt(item['id'], Isar.autoIncrement)
              ..title = item['title']?.toString() ?? 'Khoản chi'
              ..amount = _parseDouble(item['amount'])
              ..categoryId = item['categoryId']?.toString() ?? 'bills'
              ..note = item['note']?.toString()
              ..createdAt =
                  DateTime.tryParse(item['createdAt']?.toString() ?? '') ??
                      DateTime.now();
            await _db.fixedExpenses.put(f);
          }
        }

        if (data.containsKey('journals')) {
          final journalsList = data['journals'] as List<dynamic>;
          for (final item in journalsList) {
            final j = Journal()
              ..id = _parseInt(item['id'], Isar.autoIncrement)
              ..title = item['title']?.toString()
              ..content = item['content']?.toString() ?? ''
              ..date = DateTime.tryParse(item['date']?.toString() ?? '') ?? DateTime.now();
            await _db.journals.put(j);
          }
        }
      });
      return true;
    } catch (e) {
      debugPrint('Import JSON ERROR: $e');
      return false;
    }
  }

  /// Import từ file JSON đã xuất trước đó
  /// Sẽ XÓA TOÀN BỘ dữ liệu hiện tại trước khi Import để đảm bảo không bị lỗi ID.
  Future<bool> importFromJson() async {
    try {
      AuthWrapper.pauseLock = true;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        // Gói backup mới là .zip (kèm ảnh hóa đơn), bản cũ là .json
        allowedExtensions: ['json', 'zip'],
      );
      AuthWrapper.pauseLock = false;

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final file = File(result.files.single.path!);

      if (file.path.toLowerCase().endsWith('.zip')) {
        return await importFromArchiveBytes(await file.readAsBytes());
      }

      return await importFromJsonString(await file.readAsString());
    } catch (e) {
      debugPrint('Import JSON file ERROR: $e');
      return false;
    }
  }

  /// Import từ file ZIP chứa các file CSV
  Future<bool> importFromCsvZip() async {
    try {
      AuthWrapper.pauseLock = true;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      AuthWrapper.pauseLock = false;

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();

      // Gói backup .zip (data.json + ảnh) đi đường riêng
      if (_isBackupArchive(bytes)) {
        return await importFromArchiveBytes(bytes);
      }

      final archive = ZipDecoder().decodeBytes(bytes);

      // Không có file CSV nào nhận diện được thì DỪNG, đừng xóa dữ liệu.
      // Trước đây zip lạ vẫn clear sạch database rồi báo thành công.
      final hasKnownCsv = archive.files.any((f) =>
          f.isFile && _knownCsvNames.contains(f.name.split('/').last));
      if (!hasKnownCsv) {
        debugPrint('Zip không chứa file CSV nào của app');
        return false;
      }

      // Auto Backup trước khi xử lý
      await _writeAutoBackup();

      await _db.writeTxn(() async {
        // Clear old data
        await _db.clear();

        for (final file in archive) {
          if (file.isFile) {
            // Loại bỏ prefix đường dẫn nếu zip có subfolder
            final filename = file.name.split('/').last;
            final content = utf8.decode(file.content as List<int>);
            final csvRows = const CsvToListConverter().convert(content);
            
            // dòng đầu tiên là header, ta bỏ qua
            if (csvRows.length <= 1) continue;

            if (filename == 'expenses.csv') {
              for (int i = 1; i < csvRows.length; i++) {
                final e = expenseFromCsvRow(csvRows[i]);
                if (e == null) continue;
                await _db.expenses.put(e);
              }
            } else if (filename == 'budgets.csv') {
              for (int i = 1; i < csvRows.length; i++) {
                final row = csvRows[i];
                if (row.length < 5) continue;
                final b = Budget()
                  ..id = _parseInt(row[0], Isar.autoIncrement)
                  ..categoryId = row[1].toString().isEmpty ? 'food' : row[1].toString()
                  ..amountLimit = _parseDouble(row[2])
                  ..month = _parseInt(row[3], DateTime.now().month)
                  ..year = _parseInt(row[4], DateTime.now().year);
                await _db.budgets.put(b);
              }
            } else if (filename == 'fixed_expenses.csv') {
              for (int i = 1; i < csvRows.length; i++) {
                final row = csvRows[i];
                if (row.length < 5) continue;
                final f = FixedExpense()
                  ..id = _parseInt(row[0], Isar.autoIncrement)
                  ..title = row[1].toString().isEmpty ? 'Khoản chi' : row[1].toString()
                  ..amount = _parseDouble(row[2])
                  ..categoryId = row[3].toString().isEmpty ? 'bills' : row[3].toString()
                  ..note = _parseNullableString(row[4])
                  ..createdAt = DateTime.now();
                await _db.fixedExpenses.put(f);
              }
            } else if (filename == 'journals.csv') {
              for (int i = 1; i < csvRows.length; i++) {
                final row = csvRows[i];
                if (row.length < 4) continue;
                final j = Journal()
                  ..id = _parseInt(row[0], Isar.autoIncrement)
                  ..title = _parseNullableString(row[1])
                  ..content = row[2].toString()
                  ..date = DateTime.tryParse(row[3].toString()) ?? DateTime.now();
                await _db.journals.put(j);
              }
            }
          }
        }
      });
      return true;
    } catch (e) {
      debugPrint('Import CSV Zip Error: $e');
      return false;
    }
  }
}

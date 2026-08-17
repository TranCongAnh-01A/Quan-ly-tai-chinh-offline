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
import '../ui/screens/auth/auth_wrapper.dart';
import 'export_service.dart';

class ImportService {
  Isar get _db => DatabaseService.instance;

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

  String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    if (str.isEmpty || str == 'null') return null;
    return str;
  }

  /// Import từ chuỗi JSON (Dùng cho Cloud Sync)
  Future<bool> importFromJsonString(String content) async {
    try {
      // Auto Backup trước khi xử lý
      if (await hasAnyData()) {
        final backupJson = await ExportService().getAllDataAsJsonString();
        final tempDir = await getApplicationDocumentsDirectory();
        final backupFile = File('${tempDir.path}/monejour_auto_backup_${DateTime.now().millisecondsSinceEpoch}.json');
        await backupFile.writeAsString(backupJson);
      }

      final data = jsonDecode(content) as Map<String, dynamic>;

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
              ..receiptImagePath = item['receiptImagePath']?.toString();
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
              ..createdAt = DateTime.now();
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
      if (kDebugMode) {
        print('Error importing JSON string: $e');
      }
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
        allowedExtensions: ['json'],
      );
      AuthWrapper.pauseLock = false;

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      
      return await importFromJsonString(content);
    } catch (e) {
      if (kDebugMode) {
        print('Error importing JSON: $e');
      }
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
      final archive = ZipDecoder().decodeBytes(bytes);

      // Auto Backup trước khi xử lý
      if (await hasAnyData()) {
        final backupJson = await ExportService().getAllDataAsJsonString();
        final tempDir = await getApplicationDocumentsDirectory();
        final backupFile = File('${tempDir.path}/monejour_auto_backup_${DateTime.now().millisecondsSinceEpoch}.json');
        await backupFile.writeAsString(backupJson);
      }

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
                final row = csvRows[i];
                if (row.length < 6) continue;
                final e = Expense()
                  ..id = _parseInt(row[0], Isar.autoIncrement)
                  ..amount = _parseDouble(row[1])
                  ..category = row[2].toString().isEmpty ? 'other' : row[2].toString()
                  ..note = _parseNullableString(row[3])
                  ..date = DateTime.tryParse(row[4].toString()) ?? DateTime.now()
                  ..isIncome = _parseBool(row[5])
                  ..createdAt = row.length > 6 ? (DateTime.tryParse(row[6].toString()) ?? DateTime.now()) : DateTime.now()
                  ..isFixed = row.length > 7 ? _parseBool(row[7]) : false
                  ..isTransfer = row.length > 8 ? _parseBool(row[8]) : false
                  ..source = (() {
                    final idx = row.length > 9 ? _parseInt(row[9], 0) : 0;
                    return (idx >= 0 && idx < FundingSource.values.length)
                        ? FundingSource.values[idx]
                        : FundingSource.cash;
                  })()
                  ..receiptImagePath = _parseNullableString(row[10]);
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

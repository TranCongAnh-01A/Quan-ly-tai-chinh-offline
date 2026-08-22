import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';
import '../data/models/expense.dart';
import '../data/models/budget.dart';
import '../data/models/fixed_expense.dart';
import '../data/models/journal.dart';

import '../ui/screens/auth/auth_wrapper.dart';

class ExportService {
  Isar get _db => DatabaseService.instance;

  /// Lấy toàn bộ dữ liệu dưới dạng chuỗi JSON (Dùng cho Cloud Sync)
  Future<String> getAllDataAsJsonString() async {
    final expenses = await _db.expenses.where().findAll();
    final budgets = await _db.budgets.where().findAll();
    final fixedExpenses = await _db.fixedExpenses.where().findAll();
    final journals = await _db.journals.where().findAll();

    final data = {
      'expenses': expenses.map((e) => {
            'id': e.id,
            'amount': e.amount,
            'category': e.category,
            'note': e.note,
            'date': e.date.toIso8601String(),
            'isIncome': e.isIncome,
            'createdAt': e.createdAt.toIso8601String(),
            'isFixed': e.isFixed,
            'isTransfer': e.isTransfer,
            'source': e.source.index,
            'receiptImagePath': e.receiptImagePath,
          }).toList(),
      'budgets': budgets.map((b) => {
            'id': b.id,
            'categoryId': b.categoryId,
            'amountLimit': b.amountLimit,
            'month': b.month,
            'year': b.year,
          }).toList(),
      'fixedExpenses': fixedExpenses.map((f) => {
            'id': f.id,
            'title': f.title,
            'amount': f.amount,
            'categoryId': f.categoryId,
            'note': f.note,
          }).toList(),
      'journals': journals.map((j) => {
            'id': j.id,
            'title': j.title,
            'content': j.content,
            'date': j.date.toIso8601String(),
          }).toList(),
    };

    return jsonEncode(data);
  }

  /// Xuất toàn bộ dữ liệu ra file JSON duy nhất và share
  Future<void> exportToJson() async {
    final jsonString = await getAllDataAsJsonString();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/monejour_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonString);

    AuthWrapper.pauseLock = true;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'MoneJour Backup JSON',
    );
    AuthWrapper.pauseLock = false;
  }

  String _escapeCsvField(String? value) {
    if (value == null || value.isEmpty) return '';
    // Theo chuẩn RFC 4180, nếu chuỗi chứa dấu phẩy, ngoặc kép, hoặc xuống dòng, phải bao bằng ngoặc kép.
    // Các ngoặc kép bên trong chuỗi phải được nhân đôi ("").
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      final escapedQuotes = value.replaceAll('"', '""');
      return '"$escapedQuotes"';
    }
    return value;
  }

  /// Xuất dữ liệu ra file CSV được nén trong 1 file ZIP và share
  Future<void> exportToCsvZip() async {
    final expenses = await _db.expenses.where().findAll();
    final budgets = await _db.budgets.where().findAll();
    final fixedExpenses = await _db.fixedExpenses.where().findAll();
    final journals = await _db.journals.where().findAll();

    // 1. Tạo CSV cho Expenses
    final expBuffer = StringBuffer();
    expBuffer.writeln('ID,Amount,Category,Note,Date,IsIncome,CreatedAt,IsFixed,IsTransfer,Source,ReceiptImagePath');
    for (final e in expenses) {
      final note = _escapeCsvField(e.note);
      final category = _escapeCsvField(e.category);
      final receipt = _escapeCsvField(e.receiptImagePath);
      expBuffer.writeln('${e.id},${e.amount},$category,$note,${e.date.toIso8601String()},${e.isIncome},${e.createdAt.toIso8601String()},${e.isFixed},${e.isTransfer},${e.source.index},$receipt');
    }

    // 2. Tạo CSV cho Budgets
    final budBuffer = StringBuffer();
    budBuffer.writeln('ID,CategoryID,AmountLimit,Month,Year');
    for (final b in budgets) {
      final categoryId = _escapeCsvField(b.categoryId);
      budBuffer.writeln('${b.id},$categoryId,${b.amountLimit},${b.month},${b.year}');
    }

    // 3. Tạo CSV cho Fixed Expenses
    final fixBuffer = StringBuffer();
    fixBuffer.writeln('ID,Title,Amount,CategoryID,Note');
    for (final f in fixedExpenses) {
      final title = _escapeCsvField(f.title);
      final note = _escapeCsvField(f.note);
      final categoryId = _escapeCsvField(f.categoryId);
      fixBuffer.writeln('${f.id},$title,${f.amount},$categoryId,$note');
    }

    // 4. Tạo CSV cho Journals
    final jrnBuffer = StringBuffer();
    jrnBuffer.writeln('ID,Title,Content,Date');
    for (final j in journals) {
      final title = _escapeCsvField(j.title);
      final content = _escapeCsvField(j.content);
      jrnBuffer.writeln('${j.id},$title,$content,${j.date.toIso8601String()}');
    }

    // Tạo file zip
    final archive = Archive();
    final expBytes = utf8.encode(expBuffer.toString());
    final budBytes = utf8.encode(budBuffer.toString());
    final fixBytes = utf8.encode(fixBuffer.toString());
    final jrnBytes = utf8.encode(jrnBuffer.toString());

    archive.addFile(ArchiveFile('expenses.csv', expBytes.length, expBytes));
    archive.addFile(ArchiveFile('budgets.csv', budBytes.length, budBytes));
    archive.addFile(ArchiveFile('fixed_expenses.csv', fixBytes.length, fixBytes));
    archive.addFile(ArchiveFile('journals.csv', jrnBytes.length, jrnBytes));

    final zipData = ZipEncoder().encode(archive);
    
    final tempDir = await getTemporaryDirectory();
    final zipFile = File('${tempDir.path}/monejour_export.zip');
    await zipFile.writeAsBytes(zipData);

    AuthWrapper.pauseLock = true;
    await Share.shareXFiles(
      [XFile(zipFile.path)],
      subject: 'MoneJour Export CSV (Zip)',
      text: 'Dữ liệu các bảng đã được xuất dưới định dạng CSV.',
    );
    AuthWrapper.pauseLock = false;
  }
}

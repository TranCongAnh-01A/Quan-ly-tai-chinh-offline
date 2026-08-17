import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/fixed_expense.dart';
import '../../data/models/expense.dart' show FundingSource;
import '../../data/repositories/fixed_expense_repository.dart';
import 'fixed_expense_state.dart';

/// Cubit quản lý danh sách template chi tiêu cố định.
///
/// Trách nhiệm:
///   - CRUD template (thêm/sửa/xóa mẫu chi tiêu)
///   - Thực thi thanh toán nhanh (execute → tạo Expense thật)
///   - Auto-refresh qua Isar watcher
class FixedExpenseCubit extends Cubit<FixedExpenseState> {
  final FixedExpenseRepository _repository;
  StreamSubscription? _watchSubscription;

  FixedExpenseCubit({FixedExpenseRepository? repository})
      : _repository = repository ?? FixedExpenseRepository(),
        super(const FixedExpenseLoading()) {
    _watchSubscription = _repository.watchChanges().listen((_) {
      loadTemplates();
    });
  }

  /// Tải tất cả template.
  Future<void> loadTemplates() async {
    try {
      final templates = await _repository.getAll();
      emit(FixedExpenseLoaded(templates: templates));
    } catch (e) {
      emit(FixedExpenseError('Lỗi tải template: $e'));
    }
  }

  /// Thêm template mới.
  Future<void> addTemplate({
    required String title,
    required double amount,
    required String categoryId,
    String? note,
  }) async {
    final template = FixedExpense()
      ..title = title
      ..amount = amount
      ..categoryId = categoryId
      ..note = note
      ..createdAt = DateTime.now();

    await _repository.add(template);
    // Isar watcher sẽ trigger loadTemplates() tự động
  }

  /// Cập nhật template.
  Future<void> updateTemplate(FixedExpense template) async {
    await _repository.update(template);
  }

  /// Xóa template.
  Future<void> deleteTemplate(int id) async {
    await _repository.delete(id);
  }

  /// Thực thi thanh toán nhanh — clone template thành Expense thật.
  ///
  /// Luồng: UI gọi → repo.executeFixedExpense() → Isar ghi Expense
  /// → ExpenseCubit.watchChanges() tự trigger reload danh sách + số dư
  Future<void> confirmFixedExpense(FixedExpense template, {FundingSource source = FundingSource.cash}) async {
    await _repository.executeFixedExpense(template, source: source);
  }

  @override
  Future<void> close() {
    _watchSubscription?.cancel();
    return super.close();
  }
}

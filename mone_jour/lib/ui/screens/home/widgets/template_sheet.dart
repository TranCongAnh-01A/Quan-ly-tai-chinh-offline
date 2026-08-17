import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import '../../../../data/models/fixed_expense.dart';
import '../../../../logic/fixed_expense/fixed_expense_cubit.dart';
import '../../../widgets/category_picker.dart';

/// Bottom Sheet thêm/sửa template chi tiêu cố định.
///
/// Hỗ trợ 2 chế độ:
///   - Thêm mới: editTemplate = null
///   - Chỉnh sửa: editTemplate != null → điền sẵn dữ liệu cũ
class TemplateSheet extends StatefulWidget {
  final FixedExpense? editTemplate;

  const TemplateSheet({super.key, this.editTemplate});

  @override
  State<TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends State<TemplateSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'bills';
  bool _isSaving = false;
  
  bool _showTitleError = false;
  bool _showAmountError = false;

  bool get _isEditMode => widget.editTemplate != null;

  @override
  void initState() {
    super.initState();

    // Edit mode → điền dữ liệu cũ vào form
    if (_isEditMode) {
      final t = widget.editTemplate!;
      _titleController.text = t.title;
      _amountController.text = NumberFormat('#,###', 'vi_VN').format(t.amount.round());
      _selectedCategory = t.categoryId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEditMode ? 'Chỉnh sửa chi tiêu cố định' : 'Tạo chi tiêu cố định',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // ── Tên khoản chi ──
            TextField(
              controller: _titleController,
              onChanged: (_) => setState(() => _showTitleError = false),
              decoration: InputDecoration(
                labelText: 'Tên khoản chi',
                hintText: 'VD: Tiền trọ, Netflix, Điện nước...',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _showTitleError ? AppTheme.dangerRed : Colors.transparent,
                    width: _showTitleError ? 2.0 : 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _showTitleError ? AppTheme.dangerRed : theme.colorScheme.primary,
                    width: 2.0,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
              ),
              autofocus: !_isEditMode,
            ),
            const SizedBox(height: 16),

            // ── Số tiền ──
            TextField(
              controller: _amountController,
              onChanged: (_) => setState(() => _showAmountError = false),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Số tiền (VND)',
                hintText: '0',
                suffixText: '₫',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _showAmountError ? AppTheme.dangerRed : Colors.transparent,
                    width: _showAmountError ? 2.0 : 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _showAmountError ? AppTheme.dangerRed : theme.colorScheme.primary,
                    width: 2.0,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            // ── Danh mục ──
            Text(
              'Danh mục',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            CategoryPicker(
              selectedCategoryId: _selectedCategory,
              onSelected: (id) => setState(() => _selectedCategory = id),
            ),
            const SizedBox(height: 20),

            // ── Nút lưu ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.actionGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditMode ? 'Cập nhật' : 'Tạo mẫu',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();

    bool hasError = false;

    if (title.isEmpty) {
      setState(() => _showTitleError = true);
      hasError = true;
    }

    final cleanAmountText = amountText.replaceAll(RegExp(r'[^\d]'), '');
    final amount = double.tryParse(cleanAmountText);
    if (amount == null || amount <= 0) {
      setState(() => _showAmountError = true);
      hasError = true;
    }

    if (hasError) return;

    final cubit = context.read<FixedExpenseCubit>();

    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        // Tạo object mới thay vì mutate trực tiếp Isar managed object
        final updated = FixedExpense()
          ..id = widget.editTemplate!.id
          ..title = title
          ..amount = amount!
          ..categoryId = _selectedCategory
          ..note = null
          ..createdAt = widget.editTemplate!.createdAt;
        await cubit.updateTemplate(updated);
      } else {
        await cubit.addTemplate(
          title: title,
          amount: amount!,
          categoryId: _selectedCategory,
          note: null,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Lỗi lưu dữ liệu: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Helper — mở TemplateSheet dạng bottom sheet.
void showTemplateSheet(
  BuildContext context, {
  FixedExpense? editTemplate,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => BlocProvider.value(
      value: context.read<FixedExpenseCubit>(),
      child: TemplateSheet(editTemplate: editTemplate),
    ),
  );
}

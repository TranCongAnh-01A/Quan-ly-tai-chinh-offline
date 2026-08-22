import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import '../../../../logic/budget/budget_cubit.dart';
import '../../../widgets/category_picker.dart';

/// Dialog thêm/sửa hạn mức chi tiêu.
void showSetBudgetDialog(
  BuildContext context, {
  String? editCategoryId,
  double? editAmount,
  int? editBudgetId,
}) {
  final isEdit = editCategoryId != null;
  String selectedCategory = editCategoryId ?? 'food';
  final amountController = TextEditingController(
    text: editAmount != null
        ? NumberFormat('#,###', 'vi_VN').format(editAmount.round())
        : '',
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      bool showAmountError = false;
      
      return StatefulBuilder(
        builder: (context, setSheetState) {
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
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEdit
                        ? 'Chỉnh sửa hạn mức'
                        : 'Thiết lập hạn mức',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Danh mục
                  Text(
                    'Danh mục',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Chỉ cho chọn danh mục nếu đang thêm mới
                  AbsorbPointer(
                    absorbing: isEdit,
                    child: Opacity(
                      opacity: isEdit ? 0.6 : 1.0,
                      child: CategoryPicker(
                        selectedCategoryId: selectedCategory,
                        onSelected: (id) {
                          setSheetState(() => selectedCategory = id);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Số tiền
                  TextField(
                    controller: amountController,
                    onChanged: (_) {
                      if (showAmountError) {
                        setSheetState(() => showAmountError = false);
                      }
                    },
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyInputFormatter(),
                    ],
                    autofocus: !isEdit,
                    decoration: InputDecoration(
                      labelText: 'Hạn mức tháng (VND)',
                      hintText: 'VD: 1000000',
                      suffixText: '₫',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: showAmountError ? AppTheme.dangerRed : Colors.transparent,
                          width: showAmountError ? 2.0 : 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: showAmountError ? AppTheme.dangerRed : theme.colorScheme.primary,
                          width: 2.0,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nút hành động
                  Row(
                    children: [
                      // Nút xóa (chỉ hiện khi edit)
                      if (isEdit && editBudgetId != null)
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Xóa hạn mức?'),
                                    content: const Text(
                                      'Bạn có chắc muốn xóa hạn mức chi tiêu này?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: const Text('Hủy'),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          context
                                              .read<BudgetCubit>()
                                              .removeBudget(editBudgetId);
                                          Navigator.pop(dialogContext);
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.dangerRed,
                                        ),
                                        child: const Text('Xóa'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.dangerRed,
                                side: const BorderSide(
                                  color: AppTheme.dangerRed,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Xóa'),
                            ),
                          ),
                        ),
                      if (isEdit) const SizedBox(width: 12),

                      // Nút lưu
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: () {
                              final cleanText = amountController.text
                                  .trim()
                                  .replaceAll(RegExp(r'[^\d]'), '');
                              final amount = double.tryParse(cleanText);
                              if (amount == null || amount <= 0) {
                                setSheetState(() => showAmountError = true);
                                return;
                              }

                              context.read<BudgetCubit>().setBudget(
                                    categoryId: selectedCategory,
                                    amountLimit: amount,
                                  );
                              Navigator.pop(sheetContext);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryPastel,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              isEdit ? 'Cập nhật' : 'Thiết lập',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

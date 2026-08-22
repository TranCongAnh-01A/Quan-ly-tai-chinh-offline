import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/categories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/expense.dart' show FundingSource;
import '../../../../data/models/fixed_expense.dart';
import '../../../../logic/fixed_expense/fixed_expense_cubit.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'template_sheet.dart';

/// Bottom sheet hành động khi nhấn vào chi tiêu cố định.
///
/// Gộp 3 chức năng: Xác nhận thanh toán + Chỉnh sửa + Xóa
/// vào 1 sheet duy nhất thay vì tách tap/longpress riêng biệt.
void showFixedExpenseActions(BuildContext context, FixedExpense template) {
  final category = getCategoryById(template.categoryId);

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Thông tin template
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      category.icon,
                      color: category.color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatVND(template.amount),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppTheme.expenseRed,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(),

            // Xác nhận thanh toán (Tiền mặt)
            ListTile(
              leading: Icon(
                PhosphorIcons.wallet(PhosphorIconsStyle.fill),
                color: AppTheme.incomeGreen,
              ),
              title: const Text('Thanh toán bằng Tiền mặt'),
              subtitle: Text(
                'Ghi nhận ${formatVND(template.amount)} vào hôm nay',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                context
                    .read<FixedExpenseCubit>()
                    .confirmFixedExpense(template, source: FundingSource.cash);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Đã ghi nhận ${formatVND(template.amount)} từ Tiền mặt',
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: AppTheme.incomeGreen,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            // Xác nhận thanh toán (Tài khoản)
            ListTile(
              leading: Icon(
                PhosphorIcons.bank(PhosphorIconsStyle.fill),
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Thanh toán bằng Tài khoản'),
              subtitle: Text(
                'Ghi nhận ${formatVND(template.amount)} vào hôm nay',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                context
                    .read<FixedExpenseCubit>()
                    .confirmFixedExpense(template, source: FundingSource.bank);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Đã ghi nhận ${formatVND(template.amount)} từ Tài khoản',
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            // Chỉnh sửa
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Chỉnh sửa'),
              subtitle: const Text('Thay đổi tên, số tiền, danh mục'),
              onTap: () {
                Navigator.pop(sheetContext);
                showTemplateSheet(context, editTemplate: template);
              },
            ),

            // Xóa
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppTheme.dangerRed,
              ),
              title: const Text('Xóa mẫu'),
              subtitle: const Text('Lịch sử giao dịch không bị ảnh hưởng'),
              onTap: () {
                Navigator.pop(sheetContext);
                // Dialog xác nhận xóa
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Xóa chi tiêu cố định?'),
                    content: Text(
                      'Xóa mẫu "${template.title}"?\n'
                      'Lịch sử giao dịch đã tạo từ mẫu này sẽ không bị ảnh hưởng.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Hủy'),
                      ),
                      FilledButton(
                        onPressed: () {
                          context
                              .read<FixedExpenseCubit>()
                              .deleteTemplate(template.id);
                          Navigator.pop(dialogContext);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.expenseRed,
                        ),
                        child: const Text('Xóa'),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

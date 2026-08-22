import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/categories.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/receipt_storage.dart';
import '../../data/models/expense.dart';
import '../../logic/expense/expense_cubit.dart';
import '../screens/expense/add_expense_screen.dart';

import 'package:intl/intl.dart';

/// Hiển thị action sheet khi tap/longpress vào giao dịch.
///
/// Tại sao dùng shared utility thay vì code trong từng screen:
///   - DRY: cùng logic xóa/sửa ở HomeScreen + ExpenseListScreen
///   - Dễ thêm actions mới (undo, share...) chỉ cần sửa 1 nơi
///   - UX nhất quán: mọi nơi đều hiển thị bottom sheet giống nhau
void showExpenseActionSheet(BuildContext context, Expense expense) {
  final theme = Theme.of(context);
  final isTransfer = expense.isTransfer;
  final category = getCategoryById(expense.category);
  final categoryName = isTransfer
      ? (expense.source == FundingSource.cash ? 'Nạp tiền vào tài khoản' : 'Rút tiền mặt') 
      : (expense.isIncome ? 'Thu nhập' : category.name);
  final amountColor = isTransfer 
      ? theme.colorScheme.primary 
      : (expense.isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed);
  final sign = isTransfer ? '' : (expense.isIncome ? '+' : '-');

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
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header (Tên + Số tiền) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isTransfer 
                          ? theme.colorScheme.primary.withValues(alpha: 0.15) 
                          : category.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isTransfer ? PhosphorIcons.arrowsLeftRight(PhosphorIconsStyle.fill) : category.icon,
                      color: isTransfer ? theme.colorScheme.primary : category.color,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (expense.note?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            expense.note!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '$sign${formatVND(expense.amount)}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: amountColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isTransfer) ...[
                          Row(
                            children: [
                              Icon(
                                expense.source == FundingSource.cash ? PhosphorIcons.wallet() : PhosphorIcons.bank(),
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                expense.source == FundingSource.cash ? 'Tiền mặt' : 'Tài khoản',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                              ),
                              Icon(
                                expense.source == FundingSource.cash ? PhosphorIcons.bank() : PhosphorIcons.wallet(),
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                expense.source == FundingSource.cash ? 'Tài khoản' : 'Tiền mặt',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(
                                expense.source == FundingSource.cash
                                    ? PhosphorIcons.wallet()
                                    : PhosphorIcons.bank(),
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                expense.source == FundingSource.cash ? 'Tiền mặt' : 'Tài khoản',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Thời gian tạo giao dịch
                  Text(
                    DateFormat('dd/MM/yyyy\nHH:mm').format(expense.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),

            const Divider(),

            // Xem hóa đơn
            if (expense.receiptImagePath != null)
              ListTile(
                leading: Icon(
                  Icons.receipt_long,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Xem hóa đơn đính kèm'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showReceiptImage(context, expense.receiptImagePath!);
                },
              ),

            // Chỉnh sửa
            ListTile(
              enabled: !expense.isFixed,
              leading: Icon(
                Icons.edit_outlined,
                color: expense.isFixed
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                    : theme.colorScheme.primary,
              ),
              title: Text(
                'Chỉnh sửa',
                style: TextStyle(
                  color: expense.isFixed
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                      : null,
                ),
              ),
              subtitle: Text(
                expense.isFixed
                    ? 'Không thể sửa khoản thu/chi cố định'
                    : 'Thay đổi số tiền, danh mục, ghi chú',
                style: TextStyle(
                  color: expense.isFixed
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                      : null,
                ),
              ),
              onTap: expense.isFixed
                  ? null
                  : () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ExpenseCubit>(),
                            child: AddExpenseScreen(editExpense: expense),
                          ),
                        ),
                      );
                    },
            ),

            // Xóa
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppTheme.dangerRed,
              ),
              title: const Text('Xóa giao dịch'),
              subtitle: const Text('Không thể hoàn tác'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteConfirmation(context, expense);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Dialog xác nhận xóa — tách riêng để giữ code gọn.
void _showDeleteConfirmation(BuildContext context, Expense expense) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Xóa giao dịch?'),
      content: const Text('Bạn có chắc muốn xóa khoản này? Không thể hoàn tác.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            context.read<ExpenseCubit>().deleteExpense(expense.id);
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
}

void _showReceiptImage(BuildContext context, String storedPath) {
  // DB chỉ lưu tên file — ghép với thư mục documents hiện tại lúc đọc
  final imagePath = ReceiptStorage.resolve(storedPath);
  if (imagePath == null) return;

  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.black87,
                  child: const Text(
                    'Không tìm thấy ảnh hóa đơn.',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton.filled(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ),
        ],
      ),
    ),
  );
}

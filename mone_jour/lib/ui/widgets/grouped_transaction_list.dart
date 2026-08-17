import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/expense_grouper.dart';
import '../../data/models/expense.dart';

/// Widget hiển thị lịch sử giao dịch gộp nhóm theo ngày.
///
/// Cấu trúc kiểu app ngân hàng:
///   Header ngày (nhãn + tổng dư) → Danh sách items bên dưới.
class GroupedTransactionList extends StatelessWidget {
  final List<Expense> expenses;
  final int? maxItems;
  final void Function(Expense)? onTap;
  final void Function(Expense)? onLongPress;

  const GroupedTransactionList({
    super.key,
    required this.expenses,
    this.maxItems,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return _buildEmptyState(context);
    }

    final displayExpenses =
        maxItems != null ? expenses.take(maxItems!).toList() : expenses;
    final grouped = groupExpensesByDate(displayExpenses);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: grouped.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final date = grouped.keys.elementAt(index);
        final dayExpenses = grouped[date]!;

        return _DayGroup(
          date: date,
          expenses: dayExpenses,
          onTap: onTap,
          onLongPress: onLongPress,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 30,
                color: AppTheme.primaryPastel,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Chưa có giao dịch nào',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhóm giao dịch trong 1 ngày.
class _DayGroup extends StatelessWidget {
  final DateTime date;
  final List<Expense> expenses;
  final void Function(Expense)? onTap;
  final void Function(Expense)? onLongPress;

  const _DayGroup({
    required this.date,
    required this.expenses,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Chỉ tổng chi tiêu, bỏ qua thu nhập và chuyển khoản
    final dayExpenseTotal = expenses
        .where((e) => !e.isIncome && !e.isTransfer)
        .fold<double>(0.0, (sum, e) => sum + e.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ngày ──
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Row(
              children: [
                Text(
                  '${date.day} THÁNG ${date.month}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    fontSize: 11,
                  ),
                ),
                if (dayExpenseTotal > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    formatVND(dayExpenseTotal),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Card chứa items ──
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (int i = 0; i < expenses.length; i++) ...[
                  _TransactionItem(
                    expense: expenses[i],
                    onTap: onTap != null ? () => onTap!(expenses[i]) : null,
                    onLongPress: onLongPress != null
                        ? () => onLongPress!(expenses[i])
                        : null,
                  ),
                  // Divider giữa các item (không phải item cuối)
                  if (i < expenses.length - 1)
                    Divider(
                      height: 1,
                      indent: 62,
                      endIndent: 16,
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Item hiển thị 1 giao dịch.
class _TransactionItem extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _TransactionItem({
    required this.expense,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = getCategoryById(expense.category);
    final isTransfer = expense.isTransfer;
    final categoryName = isTransfer 
        ? (expense.source == FundingSource.cash ? 'Nạp tiền vào tài khoản' : 'Rút tiền mặt') 
        : (expense.isIncome ? 'Thu nhập' : category.name);
    final amountColor = isTransfer 
        ? theme.colorScheme.primary 
        : (expense.isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed);
    final sign = isTransfer ? '' : (expense.isIncome ? '+' : '-');

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // ── Icon danh mục ──
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isTransfer 
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : category.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isTransfer ? PhosphorIcons.arrowsLeftRight(PhosphorIconsStyle.fill) : category.icon,
                color: isTransfer ? theme.colorScheme.primary : category.color,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // ── Tên + ghi chú ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (expense.note != null && expense.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      expense.note!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Icons phụ (Bank/Receipt) ──
            if (expense.source == FundingSource.bank || expense.receiptImagePath != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (expense.source == FundingSource.bank)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(PhosphorIcons.bank(PhosphorIconsStyle.fill), size: 14, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  if (expense.receiptImagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(PhosphorIcons.camera(PhosphorIconsStyle.fill), size: 14, color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ],

            // ── Số tiền ──
            Text(
              '$sign${formatVND(expense.amount)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

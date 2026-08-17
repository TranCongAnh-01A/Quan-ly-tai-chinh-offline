import 'package:flutter/material.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/fixed_expense.dart';

/// Thẻ chi tiêu cố định — nhấn để thanh toán nhanh.
///
/// Thiết kế: card nhỏ gọn, nền hồng nhạt, icon danh mục + tiêu đề + số tiền.
class FixedExpenseCard extends StatelessWidget {
  final FixedExpense template;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double? width;

  const FixedExpenseCard({
    super.key,
    required this.template,
    required this.onTap,
    this.onLongPress,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final category = getCategoryById(template.categoryId);
    final theme = Theme.of(context);

    return SizedBox(
      width: width ?? 170,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon ──
                Container(
                  width: 42,
                  height: 42,
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

                const Spacer(),

                // ── Tiêu đề ──
                Text(
                  template.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                // ── Số tiền ──
                Text(
                  formatVND(template.amount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.expenseRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

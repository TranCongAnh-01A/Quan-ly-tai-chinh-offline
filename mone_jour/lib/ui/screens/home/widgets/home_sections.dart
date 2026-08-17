import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/categories.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/fixed_expense.dart';
import '../../../../logic/budget/budget_cubit.dart';
import '../../../../logic/expense/expense_cubit.dart';
import '../../../../logic/budget/budget_state.dart';
import '../../../widgets/fixed_expense_card.dart';
import '../../../widgets/budget_progress_card.dart';
import 'budget_dialog.dart';
import 'fixed_expense_actions_sheet.dart';
import 'template_sheet.dart';

class MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;

  const MonthSelector({super.key, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthStr = 'Tháng ${selectedMonth.month}, ${selectedMonth.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              context.read<ExpenseCubit>().previousMonth();
              final prev = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
              context.read<BudgetCubit>().loadBudgets(prev.month, prev.year);
            },
          ),
          Text(
            monthStr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              context.read<ExpenseCubit>().nextMonth();
              final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
              context.read<BudgetCubit>().loadBudgets(next.month, next.year);
            },
          ),
        ],
      ),
    );
  }
}

class FixedExpenseSection extends StatelessWidget {
  final List<FixedExpense> templates;

  const FixedExpenseSection({super.key, required this.templates});

  void _showAllFixedExpenses(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chi tiêu cố định (${templates.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: templates.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final template = templates[index];
                  final category = getCategoryById(template.categoryId);

                  return ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(category.icon, color: category.color, size: 20),
                    ),
                    title: Text(
                      template.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      formatVND(template.amount),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.expenseRed,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      showFixedExpenseActions(context, template);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chi tiêu cố định',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (templates.length > 3)
                    TextButton(
                      onPressed: () => _showAllFixedExpenses(context),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                      child: Text(
                        'Tất cả (${templates.length})',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => showTemplateSheet(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm'),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 125,
          child: PageView.builder(
            controller: PageController(viewportFraction: 1.0),
            itemCount: (templates.length / 3).ceil(),
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * 3;
              final endIndex = (startIndex + 3).clamp(0, templates.length);
              final pageTemplates = templates.sublist(startIndex, endIndex);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (int i = 0; i < pageTemplates.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: FixedExpenseCard(
                          template: pageTemplates[i],
                          onTap: () => showFixedExpenseActions(context, pageTemplates[i]),
                        ),
                      ),
                    ],
                    for (int i = pageTemplates.length; i < 3; i++) ...[
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class EmptyTemplateHint extends StatelessWidget {
  const EmptyTemplateHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () => showTemplateSheet(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(20),
            color: theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bookmark_add_outlined,
                  color: AppTheme.primaryPastel,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tạo chi tiêu cố định',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tiền trọ, điện nước, Netflix... thanh toán 1 chạm',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class BudgetSection extends StatelessWidget {
  final List<BudgetProgress> progresses;

  const BudgetSection({super.key, required this.progresses});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hạn mức chi tiêu',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: () => showSetBudgetDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: progresses
                .map((p) => BudgetProgressCard(
                      progress: p,
                      onTap: () => showSetBudgetDialog(
                        context,
                        editCategoryId: p.categoryId,
                        editAmount: p.amountLimit,
                        editBudgetId: p.budgetId,
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class EmptyBudgetHint extends StatelessWidget {
  const EmptyBudgetHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: InkWell(
        onTap: () => showSetBudgetDialog(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(20),
            color: theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppTheme.primaryPastel,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thiết lập hạn mức chi tiêu',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kiểm soát ngân sách theo danh mục mỗi tháng',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../logic/budget/budget_cubit.dart';
import '../../../logic/expense/expense_cubit.dart';
import '../../../logic/expense/expense_state.dart';
import '../../widgets/expense_action_sheet.dart';
import '../../widgets/filter_transaction_sheet.dart';
import '../../widgets/animated_slide_down.dart';
import '../../widgets/grouped_transaction_list.dart';
import '../../widgets/summary_card.dart';
import '../stats/stats_screen.dart';
import '../../widgets/tutorial_dialog.dart';
import 'add_expense_screen.dart';

/// Màn hình danh sách chi tiêu — hiển thị tổng hợp + danh sách theo tháng.
///
/// Layout:
///   - Header: nút chuyển tháng (< Tháng 05/2026 >)
///   - SummaryCard: Balance + Thu/Chi
///   - ListView: danh sách ExpenseCard (mới nhất trước)
///   - FAB: nút thêm mới
class ExpenseListScreen extends StatelessWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ExpenseCubit, ExpenseState>(
        builder: (context, state) {
          return switch (state) {
            ExpenseLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            ExpenseError(message: final msg) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.dangerRed),
                    const SizedBox(height: 12),
                    Text(msg, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          context.read<ExpenseCubit>().loadMonth(),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ExpenseLoaded() => _buildLoadedView(context, state),
          };
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_expense',
        onPressed: () => _openAddScreen(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLoadedView(BuildContext context, ExpenseLoaded state) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        // ── App Bar ──
        SliverAppBar(
          floating: true,
          leading: IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Hướng dẫn sử dụng',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const TutorialDialog(),
              );
            },
          ),
          title: Text(
            'Chi tiêu',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.pie_chart_outline),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const StatsScreen(),
                  ),
                );
              },
            ),
          ],
        ),




        // ── Chọn tháng & Summary Card ──
        SliverToBoxAdapter(
          child: FadeInSlideDown(
            index: 0,
            child: Column(
              children: [
                _buildMonthSelector(context, state.selectedMonth),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SummaryCard(
                    totalExpense: state.totalExpense,
                    totalIncome: state.totalIncome,
                    balance: state.balance,
                    totalCash: state.totalCash,
                    totalBank: state.totalBank,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Tiêu đề danh sách & Nút lọc ──
        SliverToBoxAdapter(
          child: FadeInSlideDown(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Text(
                    'Giao dịch gần đây',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.filter_list_rounded),
                    tooltip: 'Lọc giao dịch',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const FilterTransactionSheet(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Danh sách chi tiêu gộp nhóm theo ngày ──
        if (state.expenses.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: FadeInSlideDown(
              index: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có giao dịch nào',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nhấn + để thêm khoản chi tiêu đầu tiên',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: FadeInSlideDown(
              index: 2,
              child: GroupedTransactionList(
                expenses: state.expenses,
                onTap: (expense) => showExpenseActionSheet(context, expense),
              ),
            ),
          ),

        // Spacing cho FAB không che item cuối
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  /// Mở màn hình thêm chi tiêu mới.
  void _openAddScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ExpenseCubit>(),
          child: const AddExpenseScreen(),
        ),
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context, DateTime selectedMonth) {
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
              // Đồng bộ hạn mức chi tiêu sang tháng trước
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
              // Đồng bộ hạn mức chi tiêu sang tháng sau
              final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
              context.read<BudgetCubit>().loadBudgets(next.month, next.year);
            },
          ),
        ],
      ),
    );
  }

}

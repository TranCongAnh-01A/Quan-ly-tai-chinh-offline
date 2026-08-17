import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../logic/budget/budget_cubit.dart';
import '../../../logic/budget/budget_state.dart';
import '../../../logic/expense/expense_cubit.dart';
import '../../../logic/expense/expense_state.dart';
import '../../../logic/fixed_expense/fixed_expense_cubit.dart';
import '../../../logic/fixed_expense/fixed_expense_state.dart';
import '../../widgets/animated_slide_down.dart';
import '../../widgets/expense_action_sheet.dart';
import '../../widgets/filter_transaction_sheet.dart';
import '../../widgets/grouped_transaction_list.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/tutorial_dialog.dart';
import 'widgets/home_sections.dart';
import '../expense/add_expense_screen.dart';

/// Màn hình Trang chủ — Dashboard tổng quan + Chi tiêu cố định.
///
/// Layout (cuộn dọc):
///   1. Lời chào theo thời gian trong ngày
///   2. SummaryCard (Balance, Thu nhập, Chi tiêu tháng này)
///   3. Section "Chi tiêu cố định" (cuộn ngang)
///   4. Danh sách giao dịch gần đây (5 gần nhất)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  int _displayLimit = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 && !_isLoadingMore) {
      setState(() => _isLoadingMore = true);
      // Delay nhẹ để user thấy loading indicator
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _displayLimit += 20;
            _isLoadingMore = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
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
          'Giản Ký',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Summary Card ──
            FadeInSlideDown(
              index: 0,
              child: BlocBuilder<ExpenseCubit, ExpenseState>(
                builder: (context, state) {
                  if (state is ExpenseLoaded) {
                    return Column(
                      children: [
                        MonthSelector(selectedMonth: state.selectedMonth),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Stack(
                            children: [
                                SummaryCard(
                                  totalExpense: state.totalExpense,
                                  totalIncome: state.totalIncome,
                                  balance: state.balance,
                                  totalCash: state.totalCash,
                                  totalBank: state.totalBank,
                                ),
                              // Nút '+' thêm giao dịch nhanh
                              Positioned(
                                top: 8,
                                right: 24,
                                child: Material(
                                  color: AppTheme.primaryPastel.withValues(alpha: 0.15),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => _openAddExpenseScreen(context),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.add,
                                        color: AppTheme.primaryPastel,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),

            // ── Section: Chi tiêu cố định ──
            FadeInSlideDown(
              index: 1,
              child: BlocBuilder<FixedExpenseCubit, FixedExpenseState>(
                builder: (context, state) {
                  if (state is FixedExpenseLoaded && state.templates.isNotEmpty) {
                    return FixedExpenseSection(templates: state.templates);
                  }
                  return const EmptyTemplateHint();
                },
              ),
            ),

            // ── Section: Hạn mức chi tiêu ──
            FadeInSlideDown(
              index: 2,
              child: BlocBuilder<BudgetCubit, BudgetState>(
                builder: (context, state) {
                  if (state is BudgetLoaded && state.progresses.isNotEmpty) {
                    return BudgetSection(progresses: state.progresses);
                  }
                  return const EmptyBudgetHint();
                },
              ),
            ),

            // ── Section: Giao dịch gần đây ──
            FadeInSlideDown(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
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

            FadeInSlideDown(
              index: 4,
              child: BlocBuilder<ExpenseCubit, ExpenseState>(
                builder: (context, state) {
                  if (state is ExpenseLoaded) {
                    final hasMore = state.expenses.length > _displayLimit;
                    return Column(
                      children: [
                        GroupedTransactionList(
                          expenses: state.expenses,
                          maxItems: _displayLimit,
                          onTap: (expense) => showExpenseActionSheet(context, expense),
                        ),
                        // Loading indicator khi đang tải thêm
                        if (_isLoadingMore && hasMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                      ],
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// Mở màn hình thêm giao dịch mới (tái sử dụng từ ExpenseListScreen)
  void _openAddExpenseScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ExpenseCubit>(),
          child: const AddExpenseScreen(),
        ),
      ),
    );
  }
}


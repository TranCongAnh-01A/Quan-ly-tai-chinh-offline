import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../logic/stats/stats_cubit.dart';
import '../../../logic/stats/stats_state.dart';
import '../../widgets/grouped_transaction_list.dart';
import '../../widgets/expense_action_sheet.dart';

import 'widgets/stats_sections.dart';

/// Màn hình thống kê thu/chi theo tháng.
///
/// Hỗ trợ 2 kiểu biểu đồ:
///   - Biểu đồ tròn (Pie Chart) — nhìn tỷ lệ % giữa các danh mục
///   - Biểu đồ cột (Bar Chart) — so sánh số tiền tuyệt đối
/// Người dùng có thể chuyển đổi qua lại bằng nút toggle trên AppBar.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _touchedIndex = -1;
  bool _showIncome = false;

  /// true = biểu đồ tròn, false = biểu đồ cột
  bool _isPieChart = true;

  final ScrollController _scrollController = ScrollController();
  int _displayLimit = 10;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    context.read<StatsCubit>().loadStatsByMonth(now.month, now.year);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      setState(() {
        _displayLimit += 10;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thống kê',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Nút chuyển đổi kiểu biểu đồ
          IconButton(
            icon: Icon(_isPieChart ? Icons.bar_chart_rounded : Icons.pie_chart_rounded),
            tooltip: _isPieChart ? 'Biểu đồ cột' : 'Biểu đồ tròn',
            onPressed: () => setState(() {
              _isPieChart = !_isPieChart;
              _touchedIndex = -1;
            }),
          ),
        ],
      ),
      body: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, state) {
          if (state is StatsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is StatsError) {
            return Center(child: Text(state.message));
          }

          if (state is StatsLoaded) {
            return _buildContent(context, theme, state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, StatsLoaded state) {
    final dataMap = _showIncome ? state.incomesByCategory : state.expensesByCategory;
    final total = _showIncome ? state.totalIncome : state.totalExpense;

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          // ── Header chọn thời gian ──
          StatsFilterHeader(state: state),

          // ── Toggle Chi tiêu / Thu nhập ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Chi tiêu')),
                ButtonSegment(value: true, label: Text('Thu nhập')),
              ],
              selected: {_showIncome},
              onSelectionChanged: (set) => setState(() {
                _showIncome = set.first;
                _touchedIndex = -1;
              }),
              style: SegmentedButton.styleFrom(
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor:
                    _showIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Biểu đồ ──
          if (dataMap.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.insert_chart_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Không có dữ liệu',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Biểu đồ (Pie hoặc Bar)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isPieChart
                  ? StatsPieChart(
                      dataMap: dataMap,
                      total: total,
                      showIncome: _showIncome,
                      touchedIndex: _touchedIndex,
                      onTouch: (idx) => setState(() => _touchedIndex = idx),
                    )
                  : StatsBarChart(dataMap: dataMap),
            ),

            const SizedBox(height: 20),

            // ── Danh sách chi tiết theo danh mục ──
            StatsCategoryList(dataMap: dataMap, total: total),
            
            // ── Lịch sử giao dịch ──
            if (state.transactions.isNotEmpty) ...[
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Lịch sử giao dịch',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              GroupedTransactionList(
                expenses: state.transactions,
                maxItems: _displayLimit,
                onLongPress: (expense) => showExpenseActionSheet(context, expense),
              ),
              const SizedBox(height: 40),
            ],
          ],
        ],
      ),
    );
  }
}

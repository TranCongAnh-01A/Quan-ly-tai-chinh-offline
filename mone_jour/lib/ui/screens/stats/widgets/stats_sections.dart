import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/categories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../logic/stats/stats_cubit.dart';
import '../../../../logic/stats/stats_state.dart';

class StatsFilterHeader extends StatelessWidget {
  final StatsLoaded state;

  const StatsFilterHeader({super.key, required this.state});

  String _getFilterTitle() {
    switch (state.filterMode) {
      case FilterMode.month:
        return 'Tháng ${state.month}/${state.year}';
      case FilterMode.year:
        return 'Năm ${state.year}';
      case FilterMode.custom:
        if (state.startDate != null && state.endDate != null) {
          final start = '${state.startDate!.day}/${state.startDate!.month}/${state.startDate!.year}';
          final end = '${state.endDate!.day}/${state.endDate!.month}/${state.endDate!.year}';
          return '$start - $end';
        }
        return 'Tùy chỉnh';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (state.filterMode != FilterMode.custom)
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => context.read<StatsCubit>().previousPeriod(),
            )
          else
            const SizedBox(width: 48),

          Expanded(
            child: Center(
              child: PopupMenuButton<FilterMode>(
                initialValue: state.filterMode,
                onSelected: (mode) async {
                  if (mode == FilterMode.custom) {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      helpText: 'Chọn khoảng thời gian',
                      cancelText: 'Hủy',
                      confirmText: 'Xong',
                    );
                    if (picked != null && context.mounted) {
                      context.read<StatsCubit>().loadStatsByDateRange(picked.start, picked.end);
                    }
                  } else if (mode == FilterMode.year) {
                    context.read<StatsCubit>().loadStatsByYear(state.year ?? DateTime.now().year);
                  } else {
                    context.read<StatsCubit>().loadStatsByMonth(
                      state.month ?? DateTime.now().month,
                      state.year ?? DateTime.now().year,
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: FilterMode.month, child: Text('Theo tháng')),
                  PopupMenuItem(value: FilterMode.year, child: Text('Theo năm')),
                  PopupMenuItem(value: FilterMode.custom, child: Text('Tùy chỉnh khoảng ngày')),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getFilterTitle(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),

          if (state.filterMode != FilterMode.custom)
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => context.read<StatsCubit>().nextPeriod(),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class StatsCategoryList extends StatelessWidget {
  final Map<String, double> dataMap;
  final double total;

  const StatsCategoryList({
    super.key,
    required this.dataMap,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final entries = dataMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final category = getCategoryById(entry.key);
        final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(category.icon, color: category.color, size: 20),
          ),
          title: Text(
            category.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('${percentage.toStringAsFixed(1)}%'),
          trailing: Text(
            formatVND(entry.value),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        );
      },
    );
  }
}

class StatsPieChart extends StatelessWidget {
  final Map<String, double> dataMap;
  final double total;
  final bool showIncome;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const StatsPieChart({
    super.key,
    required this.dataMap,
    required this.total,
    required this.showIncome,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = dataMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      key: const ValueKey('pie'),
      height: 250,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    onTouch(-1);
                    return;
                  }
                  onTouch(pieTouchResponse.touchedSection!.touchedSectionIndex);
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 70,
              sections: List.generate(entries.length, (i) {
                final isTouched = i == touchedIndex;
                final radius = isTouched ? 60.0 : 50.0;
                final category = getCategoryById(entries[i].key);
                final value = entries[i].value;
                final percentage = (value / total) * 100;

                return PieChartSectionData(
                  color: category.color,
                  value: value,
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: isTouched ? 14.0 : 12.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tổng cộng', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  formatVND(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: showIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatsBarChart extends StatelessWidget {
  final Map<String, double> dataMap;

  const StatsBarChart({
    super.key,
    required this.dataMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = dataMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.isNotEmpty ? entries.first.value : 1.0;

    return SizedBox(
      key: const ValueKey('bar'),
      height: 250,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxValue * 1.3,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                tooltipMargin: 0,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    formatVND(rod.toY),
                    TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= entries.length) {
                      return const SizedBox.shrink();
                    }
                    final category = getCategoryById(entries[index].key);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Icon(category.icon, color: category.color, size: 20),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            barGroups: List.generate(entries.length, (i) {
              final category = getCategoryById(entries[i].key);
              return BarChartGroupData(
                x: i,
                showingTooltipIndicators: [0],
                barRods: [
                  BarChartRodData(
                    toY: entries[i].value,
                    color: category.color,
                    width: entries.length <= 4 ? 28 : 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

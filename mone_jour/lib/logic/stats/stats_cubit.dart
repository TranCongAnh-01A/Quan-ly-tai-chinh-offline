import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/expense.dart';
import '../../data/repositories/expense_repository.dart';
import 'stats_state.dart';

class StatsCubit extends Cubit<StatsState> {
  final ExpenseRepository _expenseRepo;
  StreamSubscription? _expenseWatcher;

  // Trạng thái bộ lọc hiện tại
  FilterMode _currentFilterMode = FilterMode.month;
  int _currentMonth = DateTime.now().month;
  int _currentYear = DateTime.now().year;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  StatsCubit({ExpenseRepository? expenseRepository})
      : _expenseRepo = expenseRepository ?? ExpenseRepository(),
        super(StatsInitial()) {
    _expenseWatcher = _expenseRepo.watchChanges().listen((_) {
      _reloadCurrentState();
    });
  }

  void _reloadCurrentState() {
    switch (_currentFilterMode) {
      case FilterMode.month:
        loadStatsByMonth(_currentMonth, _currentYear);
        break;
      case FilterMode.year:
        loadStatsByYear(_currentYear);
        break;
      case FilterMode.custom:
        if (_customStartDate != null && _customEndDate != null) {
          loadStatsByDateRange(_customStartDate!, _customEndDate!);
        }
        break;
    }
  }

  Future<void> loadStatsByMonth(int month, int year) async {
    try {
      emit(StatsLoading());
      _currentFilterMode = FilterMode.month;
      _currentMonth = month;
      _currentYear = year;

      final expenses = await _expenseRepo.getByMonth(year, month);
      _processAndEmitStats(expenses);
    } catch (e) {
      emit(StatsError(e.toString()));
    }
  }

  Future<void> loadStatsByYear(int year) async {
    try {
      emit(StatsLoading());
      _currentFilterMode = FilterMode.year;
      _currentYear = year;

      final start = DateTime(year, 1, 1);
      final end = DateTime(year, 12, 31, 23, 59, 59, 999, 999);
      final expenses = await _expenseRepo.getByDateRange(start, end);
      
      _processAndEmitStats(expenses);
    } catch (e) {
      emit(StatsError(e.toString()));
    }
  }

  Future<void> loadStatsByDateRange(DateTime start, DateTime end) async {
    try {
      emit(StatsLoading());
      _currentFilterMode = FilterMode.custom;
      
      // Đảm bảo startDate là 00:00:00 và endDate là 23:59:59
      _customStartDate = DateTime(start.year, start.month, start.day);
      _customEndDate = DateTime(end.year, end.month, end.day, 23, 59, 59, 999, 999);

      final expenses = await _expenseRepo.getByDateRange(_customStartDate!, _customEndDate!);
      
      _processAndEmitStats(expenses);
    } catch (e) {
      emit(StatsError(e.toString()));
    }
  }

  void _processAndEmitStats(List<Expense> expenses) {
    double totalExpense = 0;
    double totalIncome = 0;
    final expensesByCategory = <String, double>{};
    final incomesByCategory = <String, double>{};

    for (final e in expenses) {
      if (e.isTransfer) continue;
      if (e.isIncome) {
        totalIncome += e.amount;
        incomesByCategory[e.category] =
            (incomesByCategory[e.category] ?? 0) + e.amount;
      } else {
        totalExpense += e.amount;
        expensesByCategory[e.category] =
            (expensesByCategory[e.category] ?? 0) + e.amount;
      }
    }

    emit(StatsLoaded(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      expensesByCategory: expensesByCategory,
      incomesByCategory: incomesByCategory,
      filterMode: _currentFilterMode,
      month: _currentFilterMode == FilterMode.month ? _currentMonth : null,
      year: (_currentFilterMode == FilterMode.month || _currentFilterMode == FilterMode.year) 
          ? _currentYear : null,
      startDate: _currentFilterMode == FilterMode.custom ? _customStartDate : null,
      endDate: _currentFilterMode == FilterMode.custom ? _customEndDate : null,
      transactions: expenses,
    ));
  }

  // Helper methods cho nút Previous/Next (chỉ áp dụng cho Month/Year)
  Future<void> previousPeriod() async {
    if (_currentFilterMode == FilterMode.month) {
      int m = _currentMonth - 1;
      int y = _currentYear;
      if (m < 1) {
        m = 12;
        y -= 1;
      }
      await loadStatsByMonth(m, y);
    } else if (_currentFilterMode == FilterMode.year) {
      await loadStatsByYear(_currentYear - 1);
    }
  }

  Future<void> nextPeriod() async {
    if (_currentFilterMode == FilterMode.month) {
      int m = _currentMonth + 1;
      int y = _currentYear;
      if (m > 12) {
        m = 1;
        y += 1;
      }
      await loadStatsByMonth(m, y);
    } else if (_currentFilterMode == FilterMode.year) {
      await loadStatsByYear(_currentYear + 1);
    }
  }

  @override
  Future<void> close() {
    _expenseWatcher?.cancel();
    return super.close();
  }
}

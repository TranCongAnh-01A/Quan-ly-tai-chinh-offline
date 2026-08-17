import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/categories.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../../data/models/expense.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../logic/expense/expense_cubit.dart';
import '../../../logic/expense/expense_state.dart';
import 'expense_action_sheet.dart';
import 'grouped_transaction_list.dart';

enum TimeFilterType { all, month, customRange }

class FilterTransactionSheet extends StatefulWidget {
  const FilterTransactionSheet({super.key});

  @override
  State<FilterTransactionSheet> createState() => _FilterTransactionSheetState();
}

class _FilterTransactionSheetState extends State<FilterTransactionSheet> {
  final _noteController = TextEditingController();
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();
  String? _selectedCategory;

  bool _minAmountError = false;
  bool _maxAmountError = false;
  String? _formError;

  TimeFilterType _timeFilterType = TimeFilterType.month;
  DateTime? _selectedMonthDate;
  DateTimeRange? _selectedDateRange;

  List<Expense>? _results;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final expenseState = context.read<ExpenseCubit>().state;
    final now = DateTime.now();
    if (expenseState is ExpenseLoaded) {
      _selectedMonthDate = DateTime(
          expenseState.selectedMonth.year, expenseState.selectedMonth.month, 1);
    } else {
      _selectedMonthDate = DateTime(now.year, now.month, 1);
    }
    final firstDay = _selectedMonthDate!;
    final lastDay = DateTime(firstDay.year, firstDay.month + 1, 0);
    _selectedDateRange = DateTimeRange(start: firstDay, end: lastDay);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _onFilter() async {
    final note = _noteController.text.trim();
    final minAmountStr = _minAmountController.text.trim().replaceAll('.', '');
    final maxAmountStr = _maxAmountController.text.trim().replaceAll('.', '');
    
    final minAmount = double.tryParse(minAmountStr);
    final maxAmount = double.tryParse(maxAmountStr);

    setState(() {
      _minAmountError = false;
      _maxAmountError = false;
      _formError = null;
    });

    // Validate 1: Nếu nhập cả hai số tiền và số tối thiểu > số tối đa
    if (minAmount != null && maxAmount != null && minAmount > maxAmount) {
      setState(() {
        _minAmountError = true;
        _maxAmountError = true;
        _formError = 'Số tiền "Từ" không được lớn hơn số tiền "Đến"';
      });
      return;
    }

    // Validate 2: Phải điền ít nhất 1 trường
    if (note.isEmpty && minAmount == null && maxAmount == null && _selectedCategory == null && _timeFilterType == TimeFilterType.all) {
      setState(() => _formError = 'Vui lòng chọn hoặc nhập ít nhất 1 điều kiện để lọc');
      return;
    }

    setState(() {
      _isLoading = true;
      _results = null;
    });

    try {
      final repo = ExpenseRepository();
      
      DateTime? startDate;
      DateTime? endDate;
      
      if (_timeFilterType == TimeFilterType.month && _selectedMonthDate != null) {
        startDate = DateTime(_selectedMonthDate!.year, _selectedMonthDate!.month, 1);
        endDate = DateTime(_selectedMonthDate!.year, _selectedMonthDate!.month + 1, 0, 23, 59, 59, 999, 999);
      } else if (_timeFilterType == TimeFilterType.customRange && _selectedDateRange != null) {
        startDate = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day, 0, 0, 0);
        endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59, 999, 999);
      }

      final expenses = await repo.searchExpenses(
        note: note,
        minAmount: minAmount,
        maxAmount: maxAmount,
        categoryId: _selectedCategory,
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted) {
        setState(() {
          _results = expenses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lọc: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle bar ──
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Lọc giao dịch',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // ── Form Area (Scrollable) ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Ghi chú
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: 'Tên ghi chú',
                        prefixIcon: const Icon(Icons.edit_note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Khoảng tiền (Row 2 ô)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minAmountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              CurrencyInputFormatter(),
                            ],
                            onChanged: (_) {
                              if (_minAmountError) setState(() => _minAmountError = false);
                            },
                            decoration: InputDecoration(
                              labelText: 'Từ (đ)',
                              prefixIcon: const Icon(Icons.attach_money),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _minAmountError ? AppTheme.dangerRed : theme.colorScheme.outline,
                                  width: _minAmountError ? 2.0 : 1.0,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxAmountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              CurrencyInputFormatter(),
                            ],
                            onChanged: (_) {
                              if (_maxAmountError) setState(() => _maxAmountError = false);
                            },
                            decoration: InputDecoration(
                              labelText: 'Đến (đ)',
                              prefixIcon: const Icon(Icons.money_off),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _maxAmountError ? AppTheme.dangerRed : theme.colorScheme.outline,
                                  width: _maxAmountError ? 2.0 : 1.0,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Khoảng thời gian ──
                    Text(
                      'Thời gian',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTimeFilterChip('Theo tháng', TimeFilterType.month, theme),
                        const SizedBox(width: 8),
                        _buildTimeFilterChip('Khoảng ngày', TimeFilterType.customRange, theme),
                        const SizedBox(width: 8),
                        _buildTimeFilterChip('Tất cả', TimeFilterType.all, theme),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_timeFilterType == TimeFilterType.month) ...[
                      InkWell(
                        onTap: _pickMonthYear,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Text(
                                'Tháng ${_selectedMonthDate?.month}/${_selectedMonthDate?.year}',
                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              Icon(Icons.edit_calendar, size: 20, color: theme.colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (_timeFilterType == TimeFilterType.customRange) ...[
                      InkWell(
                        onTap: _pickCustomRange,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.date_range, color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedDateRange != null
                                      ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year}  –  ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}'
                                      : 'Chọn khoảng thời gian',
                                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.edit_calendar, size: 20, color: theme.colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      const SizedBox(height: 8),
                    ],

                    // Danh mục
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Danh mục',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Tất cả danh mục'),
                        ),
                        ...defaultExpenseCategories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat.id,
                            child: Row(
                              children: [
                                Icon(cat.icon, color: cat.color),
                                const SizedBox(width: 8),
                                Text(cat.name),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCategory = val;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Lỗi Form chung
                    if (_formError != null) ...[
                      Text(
                        _formError!,
                        style: const TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Nút Lọc
                    FilledButton.icon(
                      onPressed: _onFilter,
                      icon: const Icon(Icons.filter_list),
                      label: const Text('Lọc kết quả', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // ── Kết quả tìm kiếm ──
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_results != null) ...[
                      Row(
                        children: [
                          Text(
                            'Kết quả',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_results!.length} giao dịch',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_results!.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
                                const SizedBox(height: 8),
                                Text('Không tìm thấy giao dịch nào', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        )
                      else
                        GroupedTransactionList(
                          expenses: _results!,
                          onTap: (expense) => showExpenseActionSheet(context, expense),
                          onLongPress: (expense) => showExpenseActionSheet(context, expense),
                        ),
                      const SizedBox(height: 40), // Padding bottom
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildTimeFilterChip(String label, TimeFilterType type, ThemeData theme) {
    final isSelected = _timeFilterType == type;
    return Expanded(
      child: ChoiceChip(
        label: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _timeFilterType = type;
            });
          }
        },
        showCheckmark: false,
        selectedColor: theme.colorScheme.primaryContainer,
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonthYear() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonthDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'CHỌN NĂM VÀ THÁNG (BẤM VÀO 1 NGÀY BẤT KỲ CỦA THÁNG ĐÓ)',
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) {
      setState(() {
        _selectedMonthDate = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'CHỌN KHOẢNG THỜI GIAN',
      cancelText: 'Hủy',
      confirmText: 'Xong',
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }
}

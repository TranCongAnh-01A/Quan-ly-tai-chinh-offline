import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/categories.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/receipt_storage.dart';
import '../../../data/models/expense.dart';
import '../../../logic/budget/budget_cubit.dart';
import '../../../logic/budget/budget_state.dart';
import '../../../logic/expense/expense_cubit.dart';
import '../../widgets/category_picker.dart';
import '../auth/auth_wrapper.dart';

enum TransactionType { expense, income, transfer }

class AddExpenseScreen extends StatefulWidget {
  final Expense? editExpense;

  const AddExpenseScreen({super.key, this.editExpense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'food';
  TransactionType _txType = TransactionType.expense;
  late DateTime _selectedDate;
  bool _isSaving = false;
  bool _amountError = false;

  FundingSource _selectedSource = FundingSource.cash;

  /// Tên file ảnh hóa đơn (xem ReceiptStorage — KHÔNG lưu đường dẫn tuyệt đối)
  String? _receiptImagePath;

  /// Ảnh được chụp/chọn trong phiên làm việc này. Nếu người dùng thoát mà
  /// không lưu, hoặc thay bằng ảnh khác, các file này phải được xóa để không
  /// tích tụ ảnh mồ côi trong thư mục documents.
  final List<String> _sessionFiles = [];
  bool _savedSuccessfully = false;

  bool get _isEditMode => widget.editExpense != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final e = widget.editExpense!;
      _amountController.text = CurrencyInputFormatter()
          .formatEditUpdate(
            TextEditingValue.empty,
            TextEditingValue(text: e.amount.round().toString()),
          )
          .text;
      _noteController.text = e.note ?? '';
      _selectedCategory = e.category;
      
      if (e.isTransfer) {
        _txType = TransactionType.transfer;
      } else {
        _txType = e.isIncome ? TransactionType.income : TransactionType.expense;
      }
      
      _selectedDate = e.date;
      _selectedSource = e.source;
      _receiptImagePath = e.receiptImagePath;
    } else {
      _selectedDate = DateTime.now();
    }

    _amountController.addListener(() {
      if (_amountError && _amountController.text.isNotEmpty) {
        setState(() => _amountError = false);
      }
    });
  }

  @override
  void dispose() {
    // Dọn ảnh đã chụp trong phiên này nhưng cuối cùng không được lưu
    for (final fileName in _sessionFiles) {
      if (_savedSuccessfully && fileName == _receiptImagePath) continue;
      ReceiptStorage.delete(fileName);
    }

    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final picker = ImagePicker();
    AuthWrapper.pauseLock = true;
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70, // Tối ưu dung lượng
        maxWidth: 1024,
      );

      if (pickedFile != null) {
        final fileName = await ReceiptStorage.save(pickedFile.path);
        final replaced = _receiptImagePath;

        _sessionFiles.add(fileName);
        if (mounted) {
          setState(() => _receiptImagePath = fileName);
        }

        // Ảnh vừa chụp ở phiên này mà đã bị thay thế → xóa ngay, nó chưa
        // từng được giao dịch nào tham chiếu.
        if (replaced != null && _sessionFiles.remove(replaced)) {
          await ReceiptStorage.delete(replaced);
        }
      }
    } finally {
      AuthWrapper.pauseLock = false;
    }
  }

  /// Bỏ ảnh khỏi giao dịch.
  ///
  /// Chỉ xóa file ngay nếu đó là ảnh vừa chụp ở phiên này. Ảnh của giao dịch
  /// đã lưu chỉ được xóa sau khi lưu thành công — tránh mất ảnh nếu người
  /// dùng đổi ý và thoát màn hình.
  void _removeReceipt() {
    final removed = _receiptImagePath;
    setState(() => _receiptImagePath = null);

    if (removed != null && _sessionFiles.remove(removed)) {
      ReceiptStorage.delete(removed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Sửa giao dịch' : 'Thêm giao dịch'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.actionGreen,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Lưu'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Toggle Loại giao dịch ──
            Center(
              child: SegmentedButton<TransactionType>(
                segments: [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: const Text('Chi tiêu'),
                    icon: Icon(PhosphorIcons.arrowUpRight(PhosphorIconsStyle.bold)),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: const Text('Thu nhập'),
                    icon: Icon(PhosphorIcons.arrowDownLeft(PhosphorIconsStyle.bold)),
                  ),
                  ButtonSegment(
                    value: TransactionType.transfer,
                    label: const Text('Chuyển tiền'),
                    icon: Icon(PhosphorIcons.arrowsLeftRight(PhosphorIconsStyle.bold)),
                  ),
                ],
                selected: {_txType},
                onSelectionChanged: (value) {
                  setState(() {
                    _txType = value.first;
                    if (_txType == TransactionType.income) {
                      _selectedCategory = 'income';
                    } else if (_txType == TransactionType.expense && _selectedCategory == 'income') {
                      _selectedCategory = 'food';
                    } else if (_txType == TransactionType.transfer) {
                      _selectedCategory = 'transfer';
                    }
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      if (_txType == TransactionType.income) return AppTheme.actionGreen.withValues(alpha: 0.15);
                      if (_txType == TransactionType.expense) return AppTheme.expenseRed.withValues(alpha: 0.15);
                      return theme.colorScheme.primary.withValues(alpha: 0.15);
                    }
                    return null;
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Nguồn tiền ──
            if (_txType == TransactionType.transfer) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Từ', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _selectedSource == FundingSource.cash ? PhosphorIcons.wallet() : PhosphorIcons.bank(),
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedSource == FundingSource.cash ? 'Tiền mặt' : 'Tài khoản',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton.filledTonal(
                      onPressed: () {
                        setState(() {
                          _selectedSource = _selectedSource == FundingSource.cash
                              ? FundingSource.bank
                              : FundingSource.cash;
                        });
                      },
                      icon: Icon(PhosphorIcons.arrowsLeftRight()),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Đến', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _selectedSource == FundingSource.cash ? 'Tài khoản' : 'Tiền mặt',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _selectedSource == FundingSource.cash ? PhosphorIcons.bank() : PhosphorIcons.wallet(),
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: SegmentedButton<FundingSource>(
                  segments: [
                    ButtonSegment(
                      value: FundingSource.cash,
                      label: const Text('Tiền mặt'),
                      icon: Icon(PhosphorIcons.wallet(PhosphorIconsStyle.bold)),
                    ),
                    ButtonSegment(
                      value: FundingSource.bank,
                      label: const Text('Tài khoản'),
                      icon: Icon(PhosphorIcons.bank(PhosphorIconsStyle.bold)),
                    ),
                  ],
                  selected: {_selectedSource},
                  onSelectionChanged: (value) {
                    setState(() {
                      _selectedSource = value.first;
                    });
                  },
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Số tiền ──
            Text('Số tiền (VND)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _txType == TransactionType.income
                    ? AppTheme.actionGreen
                    : (_txType == TransactionType.expense ? AppTheme.expenseRed : theme.colorScheme.primary),
              ),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: '₫',
                suffixStyle: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _amountError ? AppTheme.expenseRed : theme.colorScheme.outline,
                    width: _amountError ? 2.0 : 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _amountError ? AppTheme.expenseRed : theme.colorScheme.primary,
                    width: 2.0,
                  ),
                ),
              ),
              autofocus: true,
            ),

            const SizedBox(height: 24),

            if (_txType == TransactionType.expense) ...[
              Text('Danh mục', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              CategoryPicker(
                selectedCategoryId: _selectedCategory,
                onSelected: (id) => setState(() => _selectedCategory = id),
              ),
              const SizedBox(height: 24),
            ],

            // ── Ngày ──
            Text('Ngày', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.calendarBlank(), size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(formatDateFull(_selectedDate), style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Hóa đơn ──
            Text('Hóa đơn', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_receiptImagePath != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(ReceiptStorage.resolve(_receiptImagePath)!),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        width: double.infinity,
                        alignment: Alignment.center,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Text(
                          'Không đọc được ảnh hóa đơn',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filled(
                      onPressed: _removeReceipt,
                      icon: Icon(PhosphorIcons.x()),
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickReceipt(ImageSource.camera),
                      icon: Icon(PhosphorIcons.camera()),
                      label: const Text('Chụp ảnh'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickReceipt(ImageSource.gallery),
                      icon: Icon(PhosphorIcons.image()),
                      label: const Text('Thư viện'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // ── Ghi chú ──
            Text('Ghi chú (tùy chọn)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Cà phê sáng với bạn...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim();
    final cleanAmountText = amountText.replaceAll(RegExp(r'[^\d]'), '');
    final amount = double.tryParse(cleanAmountText);

    if (amountText.isEmpty || amount == null || amount <= 0) {
      setState(() => _amountError = true);
      return;
    }

    final expenseCubit = context.read<ExpenseCubit>();
    final isIncome = _txType == TransactionType.income;
    final isTransfer = _txType == TransactionType.transfer;
    final finalCategory = isTransfer ? 'transfer' : _selectedCategory;

    // ── Kiểm tra cảnh báo hạn mức (chỉ áp dụng cho chi tiêu, không phải thu nhập/chuyển tiền) ──
    if (!isIncome && !isTransfer) {
      final budgetCubit = context.read<BudgetCubit>();
      final oldExpense = _isEditMode ? widget.editExpense! : null;
      // Chỉ khoản CHI (không phải thu nhập/chuyển tiền) mới nằm trong spending,
      // nên chỉ khoản chi cũ mới được trừ ra khi tính lại cảnh báo.
      final oldCounted =
          oldExpense != null && !oldExpense.isIncome && !oldExpense.isTransfer;
      final warning = await budgetCubit.checkBudgetWarning(
        finalCategory,
        amount,
        // Tra hạn mức theo tháng của giao dịch, không phải tháng đang xem
        date: _selectedDate,
        oldAmount: oldCounted ? oldExpense.amount : 0.0,
        oldCategoryId: oldCounted ? oldExpense.category : null,
        oldDate: oldCounted ? oldExpense.date : null,
      );

      if (warning != null && mounted) {
        final categoryName = getCategoryById(finalCategory).name;
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(
              warning.status == BudgetStatus.exceeded
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline_rounded,
              color: warning.status == BudgetStatus.exceeded
                  ? AppTheme.dangerRed
                  : Colors.orange,
              size: 40,
            ),
            title: Text(
              warning.status == BudgetStatus.exceeded
                  ? 'Vượt hạn mức!'
                  : 'Sắp vượt hạn mức',
            ),
            content: Text(
              'Danh mục "$categoryName" sẽ đạt ${warning.percentage}% hạn mức '
              'tháng ${_selectedDate.month}/${_selectedDate.year}.\n'
              'Bạn có chắc chắn muốn lưu giao dịch này?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: warning.status == BudgetStatus.exceeded
                      ? AppTheme.dangerRed
                      : Colors.orange,
                ),
                child: const Text('Vẫn lưu'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) return;
      }
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        final updated = Expense()
          ..id = widget.editExpense!.id
          ..amount = amount
          ..category = finalCategory
          ..isIncome = isIncome
          ..isTransfer = isTransfer
          ..source = _selectedSource
          ..receiptImagePath = _receiptImagePath
          ..date = _selectedDate
          ..note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim()
          ..isFixed = widget.editExpense!.isFixed
          ..createdAt = widget.editExpense!.createdAt;
        await expenseCubit.updateExpense(updated);
      } else {
        await expenseCubit.addExpense(
          amount: amount,
          category: finalCategory,
          isIncome: isIncome,
          isTransfer: isTransfer,
          source: _selectedSource,
          receiptImagePath: _receiptImagePath,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );
      }

      _savedSuccessfully = true;

      // Ảnh cũ không còn giao dịch nào trỏ tới → xóa để không tích tụ file rác
      final oldReceipt = widget.editExpense?.receiptImagePath;
      if (oldReceipt != null &&
          ReceiptStorage.fileNameOf(oldReceipt) !=
              (_receiptImagePath == null
                  ? null
                  : ReceiptStorage.fileNameOf(_receiptImagePath!))) {
        await ReceiptStorage.delete(oldReceipt);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Lỗi lưu dữ liệu: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.expenseRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../logic/budget/budget_cubit.dart';
import '../../../../logic/expense/expense_cubit.dart';
import '../../../../logic/fixed_expense/fixed_expense_cubit.dart';
import '../../../../logic/journal/journal_cubit.dart';
import '../../../../logic/stats/stats_cubit.dart';
import '../../../../services/import_service.dart';

/// Danh sách bản sao lưu tự động + nút khôi phục.
///
/// App tự chụp lại dữ liệu trước mỗi lần khôi phục/nhập file, nhưng các bản
/// chụp đó nằm trong thư mục riêng của app — bộ chọn file của hệ điều hành
/// không nhìn thấy. Không có màn hình này thì lưới an toàn coi như không có.
class AutoBackupCard extends StatefulWidget {
  const AutoBackupCard({super.key});

  @override
  State<AutoBackupCard> createState() => _AutoBackupCardState();
}

class _AutoBackupCardState extends State<AutoBackupCard> {
  final ImportService _importService = ImportService();

  List<AutoBackupEntry> _backups = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final backups = await _importService.listAutoBackups();
    if (!mounted) return;

    setState(() {
      _backups = backups;
      _isLoading = false;
    });
  }

  Future<void> _confirmRestore(AutoBackupEntry entry) async {
    final when = DateFormat('HH:mm dd/MM/yyyy').format(entry.createdAt);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Khôi phục bản tự động'),
        content: Text(
          'Quay lại dữ liệu tại thời điểm $when.\n\n'
          'Toàn bộ dữ liệu hiện tại sẽ bị thay thế. Trước khi ghi đè, app tự '
          'tạo thêm một bản sao lưu nữa nên bạn vẫn có thể quay lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _restore(entry);
  }

  Future<void> _restore(AutoBackupEntry entry) async {
    setState(() => _isLoading = true);

    final success = await _importService.restoreFromAutoBackup(entry);
    if (!mounted) return;

    if (success) {
      final now = DateTime.now();
      context.read<ExpenseCubit>().loadMonth(now);
      context.read<StatsCubit>().loadStatsByMonth(now.month, now.year);
      context.read<BudgetCubit>().loadBudgets();
      context.read<FixedExpenseCubit>().loadTemplates();
      context.read<JournalCubit>().loadJournals();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Đã khôi phục bản sao lưu tự động'
              : 'Không đọc được bản sao lưu này. Dữ liệu hiện tại được giữ nguyên.',
        ),
        backgroundColor: success ? AppTheme.incomeGreen : AppTheme.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Khôi phục xong lại sinh thêm 1 bản mới → nạp lại danh sách
    await _loadBackups();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_backups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Chưa có bản sao lưu tự động nào.\n'
                'App tự tạo trước mỗi lần khôi phục hoặc nhập dữ liệu.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            for (final entry in _backups)
              ListTile(
                leading: Icon(
                  Icons.history_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  DateFormat('HH:mm dd/MM/yyyy').format(entry.createdAt),
                ),
                subtitle: Text(entry.readableSize),
                trailing: TextButton(
                  onPressed: () => _confirmRestore(entry),
                  child: const Text('Khôi phục'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Giữ ${ImportService.maxAutoBackups} bản gần nhất, '
                'tự tạo trước mỗi lần khôi phục hoặc nhập dữ liệu.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

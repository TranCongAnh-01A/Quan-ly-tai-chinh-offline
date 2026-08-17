import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../logic/theme/theme_cubit.dart';
import '../../../../logic/settings/settings_cubit.dart';
import '../../../../logic/settings/settings_state.dart';
import '../../../../logic/expense/expense_cubit.dart';
import '../../../../logic/stats/stats_cubit.dart';
import '../../../../logic/budget/budget_cubit.dart';
import '../../../../logic/fixed_expense/fixed_expense_cubit.dart';
import '../../../../logic/cloud_sync/cloud_sync_cubit.dart';
import '../../../../logic/cloud_sync/cloud_sync_state.dart';
import '../../../../services/export_service.dart';
import '../../../../services/import_service.dart';
import '../../auth/pin_screen.dart';

class SettingsSectionTitle extends StatelessWidget {
  final String title;

  const SettingsSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

class CloudSyncCard extends StatelessWidget {
  const CloudSyncCard({super.key});

  String _formatTime(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return isoString;
    }
  }

  void _showRestoreConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận khôi phục'),
        content: const Text(
          'Hành động này sẽ XÓA TOÀN BỘ dữ liệu hiện tại trong máy và tải dữ liệu từ Google Drive về đè lên. Bạn có chắc chắn không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CloudSyncCubit>().restoreNow();
            },
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<CloudSyncCubit, CloudSyncState>(
      listener: (context, state) {
        if (state is CloudSyncError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is CloudSyncSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final isConnected = state is CloudSyncConnected || state is CloudSyncSuccess;
        final email = state is CloudSyncConnected
            ? state.email
            : (state is CloudSyncSuccess ? state.email : null);
        final lastSyncTime = state is CloudSyncConnected
            ? state.lastSyncTime
            : (state is CloudSyncSuccess ? state.lastSyncTime : null);
        final isLoading = state is CloudSyncLoading;

        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_sync, color: AppTheme.primaryPastel),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected ? 'Đã liên kết Google Drive' : 'Đồng bộ Google Drive',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (email != null)
                            Text(
                              email,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          if (lastSyncTime != null)
                            Text(
                              'Lần cuối: ${_formatTime(lastSyncTime)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          if (isConnected) {
                            context.read<CloudSyncCubit>().signOut();
                          } else {
                            context.read<CloudSyncCubit>().signIn();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConnected ? Colors.red.shade100 : AppTheme.primaryPastel,
                          foregroundColor: isConnected ? Colors.red : Colors.white,
                          elevation: 0,
                        ),
                        child: Text(isConnected ? 'Hủy' : 'Liên kết'),
                      ),
                  ],
                ),
                if (isConnected) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLoading ? null : () => context.read<CloudSyncCubit>().backupNow(),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Sao lưu'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLoading ? null : () => _showRestoreConfirmDialog(context),
                          icon: const Icon(Icons.download),
                          label: const Text('Khôi phục'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class ThemeCard extends StatelessWidget {
  const ThemeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          final isSystemDark =
              MediaQuery.of(context).platformBrightness == Brightness.dark;
          final isDark = state.themeMode == ThemeMode.dark ||
              (state.themeMode == ThemeMode.system && isSystemDark);

          return SwitchListTile(
            title: Text(
              'Chế độ tối (Dark Mode)',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Đổi màu nền đen để bảo vệ mắt',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            value: isDark,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.primaryPastel,
            onChanged: (value) {
              context.read<ThemeCubit>().toggleTheme(value);
            },
          );
        },
      ),
    );
  }
}

class SecurityCard extends StatelessWidget {
  const SecurityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return Column(
            children: [
              SwitchListTile(
                title: Text(
                  'Khóa ứng dụng',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Yêu cầu mã PIN 4 số khi mở app',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: state.isPinEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: AppTheme.primaryPastel,
                onChanged: (value) async {
                  if (value) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PinScreen(mode: PinMode.setup),
                      ),
                    );
                  } else {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PinScreen(mode: PinMode.remove),
                      ),
                    );
                  }
                },
              ),
              if (state.isPinEnabled) ...[
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    'Đổi mã PIN',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final verified = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PinScreen(mode: PinMode.verify),
                      ),
                    );
                    if (verified == true && context.mounted) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PinScreen(mode: PinMode.setup),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                BiometricSwitch(isBiometricEnabled: state.isBiometricEnabled),
              ],
            ],
          );
        },
      ),
    );
  }
}

class BiometricSwitch extends StatefulWidget {
  final bool isBiometricEnabled;
  
  const BiometricSwitch({super.key, required this.isBiometricEnabled});

  @override
  State<BiometricSwitch> createState() => _BiometricSwitchState();
}

class _BiometricSwitchState extends State<BiometricSwitch> {
  bool _isSupported = true; 
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final auth = LocalAuthentication();
    final canCheck = await auth.canCheckBiometrics;
    final isSupported = await auth.isDeviceSupported();
    if (mounted) {
      setState(() {
        _isSupported = canCheck && isSupported;
        _hasChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supported = !_hasChecked || _isSupported;

    return SwitchListTile(
      title: Text(
        'Mở khóa bằng vân tay',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: supported ? null : theme.colorScheme.onSurface.withValues(alpha: 0.38),
        ),
      ),
      subtitle: Text(
        !supported
            ? 'Thiết bị không hỗ trợ vân tay'
            : (widget.isBiometricEnabled
                ? 'Đang bật — nhấn để tắt'
                : 'Sử dụng vân tay để mở khóa'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: supported ? 1.0 : 0.38),
        ),
      ),
      value: supported ? widget.isBiometricEnabled : false,
      activeThumbColor: Colors.white,
      activeTrackColor: AppTheme.primaryPastel,
      onChanged: supported
          ? (value) {
              context.read<SettingsCubit>().setBiometricEnabled(value);
            }
          : null,
    );
  }
}

class DataCard extends StatelessWidget {
  const DataCard({super.key});

  void _showExportOptions(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                'Chọn định dạng xuất file',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.data_object_rounded),
                title: const Text('Định dạng JSON'),
                subtitle: const Text('1 file duy nhất, thích hợp để khôi phục sau này'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await ExportService().exportToJson();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.table_view_rounded),
                title: const Text('Định dạng CSV (Zip)'),
                subtitle: const Text('Nhiều file riêng biệt, xem trên Excel/Google Sheets'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await ExportService().exportToCsvZip();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showImportOptions(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        Future<void> handleImport(Future<bool> Function() importFunction, String type) async {
          Navigator.pop(sheetContext);

          final hasData = await ImportService().hasAnyData();
          if (hasData && context.mounted) {
            final shouldBackup = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Phát hiện dữ liệu hiện tại'),
                content: const Text(
                  'Bạn đang có dữ liệu trong ứng dụng. Quá trình nhập sẽ xóa toàn bộ dữ liệu hiện tại. Bạn có muốn sao lưu dữ liệu hiện tại trước không?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null), 
                    child: const Text('Hủy nhập'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Không, xóa sạch', style: TextStyle(color: AppTheme.dangerRed)),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Có, sao lưu'),
                  ),
                ],
              ),
            );

            if (shouldBackup == null) return; 
            if (shouldBackup == true) {
              await ExportService().exportToJson(); 
            }
          }
          
          if (!context.mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          final success = await importFunction();
          
          if (context.mounted) {
            Navigator.pop(context); 
            
            if (success) {
              final now = DateTime.now();
              context.read<ExpenseCubit>().loadMonth(now);
              context.read<StatsCubit>().loadStatsByMonth(now.month, now.year);
              context.read<BudgetCubit>().loadBudgets();
              context.read<FixedExpenseCubit>().loadTemplates();
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? 'Nhập dữ liệu $type thành công' : 'Nhập dữ liệu $type thất bại'),
                backgroundColor: success ? AppTheme.incomeGreen : AppTheme.dangerRed,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                'Chọn định dạng nhập file',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.data_object_rounded),
                title: const Text('Định dạng JSON'),
                subtitle: const Text('Khôi phục từ file .json đã xuất'),
                onTap: () => handleImport(() => ImportService().importFromJson(), 'JSON'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.table_view_rounded),
                title: const Text('Định dạng CSV (Zip)'),
                subtitle: const Text('Khôi phục từ file .zip chứa các file csv'),
                onTap: () => handleImport(() => ImportService().importFromCsvZip(), 'CSV Zip'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
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
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.upload_rounded, color: theme.colorScheme.primary),
            title: Text(
              'Xuất dữ liệu (Export)',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Lưu bản sao dữ liệu sang máy khác',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showExportOptions(context, theme),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.download_rounded, color: theme.colorScheme.primary),
            title: Text(
              'Nhập dữ liệu (Import)',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Khôi phục dữ liệu từ bản sao (Sẽ ghi đè)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showImportOptions(context, theme),
          ),
        ],
      ),
    );
  }
}

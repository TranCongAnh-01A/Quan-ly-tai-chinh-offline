import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/journal.dart';
import '../../../logic/journal/journal_cubit.dart';
import '../../../logic/journal/journal_state.dart';
import 'note_editor_screen.dart';
import '../../widgets/tutorial_dialog.dart';
import '../../widgets/animated_slide_down.dart';

/// Màn hình danh sách ghi chú.
///
/// Hiển thị các ghi chú dưới dạng "khối" (card) giống Google Keep:
///   - Mỗi card hiển thị tiêu đề (nếu có) + preview nội dung
///   - Tap → mở NoteEditorScreen full-screen
///   - Long press → bảng tùy chọn xóa
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  @override
  void initState() {
    super.initState();
    context.read<JournalCubit>().loadJournals();
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
          'Ghi chú',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: BlocBuilder<JournalCubit, JournalState>(
        builder: (context, state) {
          if (state is JournalLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is JournalError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppTheme.dangerRed),
                  const SizedBox(height: 12),
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        context.read<JournalCubit>().loadJournals(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (state is JournalLoaded) {
            if (state.journals.isEmpty) {
              return _buildEmptyState(theme);
            }
            return _buildNotesList(context, state.journals);
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Trạng thái rỗng — hiển thị khi chưa có ghi chú nào
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.note_alt_outlined,
              size: 36,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có ghi chú nào',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nhấn + để tạo ghi chú đầu tiên',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Danh sách ghi chú dạng khối
  Widget _buildNotesList(BuildContext context, List<Journal> journals) {
    return ListView.separated(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 80),
      itemCount: journals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return FadeInSlideDown(
          index: index,
          child: _NoteCard(
            note: journals[index],
            onTap: () => _openEditor(context, editNote: journals[index]),
            onLongPress: () => _showDeleteSheet(context, journals[index]),
          ),
        );
      },
    );
  }

  /// Mở màn hình chỉnh sửa full-screen
  void _openEditor(BuildContext context, {Journal? editNote}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<JournalCubit>(),
          child: NoteEditorScreen(editNote: editNote),
        ),
      ),
    );
  }

  /// Hiển thị bảng tùy chọn xóa khi ấn đè
  void _showDeleteSheet(BuildContext context, Journal note) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Thông tin ghi chú
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title?.isNotEmpty == true
                            ? note.title!
                            : note.content.length > 40
                                ? '${note.content.substring(0, 40)}...'
                                : note.content,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Nút xóa
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.dangerRed,
                ),
                title: const Text('Xóa ghi chú'),
                subtitle: const Text('Không thể hoàn tác'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context, note);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Dialog xác nhận xóa
  void _confirmDelete(BuildContext context, Journal note) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa ghi chú?'),
        content: const Text('Bạn có chắc muốn xóa ghi chú này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              context.read<JournalCubit>().deleteJournal(note.id);
              Navigator.pop(dialogContext);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

/// Widget hiển thị một khối ghi chú.
///
/// Cấu trúc:
///   - Tiêu đề (in đậm, lớn) — nếu có
///   - Preview nội dung (giới hạn 3 dòng)
///   - Nhãn ngày tạo ở dưới cùng
class _NoteCard extends StatelessWidget {
  final Journal note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTitle = note.title != null && note.title!.isNotEmpty;
    final dateStr = DateFormat('dd/MM/yyyy').format(note.date);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Tiêu đề ──
              if (hasTitle) ...[
                Text(
                  note.title!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
              ],

              // ── Nội dung preview ──
              Text(
                note.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 10),

              // ── Ngày tạo ──
              Text(
                dateStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/models/journal.dart';
import '../../../logic/journal/journal_cubit.dart';

/// Màn hình chỉnh sửa ghi chú toàn màn hình.
///
/// Tại sao dùng full-screen thay vì bottom sheet:
///   - UX tốt hơn cho việc nhập liệu dài (bàn phím không chiếm hết sheet)
///   - Tương đồng với trải nghiệm các app ghi chú phổ biến (Apple Notes, Google Keep)
///   - Tự động lưu khi rời khỏi màn hình → người dùng không sợ mất dữ liệu
class NoteEditorScreen extends StatefulWidget {
  /// Nếu null → tạo mới, nếu có → chỉnh sửa ghi chú đã tồn tại
  final Journal? editNote;

  const NoteEditorScreen({super.key, this.editNote});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;

  /// Ghi nhận trạng thái ban đầu để so sánh khi rời màn hình
  late final String _initialTitle;
  late final String _initialContent;

  /// Cờ chống lưu trùng lặp — tránh tạo 2 bản ghi khi cả AppBar back
  /// và PopScope đều trigger _saveNote
  bool _hasSaved = false;

  bool get _isEditing => widget.editNote != null;

  bool get _hasChanges =>
      _titleController.text.trim() != _initialTitle ||
      _contentController.text.trim() != _initialContent;

  bool get _hasContent => _contentController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.editNote?.title ?? '');
    _contentController =
        TextEditingController(text: widget.editNote?.content ?? '');
    _contentFocusNode = FocusNode();

    _initialTitle = widget.editNote?.title?.trim() ?? '';
    _initialContent = widget.editNote?.content.trim() ?? '';

    // Tự động focus vào nội dung khi tạo mới
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _contentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  /// Lưu ghi chú — gọi khi bấm nút lưu hoặc khi rời màn hình.
  /// Cờ _hasSaved đảm bảo chỉ lưu đúng 1 lần duy nhất.
  Future<void> _saveNote() async {
    if (_hasSaved) return;
    if (!mounted) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Không lưu ghi chú rỗng
    if (content.isEmpty) return;

    // Không lưu nếu không có thay đổi
    if (!_hasChanges) return;

    _hasSaved = true;

    final cubit = context.read<JournalCubit>();

    if (_isEditing) {
      final updated = widget.editNote!
        ..title = title.isEmpty ? null : title
        ..content = content;
      await cubit.updateJournal(updated);
    } else {
      await cubit.addJournal(
        title: title.isEmpty ? null : title,
        content: content,
        date: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = _isEditing
        ? DateFormat("dd 'tháng' MM, yyyy – HH:mm", 'vi_VN')
            .format(widget.editNote!.date)
        : DateFormat("dd 'tháng' MM, yyyy – HH:mm", 'vi_VN')
            .format(DateTime.now());

    return PopScope(
      // Chặn back hệ thống → lưu trước, pop sau (tránh controller bị dispose)
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return; // Đã pop rồi thì không xử lý nữa
        await _saveNote();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _saveNote();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          actions: [
            // Nút lưu thủ công (hiển thị khi có nội dung)
            ListenableBuilder(
              listenable: _contentController,
              builder: (context, _) {
                return TextButton(
                  onPressed: _hasContent
                      ? () async {
                          await _saveNote();
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      : null,
                  child: Text(
                    'Lưu',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _hasContent
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Nhãn thời gian ──
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Text(
                  dateStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),

              // ── Tiêu đề ──
              TextField(
                controller: _titleController,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tiêu đề',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
              ),

              const Divider(height: 24),

              // ── Nội dung ──
              TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                ),
                decoration: const InputDecoration(
                  hintText: 'Bắt đầu viết...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                minLines: 20,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

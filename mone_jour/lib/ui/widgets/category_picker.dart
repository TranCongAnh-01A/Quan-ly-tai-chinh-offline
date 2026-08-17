import 'package:flutter/material.dart';

import '../../core/constants/categories.dart';

/// Component chọn danh mục chi tiêu.
///
/// Hiển thị các danh mục dạng Wrap ChoiceChip (loại bỏ 'income').
/// Chip được chọn có nền và viền màu tương ứng của danh mục.
class CategoryPicker extends StatelessWidget {
  final String selectedCategoryId;
  final ValueChanged<String> onSelected;

  const CategoryPicker({
    super.key,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseCategories = defaultExpenseCategories
        .where((c) => c.id != 'income')
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: expenseCategories.map((category) {
        final isSelected = category.id == selectedCategoryId;
        
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.icon,
                size: 16,
                color: isSelected
                    ? category.color
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(category.name),
            ],
          ),
          selected: isSelected,
          onSelected: (_) => onSelected(category.id),
          selectedColor: category.color.withValues(alpha: 0.15),
          backgroundColor: theme.colorScheme.surface,
          side: BorderSide(
            color: isSelected
                ? category.color
                : theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          labelStyle: TextStyle(
            color: isSelected
                ? category.color
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        );
      }).toList(),
    );
  }
}

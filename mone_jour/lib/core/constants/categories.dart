import 'package:flutter/material.dart';

/// Danh mục chi tiêu mặc định cho MVP.
///
/// Tại sao dùng class thay enum:
///   - Dễ mở rộng sang custom categories (Phase 2)
///   - Chứa được icon + color cho UI mà không cần map riêng
class ExpenseCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// Danh sách danh mục chi tiêu mặc định
const List<ExpenseCategory> defaultExpenseCategories = [
  ExpenseCategory(
    id: 'food',
    name: 'Ăn uống',
    icon: Icons.restaurant,
    color: Color(0xFFFF6B6B),
  ),
  ExpenseCategory(
    id: 'transport',
    name: 'Di chuyển',
    icon: Icons.directions_car,
    color: Color(0xFF4ECDC4),
  ),
  ExpenseCategory(
    id: 'shopping',
    name: 'Mua sắm',
    icon: Icons.shopping_bag,
    color: Color(0xFFFFE66D),
  ),
  ExpenseCategory(
    id: 'entertainment',
    name: 'Giải trí',
    icon: Icons.movie,
    color: Color(0xFFA78BFA),
  ),
  ExpenseCategory(
    id: 'bills',
    name: 'Hóa đơn',
    icon: Icons.receipt_long,
    color: Color(0xFF60A5FA),
  ),
  ExpenseCategory(
    id: 'health',
    name: 'Sức khỏe',
    icon: Icons.favorite,
    color: Color(0xFFF472B6),
  ),
  ExpenseCategory(
    id: 'education',
    name: 'Học tập',
    icon: Icons.school,
    color: Color(0xFF34D399),
  ),
  ExpenseCategory(
    id: 'income',
    name: 'Thu nhập',
    icon: Icons.account_balance_wallet,
    color: Color(0xFF10B981),
  ),
  ExpenseCategory(
    id: 'other',
    name: 'Khác',
    icon: Icons.more_horiz,
    color: Color(0xFF94A3B8),
  ),
];

/// Tra cứu nhanh danh mục theo ID
ExpenseCategory getCategoryById(String id) {
  return defaultExpenseCategories.firstWhere(
    (c) => c.id == id,
    orElse: () => defaultExpenseCategories.last,
  );
}

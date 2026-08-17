import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';

class SummaryCard extends StatelessWidget {
  final double totalExpense;
  final double totalIncome;
  final double balance;
  final double totalCash;
  final double totalBank;

  const SummaryCard({
    super.key,
    required this.totalExpense,
    required this.totalIncome,
    required this.balance,
    required this.totalCash,
    required this.totalBank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          // Số dư tổng
          Text(
            'Tổng tài sản',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatVND(balance),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 20),
          
          // Chi tiết Cash / Bank
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniBalance(context, 'Tiền mặt', totalCash, PhosphorIcons.wallet(PhosphorIconsStyle.bold)),
              const SizedBox(width: 24),
              _buildMiniBalance(context, 'Tài khoản', totalBank, PhosphorIcons.bank(PhosphorIconsStyle.bold)),
            ],
          ),

          const SizedBox(height: 24),
          Divider(color: Theme.of(context).colorScheme.outline, height: 1),
          const SizedBox(height: 16),

          // Thu nhập vs Chi tiêu
          Row(
            children: [
              Expanded(
                child: _buildSubItem(
                  context: context,
                  icon: PhosphorIcons.arrowDownLeft(PhosphorIconsStyle.bold),
                  label: 'Thu nhập',
                  amount: formatVND(totalIncome),
                  color: AppTheme.actionGreen,
                ),
              ),
              Container(width: 1, height: 40, color: Theme.of(context).colorScheme.outline),
              Expanded(
                child: _buildSubItem(
                  context: context,
                  icon: PhosphorIcons.arrowUpRight(PhosphorIconsStyle.bold),
                  label: 'Chi tiêu',
                  amount: formatVND(totalExpense),
                  color: AppTheme.expenseRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBalance(BuildContext context, String label, double amount, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(formatVND(amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
      ],
    );
  }

  Widget _buildSubItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String amount,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          amount,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

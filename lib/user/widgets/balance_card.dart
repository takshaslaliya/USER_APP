import 'package:flutter/material.dart';
import 'package:splitease_test/core/theme/app_theme.dart';

class BalanceCard extends StatelessWidget {
  final double totalBalance;
  final double youOwe;
  final double youGet;

  const BalanceCard({
    super.key,
    required this.totalBalance,
    required this.youOwe,
    required this.youGet,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Force everything to be explicit white when card is solid orange
    const Color cardTextColor = Colors.white;
    const Color cardSubColor = Colors.white70;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : AppColors.softShadowColor,
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: TextStyle(
              color: cardSubColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${_format(totalBalance)}',
            style: TextStyle(
              color: cardTextColor,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _statColumn(
                  label: 'You Owe',
                  amount: youOwe,
                  color: Colors.white,
                  icon: Icons.arrow_upward_rounded,
                  textColor: cardTextColor,
                  subColor: cardSubColor,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _statColumn(
                  label: 'You Get',
                  amount: youGet,
                  color: Colors.white,
                  icon: Icons.arrow_downward_rounded,
                  textColor: cardTextColor,
                  subColor: cardSubColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  (youGet - youOwe) >= 0
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: cardTextColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  (youGet - youOwe) >= 0
                      ? 'You are in credit by ₹${_format(youGet - youOwe)}'
                      : 'You owe overall ₹${_format(youOwe - youGet)}',
                  style: const TextStyle(
                    color: cardTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
    required Color textColor,
    required Color subColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: subColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '₹${_format(amount)}',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _format(double val) {
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}K';
    }
    return val.toStringAsFixed(0);
  }
}

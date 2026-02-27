import 'package:flutter/material.dart';
import '../models/split_model.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

class SplitCard extends StatelessWidget {
  final SplitModel split;
  final VoidCallback? onTap;

  const SplitCard({super.key, required this.split, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(
            color: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurfaceVariant,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Category icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _categoryEmoji(split.category),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        split.title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${split.members.length} members · ${split.category}',
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_format(split.totalAmount)}',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusChip(
                      isPaid: split.status == SplitStatus.paid,
                      small: true,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: split.progressPercent,
                backgroundColor: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  split.status == SplitStatus.paid
                      ? AppColors.paid
                      : AppColors.primary,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${split.paidCount}/${split.members.length} paid',
              style: TextStyle(color: subColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryEmoji(String cat) {
    switch (cat.toLowerCase()) {
      case 'travel':
        return '✈️';
      case 'food':
        return '🍽️';
      case 'bills':
        return '🏠';
      case 'entertainment':
        return '📺';
      default:
        return '💰';
    }
  }

  String _format(double val) {
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}K';
    }
    return val.toStringAsFixed(0);
  }
}

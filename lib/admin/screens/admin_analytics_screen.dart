import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:splitease_test/core/models/dummy_data.dart';
import 'package:splitease_test/core/theme/app_theme.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final borderColor = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;

    final categories = [
      {'name': 'Food', 'amount': 4200.0, 'color': AppColors.pending},
      {'name': 'Travel', 'amount': 12500.0, 'color': AppColors.primary},
      {'name': 'Bills', 'amount': 18000.0, 'color': AppColors.adminAccent},
      {'name': 'Entertainment', 'amount': 649.0, 'color': AppColors.paid},
    ];
    final totalCat = categories.fold(
      0.0,
      (s, c) => s + (c['amount'] as double),
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_rounded, color: textColor, size: 20),
          ),
        ),
        title: Text(
          'Analytics',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Monthly volume header
            Text(
              'Monthly Volume',
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Total splits created per month',
              style: TextStyle(color: subColor, fontSize: 12),
            ),
            SizedBox(height: 20),
            // Bar chart
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 160,
                    child: CustomPaint(
                      painter: _BarChartPainter(
                        data: DummyData.monthlyData,
                        isDark: isDark,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                  SizedBox(height: 12),
                  // Month labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: DummyData.monthlyData
                        .map(
                          (d) => Text(
                            d['month'] as String,
                            style: TextStyle(color: subColor, fontSize: 11),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Summary row
            Row(
              children: [
                _SummaryChip(
                  label: 'Avg Split',
                  value: '₹7.2K',
                  icon: Icons.analytics_outlined,
                  color: AppColors.primary,
                  isDark: isDark,
                ),
                SizedBox(width: 10),
                _SummaryChip(
                  label: 'Peak Month',
                  value: 'Feb',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.paid,
                  isDark: isDark,
                ),
                SizedBox(width: 10),
                _SummaryChip(
                  label: 'Top User',
                  value: 'Arjun',
                  icon: Icons.star_outline_rounded,
                  color: AppColors.adminAccent,
                  isDark: isDark,
                ),
              ],
            ),
            SizedBox(height: 24),
            // Category breakdown
            Text(
              'By Category',
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: categories.map((cat) {
                  final pct = ((cat['amount'] as double) / totalCat);
                  return Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              cat['name'] as String,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '₹${(cat['amount'] as double).toStringAsFixed(0)}',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '${(pct * 100).toStringAsFixed(0)}%',
                              style: TextStyle(color: subColor, fontSize: 11),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: isDark
                                ? AppColors.darkSurfaceVariant
                                : AppColors.lightSurfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              cat['color'] as Color,
                            ),
                            minHeight: 7,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final bool isDark;

  _BarChartPainter({required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = data.fold(0.0, (m, d) => math.max(m, d['amount'] as double));
    final barWidth = (size.width - (data.length - 1) * 10) / data.length;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: AppColors.primaryGradient,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (int i = 0; i < data.length; i++) {
      final val = data[i]['amount'] as double;
      final barH = (val / maxVal) * size.height;
      final x = i * (barWidth + 10);
      final y = size.height - barH;
      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        const Radius.circular(6),
      );
      canvas.drawRRect(rRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final borderColor = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;

    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(label, style: TextStyle(color: subColor, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

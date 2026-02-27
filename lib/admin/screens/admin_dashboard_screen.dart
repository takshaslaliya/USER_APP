import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dummy_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_stat_card.dart';
import '../../screens/home_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        // Admin badge + title
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: AppColors.adminGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '⚡ Admin Panel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Overview',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: themeProvider.toggle,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkSurfaceVariant
                                    : AppColors.lightSurfaceVariant,
                              ),
                            ),
                            child: Icon(
                              isDark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              color: textColor,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Admin avatar
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.adminGradient,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'AD',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Stats grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        AdminStatCard(
                          label: 'Total Users',
                          value: '${DummyData.totalUsers}',
                          icon: Icons.people_outline_rounded,
                          iconColor: AppColors.primary,
                          iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        AdminStatCard(
                          label: 'Active Splits',
                          value: '${DummyData.activeSplits}',
                          icon: Icons.receipt_long_outlined,
                          iconColor: AppColors.pending,
                          iconBgColor: AppColors.pendingBg,
                        ),
                        AdminStatCard(
                          label: 'Total Settled',
                          value: '₹21.8K',
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: AppColors.paid,
                          iconBgColor: AppColors.paidBg,
                        ),
                        AdminStatCard(
                          label: 'Pending Amount',
                          value: '₹30.5K',
                          icon: Icons.pending_outlined,
                          iconColor: AppColors.error,
                          iconBgColor: AppColors.error.withValues(alpha: 0.1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Quick nav
                    Text(
                      'Manage',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _NavCard(
                          icon: Icons.people_rounded,
                          label: 'Users',
                          color: AppColors.primary,
                          onTap: () =>
                              Navigator.pushNamed(context, '/admin/users'),
                        ),
                        const SizedBox(width: 12),
                        _NavCard(
                          icon: Icons.receipt_rounded,
                          label: 'Splits',
                          color: AppColors.pending,
                          onTap: () =>
                              Navigator.pushNamed(context, '/admin/splits'),
                        ),
                        const SizedBox(width: 12),
                        _NavCard(
                          icon: Icons.bar_chart_rounded,
                          label: 'Analytics',
                          color: AppColors.adminAccent,
                          onTap: () =>
                              Navigator.pushNamed(context, '/admin/analytics'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Recent activity
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = DummyData.recentActivity[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceVariant
                                : AppColors.lightSurfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              item['icon']!,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['user']!,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                item['action']!,
                                style: TextStyle(color: subColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          item['time']!,
                          style: TextStyle(color: subColor, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }, childCount: DummyData.recentActivity.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

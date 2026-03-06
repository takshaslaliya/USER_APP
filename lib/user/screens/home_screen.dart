import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitease_test/core/providers/navigation_provider.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/user/screens/tabs/dashboard_tab.dart';
import 'package:splitease_test/user/screens/tabs/groups_tab.dart';
import 'package:splitease_test/user/screens/tabs/add_group_tab.dart';
import 'package:splitease_test/user/screens/tabs/personal_settlement_tab.dart';
import 'package:splitease_test/user/screens/tabs/settings_tab.dart';
import 'package:splitease_test/core/services/achievement_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Track app opening for 'Consistent User' achievement
    AchievementService.trackUsage();
  }

  final List<Widget> _tabs = [
    const DashboardTab(),
    const GroupsTab(),
    const AddGroupTab(),
    const PersonalSettlementTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navProvider = Provider.of<NavigationProvider>(context);
    final currentIndex = navProvider.currentIndex;

    return PopScope(
      // Never allow the back gesture/button to pop this route
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentIndex != 0) {
          // On non-dashboard tab → go back to dashboard
          navProvider.currentIndex = 0;
        }
        // On dashboard tab → do nothing (back button is fully blocked)
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: Stack(
          children: [
            IndexedStack(index: currentIndex, children: _tabs),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: _buildFloatingBottomNav(isDark, currentIndex, navProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBottomNav(
    bool isDark,
    int currentIndex,
    NavigationProvider navProvider,
  ) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20),
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurfaceVariant,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(
              0,
              Icons.home_rounded,
              isDark,
              currentIndex,
              navProvider,
            ),
            _buildNavItem(
              1,
              Icons.group_rounded,
              isDark,
              currentIndex,
              navProvider,
            ),

            // Center Add Button (Index 2)
            _buildNavItem(
              2,
              Icons.add_rounded,
              isDark,
              currentIndex,
              navProvider,
            ),

            // Personal Settlement (replaces Shared Groups)
            _buildNavItem(
              3,
              Icons.account_balance_wallet_rounded,
              isDark,
              currentIndex,
              navProvider,
            ),
            _buildNavItem(
              4,
              Icons.settings_rounded,
              isDark,
              currentIndex,
              navProvider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    bool isDark,
    int currentIndex,
    NavigationProvider navProvider,
  ) {
    final isSelected = currentIndex == index;
    final color = isSelected
        ? Color(0xFF0A1628)
        : AppColors.darkSubtext; // Dark navy for selected icon

    return GestureDetector(
      onTap: () {
        navProvider.currentIndex = index;
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 48,
        transform: isSelected
            ? Matrix4.translationValues(0.0, -8.0, 0.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppColors.primary : Colors.transparent,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

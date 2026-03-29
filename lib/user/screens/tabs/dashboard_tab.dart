import 'package:flutter/material.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/core/services/dashboard_service.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/user/screens/notification_screen.dart';
import 'package:splitease_test/core/models/achievement_model.dart';
import 'package:splitease_test/core/services/achievement_service.dart';
import 'package:provider/provider.dart';
import 'package:splitease_test/core/providers/navigation_provider.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/models/monthly_stats_model.dart';
import 'package:splitease_test/core/services/user_service.dart';
import 'package:splitease_test/user/screens/monthly_transactions_screen.dart';
import 'package:intl/intl.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitease_test/core/providers/data_refresh_provider.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  // Dashboard API data
  DashboardData? _dashboardData;
  bool _isDashboardLoading = true;
  String? _dashboardError;
  List<AchievementModel> _achievements = [];
  List<MonthlyStats> _monthlyStats = [];

  // Groups (for when the dashboard groups list isn't enough)
  List<GroupModel> _groups = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Handle global refresh signal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DataRefreshProvider>().addListener(_refreshDataListener);
      }
    });

    // Start polling every 20 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) {
        _refreshData(isPolling: true);
      }
    });
  }

  void _refreshDataListener() {
    if (mounted) _refreshData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    // Use a try-catch for context in dispose
    try {
      context.read<DataRefreshProvider>().removeListener(_refreshDataListener);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _refreshData({bool isPolling = false}) async {
    if (isPolling && (_isDashboardLoading || _searchQuery.isNotEmpty)) return;

    if (!isPolling) {
      setState(() {
        _isDashboardLoading = true;
        _dashboardError = null;
      });
    }

    try {
      // Parallel fetch for all dashboard components
      final results = await Future.wait([
        DashboardService.fetchDashboard().timeout(const Duration(seconds: 60)),
        GroupService.fetchGroups().timeout(const Duration(seconds: 60)),
        AchievementService.fetchAchievements().timeout(const Duration(seconds: 60)),
        AuthService.getProfile().timeout(const Duration(seconds: 60)),
        UserService.fetchMonthlyStats().timeout(const Duration(seconds: 60)),
      ]);

      final dashResult = results[0] as DashboardResult;
      final groupResult = results[1] as GroupResult;
      final achievementsData = results[2] as List<AchievementModel>;
      final profileResult = results[3] as AuthResult;
      final statsData = results[4] as List<MonthlyStats>;

      if (!mounted) return;

      setState(() {
        _isDashboardLoading = false;
        _achievements = achievementsData;
        _monthlyStats = statsData;

        if (dashResult.success && dashResult.data != null) {
          _dashboardData = dashResult.data;

          // Enrich with latest user profile data if available
          if (profileResult.success && profileResult.data != null) {
            _dashboardData = DashboardData(
              user: profileResult.data!,
              moneyToSend: dashResult.data!.moneyToSend,
              moneyToReceive: dashResult.data!.moneyToReceive,
              recentGroups: dashResult.data!.recentGroups,
            );
          }
          _dashboardError = null;
        } else {
          _dashboardError = dashResult.message;
        }

        // Process Groups
        if (groupResult.success && groupResult.data != null) {
          final List<dynamic> data = groupResult.data;
          _processGroups(data);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDashboardLoading = false;
          _dashboardError = 'Refresh failed: $e';
        });
      }
    }
  }

  Future<void> _processGroups(List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<GroupModel> loadedGroups = [];

      for (final g in data) {
        final group = GroupModel.fromJson(g);
        final localIcon = prefs.getString('group_icon_${group.id}');
        if (localIcon != null) {
          final file = File(localIcon);
          if (file.existsSync()) {
            group.customImageUrl = localIcon;
          }
        }
        loadedGroups.add(group);
      }

      if (mounted) {
        setState(() {
          _groups = loadedGroups;
        });
      }
    } catch (e) {
      debugPrint('Error processing groups: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use live values from API, fallback to 0
    final double moneyToSend = _dashboardData?.moneyToSend ?? 0.0;
    final double moneyToReceive = _dashboardData?.moneyToReceive ?? 0.0;
    final double netBalance = moneyToReceive - moneyToSend;

    // ── Balance Card Content calculation ──────────────────────────
    // Which groups to display in "Activity"?
    // When searching: filter all groups by name
    // When not searching: use recent_groups from dashboard API
    List<Map<String, dynamic>> displayRecentGroups = [];
    List<GroupModel> searchResults = [];

    if (_searchQuery.isNotEmpty) {
      searchResults = _groups
          .where((g) => g.name.toLowerCase().contains(_searchQuery))
          .toList();
    } else {
      displayRecentGroups = (_dashboardData?.recentGroups ?? [])
          .cast<Map<String, dynamic>>()
          .toList();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    AppColors.bgGradientDarkTop,
                    AppColors.bgGradientDarkTop,
                    AppColors.bgGradientDarkBottom,
                    AppColors.darkBg,
                  ]
                : [
                    Color.alphaBlend(
                      AppColors.primary.withValues(alpha: 0.85),
                      Colors.white,
                    ),
                    Color.alphaBlend(
                      AppColors.primaryLight.withValues(alpha: 0.55),
                      Colors.white,
                    ),
                    Color.alphaBlend(
                      AppColors.primaryLight.withValues(alpha: 0.18),
                      Colors.white,
                    ),
                    Colors.white,
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: AppColors.primary,
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top App Bar ──────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                // Navigate to settings tab index 4
                                // Or just show profile info
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                  image:
                                      (_dashboardData
                                              ?.user['profile_photo_url'] !=
                                          null)
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            _dashboardData!
                                                .user['profile_photo_url'],
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : (_dashboardData
                                                ?.user['profile_photo_base64'] !=
                                            null)
                                      ? DecorationImage(
                                          image: MemoryImage(
                                            base64Decode(
                                              _dashboardData!
                                                  .user['profile_photo_base64']
                                                  .split(',')
                                                  .last,
                                            ),
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child:
                                    (_dashboardData
                                                ?.user['profile_photo_url'] ==
                                            null &&
                                        _dashboardData
                                                ?.user['profile_photo_base64'] ==
                                            null)
                                    ? Center(
                                        child: Text(
                                          (_dashboardData?.user['full_name'] ??
                                                  'U')[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Image.asset(
                              'assets/images/App_Logo.png',
                              width: 50,
                              height: 50,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (_isDashboardLoading)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NotificationScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurface
                                      : AppColors.lightSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.darkSurfaceVariant
                                        : AppColors.lightSurfaceVariant,
                                  ),
                                ),
                                child: Icon(
                                  Icons.notifications_outlined,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // ── Balance Card ─────────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      height:
                          230, // Increased to 230 to fix remaining pixel overflow
                      width: double.infinity,
                      child: Stack(
                        children: [
                          // ── Dynamic Gradient Background ────────────────
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: netBalance > 0
                                    ? [
                                        const Color(0xFF2ECC71), // Green
                                        const Color(0xFF27AE60),
                                        const Color(0xFF1B5E20),
                                      ]
                                    : netBalance < 0
                                    ? [
                                        const Color(0xFFE74C3C), // Red
                                        const Color(0xFFC0392B),
                                        const Color(0xFFB71C1C),
                                      ]
                                    : [
                                        const Color(0xFF1CB0A0), // Teal
                                        const Color(0xFF169083),
                                        const Color(0xFF0D4D44),
                                      ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (netBalance > 0
                                              ? const Color(0xFF2ECC71)
                                              : netBalance < 0
                                              ? const Color(0xFFE74C3C)
                                              : const Color(0xFF1CB0A0))
                                          .withValues(alpha: 0.3),
                                  blurRadius: 25,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                          ),

                          // ── Faded Logo Pattern (Fading away effect) ──────
                          Positioned(
                            right: -50,
                            top: -50,
                            child: Opacity(
                              opacity: 0.12,
                              child: Transform.rotate(
                                angle: -0.3,
                                child: Image.asset(
                                  'assets/images/App_Logo.png',
                                  width: 280,
                                  height: 280,
                                  color: Colors.white,
                                  colorBlendMode: BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),

                          // ── Content Overlay ──────────────────────────
                          Padding(
                            padding: const EdgeInsets.all(
                              24.0,
                            ), // Reduced to fix overflow
                            child: _isDashboardLoading
                                ? _buildBalanceCardSkeleton()
                                : _buildBalanceCardContent(
                                    netBalance,
                                    moneyToSend,
                                    moneyToReceive,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Action Row: Add & View Personal Expenses ────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: _showAddPersonalExpenseDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryLight,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add Expense',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () => Navigator.pushNamed(context, '/personal-expenses').then((_) => _refreshData()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_rounded, 
                                    color: isDark ? AppColors.darkText : AppColors.primary, 
                                    size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'History',
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkText : AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Search Bar ───────────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          icon: Icon(
                            Icons.search,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          hintText: 'Search Groups or Persons',
                          hintStyle: TextStyle(
                            color: isDark
                                ? AppColors.darkSubtext
                                : Color(0xFF8EB8C8),
                            fontSize: 14,
                          ),
                          isDense: true,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 18),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Stats Summary ────────────────────────────
                  if (_searchQuery.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Row(
                        children: [
                          _StatBox(
                            label: 'Personal Expenses',
                            value:
                                '${_dashboardData?.user['total_splits'] ?? 0}',
                            icon: Icons.receipt_long_rounded,
                            isDark: isDark,
                            onTap: () => Navigator.pushNamed(context, '/personal-expenses').then((_) => _refreshData()),
                          ),
                          const SizedBox(width: 16),
                          _StatBox(
                            label: 'Joined',
                            value: () {
                              try {
                                // Prefer joined_at, then created_at
                                final rawDate =
                                    _dashboardData?.user['joined_at'] ??
                                    _dashboardData?.user['created_at'];

                                if (rawDate != null) {
                                  final date = DateTime.parse(rawDate);
                                  final monthName = [
                                    'Jan',
                                    'Feb',
                                    'Mar',
                                    'Apr',
                                    'May',
                                    'Jun',
                                    'Jul',
                                    'Aug',
                                    'Sep',
                                    'Oct',
                                    'Nov',
                                    'Dec',
                                  ][date.month - 1];
                                  return '$monthName ${date.year}';
                                }
                                return 'N/A';
                              } catch (_) {
                                return 'N/A';
                              }
                            }(),
                            icon: Icons.calendar_today_rounded,
                            isDark: isDark,
                            onTap: _refreshData,
                          ),
                        ],
                      ),
                    ),

                  if (_searchQuery.isEmpty) const SizedBox(height: 28),

                  // ── Achievements ──────────────────────────────
                  if (_searchQuery.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        'Achievements',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkText
                              : Color(0xFF1D3A44),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: _achievements.isEmpty
                          ? Center(
                              child: Text(
                                'No achievements yet',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkSubtext
                                      : Color(0xFF5E7A81),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
                              itemCount: _achievements.length,
                              itemBuilder: (context, index) {
                                final a = _achievements[index];
                                final config = _getAchievementConfig(a.type);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Opacity(
                                    opacity: a.isUnlocked ? 1.0 : 0.4,
                                    child: _BadgeCard(
                                      icon: config.icon,
                                      title: a.title,
                                      subtitle: a.description,
                                      color: a.isUnlocked
                                          ? config.color
                                          : (isDark
                                                ? Colors.white24
                                                : Colors.grey),
                                      isDark: isDark,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ── Monthly Statistics ───────────────────────
                  if (_searchQuery.isEmpty && _monthlyStats.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly Statistics',
                            style: TextStyle(
                              color: isDark ? AppColors.darkText : Color(0xFF1D3A44),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                initialDatePickerMode: DatePickerMode.year,
                              );
                              if (picked != null && mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MonthlyTransactionsScreen(
                                      month: DateFormat('yyyy-MM').format(picked),
                                      monthName: DateFormat('MMMM').format(picked),
                                    ),
                                  ),
                                );
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140, // Match Achievements height roughly
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        itemCount: _monthlyStats.length,
                        itemBuilder: (context, index) {
                          final stat = _monthlyStats[index];
                          final isNegative = stat.net < 0;
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MonthlyTransactionsScreen(
                                    month: stat.month,
                                    monthName: stat.monthName,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 160,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? AppColors.darkSurfaceVariant : Colors.transparent,
                                  width: isDark ? 1 : 0,
                                ),
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    stat.monthName,
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkSubtext : Color(0xFF5E7A81),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '₹${stat.net.abs().toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkText : Color(0xFF1D3A44),
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        isNegative ? Icons.arrow_downward : Icons.arrow_upward,
                                        size: 16,
                                        color: isNegative ? AppColors.error : Color(0xFF2ECC71),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isNegative ? 'Net Spent' : 'Net Plus',
                                    style: TextStyle(
                                      color: isNegative ? AppColors.error : Color(0xFF2ECC71),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ── Activity Header ──────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Activity',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkText
                                : Color(0xFF1D3A44),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_searchQuery.isEmpty &&
                            displayRecentGroups.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              Provider.of<NavigationProvider>(
                                context,
                                listen: false,
                              ).currentIndex = 1;
                            },
                            child: Text(
                              'See All',
                              style: TextStyle(
                                color: Color(0xFF1CB0A0),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (_searchQuery.isNotEmpty && searchResults.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              Provider.of<NavigationProvider>(
                                context,
                                listen: false,
                              ).currentIndex = 1;
                            },
                            child: Text(
                              'See All',
                              style: TextStyle(
                                color: Color(0xFF1CB0A0),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: _isDashboardLoading && _dashboardData == null
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : _dashboardError != null && _dashboardData == null
                        ? _buildErrorState(isDark)
                        : _searchQuery.isNotEmpty
                        // Search mode: show from all groups
                        ? searchResults.isEmpty
                              ? _buildEmptyState(context, isDark)
                              : Column(
                                  children: searchResults
                                      .take(10)
                                      .map(
                                        (group) => InkWell(
                                          onTap: () => Navigator.pushNamed(
                                            context,
                                            '/details',
                                            arguments: {
                                              'group': group,
                                              'heroTag':
                                                  'dashboard_tab_avatar_${group.id}',
                                            },
                                          ).then((_) => _refreshData()),
                                          child: _buildGroupTile(
                                            title: group.name,
                                            subtitle: group.expenses.isNotEmpty
                                                ? 'Recent: ${group.expenses.last.title}'
                                                : '${group.subGroupCount} transactions',
                                            amount:
                                                '₹${group.displayTotal.toInt()}',
                                            isDark: isDark,
                                            imageUrl: group.bestPhoto,
                                            groupId: group.id,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                )
                        // Normal mode: show recent groups from dashboard API
                        : displayRecentGroups.isEmpty
                        ? _buildEmptyState(context, isDark)
                        : Column(
                            children: displayRecentGroups.take(10).map((g) {
                              final name =
                                  g['name'] as String? ?? 'Unknown Group';
                              final description =
                                  g['description'] as String? ?? '';
                              final totalExpense =
                                  (g['total_amount'] ??
                                          g['total_expense'] ??
                                          0.0)
                                      as num;
                              final groupId = g['id'] as String? ?? '';

                              // Try to find a matching local group for navigation
                              final localGroup = _groups.firstWhere(
                                (lg) => lg.id == groupId,
                                orElse: () => GroupModel.fromJson(g),
                              );

                              return InkWell(
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/details',
                                  arguments: {
                                    'group': localGroup,
                                    'heroTag':
                                        'dashboard_tab_avatar_${localGroup.id}',
                                  },
                                ).then((_) => _refreshData()),
                                child: _buildGroupTile(
                                  title: name,
                                  subtitle: description.isNotEmpty
                                      ? description
                                      : 'Tap to view details',
                                  amount: totalExpense > 0
                                      ? '₹${totalExpense.toInt()}'
                                      : '–',
                                  isDark: isDark,
                                  imageUrl: localGroup.bestPhoto,
                                  groupId: groupId,
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  SizedBox(height: 140), // Space for bottom nav
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Balance Card inner content (live data) ──────────────────────
  Widget _buildBalanceCardContent(
    double netBalance,
    double moneyToSend,
    double moneyToReceive,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              netBalance > 0
                  ? 'You Get Back'
                  : netBalance < 0
                  ? 'You Owe Total'
                  : 'Net Balance',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox.shrink(),
          ],
        ),
        SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '₹',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: netBalance.abs()),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final formatted = value.toInt().toString().replaceAllMapped(
                  RegExp(r'\B(?=(\d{3})+(?!\d))'),
                  (m) => ',',
                );
                return Text(
                  formatted,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                );
              },
            ),
          ],
        ),
        SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _balanceStat(
                Icons.arrow_upward_rounded,
                'You Owe',
                '₹${moneyToSend.toInt()}',
                Color(0xFFE56A6A),
              ),
            ),
            SizedBox(width: 16),
            Container(width: 1, height: 30, color: Colors.white24),
            SizedBox(width: 16),
            Expanded(
              child: _balanceStat(
                Icons.arrow_downward_rounded,
                'You Get',
                '₹${moneyToReceive.toInt()}',
                Color(0xFF45F5E4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Loading skeleton for balance card ──────────────────────────
  Widget _buildBalanceCardSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _shimmerBox(width: 100, height: 16),
        SizedBox(height: 12),
        _shimmerBox(width: 160, height: 44),
        SizedBox(height: 24),
        Row(
          children: [
            _shimmerBox(width: 80, height: 36),
            SizedBox(width: 32),
            Container(width: 1, height: 30, color: Colors.white24),
            SizedBox(width: 32),
            _shimmerBox(width: 80, height: 36),
          ],
        ),
      ],
    );
  }

  Widget _shimmerBox({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // ── Generic group tile ──────────────────────────────────────────
  static Widget _buildGroupTile({
    required String title,
    required String subtitle,
    required String amount,
    required bool isDark,
    String? imageUrl,
    String? groupId,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceVariant : Colors.transparent,
          width: isDark ? 1 : 0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Hero(
            tag: 'dashboard_tab_avatar_${groupId}',
            child: Container(
              width: 48,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                image: imageUrl != null && imageUrl.isNotEmpty
                    ? DecorationImage(
                        image:
                            () {
                                  if (imageUrl.startsWith('http')) {
                                    return NetworkImage(imageUrl);
                                  } else if (imageUrl.startsWith('data:')) {
                                    final base64Str = imageUrl.split(',').last;
                                    return MemoryImage(base64Decode(base64Str));
                                  } else {
                                    return FileImage(File(imageUrl));
                                  }
                                }()
                                as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (imageUrl == null || imageUrl.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            title.trim().isNotEmpty
                                ? title.trim().substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.darkText : Color(0xFF1D3A44),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.primary : Color(0xFF1CB0A0),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: isDark ? AppColors.darkText : Color(0xFF1D3A44),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Icon(
                Icons.more_vert_rounded,
                color: isDark ? AppColors.darkSubtext : Color(0xFF1CB0A0),
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _balanceStat(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        SizedBox(height: 2), // Slightly reduced from 4
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16, // Reduced from 18 to fix overflow
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.error),
          SizedBox(height: 16),
          Text(
            'Could not load dashboard',
            style: TextStyle(
              color: isDark ? AppColors.darkText : Color(0xFF1D3A44),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _dashboardError ?? 'Please check your connection',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.darkSubtext : Color(0xFF5E7A81),
              fontSize: 13,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
            label: Text('Retry', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceVariant : Colors.transparent,
          width: isDark ? 1 : 0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No expenses yet',
            style: TextStyle(
              color: isDark ? AppColors.darkText : Color(0xFF1D3A44),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You haven\'t split any bills yet.\nCreate a group to get started!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.darkSubtext : Color(0xFF5E7A81),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              DefaultTabController.of(context).animateTo(1);
            },
            icon: Icon(Icons.add_rounded, size: 20, color: Colors.white),
            label: Text(
              'Create your first group',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  _AchievementUIConfig _getAchievementConfig(String type) {
    switch (type) {
      case 'regular_split':
        return _AchievementUIConfig(Icons.receipt_long_rounded, Colors.amber);
      case 'sub_split':
        return _AchievementUIConfig(Icons.account_tree_rounded, Colors.green);
      case 'app_usage':
        return _AchievementUIConfig(Icons.check_circle_rounded, Colors.blue);
      default:
        return _AchievementUIConfig(Icons.star_rounded, Colors.purple);
    }
  }

  void _showAddPersonalExpenseDialog() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isIncome = false;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              title: Text('Add Personal Expense',
                  style: TextStyle(
                      color: isDark ? AppColors.darkText : Color(0xFF1D3A44))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Expense Name',
                        hintText: 'e.g. Coffee, Lunch',
                        labelStyle: TextStyle(
                            color: isDark
                                ? AppColors.darkSubtext
                                : Color(0xFF5E7A81)),
                      ),
                      style: TextStyle(
                          color: isDark ? AppColors.darkText : Color(0xFF1D3A44)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        labelStyle: TextStyle(
                            color: isDark
                                ? AppColors.darkSubtext
                                : Color(0xFF5E7A81)),
                      ),
                      style: TextStyle(
                          color: isDark ? AppColors.darkText : Color(0xFF1D3A44)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryCtrl,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        hintText: 'e.g. Food, Travel, Salary',
                        labelStyle: TextStyle(
                            color: isDark
                                ? AppColors.darkSubtext
                                : Color(0xFF5E7A81)),
                      ),
                      style: TextStyle(
                          color: isDark ? AppColors.darkText : Color(0xFF1D3A44)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: TextStyle(
                            color: isDark
                                ? AppColors.darkSubtext
                                : Color(0xFF5E7A81)),
                      ),
                      style: TextStyle(
                          color: isDark ? AppColors.darkText : Color(0xFF1D3A44)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: isIncome,
                          onChanged: (val) {
                            setDialogState(() => isIncome = val ?? false);
                          },
                          activeColor: AppColors.primary,
                        ),
                        Text('This is Income',
                            style: TextStyle(
                                color: isDark
                                    ? AppColors.darkText
                                    : Color(0xFF1D3A44))),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(
                          color: isDark
                              ? AppColors.darkSubtext
                              : Color(0xFF5E7A81))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                    double amount = double.tryParse(amountCtrl.text) ?? 0.0;

                    final result = await UserService.addPersonalExpense(
                      name: nameCtrl.text,
                      amount: amount,
                      type: isIncome ? 'Income' : 'Spent',
                      category: categoryCtrl.text.isEmpty
                          ? (isIncome ? 'Income' : 'Other')
                          : categoryCtrl.text,
                      description: descCtrl.text.isEmpty ? null : descCtrl.text,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result.message),
                          backgroundColor:
                              result.success ? AppColors.primary : AppColors.error,
                        ),
                      );
                      if (result.success) _refreshData();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AchievementUIConfig {
  final IconData icon;
  final Color color;
  _AchievementUIConfig(this.icon, this.color);
}

class _BadgeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;

  const _BadgeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceVariant : Colors.transparent,
          width: isDark ? 1 : 0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.darkText : const Color(0xFF1D3A44),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.darkSubtext : const Color(0xFF5E7A81),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final VoidCallback? onTap;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.transparent,
              width: isDark ? 1 : 0,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: isDark ? AppColors.darkText : const Color(0xFF1D3A44),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkSubtext
                      : const Color(0xFF5E7A81),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

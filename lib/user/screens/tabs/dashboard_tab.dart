import 'package:flutter/material.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/core/services/dashboard_service.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/user/screens/notification_screen.dart';

import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Groups (for when the dashboard groups list isn't enough)
  List<GroupModel> _groups = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isDashboardLoading = true;
      _dashboardError = null;
    });

    // Fetch dashboard summary (money_to_send, money_to_receive, recent_groups)
    final dashResult = await DashboardService.fetchDashboard();

    // Also fetch all user groups for search support
    final groupResult = await GroupService.fetchGroups();

    if (!mounted) return;

    setState(() {
      _isDashboardLoading = false;
    });

    if (dashResult.success && dashResult.data != null) {
      setState(() {
        _dashboardData = dashResult.data;
        _dashboardError = null;
      });
    } else {
      setState(() {
        _dashboardError = dashResult.message;
      });
    }

    if (groupResult.success && groupResult.data != null) {
      final List<dynamic> data = groupResult.data;
      final prefs = await SharedPreferences.getInstance();
      final loadedGroups = data.map((g) {
        final group = GroupModel.fromJson(g);
        final localIcon = prefs.getString('group_icon_${group.id}');
        if (localIcon != null && File(localIcon).existsSync()) {
          group.customImageUrl = localIcon;
        }
        return group;
      }).toList();
      if (mounted) {
        setState(() {
          _groups = loadedGroups;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use live values from API, fallback to 0
    final double moneyToSend = _dashboardData?.moneyToSend ?? 0.0;
    final double moneyToReceive = _dashboardData?.moneyToReceive ?? 0.0;
    final double netBalance = moneyToReceive - moneyToSend;

    List<Color> cardGradient;
    if (moneyToSend > moneyToReceive) {
      // Net negative — reddish
      cardGradient = const [
        Color(0xFF5E3535),
        Color(0xFF4A2525),
        Color(0xFF3A1B1B),
        Color(0xFF291010),
      ];
    } else if (moneyToReceive > moneyToSend) {
      // Net positive — greenish
      cardGradient = const [
        Color(0xFF2A5E3E),
        Color(0xFF1C4A2D),
        Color(0xFF133A1F),
        Color(0xFF0A2914),
      ];
    } else {
      cardGradient = const [
        Color(0xFF1E525E),
        Color(0xFF133F4A),
        Color(0xFF0F323A),
        Color(0xFF082229),
      ];
    }

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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshData,
        child: Container(
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
                        Image.asset(
                          'assets/images/App_Logo.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                        Row(
                          children: [
                            if (_isDashboardLoading)
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            const SizedBox(width: 12),
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
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: cardGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: cardGradient.last.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _isDashboardLoading
                          ? _buildBalanceCardSkeleton()
                          : _buildBalanceCardContent(
                              netBalance,
                              moneyToSend,
                              moneyToReceive,
                            ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // ── Quick Actions / Prestige Banner ──────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.alphaBlend(
                                  AppColors.primary.withValues(alpha: 0.55),
                                  const Color(0xFF0D1F2D),
                                ),
                                Color.alphaBlend(
                                  AppColors.primary.withValues(alpha: 0.25),
                                  const Color(0xFF081520),
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.workspace_premium_rounded,
                                  color: AppColors.primaryLight,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Prestige Plan',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Active Premium Member',
                                      style: TextStyle(
                                        color: AppColors.primaryLight,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white54,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

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

                  SizedBox(height: 24),

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
                              DefaultTabController.of(context).animateTo(1);
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
                              DefaultTabController.of(context).animateTo(1);
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
                                            arguments: group,
                                          ).then((_) => _refreshData()),
                                          child: _buildGroupTile(
                                            title: group.name,
                                            subtitle: group.expenses.isNotEmpty
                                                ? 'Recent: ${group.expenses.last.title}'
                                                : '${group.subGroupCount} transactions',
                                            amount:
                                                '₹${group.displayTotal.toInt()}',
                                            isDark: isDark,
                                            imageUrl: group.customImageUrl,
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
                                  (g['total_expense'] as num?)?.toDouble() ??
                                  0.0;
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
                                  arguments: localGroup,
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
                                  imageUrl: localGroup.customImageUrl,
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
              netBalance >= 0 ? 'You Get Back' : 'You Owe',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(
              width: 80,
              height: 30,
              child: CustomPaint(painter: _SparklinePainter()),
            ),
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
            _balanceStat(
              Icons.arrow_upward_rounded,
              'You Owe',
              '₹${moneyToSend.toInt()}',
              Color(0xFFE56A6A),
            ),
            SizedBox(width: 32),
            Container(width: 1, height: 30, color: Colors.white24),
            SizedBox(width: 32),
            _balanceStat(
              Icons.arrow_downward_rounded,
              'You Get',
              '₹${moneyToReceive.toInt()}',
              Color(0xFF45F5E4),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              image: imageUrl != null
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
            child: imageUrl == null
                ? Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 24,
                  )
                : null,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
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
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF45F5E4).withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.2, size.height * 0.6),
      Offset(size.width * 0.4, size.height * 0.7),
      Offset(size.width * 0.6, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width, size.height * 0.1),
    ];

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 1.5, paint);
      if (i < points.length - 1) {
        const int dots = 3;
        for (int j = 1; j <= dots; j++) {
          final t = j / (dots + 1);
          final p = Offset(
            points[i].dx + (points[i + 1].dx - points[i].dx) * t,
            points[i].dy + (points[i + 1].dy - points[i].dy) * t,
          );
          canvas.drawCircle(p, 1, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) => false;
}

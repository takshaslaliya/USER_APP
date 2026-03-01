import 'package:flutter/material.dart';
import 'package:splitease_test/core/theme/app_theme.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/services/group_service.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<GroupModel> _groups = [];
  bool _isLoading = false;
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
    setState(() => _isLoading = true);
    final result = await GroupService.fetchGroups();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.data != null) {
      final List<dynamic> data = result.data;
      setState(() {
        _groups = data.map((g) => GroupModel.fromJson(g)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double totalBalance = 24450.0;
    final double totalOwe = 12000.0;
    final double totalGet = 6350.0;

    List<Color> cardGradient;
    if (totalOwe > totalGet) {
      // Slight red tint
      cardGradient = const [
        Color(0xFF5E3535),
        Color(0xFF4A2525),
        Color(0xFF3A1B1B),
        Color(0xFF291010),
      ];
    } else if (totalGet > totalOwe) {
      // Slight green tint
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

    // Logic: If NOT searching, only show groups with activity.
    // If searching, show all groups that match the name.
    List<GroupModel> displayGroups;
    if (_searchQuery.isEmpty) {
      displayGroups = _groups.where((g) => g.subGroupCount > 0).toList();
    } else {
      displayGroups = _groups
          .where((g) => g.name.toLowerCase().contains(_searchQuery))
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top App Bar ──────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/images/app_logo.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // ── Balance Card ─────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Balance',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            // Mini sparkline decoration
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
                              tween: Tween<double>(begin: 0, end: totalBalance),
                              duration: const Duration(milliseconds: 1500),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                final formattedValue = value
                                    .toInt()
                                    .toString()
                                    .replaceAllMapped(
                                      RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                      (Match m) => ',',
                                    );
                                return Text(
                                  formattedValue,
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
                              '₹12,000',
                              Color(0xFFE56A6A),
                            ),
                            SizedBox(width: 32),
                            // Divider
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.white24,
                            ),
                            SizedBox(width: 32),
                            _balanceStat(
                              Icons.arrow_downward_rounded,
                              'You Get',
                              '₹6,350',
                              Color(0xFF45F5E4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24), // Added spacer to prevent collision
                // ── Quick Actions ─────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Premium Banner Full Width
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

                      // Recently Activity removed as per user request
                    ],
                  ),
                ),

                SizedBox(height: 32),

                // ── Search Bar ────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
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
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

                // ── Active Splits Header ──────────────────────
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
                      if (displayGroups.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            // This might need context from HomeScreen to change index
                            // For now just show a message or use a global key if available
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
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _isLoading && _groups.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : displayGroups.isEmpty
                      ? _buildEmptyState(context, isDark)
                      : Column(
                          children: displayGroups.take(10).map((group) {
                            return InkWell(
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/details',
                                arguments: group,
                              ).then((_) => _refreshData()),
                              child: _buildSplitTile(
                                icon: Icons.receipt_long_rounded,
                                title: group.name,
                                subtitle: group.expenses.isNotEmpty
                                    ? 'Recent: ${group.expenses.last.title}'
                                    : '${group.subGroupCount} transactions',
                                amount: '₹${group.totalAmount.toInt()}',
                                iconColor: AppColors.primary,
                                iconBg: AppColors.primary.withValues(
                                  alpha: 0.1,
                                ),
                                isSubtitleColored: true,
                                isDark: isDark,
                                imageUrl: group.customImageUrl,
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

  // _smallAction removed as per user request to remove 'Recent Activity' button

  static Widget _buildSplitTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required Color iconColor,
    required Color iconBg,
    bool isSubtitleColored = false,
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
              color: isDark ? AppColors.darkSurfaceVariant : iconBg,
              borderRadius: BorderRadius.circular(16),
              image: imageUrl != null
                  ? DecorationImage(
                      image: imageUrl.startsWith('http')
                          ? NetworkImage(imageUrl)
                          : FileImage(File(imageUrl)) as ImageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageUrl == null
                ? Icon(
                    icon,
                    color: isDark ? AppColors.primary : iconColor,
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
                  style: TextStyle(
                    color: isSubtitleColored
                        ? (isDark ? AppColors.primary : Color(0xFF1CB0A0))
                        : (isDark ? AppColors.darkSubtext : Color(0xFF5E7A81)),
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

    // Draw little dotted lines
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 1.5, paint);
      if (i < points.length - 1) {
        // connect with dots instead of lines? The image shows tiny dots.
        // We'll draw a few dots between the points
        final int dots = 3;
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

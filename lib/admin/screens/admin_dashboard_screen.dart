import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitease_test/core/models/dummy_data.dart';
import 'package:splitease_test/core/models/user_model.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/admin/widgets/admin_stat_card.dart';

import 'dart:math' as math;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 2; // Default to Dashboard (center)
  String _selectedChartLabel = 'App Usage';

  final Map<String, List<Map<String, dynamic>>> _chartData = {
    'App Usage': DummyData.monthlyData,
    'Total Users': [
      {'month': 'Sep', 'amount': 120.0},
      {'month': 'Oct', 'amount': 150.0},
      {'month': 'Nov', 'amount': 180.0},
      {'month': 'Dec', 'amount': 210.0},
      {'month': 'Jan', 'amount': 240.0},
      {'month': 'Feb', 'amount': 280.0},
    ],
    'Active Users': [
      {'month': 'Sep', 'amount': 80.0},
      {'month': 'Oct', 'amount': 100.0},
      {'month': 'Nov', 'amount': 110.0},
      {'month': 'Dec', 'amount': 140.0},
      {'month': 'Jan', 'amount': 160.0},
      {'month': 'Feb', 'amount': 200.0},
    ],
    'Inactive Users': [
      {'month': 'Sep', 'amount': 40.0},
      {'month': 'Oct', 'amount': 50.0},
      {'month': 'Nov', 'amount': 70.0},
      {'month': 'Dec', 'amount': 70.0},
      {'month': 'Jan', 'amount': 80.0},
      {'month': 'Feb', 'amount': 80.0},
    ],
    'WhatsApp Users': [
      {'month': 'Sep', 'amount': 50.0},
      {'month': 'Oct', 'amount': 70.0},
      {'month': 'Nov', 'amount': 80.0},
      {'month': 'Dec', 'amount': 100.0},
      {'month': 'Jan', 'amount': 120.0},
      {'month': 'Feb', 'amount': 150.0},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    // List of screens for the navigation (5 items now)
    final screens = [
      _AdminUsersList(),
      _AdminWhatsAppList(),
      _buildMainDashboard(context), // Center item: Dashboard
      _AdminAlertsScreen(),
      _AdminSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF18181B), Color(0xFF2F2F33), Color(0xFF18181B)],
                )
              : null,
        ),
        child: SafeArea(
          bottom: false,
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: _DynamicBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _buildMainDashboard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppColors.adminGradient,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '⚡ Admin Panel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Data Analytics',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Theme toggle
                    GestureDetector(
                      onTap: themeProvider.toggle,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: borderColor,
                          ),
                        ),
                        child: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: textColor,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // App Usage Analytics Graph
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_graph_rounded, color: AppColors.primary, size: 18),
                              SizedBox(width: 8),
                              Text(
                                '$_selectedChartLabel Analytics',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (_selectedChartLabel != 'App Usage')
                            GestureDetector(
                              onTap: () => setState(() => _selectedChartLabel = 'App Usage'),
                              child: Text(
                                'Reset',
                                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        height: 120,
                        child: CustomPaint(
                          painter: _AdminDashboardBarPainter(
                            data: _chartData[_selectedChartLabel] ?? DummyData.monthlyData,
                            isDark: isDark,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: (_chartData[_selectedChartLabel] ?? DummyData.monthlyData)
                            .map(
                              (d) => Text(
                                d['month'] as String,
                                style: TextStyle(color: subColor, fontSize: 10),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Stats Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _selectedChartLabel = 'Total Users'),
                      child: AdminStatCard(
                        label: 'Total Users',
                        value: '${DummyData.totalUsers}',
                        icon: Icons.people_outline_rounded,
                        iconColor: AppColors.primary,
                        iconBgColor: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedChartLabel = 'Active Users'),
                      child: AdminStatCard(
                        label: 'Active Users',
                        value: '${DummyData.activeUsersCount}',
                        icon: Icons.person_add_alt_1_outlined,
                        iconColor: AppColors.paid,
                        iconBgColor: AppColors.paidBg,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedChartLabel = 'Inactive Users'),
                      child: AdminStatCard(
                        label: 'Inactive Users',
                        value: '${DummyData.inactiveUsersCount}',
                        icon: Icons.person_off_outlined,
                        iconColor: AppColors.error,
                        iconBgColor: AppColors.error.withValues(alpha: 0.1),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedChartLabel = 'WhatsApp Users'),
                      child: AdminStatCard(
                        label: 'WhatsApp Users',
                        value: '${DummyData.whatsappUsersCount}',
                        icon: Icons.message_outlined,
                        iconColor: Color(0xFF25D366),
                        iconBgColor: Color(0xFF25D366).withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminWhatsAppList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final whatsappUsers = DummyData.users.where((u) => u.isUsingWhatsApp).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'WhatsApp Connections',
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 20),
            itemCount: whatsappUsers.length,
            itemBuilder: (context, index) {
              final dynamic user = whatsappUsers[index];
              final String name = user.name?.toString() ?? 'Unknown User';
              final String phone = user.phoneNumber?.toString() ?? '+91 00000 00000';
              final String initials = user.avatarInitials?.toString() ?? '??';

              return Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFF25D366).withValues(alpha: 0.1),
                      child: Text(
                        initials,
                        style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text(
                            phone,
                            style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF25D366).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'CONNECTED',
                        style: TextStyle(color: Color(0xFF25D366), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminAlertsScreen extends StatefulWidget {
  @override
  State<_AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<_AdminAlertsScreen> {
  final TextEditingController _controller = TextEditingController();
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _charCount = _controller.text.length;
      });
    });
  }

  void _addTag(String tag) {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, tag);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + tag.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final accentColor = AppColors.adminAccent;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppColors.primaryGradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '⚡ Notifications',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Compose Message',
            style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _tagButton('{name}', () => _addTag('{name}')),
                    _tagButton('{mobile}', () => _addTag('{mobile}')),
                  ],
                ),
                SizedBox(height: 20),
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                  ),
                  child: Stack(
                    children: [
                      TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(color: textColor, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Type your message here...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          contentPadding: EdgeInsets.all(16),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 16,
                        child: Text(
                          '$_charCount chars',
                          style: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.adminGradient),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      final selectedUser = DummyData.users[1];
                      final finalMsg = _controller.text.replaceAll('{name}', selectedUser.name);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: accentColor,
                          content: Text('Message: $finalMsg'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Send to User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _tagButton(String label, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.adminAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.adminAccent.withValues(alpha: 0.2)),
            ),
            child: Text(
              label,
              style: TextStyle(color: AppColors.adminAccent, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    
    // Demo API Data
    final apis = [
      {'name': 'User Authentication API', 'status': 'Healthy', 'latency': '45ms', 'icon': Icons.lock_outline_rounded},
      {'name': 'Supabase Database', 'status': 'Healthy', 'latency': '12ms', 'icon': Icons.storage_rounded},
      {'name': 'WhatsApp Business API', 'status': 'Healthy', 'latency': '124ms', 'icon': Icons.message_rounded},
      {'name': 'Push Notification Service', 'status': 'Healthy', 'latency': '68ms', 'icon': Icons.notifications_active_outlined},
      {'name': 'Expense Engine API', 'status': 'Healthy', 'latency': '22ms', 'icon': Icons.calculate_outlined},
      {'name': 'Media Storage (S3)', 'status': 'Healthy', 'latency': '34ms', 'icon': Icons.cloud_done_outlined},
      {'name': 'Analytics Webhook', 'status': 'Healthy', 'latency': '15ms', 'icon': Icons.analytics_outlined},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Settings',
                style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF22C55E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFF22C55E).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 14),
                    SizedBox(width: 6),
                    Text(
                      'All Systems Live',
                      style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            'API HEALTH MONITOR',
            style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: apis.length,
            itemBuilder: (context, index) {
              final api = apis[index];
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (api['icon'] as IconData == Icons.message_rounded ? Color(0xFF25D366) : AppColors.adminAccent).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(api['icon'] as IconData, size: 20, color: api['icon'] as IconData == Icons.message_rounded ? Color(0xFF25D366) : AppColors.adminAccent),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            api['name'] as String,
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Latency: ${api['latency']}',
                            style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          api['status'] as String,
                          style: TextStyle(color: Color(0xFF22C55E), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Color(0xFF22C55E).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 32,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 30),
          // Additional Settings placeholder
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              gradient: LinearGradient(
                colors: [surfaceColor, surfaceColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.adminAccent),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'More administrative controls and configuration options will be available here soon.',
                    style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _DynamicBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _DynamicBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_DynamicBottomNav> createState() => _DynamicBottomNavState();
}

class _DynamicBottomNavState extends State<_DynamicBottomNav> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuart),
    );
  }

  @override
  void didUpdateWidget(covariant _DynamicBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animation = Tween<double>(
        begin: oldWidget.currentIndex.toDouble(),
        end: widget.currentIndex.toDouble(),
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuart),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.adminAccent;
    final barColor = isDark ? Color(0xFF1E293B) : Color(0xFF111827);

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 70,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double itemWidth = totalWidth / 5;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Custom Curved Background
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(totalWidth, 70),
                    painter: _CurveNavPainter(
                      selectedIndex: _animation.value,
                      color: barColor,
                    ),
                  );
                },
              ),

              // Floating Bubble
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final xPos = (_animation.value * itemWidth) + (itemWidth / 2) - 25;
                  return Positioned(
                    left: xPos,
                    top: -15, // Moves upward
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Navigation Icons
              Row(
                children: List.generate(5, (index) {
                  final isSelected = widget.currentIndex == index;
                  IconData icon;
                  switch (index) {
                    case 0: icon = Icons.people_outline_rounded; break;
                    case 1: icon = Icons.message_outlined; break;
                    case 2: icon = Icons.dashboard_outlined; break;
                    case 3: icon = Icons.notifications_none_rounded; break;
                    case 4: icon = Icons.settings_outlined; break;
                    default: icon = Icons.circle;
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTap(index),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        alignment: isSelected ? const Alignment(0, -1.3) : Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              icon,
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                              size: isSelected ? 28 : 24,
                            ),
                            if (index == 3 && !isSelected) // Badge for alerts
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF43F5E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CurveNavPainter extends CustomPainter {
  final double selectedIndex;
  final Color color;

  _CurveNavPainter({required this.selectedIndex, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final itemWidth = size.width / 5;
    final centerX = (selectedIndex * itemWidth) + (itemWidth / 2);

    // Main rectangular bar
    path.moveTo(0, 0);
    path.lineTo(centerX - 50, 0);
    
    // Smooth notch curve
    path.cubicTo(
      centerX - 35, 0,
      centerX - 30, 30,
      centerX, 30,
    );
    path.cubicTo(
      centerX + 30, 30,
      centerX + 35, 0,
      centerX + 50, 0,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Round the corners of the entire bar
    final outerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(25),
    );
    
    canvas.save();
    canvas.clipRRect(outerRRect);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CurveNavPainter oldDelegate) => 
      oldDelegate.selectedIndex != selectedIndex || oldDelegate.color != color;
}

class _AdminDashboardBarPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final bool isDark;

  _AdminDashboardBarPainter({required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = data.fold(0.0, (m, d) => math.max(m, d['amount'] as double));
    final barWidth = (size.width - (data.length - 1) * 12) / data.length;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: AppColors.adminGradient,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (int i = 0; i < data.length; i++) {
      final val = data[i]['amount'] as double;
      final barH = (val / maxVal) * size.height;
      final x = i * (barWidth + 12);
      final y = size.height - barH;
      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        const Radius.circular(4),
      );
      canvas.drawRRect(rRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AdminUsersList extends StatefulWidget {
  @override
  State<_AdminUsersList> createState() => _AdminUsersListState();
}

class _AdminUsersListState extends State<_AdminUsersList> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final accentColor = AppColors.adminAccent;

    List<dynamic> filteredUsers = [];
    try {
      filteredUsers = DummyData.users.where((user) {
        final dynamic u = user;
        if (u == null) return false;
        final name = (u.name?.toString() ?? '').toLowerCase();
        final email = (u.email?.toString() ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    } catch (_) {
      filteredUsers = [];
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppColors.adminGradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '⚡ App Users',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'User Management',
            style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          // Search Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: TextStyle(color: subColor, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                icon: Icon(Icons.search_rounded, color: accentColor, size: 20),
              ),
            ),
          ),
          SizedBox(height: 24),
          // User List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              if (index >= filteredUsers.length) return SizedBox();
              
              final dynamic user = filteredUsers[index];
              if (user == null) return SizedBox();

              String name = 'User';
              String email = 'No Email';
              String initials = '??';
              String totalSplits = '0';
              bool isAdmin = false;

              try {
                name = user.name?.toString() ?? 'User';
                email = user.email?.toString() ?? 'No Email';
                initials = user.avatarInitials?.toString() ?? '??';
                totalSplits = user.totalSplits?.toString() ?? '0';
                isAdmin = user.role?.toString().contains('admin') ?? false;
              } catch (_) {}

              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(12),
                  onTap: () => _showEditUserSheet(context, user),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isAdmin ? AppColors.adminGradient : AppColors.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    email,
                    style: TextStyle(color: subColor, fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        totalSplits,
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Splits',
                        style: TextStyle(color: subColor, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  void _showEditUserSheet(BuildContext context, UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = AppColors.adminAccent;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: subColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Edit Profile',
              style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _buildEditField('Full Name', (user as dynamic).name?.toString() ?? '', Icons.person_outline, isDark),
            SizedBox(height: 16),
            _buildEditField('Email Address', (user as dynamic).email?.toString() ?? '', Icons.email_outlined, isDark),
            SizedBox(height: 16),
            _buildEditField('Phone Number', (user as dynamic).phoneNumber?.toString() ?? '+91 00000 00000', Icons.phone_outlined, isDark),
            SizedBox(height: 16),
            _buildEditField('Password', (user as dynamic).password?.toString() ?? '', Icons.lock_outline_rounded, isDark, isPassword: true),
            SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppColors.adminGradient),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Profile updated for ${user.name}'),
                      backgroundColor: accentColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(String label, String value, IconData icon, bool isDark, {bool isPassword = false}) {
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: subColor.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: TextEditingController(text: value),
            style: TextStyle(color: textColor, fontSize: 14),
            obscureText: isPassword,
            decoration: InputDecoration(
              icon: Icon(icon, size: 18, color: subColor),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitease_test/core/models/dummy_data.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/shared/widgets/app_button.dart';
import 'package:splitease_test/user/widgets/whatsapp_link_sheet.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  // Using local state to simulate the account linking just for this prototype
  bool _isWhatsAppLinked = false;

  @override
  void initState() {
    super.initState();
  }

  void _openWhatsAppLinker() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WhatsAppLinkSheet(),
    );

    if (result == true) {
      setState(() => _isWhatsAppLinked = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WhatsApp Account Linked Successfully!'),
          backgroundColor: AppColors.whatsapp,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = DummyData.currentUser;
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
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppTheme.padding,
          right: AppTheme.padding,
          top: AppTheme.padding,
          bottom: 140, // Extra padding to clear the floating bottom nav
        ),
        child: Column(
          children: [
            SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: surfaceColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (context) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 12, bottom: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceVariant
                                  : AppColors.lightSurfaceVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.photo_library_rounded,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              'Choose from Gallery',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Gallery Selection (Coming Soon)',
                                  ),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.camera_alt_rounded,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              'Take Photo',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Camera App (Coming Soon)'),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                );
              },
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        user.avatarInitials,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: surfaceColor, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              user.name,
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, size: 12, color: subColor),
                SizedBox(width: 4),
                Text(
                  user.email,
                  style: TextStyle(color: subColor, fontSize: 13),
                ),
              ],
            ),
            SizedBox(height: 32),

            // Detailed Info
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                ),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    isDark: isDark,
                    icon: Icons.phone_rounded,
                    label: 'Phone Number',
                    value: '+91 98765 43210',
                  ),
                  Divider(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    height: 24,
                  ),
                  _InfoRow(
                    isDark: isDark,
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'UPI ID',
                    value: 'dummy@upi',
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Stats Row
            Row(
              children: [
                _StatBox(
                  label: 'Total Splits',
                  value: '${user.totalSplits}',
                  icon: Icons.receipt_long_rounded,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  subColor: subColor,
                  isDark: isDark,
                ),
                SizedBox(width: 16),
                _StatBox(
                  label: 'Joined',
                  value: '${user.joinDate.month}/${user.joinDate.year}',
                  icon: Icons.calendar_today_rounded,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  subColor: subColor,
                  isDark: isDark,
                ),
              ],
            ),

            SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Achievements',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _BadgeCard(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Settled 10',
                    subtitle: 'Groups Settled',
                    color: Colors.amber,
                    isDark: isDark,
                  ),
                  SizedBox(width: 12),
                  _BadgeCard(
                    icon: Icons.timer_rounded,
                    title: 'On-time',
                    subtitle: 'Quick Payer',
                    color: Colors.green,
                    isDark: isDark,
                  ),
                  SizedBox(width: 12),
                  _BadgeCard(
                    icon: Icons.group_add_rounded,
                    title: 'Socialite',
                    subtitle: 'Invited 5 Friends',
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Linked Accounts',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 12),

            // WhatsApp Linking Card
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.whatsapp.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons
                          .chat_bubble_rounded, // Alternative to WhatsApp icon since we don't have font_awesome
                      color: AppColors.whatsapp,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WhatsApp',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _isWhatsAppLinked
                              ? 'Linked successfully'
                              : 'Not linked to any account',
                          style: TextStyle(
                            color: _isWhatsAppLinked
                                ? AppColors.whatsapp
                                : subColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isWhatsAppLinked)
                    GestureDetector(
                      onTap: _openWhatsAppLinker,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.whatsapp,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Link',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.whatsapp,
                      size: 28,
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // App Theme Selection
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'App Theme',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 12),
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                ),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _ThemeCircle(
                    name: 'aqua',
                    colors: [Color(0xFF8DF7F0), Color(0xFF2EF2E2)],
                    provider: themeProvider,
                  ),
                  _ThemeCircle(
                    name: 'purple',
                    colors: [Color(0xFFD8B4FE), Color(0xFFA855F7)],
                    provider: themeProvider,
                  ),
                  _ThemeCircle(
                    name: 'orange',
                    colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
                    provider: themeProvider,
                  ),
                  _ThemeCircle(
                    name: 'red',
                    colors: [Color(0xFFFCA5A5), Color(0xFFEF4444)],
                    provider: themeProvider,
                  ),
                  _ThemeCircle(
                    name: 'green',
                    colors: [Color(0xFF86EFAC), Color(0xFF22C55E)],
                    provider: themeProvider,
                  ),
                  _ThemeCircle(
                    name: 'yellow',
                    colors: [Color(0xFFFDE047), Color(0xFFEAB308)],
                    provider: themeProvider,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Theme Toggle
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Dark Mode',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: isDark,
                    onChanged: (val) => themeProvider.toggle(),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            AppButton(
              label: 'Logout',
              icon: Icons.logout_rounded,
              gradientColors: [AppColors.error],
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color surfaceColor;
  final Color textColor;
  final Color subColor;
  final bool isDark;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.surfaceColor,
    required this.textColor,
    required this.subColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurfaceVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: subColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
          size: 20,
        ),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ThemeCircle extends StatelessWidget {
  final String name;
  final List<Color> colors;
  final ThemeProvider provider;

  const _ThemeCircle({
    required this.name,
    required this.colors,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    bool isSelected = AppColors.currentThemeName == name;
    return GestureDetector(
      onTap: () => provider.setThemeColor(name),
      child: Container(
        width: 40,
        height: 40,
        margin: EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  width: 3,
                )
              : null,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: colors.last.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
      ),
    );
  }
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
      width: 120,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkSurfaceVariant
              : AppColors.lightSurfaceVariant,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isDark ? AppColors.darkText : AppColors.lightText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

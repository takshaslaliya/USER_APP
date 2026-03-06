import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitease_test/core/models/user_model.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/services/whatsapp_service.dart';
import 'package:splitease_test/user/widgets/whatsapp_link_sheet.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:splitease_test/shared/utils/notification_helper.dart';
import 'package:splitease_test/core/providers/data_refresh_provider.dart';
import 'dart:async';
import 'dart:convert';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isWhatsAppLinked = false;
  UserModel? _user;
  bool _isLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadUser();

    // Handle global refresh signal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DataRefreshProvider>().addListener(_loadUser);
      }
    });

    // Start polling every 30 seconds for settings (less frequent)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadUser(isPolling: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    try {
      context.read<DataRefreshProvider>().removeListener(_loadUser);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadUser({bool isPolling = false}) async {
    if (isPolling && _isLoading) return;
    if (!isPolling) setState(() => _isLoading = true);

    // Load profile and whatsapp status in parallel
    final results = await Future.wait([
      AuthService.getProfile(),
      WhatsAppService.getStatus(),
    ]);

    final profileRes = results[0] as AuthResult;
    final whatsappRes = results[1] as WhatsAppResult;

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (profileRes.success && profileRes.data != null) {
          _user = UserModel.fromJson(profileRes.data!);
          // Sync WhatsApp status from profile
          _isWhatsAppLinked = _user!.whatsappConnected;
        } else if (!profileRes.success) {
          NotificationHelper.showError(context, profileRes.message);
        }

        if (whatsappRes.success && whatsappRes.data != null) {
          _isWhatsAppLinked = whatsappRes.data!['status'] == 'connected';
        }
      });
    }
  }

  Future<void> _pickImage() async {
    // Request permission (specifically for photos/gallery)
    final status = await Permission.photos.request();

    if (status.isGranted || status.isLimited) {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 100,
      );

      if (image != null) {
        final file = File(image.path);
        setState(() => _isLoading = true);
        final res = await AuthService.updateProfile(photo: file);
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (res.success && res.data != null) {
              context.read<DataRefreshProvider>().signalRefresh();
              _user = UserModel.fromJson(res.data!);
              NotificationHelper.showSuccess(
                context,
                'Profile picture updated successfully!',
              );
            } else {
              NotificationHelper.showError(context, res.message);
            }
          });
        }
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Gallery access is needed to change your profile picture. Please enable it in Settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(context);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        NotificationHelper.showError(context, 'Gallery permission is required');
      }
    }
  }

  void _showEditProfileDialog() {
    if (_user == null) return;

    final nameCtrl = TextEditingController(text: _user!.fullName);
    final userCtrl = TextEditingController(text: _user!.username);
    final mobileCtrl = TextEditingController(text: _user!.mobileNumber);
    final upiCtrl = TextEditingController(text: _user!.upiId ?? '');

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        final surfaceColor = isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface;

        return AlertDialog(
          backgroundColor: surfaceColor,
          title: Text(
            'Edit Profile',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditField('Full Name', nameCtrl, isDark),
                _buildEditField('Username', userCtrl, isDark),
                _buildEditField(
                  'Mobile Number',
                  mobileCtrl,
                  isDark,
                  TextInputType.phone,
                ),
                _buildEditField('UPI ID', upiCtrl, isDark),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: textColor)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                final body = <String, dynamic>{};
                if (nameCtrl.text != _user!.fullName) {
                  body['full_name'] = nameCtrl.text;
                }
                if (userCtrl.text != _user!.username) {
                  body['username'] = userCtrl.text;
                }
                if (mobileCtrl.text != _user!.mobileNumber) {
                  body['mobile_number'] = mobileCtrl.text;
                }
                if (upiCtrl.text != (_user!.upiId ?? '')) {
                  body['upi_id'] = upiCtrl.text;
                }

                if (body.isNotEmpty) {
                  _updateProfileMap(body);
                }
              },
              child: Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController ctrl,
    bool isDark, [
    TextInputType? type,
  ]) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subColor),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Future<void> _updateProfileMap(Map<String, dynamic> body) async {
    setState(() => _isLoading = true);
    final res = await AuthService.updateProfile(fullName: body['full_name']);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          context.read<DataRefreshProvider>().signalRefresh();
          _user = UserModel.fromJson(res.data!);
          _isWhatsAppLinked = _user!.whatsappConnected;
          NotificationHelper.showSuccess(
            context,
            'Profile updated successfully!',
          );
        } else {
          NotificationHelper.showError(context, res.message);
        }
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
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
      NotificationHelper.showSuccess(
        context,
        'WhatsApp Account Linked Successfully!',
      );
    }
  }

  Future<void> _disconnectWhatsApp() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect WhatsApp?'),
        content: const Text(
          'Are you sure you want to disconnect your WhatsApp account? You will no longer receive notifications on WhatsApp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final res = await WhatsAppService.disconnect();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success) {
          _isWhatsAppLinked = false;
        }
      });
      if (res.success) {
        NotificationHelper.showSuccess(context, res.message);
      } else {
        NotificationHelper.showError(context, res.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _user?.fullName ?? 'User';
    final email = _user?.email ?? 'user@example.com';
    final mobile = _user?.mobileNumber ?? 'Not set';
    final username = _user?.username ?? '';
    final initials = _user?.initials ?? 'U';

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
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: _isLoading ? 2 : 0,
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : null,
      ),
      extendBodyBehindAppBar: true,
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
                              _pickImage();
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
                    child: _buildProfileImage(initials),
                  ),
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: surfaceColor, width: 2),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: _showEditProfileDialog,
              child: Text(
                fullName,
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 4),
            if (username.isNotEmpty)
              Text(
                '@$username',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _user?.emailVerified == true
                      ? Icons.verified_rounded
                      : Icons.lock_rounded,
                  size: 14,
                  color: _user?.emailVerified == true
                      ? AppColors.primary
                      : subColor,
                ),
                SizedBox(width: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
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
                    value: mobile,
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
                    value: _user?.upiId ?? 'Not set',
                    onTap: _showEditProfileDialog,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

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
                      color: Colors.white, // Provide a clean white base
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Center(
                        child: Image.asset(
                          'assets/images/whatsapp_logo.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover, // Zoom in slightly to cut corners
                        ),
                      ),
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
                    GestureDetector(
                      onTap: _disconnectWhatsApp,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'Disconnect',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

            // Appearance Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Appearance',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(4),
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
                  _AppearanceOption(
                    label: 'System',
                    mode: ThemeMode.system,
                    provider: themeProvider,
                    isDark: isDark,
                  ),
                  _AppearanceOption(
                    label: 'Light',
                    mode: ThemeMode.light,
                    provider: themeProvider,
                    isDark: isDark,
                  ),
                  _AppearanceOption(
                    label: 'Dark',
                    mode: ThemeMode.dark,
                    provider: themeProvider,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            GestureDetector(
              onTap: _logout,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFEF4444).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(String initials) {
    if (_user?.profilePhotoUrl != null && _user!.profilePhotoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.network(
          _user!.profilePhotoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildInitials(initials),
        ),
      );
    }

    if (_user?.profilePhotoBase64 != null &&
        _user!.profilePhotoBase64!.isNotEmpty) {
      try {
        final base64String = _user!.profilePhotoBase64!.split(',').last;
        return ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Image.memory(
            base64Decode(base64String),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildInitials(initials),
          ),
        );
      } catch (e) {
        return _buildInitials(initials);
      }
    }

    return _buildInitials(initials);
  }

  Widget _buildInitials(String initials) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w700,
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
  final VoidCallback? onTap;

  const _InfoRow({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              size: 20,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.lightSubtext,
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
            ),
            if (onTap != null)
              Icon(Icons.edit_rounded, color: AppColors.primary, size: 16),
          ],
        ),
      ),
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

class _AppearanceOption extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final ThemeProvider provider;
  final bool isDark;

  const _AppearanceOption({
    required this.label,
    required this.mode,
    required this.provider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    bool isSelected = provider.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

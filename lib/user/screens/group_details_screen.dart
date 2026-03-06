import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/user/screens/add_expense_screen.dart';
import 'package:splitease_test/user/screens/expense_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupDetailsScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _msgController = TextEditingController();
  late GroupModel _group;
  bool _isLoading = false;
  String? _currentUserId;

  bool get _isCreator =>
      _currentUserId != null && _currentUserId == _group.creatorId;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _initUser();
    _refreshGroup();
    _loadLocalGroupIcon();
  }

  Future<void> _loadLocalGroupIcon() async {
    final prefs = await SharedPreferences.getInstance();
    final localPath = prefs.getString('group_icon_${_group.id}');
    if (localPath != null && File(localPath).existsSync()) {
      if (mounted) {
        setState(() {
          _group.customImageUrl = localPath;
        });
      }
    }
  }

  Future<void> _initUser() async {
    final user = await AuthService.getUser();
    if (mounted) {
      setState(() {
        _currentUserId = user?['id']?.toString();
      });
    }
  }

  Future<void> _refreshGroup() async {
    setState(() => _isLoading = true);
    final result = await GroupService.fetchGroupDetails(_group.id);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.data != null) {
      final prefs = await SharedPreferences.getInstance();
      final localIconPath = prefs.getString('group_icon_${_group.id}');

      setState(() {
        _group = GroupModel.fromJson(result.data!);
        // Restore local icon if server returns null/empty but we have a valid local one
        if ((_group.customImageUrl == null || _group.customImageUrl!.isEmpty) &&
            localIconPath != null &&
            File(localIconPath).existsSync()) {
          _group.customImageUrl = localIconPath;
        }
      });
    }
  }

  Future<void> _addMemberFromContacts() async {
    if (await Permission.contacts.request().isGranted) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        final phone = contact.phones.isNotEmpty
            ? contact.phones.first.number
            : '';
        final name = contact.displayName;

        if (phone.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact has no phone number')),
          );
          return;
        }

        _checkAndAddMember(name, phone);
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission denied')),
      );
    }
  }

  Future<void> _updateGroupIcon() async {
    // For Android, Permission.photos is for API 33+ (Android 13)
    // Permission.storage is for older versions.
    // Try photos first
    var status = await Permission.photos.request();

    // If photos is denied but we might be on an older Android, try storage
    if (status.isDenied) {
      status = await Permission.storage.request();
    }

    if (status.isGranted || status.isLimited) {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _isLoading = true);

        final res = await GroupService.updateGroup(
          _group.id,
          _group.name,
          _group.totalExpense,
          image.path,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
            if (res.success) {
              _group.customImageUrl = image.path;
              // Save locally
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('group_icon_${_group.id}', image.path);
              });
            }
          });

          if (res.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Group icon updated successfully!'),
                backgroundColor: AppColors.primary,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        openAppSettings();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photos permission denied')),
        );
      }
    }
  }

  Future<void> _checkAndAddMember(String name, String phone) async {
    // Normalize phone to E.164 (91XXXXXXXXXX format)
    String normalized = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (normalized.startsWith('+')) normalized = normalized.substring(1);
    if (!normalized.startsWith('91') && normalized.length == 10) {
      normalized = '91$normalized';
    }

    setState(() => _isLoading = true);
    final statusRes = await AuthService.checkUserStatus(normalized);
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Parse result
    bool isRegistered = false;
    String? upiId;
    if (statusRes.success && statusRes.data != null) {
      isRegistered = statusRes.data!['is_register'] == true;
      final rawUpi = statusRes.data!['upi_id'];
      if (rawUpi != null && rawUpi != false && rawUpi is String) {
        upiId = rawUpi;
      }
    }

    // Show status dialog before adding
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add $name?',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRegistered
                    ? AppColors.paid.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isRegistered
                      ? AppColors.paid.withValues(alpha: 0.4)
                      : AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isRegistered
                        ? Icons.verified_user_rounded
                        : Icons.person_off_rounded,
                    color: isRegistered ? AppColors.paid : AppColors.error,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRegistered
                              ? 'Registered on SplitEase'
                              : 'Not registered',
                          style: TextStyle(
                            color: isRegistered
                                ? AppColors.paid
                                : AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isRegistered
                              ? (upiId != null
                                    ? 'UPI: $upiId'
                                    : 'No UPI ID linked')
                              : 'They will receive an invite to join.',
                          style: TextStyle(color: subColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: subColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Add Member',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _callAddMemberApi(name, phone);
    }
  }

  Future<void> _callAddMemberApi(String name, String phone) async {
    setState(() => _isLoading = true);
    final res = await GroupService.addMember(
      _group.id,
      name,
      phone,
      0.0, // Initial expense amount is 0
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppColors.primary,
        ),
      );
      _refreshGroup();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppColors.error),
      );
    }
  }

  void _showAddMemberOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Member',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkText
                    : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.contacts_rounded, color: AppColors.primary),
              ),
              title: Text(
                'Choose from Contacts',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkText
                      : AppColors.lightText,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _addMemberFromContacts();
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_add_rounded, color: AppColors.primary),
              ),
              title: Text(
                'Enter Details Manually',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkText
                      : AppColors.lightText,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showManualAddDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManualAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
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
          title: Text('Add Member', style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Name',
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.lightSubtext,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Phone Number',
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.lightSubtext,
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                  _checkAndAddMember(nameCtrl.text, phoneCtrl.text);
                }
              },
              child: const Text('Check & Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  Widget _buildExpenseTile({
    required String title,
    required String amount,
    required int membersCount,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurfaceVariant,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$membersCount members',
                      style: TextStyle(color: subColor, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
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
        title: Row(
          children: [
            Hero(
              tag: 'group_avatar_${_group.id}',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  image: _group.customImageUrl != null
                      ? DecorationImage(
                          image:
                              () {
                                    final url = _group.customImageUrl!;
                                    if (url.startsWith('http') ||
                                        url.startsWith('blob:')) {
                                      return NetworkImage(url);
                                    } else if (url.startsWith('data:')) {
                                      final base64Str = url.split(',').last;
                                      return MemoryImage(
                                        base64Decode(base64Str),
                                      );
                                    } else {
                                      return FileImage(File(url));
                                    }
                                  }()
                                  as ImageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _group.customImageUrl == null
                    ? Center(
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            _group.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _group.name,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_isCreator)
            IconButton(
              icon: Icon(Icons.person_add_outlined, color: AppColors.primary),
              onPressed: _showAddMemberOptions,
            ),
          if (_isCreator)
            IconButton(
              icon: Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
              onPressed: _updateGroupIcon,
            ),
          if (_isCreator)
            IconButton(
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                final screenContext = context;
                showDialog(
                  context: screenContext,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: surfaceColor,
                    title: Text(
                      'Delete Group?',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      'Are you sure you want to delete this group? This action cannot be undone.',
                      style: TextStyle(color: subColor),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: textColor),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext); // Close dialog
                          setState(() => _isLoading = true);
                          final res = await GroupService.deleteGroup(_group.id);
                          if (!mounted) return;
                          setState(() => _isLoading = false);

                          if (res.success) {
                            if (!mounted) return;
                            Navigator.pop(screenContext); // Go back to Home
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Group deleted successfully',
                                ),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          } else {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: subColor,
          labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Group Chat'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1 || !_isCreator
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddExpenseScreen(group: _group),
                  ),
                );
                if (result == true) {
                  _refreshGroup();
                }
              },
              backgroundColor: AppColors.primary,
              icon: Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Expense',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
          ListView(
            padding: EdgeInsets.all(AppTheme.padding),
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.primaryGradient),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '₹${(_group.totalSubExpense > 0 ? _group.totalSubExpense : _group.totalAmount).toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              if (_group.expenses.isNotEmpty) ...[
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Group Expenses',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_group.expenses.length} Total',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ..._group.expenses.map((expense) {
                  return _buildExpenseTile(
                    title: expense.title,
                    amount: '₹${expense.amount.toInt()}',
                    membersCount: expense.splits.length,
                    onTap: () async {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExpenseDetailsScreen(
                            group: _group,
                            expense: expense,
                          ),
                        ),
                      );
                      if (res == true) {
                        _refreshGroup();
                      }
                    },
                    isDark: isDark,
                  );
                }),
              ], // Closes spread
            ], // Closes ListView.children
          ), // Closes ListView
          // Chat Tab
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _group.messages.length,
                  itemBuilder: (context, index) {
                    final msg = _group.messages[index];
                    final isMe = msg.senderId == 'me'; // Simplified
                    final senderName = msg.senderId == 'system'
                        ? 'System'
                        : 'User';

                    if (msg.isSystem) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              msg.text,
                              style: TextStyle(color: subColor, fontSize: 12),
                            ),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (!isMe)
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                senderName.substring(0, 1),
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          SizedBox(width: 8),
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primary : surfaceColor,
                              borderRadius: BorderRadius.circular(16).copyWith(
                                bottomRight: isMe
                                    ? const Radius.circular(0)
                                    : null,
                                bottomLeft: !isMe
                                    ? const Radius.circular(0)
                                    : null,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe) ...[
                                  Text(
                                    senderName,
                                    style: TextStyle(
                                      color: subColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                ],
                                Text(
                                  msg.text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : textColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                bottom: true,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.send_rounded,
                          color: AppColors.primary,
                        ),
                        onPressed: () {
                          if (_msgController.text.isNotEmpty) {
                            _msgController.clear();
                            FocusScope.of(context).unfocus();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

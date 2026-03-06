import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  late GroupModel _group;
  bool _isLoading = false;

  bool get _isCreator => !_group.isShared;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
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

  Future<void> _refreshGroup() async {
    setState(() => _isLoading = true);
    final result = await GroupService.fetchGroupDetails(_group.id);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.data != null) {
      final prefs = await SharedPreferences.getInstance();
      final localIconPath = prefs.getString('group_icon_${_group.id}');

      setState(() {
        final wasShared = _group.isShared;
        _group = GroupModel.fromJson(result.data!);
        // Preserve isShared if the API doesn't specify it (fallback to previous state)
        if (wasShared &&
            !result.data!.containsKey('group_type') &&
            !result.data!.containsKey('is_shared')) {
          _group = GroupModel(
            id: _group.id,
            name: _group.name,
            description: _group.description,
            parentId: _group.parentId,
            customImageUrl: _group.customImageUrl,
            creatorId: _group.creatorId,
            createdDate: _group.createdDate,
            members: _group.members,
            expenses: _group.expenses,
            messages: _group.messages,
            memberCount: _group.memberCount,
            subGroupCount: _group.subGroupCount,
            totalExpense: _group.totalExpense,
            totalSubExpense: _group.totalSubExpense,
            splitType: _group.splitType,
            isShared: true, // Keep it shared
          );
        }
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

        _checkAndAddMember(name, phone, skipDialog: true);
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

  Future<void> _checkAndAddMember(
    String name,
    String phone, {
    bool skipDialog = false,
  }) async {
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

    // Parse result — handle bool, string "true"/"false", and missing key robustly
    bool isRegistered = false;
    String? upiId;
    if (statusRes.data != null) {
      final raw = statusRes.data!['is_register'];
      isRegistered = (raw == true) || (raw?.toString().toLowerCase() == 'true');
      final rawUpi = statusRes.data!['upi_id'];
      if (rawUpi != null &&
          rawUpi != false &&
          rawUpi.toString().isNotEmpty &&
          rawUpi.toString() != 'false') {
        upiId = rawUpi.toString();
      }
    }

    if (skipDialog) {
      _callAddMemberApi(name, normalized, upiId: upiId);
      return;
    }

    // Show status dialog before adding
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final upiController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Add $name?',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Registration Status Badge ──────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
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
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRegistered
                                  ? 'Registered on SplitEase'
                                  : 'Not on SplitEase',
                              style: TextStyle(
                                color: isRegistered
                                    ? AppColors.paid
                                    : AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isRegistered
                                  ? (upiId != null
                                        ? 'UPI: $upiId'
                                        : 'No UPI ID linked to their account')
                                  : 'They are not on SplitEase yet.',
                              style: TextStyle(color: subColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── UPI Input for unregistered members ─────────────────
                if (!isRegistered) ...[
                  const SizedBox(height: 14),
                  Text(
                    'UPI ID for Payment',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                      ),
                    ),
                    child: TextField(
                      controller: upiController,
                      autofocus: false,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'e.g. name@okicici',
                        hintStyle: TextStyle(color: subColor, fontSize: 13),
                        prefixIcon: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        isDense: true,
                      ),
                      onChanged: (v) => setDialogState(() {}),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Optional — used to route payments to their account',
                    style: TextStyle(color: subColor, fontSize: 11),
                  ),
                ],
              ],
            ),
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
      ),
    );

    if (confirmed == true) {
      final enteredUpi = upiController.text.trim();
      _callAddMemberApi(
        name,
        normalized,
        upiId: enteredUpi.isEmpty ? null : enteredUpi,
      );
    }
    upiController.dispose();
  }

  Future<void> _callAddMemberApi(
    String name,
    String phone, {
    String? upiId,
  }) async {
    setState(() => _isLoading = true);
    final res = await GroupService.addMember(
      _group.id,
      name,
      phone,
      0.0, // Initial expense amount is 0
      upiId: upiId,
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
                inputFormatters: [LengthLimitingTextInputFormatter(25)],
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
                  _checkAndAddMember(
                    nameCtrl.text,
                    phoneCtrl.text,
                    skipDialog: true,
                  );
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 14,
                        color: subColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$membersCount members',
                        style: TextStyle(color: subColor, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
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
                            if (!screenContext.mounted) return;
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
                            if (!screenContext.mounted) return;
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
      ),
      floatingActionButton: FloatingActionButton.extended(
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 32),
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
            const SizedBox(height: 16),
            ..._group.expenses.map((expense) {
              return _buildExpenseTile(
                title: expense.title,
                amount: '₹${expense.amount.toInt()}',
                membersCount: expense.memberCount,
                onTap: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ExpenseDetailsScreen(group: _group, expense: expense),
                    ),
                  );
                  if (res == true) {
                    _refreshGroup();
                  }
                },
                isDark: isDark,
              );
            }),
          ],
        ],
      ),
    );
  }
}

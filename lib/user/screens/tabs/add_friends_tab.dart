import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/shared/widgets/app_button.dart';
import 'package:splitease_test/core/services/friends_storage.dart';

class AddFriendsTab extends StatefulWidget {
  const AddFriendsTab({super.key});

  @override
  State<AddFriendsTab> createState() => _AddFriendsTabState();
}

class _AddFriendsTabState extends State<AddFriendsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _addFriend() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    // Save to local persistence
    await FriendsStorage.saveFriend(
      name.isNotEmpty ? name : 'New Friend',
      phone,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend added and saved locally!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }

    _nameController.clear();
    _phoneController.clear();
  }

  Future<void> _pickContact(
    TextEditingController nameCtrl,
    TextEditingController phoneCtrl,
  ) async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      try {
        if (await FlutterContacts.requestPermission()) {
          final contact = await FlutterContacts.openExternalPick();
          if (contact != null) {
            final fullContact = await FlutterContacts.getContact(contact.id);
            if (fullContact != null && fullContact.phones.isNotEmpty) {
              setState(() {
                nameCtrl.text = fullContact.displayName;
                phoneCtrl.text = fullContact.phones.first.number;
              });
            } else if (contact.phones.isNotEmpty) {
              setState(() {
                nameCtrl.text = contact.displayName;
                phoneCtrl.text = contact.phones.first.number;
              });
            } else {
              setState(() {
                nameCtrl.text = contact.displayName;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No phone number found for this contact.'),
                  ),
                );
              }
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Contacts permission denied')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open contacts.')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Contact selection is only supported on mobile devices.',
            ),
          ),
        );
      }
    }
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
        title: Text(
          'Add Friends',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: subColor,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Mobile Number'),
            Tab(text: 'Offline Add'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Phone Tab
          _buildInputTab(
            context: context,
            surfaceColor: surfaceColor,
            textColor: textColor,
            subColor: subColor,
            isDark: isDark,
            icon: Icons.phone_rounded,
            title: 'Add by Phone Number',
            controller: _phoneController,
            hintText: '+91 98765 43210',
            keyboardType: TextInputType.phone,
          ),

          // 2. Manual Name (Offline member) Tab
          _buildOfflineMemberTab(
            context: context,
            surfaceColor: surfaceColor,
            textColor: textColor,
            subColor: subColor,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineMemberTab({
    required BuildContext context,
    required Color surfaceColor,
    required Color textColor,
    required Color subColor,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppTheme.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Add Offline Member',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Add the member directly to the group without asking for permission.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subColor, fontSize: 13, height: 1.5),
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                    ),
                  ),
                  child: TextField(
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Full Name',
                      hintStyle: TextStyle(color: subColor),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                    ),
                  ),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'WhatsApp Number (Required)',
                      hintStyle: TextStyle(color: subColor),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.contacts_rounded,
                          color: AppColors.primary,
                        ),
                        onPressed: () =>
                            _pickContact(_nameController, _phoneController),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 48),
          AppButton(
            label: 'Add Friend',
            icon: Icons.person_add_rounded,
            onPressed: () {
              if (_nameController.text.trim().isNotEmpty &&
                  _phoneController.text.trim().isNotEmpty) {
                _addFriend();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Name and WhatsApp number are required.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputTab({
    required BuildContext context,
    required Color surfaceColor,
    required Color textColor,
    required Color subColor,
    required bool isDark,
    required IconData icon,
    required String title,
    required TextEditingController controller,
    required String hintText,
    required TextInputType keyboardType,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppTheme.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 32),
                ),
                SizedBox(height: 24),
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'They will receive a notification to join SplitEase once you add them to your groups.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subColor, fontSize: 13, height: 1.5),
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(color: subColor),
                      border: InputBorder.none,
                      suffixIcon: keyboardType == TextInputType.phone
                          ? IconButton(
                              icon: Icon(
                                Icons.contacts_rounded,
                                color: AppColors.primary,
                              ),
                              onPressed: () => _pickContact(
                                TextEditingController(),
                                controller,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 48),
          AppButton(
            label: 'Add Friend',
            icon: Icons.person_add_rounded,
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addFriend();
              }
            },
          ),
        ],
      ),
    );
  }
}

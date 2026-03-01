import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:splitease_test/core/models/dummy_data.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/models/member_model.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/user/screens/add_expense_screen.dart';
import 'package:splitease_test/user/widgets/member_tile.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _showAddOfflineMemberDialog(
    Color surfaceColor,
    Color textColor,
    Color subColor,
    bool isDark,
  ) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surfaceColor,
          title: Text(
            'Add Offline Member',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter name',
                  hintStyle: TextStyle(color: subColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
                style: TextStyle(color: textColor),
                autofocus: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'WhatsApp Number (Required)',
                  hintStyle: TextStyle(color: subColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.contacts_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: () async {
                      if (!kIsWeb &&
                          (defaultTargetPlatform == TargetPlatform.iOS ||
                              defaultTargetPlatform ==
                                  TargetPlatform.android)) {
                        try {
                          if (await FlutterContacts.requestPermission()) {
                            final contact =
                                await FlutterContacts.openExternalPick();
                            if (contact != null) {
                              final fullContact =
                                  await FlutterContacts.getContact(contact.id);
                              if (fullContact != null &&
                                  fullContact.phones.isNotEmpty) {
                                nameCtrl.text = fullContact.displayName;
                                phoneCtrl.text =
                                    fullContact.phones.first.number;
                              } else if (contact.phones.isNotEmpty) {
                                nameCtrl.text = contact.displayName;
                                phoneCtrl.text = contact.phones.first.number;
                              } else {
                                nameCtrl.text = contact.displayName;
                              }
                            }
                          }
                        } catch (e) {
                          // Ignore
                        }
                      } else {
                        // ignore
                      }
                    },
                  ),
                ),
                style: TextStyle(color: textColor),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: textColor)),
            ),
            TextButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty &&
                    phoneCtrl.text.trim().isNotEmpty) {
                  final newMember = MemberModel(
                    id: 'm_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim(),
                    avatarInitials: nameCtrl.text
                        .trim()
                        .substring(0, 1)
                        .toUpperCase(),
                    amountOwed: 0,
                    isPaid: true,
                    phoneNumber: phoneCtrl.text.trim(),
                  );
                  setState(() {
                    widget.group.members.add(newMember);
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Name and WhatsApp number are required.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: Text(
                'Add',
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

  void _showAddAppFriendSheet(
    Color surfaceColor,
    Color textColor,
    Color subColor,
    bool isDark,
  ) {
    final existingMemberNames = widget.group.members.map((m) => m.name).toSet();
    final availableUsers = DummyData.users
        .where((u) => !existingMemberNames.contains(u.name))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Add App Friend',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                if (availableUsers.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'All your friends are already in this group!',
                        style: TextStyle(color: subColor),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: availableUsers.length,
                      itemBuilder: (context, index) {
                        final user = availableUsers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              user.avatarInitials,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          title: Text(
                            user.name,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            user.email,
                            style: TextStyle(color: subColor, fontSize: 12),
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              final newMember = MemberModel(
                                id: user.id,
                                name: user.name,
                                avatarInitials: user.avatarInitials,
                                amountOwed: 0,
                                isPaid: true,
                              );
                              setState(() {
                                widget.group.members.add(newMember);
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${user.name} added to group!'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            },
                            child: Text(
                              'Add',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
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
              tag: 'group_avatar_${widget.group.id}',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  image: widget.group.customImageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(widget.group.customImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: widget.group.customImageUrl == null
                    ? Center(
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            DummyData.users
                                .firstWhere(
                                  (u) => u.id == widget.group.creatorId,
                                  orElse: () => DummyData.users.first,
                                )
                                .avatarInitials,
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
                widget.group.name,
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
          if (widget.group.creatorId == DummyData.currentUser.id)
            IconButton(
              icon: Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
              onPressed: () {
                // Mock action for changing the group icon
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Icon updated successfully! (Mock)'),
                    backgroundColor: AppColors.primary,
                  ),
                );
                // In a real app we would pick an image and update CustomImageUrl
                setState(() {
                  widget.group.customImageUrl = 'https://picsum.photos/200';
                });
              },
            ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
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
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: textColor)),
                    ),
                    TextButton(
                      onPressed: () {
                        DummyData.groups.removeWhere(
                          (g) => g.id == widget.group.id,
                        );
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Go back to Home
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(group: widget.group),
            ),
          ).then((_) => setState(() {})); // Refresh on return
        },
        backgroundColor: AppColors.primary,
        icon: Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Expense',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      '₹${widget.group.totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Members',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${widget.group.paidCount}/${widget.group.members.length} Paid',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ...widget.group.members.map(
                (member) => MemberTile(member: member),
              ),
              SizedBox(height: 16),
              ListTile(
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
                            SizedBox(height: 16),
                            Text(
                              'Add Member',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Icon(
                                  Icons.person_search_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                'Add App Friend',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Add someone who already uses SplitEase',
                                style: TextStyle(color: subColor, fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _showAddAppFriendSheet(
                                  surfaceColor,
                                  textColor,
                                  subColor,
                                  isDark,
                                );
                              },
                            ),
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.2,
                                ),
                                child: Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: Text(
                                'Add Offline Member',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Add directly to the group without asking for permission',
                                style: TextStyle(color: subColor, fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _showAddOfflineMemberDialog(
                                  surfaceColor,
                                  textColor,
                                  subColor,
                                  isDark,
                                );
                              },
                            ),
                            SizedBox(height: 16),
                          ],
                        ),
                      );
                    },
                  );
                },
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Add Member',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              SizedBox(height: 48), // Padding for FAB
            ],
          ),
          // Chat Tab
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: widget.group.messages.length,
                  itemBuilder: (context, index) {
                    final msg = widget.group.messages[index];
                    final isMe = msg.senderId == DummyData.currentUser.id;
                    final senderName = msg.senderId == 'system'
                        ? 'System'
                        : DummyData.users
                              .firstWhere(
                                (u) => u.id == msg.senderId,
                                orElse: () => DummyData.users.first,
                              )
                              .name;

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
              Container(
                padding: EdgeInsets.all(16),
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
                      icon: Icon(Icons.send_rounded, color: AppColors.primary),
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
            ],
          ),
        ],
      ),
    );
  }
}

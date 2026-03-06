import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Your Groups state
  List<GroupModel> _myGroups = [];
  bool _myGroupsLoading = false;
  String? _currentUserId;

  // Shared Groups state
  List<GroupModel> _sharedGroups = [];
  bool _sharedGroupsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserAndRefresh();
    _refreshSharedGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndRefresh() async {
    final user = await AuthService.getUser();
    if (mounted) {
      setState(() {
        _currentUserId = user?['id']?.toString();
      });
      _refreshMyGroups();
    }
  }

  Future<void> _refreshMyGroups() async {
    setState(() => _myGroupsLoading = true);
    final result = await GroupService.fetchGroups();
    if (!mounted) return;
    setState(() => _myGroupsLoading = false);

    if (result.success && result.data != null) {
      final List<dynamic> data = result.data;
      final prefs = await SharedPreferences.getInstance();
      final loadedGroups = data.map((g) {
        final group = GroupModel.fromJson(g);
        final localIcon = prefs.getString('group_icon_${group.id}');
        if (localIcon != null && File(localIcon).existsSync()) {
          group.customImageUrl = localIcon;
        }
        return group;
      }).toList();
      if (mounted) setState(() => _myGroups = loadedGroups);
    }
  }

  Future<void> _refreshSharedGroups() async {
    setState(() => _sharedGroupsLoading = true);
    final result = await GroupService.fetchSharedGroups();
    if (!mounted) return;
    setState(() => _sharedGroupsLoading = false);

    if (result.success && result.data != null) {
      final List<dynamic> data = result.data;
      final prefs = await SharedPreferences.getInstance();
      final loadedGroups = data.map((g) {
        final group = GroupModel.fromJson(g);
        final localIcon = prefs.getString('group_icon_${group.id}');
        if (localIcon != null && File(localIcon).existsSync()) {
          group.customImageUrl = localIcon;
        }
        return group;
      }).toList();
      if (mounted) setState(() => _sharedGroups = loadedGroups);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_refreshMyGroups(), _refreshSharedGroups()]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeGroups = _myGroups
        .where((g) => g.creatorId == _currentUserId)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Groups',
          style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.lightText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _refreshAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                width: 0.8,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: AppColors.primary,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: isDark
                  ? AppColors.darkSubtext
                  : AppColors.lightSubtext,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Your Groups'),
                Tab(text: 'Shared Groups'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── YOUR GROUPS ──────────────────────────────────────────────
          _buildGroupsList(
            context,
            isDark: isDark,
            groups: activeGroups,
            isLoading: _myGroupsLoading,
            onRefresh: _refreshMyGroups,
            emptyIcon: Icons.receipt_long_rounded,
            emptyTitle: 'No groups yet',
            emptySubtitle: 'Create a group to start splitting bills!',
            isShared: false,
          ),

          // ── SHARED GROUPS ─────────────────────────────────────────────
          _buildGroupsList(
            context,
            isDark: isDark,
            groups: _sharedGroups,
            isLoading: _sharedGroupsLoading,
            onRefresh: _refreshSharedGroups,
            emptyIcon: Icons.group_add_rounded,
            emptyTitle: 'No shared groups',
            emptySubtitle: 'Groups created by others will appear here.',
            isShared: true,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList(
    BuildContext context, {
    required bool isDark,
    required List<GroupModel> groups,
    required bool isLoading,
    required Future<void> Function() onRefresh,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    required bool isShared,
  }) {
    if (isLoading && groups.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: groups.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        emptyIcon,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      emptyTitle,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        emptySubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ).copyWith(bottom: 140),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/details',
                      arguments: group,
                    ).then((_) => onRefresh()),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'group_avatar_${group.id}',
                            child: _buildGroupAvatar(group, isDark),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkText
                                        : AppColors.lightText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      isShared
                                          ? Icons.person_rounded
                                          : Icons.group_rounded,
                                      size: 14,
                                      color: isShared
                                          ? AppColors.primary
                                          : (isDark
                                                ? AppColors.darkSubtext
                                                : AppColors.lightSubtext),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isShared
                                          ? 'Shared by others'
                                          : '${group.memberCount} members',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.darkSubtext
                                            : AppColors.lightSubtext,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${group.displayTotal.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildGroupAvatar(GroupModel group, bool isDark) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(14),
        image: group.customImageUrl != null
            ? DecorationImage(
                image: _resolveImage(group.customImageUrl!) as ImageProvider,
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: group.customImageUrl == null
          ? Center(
              child: Text(
                group.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            )
          : null,
    );
  }

  dynamic _resolveImage(String url) {
    if (url.startsWith('http') || url.startsWith('blob:')) {
      return NetworkImage(url);
    } else if (url.startsWith('data:')) {
      final base64Str = url.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    } else {
      return FileImage(File(url));
    }
  }
}

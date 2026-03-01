import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  List<GroupModel> _groups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshGroups();
  }

  Future<void> _refreshGroups() async {
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
    // Filter logic if needed, but for now show all top-level groups
    final activeGroups = _groups;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Your Groups',
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
            onPressed: _refreshGroups,
          ),
        ],
      ),
      body: _isLoading && _groups.isEmpty
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _refreshGroups,
              color: AppColors.primary,
              child: activeGroups.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                size: 64,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 32),
                            Text(
                              'No groups yet',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Create a group to start splitting bills!',
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ).copyWith(bottom: 140),
                      itemCount: activeGroups.length,
                      itemBuilder: (context, index) {
                        final group = activeGroups[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/details',
                              arguments: group,
                            ).then((_) => _refreshGroups()),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(16),
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
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkBg
                                            : AppColors.lightBg,
                                        borderRadius: BorderRadius.circular(14),
                                        image: group.customImageUrl != null
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                  group.customImageUrl!,
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: group.customImageUrl == null
                                          ? Center(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: Text(
                                                  group.name
                                                      .substring(0, 1)
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.group_rounded,
                                              size: 14,
                                              color: isDark
                                                  ? AppColors.darkSubtext
                                                  : AppColors.lightSubtext,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '${group.memberCount} members',
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
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${group.totalAmount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: isDark
                                              ? AppColors.darkText
                                              : AppColors.lightText,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (group.totalAmount > 0) ...[
                                        SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.pendingBg,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            'Pending',
                                            style: TextStyle(
                                              color: AppColors.pending,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

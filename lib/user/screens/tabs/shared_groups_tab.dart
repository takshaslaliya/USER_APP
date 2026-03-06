import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/services/group_service.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedGroupsTab extends StatefulWidget {
  const SharedGroupsTab({super.key});

  @override
  State<SharedGroupsTab> createState() => _SharedGroupsTabState();
}

class _SharedGroupsTabState extends State<SharedGroupsTab> {
  List<GroupModel> _groups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshGroups();
  }

  Future<void> _refreshGroups() async {
    setState(() => _isLoading = true);
    final result = await GroupService.fetchSharedGroups();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success && result.data != null) {
      final List<dynamic> data = result.data;
      final prefs = await SharedPreferences.getInstance();

      final loadedGroups = data.map((g) {
        final group = GroupModel.fromJson(g);
        // Check for local icon
        final localIcon = prefs.getString('group_icon_${group.id}');
        if (localIcon != null && File(localIcon).existsSync()) {
          group.customImageUrl = localIcon;
        }
        return group;
      }).toList();

      setState(() {
        _groups = loadedGroups;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sharedGroups = _groups;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Shared Groups',
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
              child: sharedGroups.isEmpty
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
                                Icons.group_add_rounded,
                                size: 64,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 32),
                            Text(
                              'No shared groups',
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
                                'Groups created by others will appear here.',
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
                      itemCount: sharedGroups.length,
                      itemBuilder: (context, index) {
                        final group = sharedGroups[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () {
                              // Pass isReadOnly as true for shared groups
                              Navigator.pushNamed(
                                context,
                                '/details',
                                arguments: group,
                              ).then((_) => _refreshGroups());
                            },
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
                                        image: group.bestPhoto != null
                                            ? DecorationImage(
                                                image:
                                                    _resolveImage(
                                                          group.bestPhoto!,
                                                        )
                                                        as ImageProvider,
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: group.bestPhoto == null
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
                                              Icons.person_rounded,
                                              size: 14,
                                              color: AppColors.primary,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Shared by others',
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

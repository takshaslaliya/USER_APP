import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/dummy_data.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/user/widgets/status_chip.dart';

class AdminSplitsScreen extends StatefulWidget {
  const AdminSplitsScreen({super.key});

  @override
  State<AdminSplitsScreen> createState() => _AdminSplitsScreenState();
}

class _AdminSplitsScreenState extends State<AdminSplitsScreen> {
  String _filter = 'All';

  List<GroupModel> get _filtered {
    switch (_filter) {
      case 'Pending':
        return DummyData.groups
            .where((g) => g.paidAmount < g.totalAmount)
            .toList();
      case 'Settled':
        return DummyData.groups
            .where((g) => g.paidAmount >= g.totalAmount && g.totalAmount > 0)
            .toList();
      default:
        return DummyData.groups;
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
        backgroundColor: bgColor,
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
        title: Text(
          'All Splits',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: ['All', 'Pending', 'Settled'].map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.darkSurfaceVariant
                                    : AppColors.lightSurfaceVariant),
                        ),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          color: selected ? Colors.white : subColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _filtered.length,
        separatorBuilder: (context, index) => SizedBox(height: 10),
        itemBuilder: (context, index) {
          final group = _filtered[index];
          // Find creator name
          final creator = DummyData.users.firstWhere(
            (u) => u.id == group.creatorId,
            orElse: () => DummyData.users.first,
          );

          return Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        image: group.customImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(group.customImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: group.customImageUrl == null
                          ? Center(
                              child: Text(
                                creator.avatarInitials,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'by ${creator.name}',
                            style: TextStyle(color: subColor, fontSize: 12),
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
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        StatusChip(
                          isPaid:
                              group.paidAmount >= group.totalAmount &&
                              group.totalAmount > 0,
                          small: true,
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: group.progressPercent,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      (group.paidAmount >= group.totalAmount &&
                              group.totalAmount > 0)
                          ? AppColors.paid
                          : AppColors.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${group.members.length} members',
                      style: TextStyle(color: subColor, fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      '${group.paidCount} paid',
                      style: TextStyle(color: subColor, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

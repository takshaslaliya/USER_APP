import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/member_model.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/user/widgets/status_chip.dart';

class MemberTile extends StatelessWidget {
  final MemberModel member;
  final bool showDivider;

  const MemberTile({super.key, required this.member, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: member.isPaid
                        ? [AppColors.paid, Color(0xFF059669)]
                        : AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    member.avatarInitials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '₹${member.amountOwed.toStringAsFixed(0)}',
                      style: TextStyle(color: subColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              StatusChip(isPaid: member.isPaid),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurfaceVariant,
          ),
      ],
    );
  }
}

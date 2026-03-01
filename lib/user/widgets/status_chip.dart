import 'package:flutter/material.dart';
import 'package:splitease_test/core/theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  final bool isPaid;
  final bool small;

  const StatusChip({super.key, required this.isPaid, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: isPaid ? AppColors.paidBg : AppColors.pendingBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 5 : 6,
            height: small ? 5 : 6,
            decoration: BoxDecoration(
              color: isPaid ? AppColors.paid : AppColors.pending,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 5),
          Text(
            isPaid ? 'Paid' : 'Pending',
            style: TextStyle(
              color: isPaid ? AppColors.paid : AppColors.pending,
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

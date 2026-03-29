import 'dart:convert';
import 'package:flutter/foundation.dart';

class MemberModel {
  final String id;
  final String name;
  final String avatarInitials;
  final double amountOwed;
  final bool isPaid;
  final String? phoneNumber;
  final bool isRegistered;
  final String? userId; // For registered members
  final double expenseAmount;
  final DateTime? joinedAt;

  const MemberModel({
    required this.id,
    required this.name,
    required this.avatarInitials,
    required this.amountOwed,
    required this.isPaid,
    this.phoneNumber,
    this.isRegistered = false,
    this.userId,
    this.expenseAmount = 0.0,
    this.joinedAt,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    String name = json['name'] ?? 'Unknown';
    String initials = '?';
    if (name.trim().isNotEmpty) {
      initials = name.trim().substring(0, 1).toUpperCase();
    }
    debugPrint('MemberModel: Parsing member JSON: ${jsonEncode(json)}');
    return MemberModel(
      id: json['id']?.toString() ?? '',
      name: name,
      avatarInitials: initials,
      amountOwed: (json['amount_owed'] ?? 0.0).toDouble(), // Compute dynamically
      isPaid: json['is_paid'] == true || json['is_paid'] == 1, 
      phoneNumber: json['phone_number'] as String?,
      isRegistered: json['is_registered'] == true,
      userId: json['user_id'] as String?,
      expenseAmount: (json['expense_amount'] ?? 0.0).toDouble(),
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'])
          : null,
    );
  }
}

import 'package:splitease_test/core/models/member_model.dart';
import 'package:splitease_test/core/models/message_model.dart';
import 'package:splitease_test/core/models/expense_model.dart';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? parentId;
  String? customImageUrl;
  final String? groupPhotoUrl;
  final String? groupPhotoBase64;
  final String? groupPhotoDeleteUrl;
  final String creatorId;
  final DateTime createdDate;
  final List<MemberModel> members;
  final List<ExpenseModel> expenses;
  final List<MessageModel> messages;
  final int memberCount;
  final int subGroupCount;
  final double totalExpense;
  final double totalSubExpense;
  final String splitType;
  final bool isShared;

  GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.parentId,
    this.customImageUrl,
    this.groupPhotoUrl,
    this.groupPhotoBase64,
    this.groupPhotoDeleteUrl,
    required this.creatorId,
    required this.createdDate,
    required this.members,
    this.expenses = const [],
    this.messages = const [],
    this.memberCount = 0,
    this.subGroupCount = 0,
    this.totalExpense = 0.0,
    this.totalSubExpense = 0.0,
    this.splitType = 'solo',
    this.isShared = false,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    List<MemberModel> parsedMembers = [];
    if (json['members'] != null && json['members'] is List) {
      parsedMembers = (json['members'] as List)
          .map((m) => MemberModel.fromJson(m))
          .toList();
    }

    // New API Spec: sub_groups contain name, total_expense, and its own members
    List<ExpenseModel> parsedExpenses = [];
    if (json['sub_groups'] != null && json['sub_groups'] is List) {
      parsedExpenses = (json['sub_groups'] as List).map((sg) {
        // Handle both old and new split formats
        final String sgName = sg['expense_name'] ?? sg['name'] ?? 'Sub-group';
        final double sgAmount =
            (sg['total_amount'] ?? sg['total_expense'] ?? 0.0).toDouble();
        final String sgSplitType = sg['type'] ?? sg['split_type'] ?? 'solo';

        // Members list can now be in 'transactions' or 'members'
        List<MemberSplit> splits = [];
        if (sg['transactions'] != null && sg['transactions'] is List) {
          splits = (sg['transactions'] as List).map((tx) {
            final fromPhone = tx['from']?.toString() ?? '';
            final toPhone = tx['to']?.toString() ?? '';
            return MemberSplit(
              id:
                  tx['member_id']?.toString() ??
                  tx['id']?.toString() ??
                  fromPhone,
              name: tx['from_name']?.toString() ?? fromPhone,
              amount: (tx['amount'] ?? 0.0).toDouble(),
              isPaid: tx['is_paid'] ?? false,
              toId: toPhone,
              toName: tx['to_name']?.toString() ?? toPhone,
            );
          }).toList();
        } else if (sg['members'] != null &&
            sg['members'] is List &&
            sg['members'].isNotEmpty &&
            sg['members'].first is Map) {
          splits = (sg['members'] as List).map((m) {
            return MemberSplit(
              id:
                  m['member_id']?.toString() ??
                  m['id']?.toString() ??
                  m['phone_number']?.toString() ??
                  '',
              name: m['name']?.toString() ?? 'Unknown',
              amount: (m['expense_amount'] ?? 0.0).toDouble(),
              isPaid: m['is_paid'] ?? false,
            );
          }).toList();
        }

        return ExpenseModel(
          id: sg['id']?.toString() ?? sg['sub_group_id']?.toString() ?? '',
          title: sgName,
          amount: sgAmount,
          paidById: sg['created_by']?.toString() ?? 'unknown',
          date: sg['created_at'] != null
              ? DateTime.tryParse(sg['created_at'].toString()) ?? DateTime.now()
              : DateTime.now(),
          splits: splits,
          splitType: sgSplitType,
          memberCount:
              (sg['total_member'] ?? sg['member_count'] ?? splits.length)
                  as int,
          mainGroupName: sg['main_group_name']?.toString(),
        );
      }).toList();
    }

    return GroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed',
      description: json['description']?.toString() ?? '',
      parentId: json['parent_id']?.toString(),
      customImageUrl: json['custom_image_url']?.toString(),
      groupPhotoUrl: json['group_photo_url']?.toString(),
      groupPhotoBase64: json['group_photo_base64']?.toString(),
      groupPhotoDeleteUrl: json['group_photo_delete_url']?.toString(),
      creatorId: json['created_by']?.toString() ?? '',
      createdDate: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      members: parsedMembers,
      splitType: json['type'] ?? json['split_type'] ?? 'solo',
      expenses: parsedExpenses,
      memberCount:
          json['total_member'] ?? json['member_count'] ?? parsedMembers.length,
      subGroupCount: json['sub_group_count'] ?? parsedExpenses.length,
      totalExpense: (json['total_amount'] ?? json['total_expense'] ?? 0.0)
          .toDouble(),
      totalSubExpense: (json['total_sub_expense'] ?? 0.0).toDouble(),
      isShared:
          (json['group_type'] == 'shared') || (json['is_shared'] ?? false),
    );
  }

  double get totalAmount => expenses.fold(0, (sum, e) => sum + e.amount);

  double get paidAmount =>
      members.where((m) => m.isPaid).fold(0, (sum, m) => sum + m.amountOwed);

  double get displayTotal {
    if (totalSubExpense > 0) return totalSubExpense;
    final calculated = totalAmount;
    return calculated > 0 ? calculated : totalExpense;
  }

  double get progressPercent =>
      displayTotal > 0 ? (paidAmount / displayTotal).clamp(0, 1) : 0;

  int get paidCount => members.where((m) => m.isPaid).length;

  String? get bestPhoto =>
      (customImageUrl != null && customImageUrl!.isNotEmpty)
      ? customImageUrl
      : (groupPhotoUrl != null && groupPhotoUrl!.isNotEmpty)
      ? groupPhotoUrl
      : (groupPhotoBase64 != null && groupPhotoBase64!.isNotEmpty)
      ? groupPhotoBase64
      : null;
}

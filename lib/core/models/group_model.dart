import 'package:splitease_test/core/models/member_model.dart';
import 'package:splitease_test/core/models/message_model.dart';
import 'package:splitease_test/core/models/expense_model.dart';

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? parentId;
  String? customImageUrl;
  final String creatorId;
  final DateTime createdDate;
  final List<MemberModel> members;
  final List<ExpenseModel> expenses;
  final List<MessageModel> messages;
  final int memberCount;
  final int subGroupCount;
  final double totalExpense;
  final double totalSubExpense;

  GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.parentId,
    this.customImageUrl,
    required this.creatorId,
    required this.createdDate,
    required this.members,
    this.expenses = const [],
    this.messages = const [],
    this.memberCount = 0,
    this.subGroupCount = 0,
    this.totalExpense = 0.0,
    this.totalSubExpense = 0.0,
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

        // Members list can now be in 'transactions' or 'members'
        List<MemberSplit> splits = [];
        if (sg['transactions'] != null && sg['transactions'] is List) {
          splits = (sg['transactions'] as List).map((tx) {
            return MemberSplit(
              id: tx['id']?.toString() ?? tx['from']?.toString() ?? '',
              name:
                  tx['from_name']?.toString() ??
                  tx['from']?.toString() ??
                  'Unknown',
              amount: (tx['amount'] ?? 0.0).toDouble(),
              isPaid: tx['is_paid'] ?? false,
            );
          }).toList();
        } else if (sg['members'] != null &&
            sg['members'] is List &&
            sg['members'].first is Map) {
          splits = (sg['members'] as List).map((m) {
            return MemberSplit(
              id: m['id']?.toString() ?? '',
              name: m['name']?.toString() ?? 'Unknown',
              amount: (m['expense_amount'] ?? 0.0).toDouble(),
              isPaid: m['is_paid'] ?? false,
            );
          }).toList();
        }

        return ExpenseModel(
          id: sg['id']?.toString() ?? '',
          title: sgName,
          amount: sgAmount,
          paidById: sg['created_by']?.toString() ?? 'unknown',
          date: sg['created_at'] != null
              ? DateTime.tryParse(sg['created_at']) ?? DateTime.now()
              : DateTime.now(),
          splits: splits,
        );
      }).toList();
    }

    return GroupModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unnamed',
      description: json['description'] ?? '',
      parentId: json['parent_id'],
      customImageUrl: json['custom_image_url'],
      creatorId: json['created_by'] ?? '',
      createdDate: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      members: parsedMembers,
      expenses: parsedExpenses,
      memberCount: json['member_count'] ?? parsedMembers.length,
      subGroupCount: json['sub_group_count'] ?? parsedExpenses.length,
      totalExpense: (json['total_expense'] ?? 0.0) is int
          ? (json['total_expense'] as int).toDouble()
          : (json['total_expense'] ?? 0.0).toDouble(),
      totalSubExpense: (json['total_sub_expense'] ?? 0.0) is int
          ? (json['total_sub_expense'] as int).toDouble()
          : (json['total_sub_expense'] ?? 0.0).toDouble(),
    );
  }

  double get totalAmount => expenses.fold(0, (sum, e) => sum + e.amount);

  double get paidAmount =>
      members.where((m) => m.isPaid).fold(0, (sum, m) => sum + m.amountOwed);

  double get displayTotal =>
      totalSubExpense > 0 ? totalSubExpense : totalAmount;

  double get progressPercent =>
      displayTotal > 0 ? (paidAmount / displayTotal).clamp(0, 1) : 0;

  int get paidCount => members.where((m) => m.isPaid).length;
}

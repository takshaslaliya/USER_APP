
class PersonalExpense {
  final String id;
  final String? userId;
  final String name;
  final double amount;
  final String category;
  final DateTime date;
  final bool isSpent;
  final bool isPaid;
  final String? description;
  final DateTime? createdAt;

  PersonalExpense({
    required this.id,
    this.userId,
    required this.name,
    required this.amount,
    required this.category,
    required this.date,
    required this.isSpent,
    required this.isPaid,
    this.description,
    this.createdAt,
  });

  factory PersonalExpense.fromJson(Map<String, dynamic> json) {
    return PersonalExpense(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      name: json['name']?.toString() ?? 'Unnamed',
      amount: (json['amount'] ?? 0.0).toDouble(),
      category: json['category']?.toString() ?? 'General',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      isSpent: json['is_spent'] == true || json['is_spent'] == 1,
      isPaid: json['is_paid'] == true || json['is_paid'] == 1,
      description: json['description']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'is_spent': isSpent,
      'is_paid': isPaid,
      'description': description,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

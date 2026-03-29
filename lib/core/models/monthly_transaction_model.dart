class MonthlyTransaction {
  final String id;
  final String name;
  final double amount;
  final String type; // Sent, Received, Self
  final DateTime date;
  final String groupId;
  final bool isPaid;
  final String otherParty;

  MonthlyTransaction({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.date,
    required this.groupId,
    required this.isPaid,
    required this.otherParty,
  });

  factory MonthlyTransaction.fromJson(Map<String, dynamic> json) {
    return MonthlyTransaction(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      type: json['type'] ?? 'Sent',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      groupId: json['group_id'] ?? '',
      isPaid: json['is_paid'] == true,
      otherParty: json['other_party'] ?? 'Outside',
    );
  }
}

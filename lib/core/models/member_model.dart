class MemberModel {
  final String id;
  final String name;
  final String avatarInitials;
  final double amountOwed;
  final bool isPaid;

  const MemberModel({
    required this.id,
    required this.name,
    required this.avatarInitials,
    required this.amountOwed,
    required this.isPaid,
  });
}

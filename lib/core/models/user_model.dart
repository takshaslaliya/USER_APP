enum UserRole { admin, user }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String avatarInitials;
  final DateTime joinDate;
  final int totalSplits;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarInitials,
    required this.joinDate,
    required this.totalSplits,
  });

  bool get isAdmin => role == UserRole.admin;
}

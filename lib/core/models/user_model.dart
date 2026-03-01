enum UserRole { admin, user }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String avatarInitials;
  final DateTime joinDate;
  final int totalSplits;

  final String password;
  final bool isActive;
  final bool isUsingWhatsApp;
  final String phoneNumber;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarInitials,
    required this.joinDate,
    required this.totalSplits,
    this.password = 'password123',
    this.isActive = true,
    this.isUsingWhatsApp = false,
    this.phoneNumber = '+91 98765 43210',
  });

  bool get isAdmin => role == UserRole.admin;
}

class UserModel {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String mobileNumber;
  final String? upiId;
  final bool emailVerified;
  final String role;
  final DateTime? createdAt;

  // Optional fields for compatibility/extended info
  final int totalSplits;
  final bool isActive;
  final bool isUsingWhatsApp;
  final bool whatsappConnected;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.mobileNumber,
    this.upiId,
    required this.emailVerified,
    required this.role,
    this.createdAt,
    this.totalSplits = 0,
    this.isActive = true,
    this.isUsingWhatsApp = false,
    this.whatsappConnected = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
      upiId: json['upi_id'],
      emailVerified: json['email_verified'] ?? false,
      role: json['role'] ?? 'user',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      totalSplits: json['total_splits'] ?? 0,
      isActive: json['is_active'] ?? true,
      isUsingWhatsApp: json['is_using_whatsapp'] ?? false,
      whatsappConnected: json['whatsapp_connected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'upi_id': upiId,
      'email_verified': emailVerified,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
      'total_splits': totalSplits,
      'is_active': isActive,
      'is_using_whatsapp': isUsingWhatsApp,
      'whatsapp_connected': whatsappConnected,
    };
  }

  String get initials {
    if (fullName.isEmpty) return 'U';
    final parts = fullName.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // Compatibility getters for legacy code
  String get name => fullName;
  bool get isAdmin => role == 'admin';
  String get avatarInitials => initials;
  DateTime get joinDate => createdAt ?? DateTime.now();
  String get password => 'password123';
}

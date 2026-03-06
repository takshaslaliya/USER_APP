import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:splitease_test/core/config/app_config.dart';
import 'package:splitease_test/core/services/auth_service.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String userName;
  final String title;
  final String message;
  final bool isRead;
  final String status;
  final DateTime? scheduledAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.message,
    required this.isRead,
    this.status = 'sent',
    this.scheduledAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'User',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      isRead: json['is_read'] == true || json['is_read'] == 1,
      status: json['status']?.toString() ?? 'sent',
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'].toString())
          : null,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class NotificationService {
  static Future<List<NotificationModel>> fetchNotifications() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      // Changed to user-specific notifications endpoint
      final uri = Uri.parse('${AppConfig.userUrl}/notifications');

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          return (decoded['data'] as List)
              .map((item) => NotificationModel.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('NotificationService Error: $e');
      return [];
    }
  }

  static Future<bool> markAsRead(String id) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.userUrl}/notifications/$id/read');

      final response = await http
          .put(uri, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('NotificationService MarkRead Error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Admin Endpoints
  // ─────────────────────────────────────────────────────────────────────────

  static Future<bool> sendAdminNotification({
    required List<String> userIds,
    required String title,
    required String message,
    DateTime? scheduledAt,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.adminUrl}/notifications');

      final body = {
        'user_ids': userIds,
        'title': title,
        'message': message,
        if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('NotificationService SendAdmin Error: $e');
      return false;
    }
  }

  static Future<List<NotificationModel>> fetchAllNotifications() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.adminUrl}/notifications');

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          return (decoded['data'] as List)
              .map((item) => NotificationModel.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('NotificationService FetchAll Error: $e');
      return [];
    }
  }

  static Future<List<NotificationModel>> fetchUserNotificationHistory(
    String userId,
  ) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.adminUrl}/notifications/user/$userId');

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          return (decoded['data'] as List)
              .map((item) => NotificationModel.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('NotificationService FetchUserHistory Error: $e');
      return [];
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:splitease_test/core/config/app_config.dart';
import 'package:splitease_test/core/services/auth_service.dart';

class DashboardData {
  final Map<String, dynamic> user;
  final double moneyToSend;
  final double moneyToReceive;
  final List<dynamic> recentGroups;

  DashboardData({
    required this.user,
    required this.moneyToSend,
    required this.moneyToReceive,
    required this.recentGroups,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return DashboardData(
      user: data['user'] as Map<String, dynamic>? ?? {},
      moneyToSend: (data['money_to_send'] as num?)?.toDouble() ?? 0.0,
      moneyToReceive: (data['money_to_receive'] as num?)?.toDouble() ?? 0.0,
      recentGroups: data['recent_groups'] as List<dynamic>? ?? [],
    );
  }
}

class DashboardResult {
  final bool success;
  final String message;
  final DashboardData? data;

  DashboardResult({required this.success, required this.message, this.data});
}

class DashboardService {
  static Future<DashboardResult> fetchDashboard() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.userUrl}/dashboard');
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      print('DashboardService: GET $uri -> ${response.statusCode}');

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (decoded['success'] == true) {
        return DashboardResult(
          success: true,
          message: decoded['message'] ?? 'Success',
          data: DashboardData.fromJson(decoded),
        );
      } else {
        return DashboardResult(
          success: false,
          message: decoded['message'] ?? 'Failed to load dashboard',
        );
      }
    } catch (e) {
      print('DashboardService Error: $e');
      return DashboardResult(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }
}

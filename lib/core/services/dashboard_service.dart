import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

    // Support multiple field names from backend to ensure data shows up correctly
    final send =
        data['money_to_send'] ??
        data['money_to_pay'] ??
        data['total_owe'] ??
        0.0;
    final receive =
        data['money_to_receive'] ??
        data['money_to_get'] ??
        data['total_gain'] ??
        0.0;

    return DashboardData(
      user: data['user'] as Map<String, dynamic>? ?? {},
      moneyToSend: (send is num)
          ? send.toDouble()
          : double.tryParse(send.toString()) ?? 0.0,
      moneyToReceive: (receive is num)
          ? receive.toDouble()
          : double.tryParse(receive.toString()) ?? 0.0,
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
          .timeout(const Duration(seconds: 30));

      debugPrint('DashboardService: GET $uri -> ${response.statusCode}');

      if (response.body.isEmpty) {
        return DashboardResult(
          success: false,
          message: 'Server returned an empty response',
        );
      }

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
    } on SocketException {
      return DashboardResult(success: false, message: 'No internet connection');
    } on TimeoutException {
      return DashboardResult(success: false, message: 'Request timed out');
    } catch (e) {
      debugPrint('DashboardService Error: $e');
      return DashboardResult(
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }
}

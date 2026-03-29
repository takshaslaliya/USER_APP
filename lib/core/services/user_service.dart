import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:splitease_test/core/config/app_config.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/core/models/monthly_stats_model.dart';
import 'package:splitease_test/core/models/monthly_transaction_model.dart';
import 'package:splitease_test/core/models/personal_expense_model.dart';

class UserResult {
  final bool success;
  final String message;
  final dynamic data;

  UserResult({required this.success, required this.message, this.data});
}

class UserService {
  // ── Monthly Statistics API ─────────────────────────────────────
  static Future<List<MonthlyStats>> fetchMonthlyStats() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.userUrl}/monthly-stats');
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 60));

      debugPrint('UserService: GET $uri -> ${response.statusCode}');

      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          final List<dynamic> data = decoded['data'];
          return data.map((item) => MonthlyStats.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('UserService: Error fetching stats: $e');
      return [];
    }
  }

  // ── Monthly Transactions API (Detail List) ──────────────────────
  static Future<List<MonthlyTransaction>> fetchMonthlyTransactions(String month) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.userUrl}/monthly-stats/$month');
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 60));

      debugPrint('UserService: GET $uri -> ${response.statusCode}');

      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          final List<dynamic> data = decoded['data'];
          return data.map((item) => MonthlyTransaction.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('UserService: Error fetching monthly transactions: $e');
      return [];
    }
  }

  // ── Add Personal Expense API ───────────────────────────────────
  static Future<UserResult> addPersonalExpense({
    required String name,
    required double amount,
    String? type,
    String? category,
    String? description,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.userUrl}/personal-expense');
      final body = jsonEncode({
        'name': name,
        'amount': amount,
        if (type != null) 'type': type,
        if (category != null) 'category': category,
        if (description != null) 'description': description,
      });

      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 60));

      debugPrint('UserService: POST $uri -> ${response.statusCode}');

      if (response.body.isEmpty) {
        return UserResult(success: false, message: 'Empty response from server');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      return UserResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? (decoded['success'] == true ? 'Success' : 'Failed'),
        data: decoded['data'],
      );
    } catch (e) {
      debugPrint('UserService: Error adding expense: $e');
      return UserResult(success: false, message: 'Network error. Please try again.');
    }
  }

  // ── List All Personal Expenses (GET /api/user/personal-expenses) ──
  static Future<List<PersonalExpense>> fetchPersonalExpenses() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.userUrl}/personal-expenses');
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 60));

      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final List<dynamic> data = decoded['data'];
          return data.map((item) => PersonalExpense.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('UserService: Error fetching personal expenses: $e');
      return [];
    }
  }

  // ── Update Status (PUT /api/user/personal-expense/:id) ────────────
  static Future<UserResult> updatePersonalExpenseStatus(
    String id,
    bool isPaid,
  ) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.userUrl}/personal-expense/$id');
      final body = jsonEncode({'is_paid': isPaid});

      final response = await http
          .put(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 60));

      final decoded = jsonDecode(response.body);
      return UserResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? 'Status updated',
        data: decoded['data'],
      );
    } catch (e) {
      debugPrint('UserService: Error updating personal expense status: $e');
      return UserResult(success: false, message: 'Network error');
    }
  }

  // ── Update Full Expense (PUT /api/user/personal-expense/:id) ─────
  static Future<UserResult> updatePersonalExpense({
    required String id,
    String? name,
    double? amount,
    String? type,
    String? category,
    String? description,
    bool? isPaid,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.userUrl}/personal-expense/$id');
      final body = jsonEncode({
        if (name != null) 'name': name,
        if (amount != null) 'amount': amount,
        if (type != null) 'type': type,
        if (category != null) 'category': category,
        if (description != null) 'description': description,
        if (isPaid != null) 'is_paid': isPaid,
      });

      final response = await http
          .put(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 60));

      final decoded = jsonDecode(response.body);
      return UserResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? 'Expense updated',
        data: decoded['data'],
      );
    } catch (e) {
      debugPrint('UserService: Error updating personal expense: $e');
      return UserResult(success: false, message: 'Network error');
    }
  }

  // ── Delete Expense (DELETE /api/user/personal-expense/:id) ────────
  static Future<UserResult> deletePersonalExpense(String id) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.userUrl}/personal-expense/$id');

      final response = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 60));

      final decoded = jsonDecode(response.body);
      return UserResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? 'Expense deleted',
      );
    } catch (e) {
      debugPrint('UserService: Error deleting personal expense: $e');
      return UserResult(success: false, message: 'Network error');
    }
  }
}

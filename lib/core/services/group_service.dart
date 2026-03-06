import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:splitease_test/core/config/app_config.dart';
import 'package:splitease_test/core/services/auth_service.dart';

class GroupResult {
  final bool success;
  final String message;
  final dynamic data;
  final int? statusCode;

  GroupResult({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });
}

class GroupService {
  static String get _baseUrl => AppConfig.groupsUrl;

  static Future<GroupResult> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      // Add method override for better compatibility with restricted servers
      headers['X-HTTP-Method-Override'] = method;
      http.Response response;
      final uri = Uri.parse('$_baseUrl$path');

      switch (method) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        case 'POST':
          debugPrint('GroupService POST $uri Body: ${jsonEncode(body)}');
          response = await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 15));
          break;
        case 'PUT':
          debugPrint('GroupService PUT $uri Body: ${jsonEncode(body)}');
          response = await http
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        default:
          throw Exception('Unsupported HTTP method $method');
      }

      debugPrint('GroupService: $method $uri -> ${response.statusCode}');

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return GroupResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? '',
        data: decoded['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('GroupService Error: $e');
      return GroupResult(
        success: false,
        message: 'Network error ($e). Please check your connection.',
        statusCode: 0,
      );
    }
  }

  // 1. Create Main Group
  static Future<GroupResult> createGroup(
    String name,
    String description,
  ) async {
    return _request(
      'POST',
      '',
      body: {'name': name, 'description': description},
    );
  }

  // 2. Create Sub-Group with Expense + Members
  static Future<GroupResult> createSubGroup(
    String groupId,
    String name,
    String description,
    double totalExpense,
    List<Map<String, dynamic>> members,
  ) async {
    return _request(
      'POST',
      '/$groupId/sub-groups',
      body: {
        'name': name,
        'description': description,
        'total_expense': totalExpense,
        'members': members,
      },
    );
  }

  // 2b. Calculate Optimal Split (For multiple payers)
  static Future<GroupResult> calculateOptimalSplit({
    required double totalAmount,
    required List<String> members,
    required Map<String, double> payments,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.splitUrl}/calculate-split');
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'total_amount': totalAmount,
              'members': members,
              'payments': payments,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return GroupResult(
          success: true,
          message: 'Split calculated successfully',
          data: decoded,
          statusCode: response.statusCode,
        );
      } else {
        return GroupResult(
          success: false,
          message: decoded['message'] ?? 'Failed to calculate split',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return GroupResult(
        success: false,
        message: 'Network error. Please try again.',
        statusCode: 0,
      );
    }
  }

  // 2c. Finalize Split and Save Expense
  static Future<GroupResult> updateSplit({
    required double totalAmount,
    required List<String> members,
    required Map<String, double> payments,
    required List<dynamic> transactions,
    required String groupId,
    required String expenseName,
    required String splitType,
    Map<String, String>? upiIds,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.splitUrl}/update-split');
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'total_amount': totalAmount,
              'members': members,
              'payments': payments,
              'transactions': transactions,
              'group_id': groupId,
              'expense_name': expenseName,
              'split_type': splitType,
              'upi_ids': ?upiIds,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return GroupResult(
          success: decoded['success'] == true,
          message: decoded['message'] ?? 'Expense saved successfully',
          data: decoded,
          statusCode: response.statusCode,
        );
      } else {
        return GroupResult(
          success: false,
          message: decoded['message'] ?? 'Failed to save expense',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return GroupResult(
        success: false,
        message: 'Network error: $e',
        statusCode: 0,
      );
    }
  }

  // 2d. Get Split Details (Consolidated)
  static Future<GroupResult> fetchSplitDetails(String splitId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.splitUrl}/$splitId');
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      return GroupResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? '',
        data: decoded['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return GroupResult(success: false, message: 'Network error: $e');
    }
  }

  // 2e. Update Transaction status/amount
  static Future<GroupResult> updateSplitTransaction(
    String memberId, {
    double? amount,
    bool? isPaid,
    String? name,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.splitUrl}/transaction/$memberId');
      final response = await http
          .put(
            uri,
            headers: headers,
            body: jsonEncode({
              'expense_amount': ?amount,
              'is_paid': ?isPaid,
              'name': ?name,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      return GroupResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? '',
        data: decoded,
        statusCode: response.statusCode,
      );
    } catch (e) {
      return GroupResult(success: false, message: 'Network error: $e');
    }
  }

  // 2f. Delete Consolidated Split
  static Future<GroupResult> deleteSplit(String splitId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse('${AppConfig.splitUrl}/$splitId');
      final response = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      return GroupResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? '',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return GroupResult(success: false, message: 'Network error: $e');
    }
  }

  // 3. Get All Top-Level Groups (Created by User)
  static Future<GroupResult> fetchGroups() async {
    return _request('GET', '');
  }

  // 3b. Get All Shared Groups (User is a member)
  static Future<GroupResult> fetchSharedGroups() async {
    return _request('GET', '/shared');
  }

  // 4. Get Group Details
  static Future<GroupResult> fetchGroupDetails(String groupId) async {
    return _request('GET', '/$groupId');
  }

  // 5. Update Group
  static Future<GroupResult> updateGroup(
    String groupId, {
    String? name,
    File? photo,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return GroupResult(success: false, message: 'Not logged in');
      }

      final uri = Uri.parse('$_baseUrl/$groupId');
      final request = http.MultipartRequest('PUT', uri);

      request.headers['Authorization'] = 'Bearer $token';

      if (name != null) {
        request.fields['name'] = name;
      }

      if (photo != null) {
        final photoPart = await http.MultipartFile.fromPath(
          'photo',
          photo.path,
        );
        request.files.add(photoPart);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      return GroupResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? '',
        data: decoded['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('GroupService updateGroup Error: $e');
      return GroupResult(
        success: false,
        message: 'Network error ($e). Please check your connection.',
        statusCode: 0,
      );
    }
  }

  // 6. Delete Group
  static Future<GroupResult> deleteGroup(String groupId) async {
    return _request('DELETE', '/$groupId');
  }

  // 7. Add Member
  static Future<GroupResult> addMember(
    String groupId,
    String name,
    String phoneNumber,
    double expenseAmount, {
    String? upiId,
  }) async {
    final body = {
      'name': name,
      'phone_number': phoneNumber,
      'expense_amount': expenseAmount,
      if (upiId != null && upiId.isNotEmpty) 'upi_id': upiId,
    };
    return _request('POST', '/$groupId/members', body: body);
  }

  // 8. Edit Member Expense (NEW)
  static Future<GroupResult> updateMemberExpense(
    String groupId,
    String memberId,
    String? name,
    double? expenseAmount,
  ) async {
    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (expenseAmount != null) body['expense_amount'] = expenseAmount;

    return _request('PUT', '/$groupId/members/$memberId', body: body);
  }

  // 9. Remove Member
  static Future<GroupResult> removeMember(
    String groupId,
    String memberId,
  ) async {
    return _request('DELETE', '/$groupId/members/$memberId');
  }

  // 10. Delete Sub-Group (Expense Group)
  static Future<GroupResult> deleteSubGroup(String subGroupId) async {
    return _request('DELETE', '/sub-groups/$subGroupId');
  }

  // 11. Toggle Member Paid Status (NEW)
  static Future<GroupResult> toggleMemberPaidStatus(
    String subGroupId,
    String memberId,
    bool isPaid,
  ) async {
    return _request(
      'PUT',
      '/sub-groups/$subGroupId/members/$memberId/status',
      body: {'is_paid': isPaid},
    );
  }

  // 12. Fetch Personal Settlements (NEW)
  static Future<GroupResult> fetchSettlements() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final uri = Uri.parse(AppConfig.settlementUrl);
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      return GroupResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? '',
        data: decoded['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return GroupResult(success: false, message: 'Network error: $e');
    }
  }
}

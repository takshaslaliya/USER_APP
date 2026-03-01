import 'dart:convert';
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
      http.Response response;
      final uri = Uri.parse('$_baseUrl$path');

      switch (method) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 15));
          break;
        case 'PUT':
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

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return GroupResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? '',
        data: decoded['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return GroupResult(
        success: false,
        message: 'Network error. Please try again.',
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

  // 3. Get All Top-Level Groups
  static Future<GroupResult> fetchGroups() async {
    return _request('GET', '');
  }

  // 4. Get Group Details
  static Future<GroupResult> fetchGroupDetails(String groupId) async {
    return _request('GET', '/$groupId');
  }

  // 5. Update Group
  static Future<GroupResult> updateGroup(
    String groupId,
    String? name,
    double? totalExpense,
    String? customImageUrl,
  ) async {
    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (totalExpense != null) body['total_expense'] = totalExpense;
    if (customImageUrl != null) body['custom_image_url'] = customImageUrl;

    return _request('PUT', '/$groupId', body: body);
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
    double expenseAmount,
  ) async {
    return _request(
      'POST',
      '/$groupId/members',
      body: {
        'name': name,
        'phone_number': phoneNumber,
        'expense_amount': expenseAmount,
      },
    );
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
  static Future<GroupResult> deleteSubGroup(
    String groupId,
    String subGroupId,
  ) async {
    return _request('DELETE', '/$groupId/sub-groups/$subGroupId');
  }
}

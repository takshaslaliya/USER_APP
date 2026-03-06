import 'dart:io';
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
          print('GroupService POST $uri Body: ${jsonEncode(body)}');
          response = await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 15));
          break;
        case 'PUT':
          print('GroupService PUT $uri Body: ${jsonEncode(body)}');
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

      print('GroupService: $method $uri -> ${response.statusCode}');

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return GroupResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? '',
        data: decoded['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      print('GroupService Error: $e');
      return GroupResult(
        success: false,
        message: 'Network error ($e). Please check your connection.',
        statusCode: 0,
      );
    }
  }

  static Future<GroupResult> _multipartRequest(
    String method,
    String path, {
    Map<String, String>? fields,
    String? filePath,
    String fileField = 'custom_image_url',
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      // Remove Content-Type to let http package set it with boundary
      headers.remove('Content-Type');

      final uri = Uri.parse('$_baseUrl$path');
      final request = http.MultipartRequest(method, uri);
      request.headers.addAll(headers);

      if (fields != null) {
        request.fields.addAll(fields);
      }

      if (filePath != null && filePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(fileField, filePath),
        );
      }

      print('GroupService Multipart: $method $uri');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('GroupService Multipart Result: ${response.statusCode}');

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return GroupResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? '',
        data: decoded['data'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      print('GroupService Multipart Error: $e');
      return GroupResult(
        success: false,
        message: 'Upload error ($e). Please try again.',
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
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/split/calculate-split');
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
    String groupId,
    String? name,
    double? totalExpense,
    String? customImageUrl,
  ) async {
    // Check if customImageUrl is a local file path
    bool isFile =
        customImageUrl != null &&
        (customImageUrl.startsWith('/') ||
            customImageUrl.contains('cache') ||
            customImageUrl.contains('picker'));

    if (isFile) {
      try {
        // Fallback approach: Try sending as Base64 in JSON first because some proxies reject PUT Multipart
        final cleanPath = customImageUrl.replaceFirst('file://', '');
        final file = File(cleanPath);
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);
        final String ext = customImageUrl.split('.').last.toLowerCase();
        final String mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        final String dataUri = 'data:$mimeType;base64,$base64Image';

        final Map<String, dynamic> body = {
          'name': name ?? 'Updated Group',
          'custom_image_url': dataUri,
        };
        // Also send total_expense as number
        if (totalExpense != null) body['total_expense'] = totalExpense;

        // EXPERIMENT: Some Appwrite proxies expect data nested in 'data' field
        final Map<String, dynamic> wrappedBody = {
          ...body,
          'data': body, // try both top-level and nested to be sure
        };

        print('GroupService: Attempting Base64 Upload for icon');
        return _request('PUT', '/$groupId', body: wrappedBody);
      } catch (e) {
        print(
          'GroupService: Base64 encoding failed, falling back to multipart',
        );
        // fallthrough to multipart if base64 fails
      }

      final Map<String, String> fields = {'name': name ?? 'Group'};
      if (totalExpense != null)
        fields['total_expense'] = totalExpense.toString();

      return _multipartRequest(
        'PUT',
        '/$groupId',
        fields: {
          ...fields,
          'data': jsonEncode(
            fields,
          ), // try sending JSON serialized version in a field too
        },
        filePath: customImageUrl,
        fileField: 'custom_image_url',
      );
    } else {
      final Map<String, dynamic> body = {};
      if (name != null) body['name'] = name;
      if (totalExpense != null) body['total_expense'] = totalExpense;
      if (customImageUrl != null) body['custom_image_url'] = customImageUrl;

      final Map<String, dynamic> wrappedBody = {...body, 'data': body};

      return _request('PUT', '/$groupId', body: wrappedBody);
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
}

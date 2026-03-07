import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:splitease_test/core/config/app_config.dart';
import 'package:splitease_test/core/services/auth_service.dart';

class WhatsAppResult {
  final bool success;
  final String message;
  final dynamic data;

  WhatsAppResult({required this.success, required this.message, this.data});
}

class WhatsAppService {
  static Future<WhatsAppResult> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final url = Uri.parse('${AppConfig.whatsappUrl}$path');

      http.Response response;
      final timeout = const Duration(seconds: 30);

      if (method == 'POST') {
        response = await http
            .post(url, headers: headers, body: jsonEncode(body))
            .timeout(timeout);
      } else if (method == 'GET') {
        response = await http.get(url, headers: headers).timeout(timeout);
      } else {
        throw Exception('Unsupported method');
      }

      if (response.body.isEmpty) {
        return WhatsAppResult(
          success: false,
          message: 'Empty response from server',
        );
      }

      try {
        final decoded = jsonDecode(response.body);
        return WhatsAppResult(
          success: decoded['success'] ?? false,
          message:
              decoded['message'] ??
              (decoded['success'] == true ? 'Success' : 'Failed'),
          data: decoded['data'],
        );
      } on FormatException {
        return WhatsAppResult(
          success: false,
          message: 'Invalid response from server',
        );
      }
    } on SocketException {
      return WhatsAppResult(success: false, message: 'No internet connection');
    } on TimeoutException {
      return WhatsAppResult(success: false, message: 'Request timed out');
    } catch (e) {
      return WhatsAppResult(success: false, message: 'Network error: $e');
    }
  }

  /// 1. Connect WhatsApp (type: 'otp' or 'qr')
  static Future<WhatsAppResult> connect({
    required String phoneNumber,
    required String type,
  }) async {
    return _request(
      'POST',
      '/connect',
      body: {'phone_number': phoneNumber, 'type': type},
    );
  }

  /// 2. Check connection status
  static Future<WhatsAppResult> getStatus() async {
    return _request('GET', '/status');
  }

  /// 3. Disconnect WhatsApp
  static Future<WhatsAppResult> disconnect() async {
    return _request('POST', '/disconnect');
  }

  /// 4. Send bulk payment requests
  static Future<WhatsAppResult> sendPayment({
    required List<Map<String, dynamic>> requests,
    required String message,
  }) async {
    return _request(
      'POST',
      '/send-payment',
      body: {'requests': requests, 'message': message},
    );
  }

  /// 5. Send group reminder for consolidated split
  static Future<WhatsAppResult> remindGroup(String groupId) async {
    return _request('POST', '/remind-group', body: {'group_id': groupId});
  }
}

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitease_test/core/config/app_config.dart';

/// Centralised result type so callers don't need to deal with exceptions.
class AuthResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final int? statusCode;

  AuthResult({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });
}

class AuthService {
  static String get _baseUrl => AppConfig.authUrl;
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  // ─────────────────────────────────────────────────────────────────────────
  // Token / session helpers
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> saveSession(
    String token,
    Map<String, dynamic> user,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API helpers
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  /// Headers including the stored Bearer token — use for authenticated calls.
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));

      debugPrint('AuthService: POST $uri -> ${response.statusCode}');

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message':
              'Server returned an empty response (Status: ${response.statusCode})',
          '_statusCode': response.statusCode,
        };
      }

      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        decoded['_statusCode'] = response.statusCode;
        return decoded;
      } on FormatException {
        debugPrint('AuthService Error: Invalid JSON -> ${response.body}');
        return {
          'success': false,
          'message':
              'Server provided an invalid response. Please try again later.',
          '_statusCode': response.statusCode,
        };
      }
    } on SocketException catch (e) {
      debugPrint('AuthService SocketException: $e');
      return {
        'success': false,
        'message':
            'No internet connection or server unreachable. Please check your network.',
        '_statusCode': 0,
      };
    } on http.ClientException catch (e) {
      debugPrint('AuthService ClientException: $e');
      return {
        'success': false,
        'message': 'Network error. Please try again.',
        '_statusCode': 0,
      };
    } on TimeoutException {
      debugPrint('AuthService Timeout: $uri');
      return {
        'success': false,
        'message':
            'Connection timed out. The server is taking too long to respond.',
        '_statusCode': 408,
      };
    } catch (e) {
      debugPrint('AuthService Error: POST $uri -> $e');
      return {
        'success': false,
        'message': 'Something went wrong. Please try again.',
        '_statusCode': 0,
      };
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Sign Up  — POST /api/auth/signup
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> signup({
    required String mobileNumber,
    required String email,
    required String username,
    required String fullName,
    required String password,
  }) async {
    final res = await _post('/signup', {
      'mobile_number': mobileNumber,
      'email': email,
      'username': username,
      'full_name': fullName,
      'password': password,
    });
    return AuthResult(
      success: res['success'] == true,
      message: res['message'] ?? 'Unknown error',
      data: res['data'] as Map<String, dynamic>?,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Verify OTP after signup  — POST /api/auth/verify-otp
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> verifySignupOtp({
    required String email,
    required String otp,
  }) async {
    final res = await _post('/verify-otp', {'email': email, 'otp': otp});
    return AuthResult(
      success: res['success'] == true,
      message: res['message'] ?? 'Unknown error',
      data: res['data'] as Map<String, dynamic>?,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Resend signup OTP  — POST /api/auth/resend-otp
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> resendSignupOtp({required String email}) async {
    final res = await _post('/resend-otp', {'email': email});
    return AuthResult(
      success: res['success'] == true,
      message: res['message'] ?? 'Unknown error',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Login with email/mobile + password  — POST /api/auth/login
  //    Saves token on success.
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> loginWithPassword({
    required String emailOrMobile,
    required String password,
  }) async {
    final res = await _post('/login', {
      'email_or_mobile': emailOrMobile,
      'password': password,
    });

    final data = res['data'] as Map<String, dynamic>?;
    if (res['success'] == true && data != null) {
      final token = data['token'] as String? ?? '';
      final user = data['user'] as Map<String, dynamic>? ?? {};
      await saveSession(token, user);
    }

    return AuthResult(
      success: res['success'] == true,
      message: res['message'] ?? 'Unknown error',
      data: data,
      statusCode: res['_statusCode'] as int?,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Request login OTP (email)  — POST /api/auth/login-otp-request
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> requestLoginOtp({required String email}) async {
    final res = await _post('/login-otp-request', {'email': email});
    return AuthResult(
      success: res['success'] == true,
      message: res['message'] ?? 'Unknown error',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Verify login OTP  — POST /api/auth/login-otp-verify
  //    Saves token on success.
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> verifyLoginOtp({
    required String email,
    required String otp,
  }) async {
    final res = await _post('/login-otp-verify', {'email': email, 'otp': otp});

    final data = res['data'] as Map<String, dynamic>?;
    if (res['success'] == true && data != null) {
      final token = data['token'] as String? ?? '';
      final user = data['user'] as Map<String, dynamic>? ?? {};
      await saveSession(token, user);
    }

    return AuthResult(
      success: res['success'] == true,
      message: res['message'] ?? 'Unknown error',
      data: data,
      statusCode: res['_statusCode'] as int?,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Logout — clears local session
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    await clearSession();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 7. Get user profile — GET /api/user/profile
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> getProfile() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http
          .get(Uri.parse('${AppConfig.userUrl}/profile'), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.body.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Server returned an empty response',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      Map<String, dynamic>? finalUserData =
          decoded['data'] as Map<String, dynamic>?;

      if (response.statusCode == 200 &&
          decoded['success'] == true &&
          finalUserData != null) {
        // Merge with current local data to avoid losing fields not returned by API
        final currentUser = await getUser();
        final currentToken = await getToken();
        if (currentUser != null && currentToken != null) {
          finalUserData = {...currentUser, ...finalUserData};
          await saveSession(currentToken, finalUserData);
        } else if (currentToken != null) {
          await saveSession(currentToken, finalUserData);
        }
      }

      return AuthResult(
        success: decoded['success'] == true,
        message:
            decoded['message'] ??
            (decoded['success'] == true
                ? 'Success'
                : 'Failed to fetch profile'),
        data: finalUserData,
      );
    } on SocketException {
      return AuthResult(
        success: false,
        message: 'No internet connection. Please check your network.',
      );
    } on TimeoutException {
      return AuthResult(
        success: false,
        message: 'Request timed out. Please try again.',
      );
    } catch (e) {
      debugPrint('getProfile Error: $e');
      return AuthResult(
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 7b. Check user status by mobile — POST /api/user/check-status
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> checkUserStatus(String mobileNumber) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('${AppConfig.userUrl}/check-status'),
            headers: headers,
            body: jsonEncode({'mobile_number': mobileNumber}),
          )
          .timeout(const Duration(seconds: 30));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      return AuthResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? 'Checked',
        data: decoded['data'] as Map<String, dynamic>?,
      );
    } on SocketException {
      return AuthResult(success: false, message: 'No internet connection.');
    } on TimeoutException {
      return AuthResult(success: false, message: 'Request timed out.');
    } catch (e) {
      debugPrint('checkUserStatus Error: $e');
      return AuthResult(
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 8. Update Profile — PUT /api/user/profile (Multipart)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> updateProfile({
    String? fullName,
    File? photo,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return AuthResult(success: false, message: 'Not logged in');
      }

      final uri = Uri.parse('${AppConfig.userUrl}/profile');
      final request = http.MultipartRequest('PUT', uri);

      // Add Headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      if (fullName != null) {
        request.fields['full_name'] = fullName;
      }

      // Add image file
      if (photo != null) {
        final photoPart = await http.MultipartFile.fromPath(
          'photo',
          photo.path,
        );
        request.files.add(photoPart);
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
      ); // Longer for files
      final response = await http.Response.fromStream(streamedResponse);

      if (response.body.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Server returned an empty response',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && decoded['success'] == true) {
        // Save updated user data locally
        final userData = decoded['data'] as Map<String, dynamic>?;
        if (userData != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userKey, jsonEncode(userData));
        }
        return AuthResult(
          success: true,
          message: decoded['message'] ?? 'Profile updated',
          data: userData,
        );
      } else {
        return AuthResult(
          success: false,
          message: decoded['message'] ?? 'Failed to update profile',
        );
      }
    } on SocketException {
      return AuthResult(
        success: false,
        message: 'No internet connection. Please check your network.',
      );
    } on TimeoutException {
      return AuthResult(
        success: false,
        message: 'Request timed out while uploading. Please try again.',
      );
    } catch (e) {
      debugPrint('UpdateProfile Error: $e');
      return AuthResult(
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 9. Get member name by mobile — POST /api/user/member-name
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> getMemberName(String mobileNumber) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('${AppConfig.userUrl}/member-name'),
            headers: headers,
            body: jsonEncode({'mobile_number': mobileNumber}),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      return AuthResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? 'Fetched',
        data: decoded['data'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 10. Settle Transactions — POST /api/settlement/settle
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> settleTransactions(String id) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('${AppConfig.settlementUrl}/settle'),
            headers: headers,
            body: jsonEncode({'id': id}),
          )
          .timeout(const Duration(seconds: 30));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      return AuthResult(
        success: decoded['success'] == true,
        message: decoded['message'] ?? 'Settled',
        data: decoded,
      );
    } on SocketException {
      return AuthResult(success: false, message: 'No internet connection');
    } on TimeoutException {
      return AuthResult(success: false, message: 'Request timed out');
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 11. Forgot Password Request — POST /api/auth/forgot-password/request
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> requestForgotPasswordOtp({
    required String email,
  }) async {
    final res = await _post('/forgot-password/request', {'email': email});
    return AuthResult(
      success: res['success'] == true,
      message: res['message'] ?? 'Unknown error',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 12. Reset Password — POST /api/auth/forgot-password/reset
  // ─────────────────────────────────────────────────────────────────────────

  static Future<AuthResult> resetPassword({
    required String email,
    required String otp,
    required String password,
  }) async {
    final res = await _post('/forgot-password/reset', {
      'email': email,
      'otp': otp,
      'password': password,
    });
    return AuthResult(
      success: res['success'] == true,
      message: res['message'] ?? 'Unknown error',
    );
  }
}

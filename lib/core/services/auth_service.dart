import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Centralised result type so callers don't need to deal with exceptions.
class AuthResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  AuthResult({required this.success, required this.message, this.data});
}

class AuthService {
  static const String _baseUrl = 'https://api.splitease.app/api/auth';
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
  };

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Network error. Please try again.'};
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
    );
  }
}

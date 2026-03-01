import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:splitease_test/core/config/app_config.dart';
import 'package:splitease_test/core/models/achievement_model.dart';
import 'package:splitease_test/core/services/auth_service.dart';

class AchievementService {
  static String get _baseUrl => AppConfig.achievementsUrl;

  /// Fetches all achievements from the backend.
  static Future<List<AchievementModel>> fetchAchievements() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .get(Uri.parse(_baseUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          final List<dynamic> list = decoded['data'] ?? [];
          return list.map((a) => AchievementModel.fromJson(a)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Optional: Track daily app usage if the backend has a tracking endpoint.
  /// This is hypothetical, hitting the achievements list might be enough for the backend to log usage.
  static Future<void> trackUsage() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      await http
          .post(
            Uri.parse('$_baseUrl/track'),
            headers: headers,
            body: jsonEncode({'type': 'app_usage'}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}

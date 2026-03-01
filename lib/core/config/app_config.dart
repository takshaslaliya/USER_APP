/// Central place for all environment / runtime configuration.
/// Change [apiBaseUrl] whenever the backend URL changes (e.g. ngrok restart).
class AppConfig {
  AppConfig._();

  /// Backend base URL — includes the /api prefix.
  static const String apiBaseUrl =
      'https://unprying-numerally-simone.ngrok-free.dev/api';

  static const String authUrl = '$apiBaseUrl/auth';

  /// Convenience getter for groups sub-path
  static const String groupsUrl = '$apiBaseUrl/groups';

  /// Convenience getter for user sub-path
  static const String userUrl = '$apiBaseUrl/user';

  /// WhatsApp API endpoints
  static const String whatsappUrl = '$apiBaseUrl/whatsapp';

  /// Achievements API endpoints
  static const String achievementsUrl = '$apiBaseUrl/achievements';
}

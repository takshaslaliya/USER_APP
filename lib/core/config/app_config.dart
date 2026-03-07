/// Central place for all environment / runtime configuration.
/// Change [apiBaseUrl] whenever the backend URL changes (e.g. ngrok restart).
class AppConfig {
  AppConfig._();

  /// Backend base URL — includes the /api prefix.
  static const String apiBaseUrl = 'https://aurotech.tech/api';

  static const String authUrl = '$apiBaseUrl/auth';

  /// Convenience getter for groups sub-path
  static const String groupsUrl = '$apiBaseUrl/groups';

  /// Convenience getter for user sub-path
  static const String userUrl = '$apiBaseUrl/user';

  /// Split API endpoints
  static const String splitUrl = '$apiBaseUrl/split';

  /// WhatsApp API endpoints
  static const String whatsappUrl = '$apiBaseUrl/whatsapp';

  /// Achievements API endpoints
  static const String achievementsUrl = '$apiBaseUrl/achievements';

  /// Settlement API endpoints
  static const String settlementUrl = '$apiBaseUrl/settlement';

  /// Admin API endpoints
  static const String adminUrl = '$apiBaseUrl/admin';
}

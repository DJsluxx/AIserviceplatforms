/// Compile-time / runtime constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'PEELED';
  static const String bundleId = 'com.peeled.app';

  static const int maxConcurrentPackages = 3;
  static const Duration defaultPeelWindow = Duration(seconds: 38);
  static const Duration expiringWarning = Duration(seconds: 5);

  static const String kSessionTokenKey = 'peeled.session_token';
  static const String kDeviceIdKey = 'peeled.device_id';

  static const String serverBaseUrlEnvKey = 'SERVER_BASE_URL';
  static const String mapboxTokenEnvKey = 'MAPBOX_PUBLIC_TOKEN';
  static const String supabaseUrlEnvKey = 'SUPABASE_URL';
  static const String supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';
  static const String posthogKeyEnvKey = 'POSTHOG_KEY';

  static const String defaultServerBaseUrl = 'https://api.peeled.app';
}

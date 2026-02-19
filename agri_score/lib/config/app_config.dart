/// App configuration constants.
class AppConfig {
  static const String apiBaseUrl =
      'https://evan-lanky-yajaira.ngrok-free.dev/api'; // Ngrok tunnel to localhost

  static const String apiBaseUrlWeb = 'http://localhost:8000/api';

  // Supabase
  static const String supabaseUrl = 'https://qociawdhvygbhsxuiask.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvY2lhd2RodnlnYmhzeHVpYXNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MTA3NTQsImV4cCI6MjA4Njk4Njc1NH0.QsciPiybLgnUgKJMwMhtJHOfTAHLKqb5uPN2NonIAdY';

  // Google Maps
  static const String googleMapsApiKey =
      'AIzaSyDijnN65BUB9IxB7E0TjK_fC78PxQg_RtA';
  static const String agroMonitoringApiKey = '5df44b52d07775cc34d87de06faedafe';
  static const String openWeatherApiKey = 'ab62c68f8d4211555f11afb377237eb2';
  static const String bhuvanApiKey = 'cd90f4552d2c870fdcc94709a53b670e1dc61a16';
  static const String marketApiKey =
      '579b464db66ec23bdd000001d62bde8ea53e4c1a6c4d367a9af4ca1d';
  // Note: GEE key not used directly in client due to complexity, fallback to AgroMonitoring

  // Theming
  static const int primaryGreen = 0xFF2E7D32;
  static const int primaryGreenLight = 0xFF4CAF50;
  static const int primaryGreenDark = 0xFF1B5E20;
  static const int accentAmber = 0xFFFFA000;
  static const int dangerRed = 0xFFD32F2F;
  static const int surfaceWhite = 0xFFFAFAFA;
  static const int cardWhite = 0xFFFFFFFF;
  static const int textDark = 0xFF212121;
  static const int textMuted = 0xFF757575;

  // Score thresholds
  static const int lowRiskMin = 800;
  static const int mediumRiskMin = 600;
}

class AppConstants {
  AppConstants._();

  // API   // 10.12.16.73    10.12.16.177  192.168.100.116
  static const String pcIpAddress = '10.12.16.177'; // Đổi IP này thành IP máy tính của bạn khi chạy trên thiết bị thật
  static const String baseUrl = 'http://$pcIpAddress:5166/api'; // Real device
  static const String baseUrlEmulator = 'http://10.0.2.2:5166/api'; // Android emulator
  static const String baseUrlIOS = 'http://localhost:5166/api';
  
  // SignalR Hub URLs
  static const String signalRHubUrl = 'http://$pcIpAddress:5166/hubs/group'; // Real device
  static const String signalRHubUrlEmulator = 'http://10.0.2.2:5166/hubs/group'; // Android emulator
  static const String signalRHubUrlIOS = 'http://localhost:5166/hubs/group'; // iOS simulator
  
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String tokenExpiryKey = 'token_expiry';
  static const String userKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String lastSyncKey = 'last_sync_at';

  // Pagination
  static const int defaultPageSize = 20;

  // Freemium Limits
  static const int maxFreeWallets = 2;

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String monthYearFormat = 'MM/yyyy';
  static const String apiDateFormat = 'yyyy-MM-ddTHH:mm:ss';

  // Animation
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration snackBarDuration = Duration(seconds: 3);
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class TokenStorage {
  final FlutterSecureStorage _storage;

  const TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiry,
  }) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    await _storage.write(key: AppConstants.tokenKey, value: accessToken);

    if (refreshToken != null) {
      await _storage.write(
        key: AppConstants.refreshTokenKey,
        value: refreshToken,
      );
    }

    if (expiry != null) {
      await _storage.write(
        key: AppConstants.tokenExpiryKey,
        value: expiry.toIso8601String(),
      );
    }
  }

  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    if (token != null && token.isNotEmpty) {
      return token;
    }
    return _storage.read(key: AppConstants.tokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: AppConstants.refreshTokenKey);
  }

  Future<DateTime?> getTokenExpiry() async {
    final raw = await _storage.read(key: AppConstants.tokenExpiryKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.tokenExpiryKey);
    await _storage.delete(key: AppConstants.tokenKey);
  }
}


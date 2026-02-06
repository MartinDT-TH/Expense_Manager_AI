import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/auth/token_storage.dart';

/// Two-Factor Authentication Data Source
/// Supports TOTP (Time-based One-Time Password) and Email/SMS OTP

abstract class TwoFactorDataSource {
  Future<TwoFactorSetupResult> setupTOTP();
  Future<bool> verifyTOTP(String code);
  Future<void> disableTwoFactor();
  Future<bool> isTwoFactorEnabled();
  Future<void> sendEmailOTP(String email);
  Future<bool> verifyEmailOTP(String email, String code);
  String generateTOTPCode(String secret);
}

class TwoFactorSetupResult {
  final bool success;
  final String? secret;
  final String? qrCodeUrl;
  final List<String>? backupCodes;
  final String? errorMessage;

  TwoFactorSetupResult({
    required this.success,
    this.secret,
    this.qrCodeUrl,
    this.backupCodes,
    this.errorMessage,
  });
}

class TwoFactorDataSourceImpl implements TwoFactorDataSource {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  TwoFactorDataSourceImpl({
    required this.apiClient,
    required this.tokenStorage,
  });

  @override
  Future<TwoFactorSetupResult> setupTOTP() async {
    try {
      final response = await apiClient.dio.post('/Auth/2fa/setup');
      
      if (response.statusCode == 200) {
        final data = response.data;
        return TwoFactorSetupResult(
          success: true,
          secret: data['secret'],
          qrCodeUrl: data['qrCodeUrl'],
          backupCodes: List<String>.from(data['backupCodes'] ?? []),
        );
      }
      
      return TwoFactorSetupResult(
        success: false,
        errorMessage: 'Thiết lập 2FA thất bại',
      );
    } catch (e) {
      return TwoFactorSetupResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<bool> verifyTOTP(String code) async {
    try {
      final response = await apiClient.dio.post(
        '/Auth/2fa/verify',
        data: {'code': code},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> disableTwoFactor() async {
    await apiClient.dio.post('/Auth/2fa/disable');
  }

  @override
  Future<bool> isTwoFactorEnabled() async {
    try {
      final response = await apiClient.dio.get('/Auth/2fa/status');
      return response.data['enabled'] ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> sendEmailOTP(String email) async {
    await apiClient.dio.post(
      '/Auth/otp/send',
      data: {'email': email, 'type': 'email'},
    );
  }

  @override
  Future<bool> verifyEmailOTP(String email, String code) async {
    try {
      final response = await apiClient.dio.post(
        '/Auth/otp/verify',
        data: {'email': email, 'code': code},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Generate TOTP code locally (for offline verification or testing)
  /// Uses RFC 6238 TOTP algorithm
  @override
  String generateTOTPCode(String secret) {
    final time = DateTime.now().millisecondsSinceEpoch ~/ 30000;
    final timeBytes = _int64ToBytes(time);
    
    final secretBytes = base64.decode(base64.normalize(secret));
    final hmac = Hmac(sha1, secretBytes);
    final hash = hmac.convert(timeBytes).bytes;
    
    final offset = hash.last & 0x0f;
    final binary = ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);
    
    final otp = binary % 1000000;
    return otp.toString().padLeft(6, '0');
  }

  List<int> _int64ToBytes(int value) {
    final result = List<int>.filled(8, 0);
    for (var i = 7; i >= 0; i--) {
      result[i] = value & 0xff;
      value >>= 8;
    }
    return result;
  }

  /// Generate random backup codes
  static List<String> generateBackupCodes({int count = 10}) {
    final random = Random.secure();
    return List.generate(count, (_) {
      return List.generate(8, (_) => random.nextInt(10)).join();
    });
  }
}

import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/auth/token_storage.dart';
import '../models/user_model.dart';
import 'google_auth_datasource.dart';

/// Enhanced Auth Remote DataSource with 2FA and Refresh Token support
abstract class AuthRemoteDataSourceV2 {
  // Basic Auth
  Future<AuthResult> login(String email, String password);
  Future<AuthResult> register(String email, String password, String fullName);
  Future<void> logout();
  Future<bool> resendVerificationEmail(String email);
  
  // 2FA
  Future<TwoFactorSetupResult> setupTwoFactor();
  Future<AuthResult> verifyTwoFactor(String twoFactorToken, String code, {bool isSetup = false});
  Future<bool> disableTwoFactor(String code);
  Future<bool> isTwoFactorEnabled();
  
  // Email OTP
  Future<bool> sendEmailOtp(String email);
  Future<AuthResult> verifyEmailOtp(String email, String code);
  
  // Token Management
  Future<TokenResult> refreshToken();
  Future<UserModel?> validateToken();
}

class TwoFactorSetupResult {
  final bool success;
  final String? message;
  final String? secret;
  final String? qrCodeUrl;
  final List<String>? backupCodes;

  TwoFactorSetupResult({
    required this.success,
    this.message,
    this.secret,
    this.qrCodeUrl,
    this.backupCodes,
  });

  factory TwoFactorSetupResult.fromJson(Map<String, dynamic> json) {
    return TwoFactorSetupResult(
      success: json['success'] ?? false,
      message: json['message'],
      secret: json['secret'],
      qrCodeUrl: json['qrCodeUrl'],
      backupCodes: json['backupCodes'] != null 
          ? List<String>.from(json['backupCodes']) 
          : null,
    );
  }
}

class TokenResult {
  final bool success;
  final String? message;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? accessTokenExpiry;
  final DateTime? refreshTokenExpiry;

  TokenResult({
    required this.success,
    this.message,
    this.accessToken,
    this.refreshToken,
    this.accessTokenExpiry,
    this.refreshTokenExpiry,
  });

  factory TokenResult.fromJson(Map<String, dynamic> json) {
    return TokenResult(
      success: json['success'] ?? false,
      message: json['message'],
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      accessTokenExpiry: json['accessTokenExpiry'] != null 
          ? DateTime.parse(json['accessTokenExpiry']) 
          : null,
      refreshTokenExpiry: json['refreshTokenExpiry'] != null 
          ? DateTime.parse(json['refreshTokenExpiry']) 
          : null,
    );
  }
}

class AuthRemoteDataSourceV2Impl implements AuthRemoteDataSourceV2 {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  AuthRemoteDataSourceV2Impl({
    required this.apiClient,
    required this.tokenStorage,
  });

  @override
  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await apiClient.dio.post(
        '/Auth/login',
        data: {'email': email, 'password': password},
      );

      final result = AuthResult.fromJson(response.data);
      
      if (result.success && result.token != null && !result.requiresTwoFactor) {
        await _saveTokens(result.token!, result.refreshToken);
      }
      
      return result;
    } on DioException catch (e) {
      return AuthResult(
        success: false,
        message: e.response?.data['message'] ?? 'Đăng nhập thất bại',
      );
    }
  }

  @override
  Future<AuthResult> register(String email, String password, String fullName) async {
    try {
      final response = await apiClient.dio.post(
        '/Auth/register',
        data: {
          'email': email,
          'password': password,
          'fullName': fullName,
        },
      );

      final result = AuthResult.fromJson(response.data);
      
      if (result.success && result.token != null) {
        await _saveTokens(result.token!, result.refreshToken);
      }
      
      return result;
    } on DioException catch (e) {
      return AuthResult(
        success: false,
        message: e.response?.data['message'] ?? 'Đăng ký thất bại',
      );
    }
  }

  @override
  Future<bool> resendVerificationEmail(String email) async {
    try {
      final response = await apiClient.dio.post(
        '/Auth/resend-verification',
        data: {'email': email},
      );
      return response.data['success'] == true;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Gửi lại email xác thực thất bại');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await apiClient.dio.post('/Auth/logout');
    } finally {
      await tokenStorage.clearAll();
    }
  }

  @override
  Future<TwoFactorSetupResult> setupTwoFactor() async {
    try {
      final response = await apiClient.dio.post('/Auth/2fa/setup');
      return TwoFactorSetupResult.fromJson(response.data);
    } on DioException catch (e) {
      return TwoFactorSetupResult(
        success: false,
        message: e.response?.data['message'] ?? 'Thiết lập 2FA thất bại',
      );
    }
  }

  @override
  Future<AuthResult> verifyTwoFactor(String twoFactorToken, String code, {bool isSetup = false}) async {
    try {
      final endpoint = isSetup ? '/Auth/2fa/confirm' : '/Auth/2fa/verify';
      
      final response = await apiClient.dio.post(
        endpoint,
        data: {
          'code': code,
          'isSetupConfirmation': isSetup,
        },
        options: Options(
          headers: isSetup ? null : {'X-TwoFactor-Token': twoFactorToken},
        ),
      );

      final result = AuthResult.fromJson(response.data);
      
      if (result.success && result.token != null) {
        await _saveTokens(result.token!, result.refreshToken);
      }
      
      return result;
    } on DioException catch (e) {
      return AuthResult(
        success: false,
        message: e.response?.data['message'] ?? 'Xác thực OTP thất bại',
      );
    }
  }

  @override
  Future<bool> disableTwoFactor(String code) async {
    try {
      final response = await apiClient.dio.post(
        '/Auth/2fa/disable',
        data: {'code': code},
      );
      return response.data['success'] ?? false;
    } catch (e) {
      return false;
    }
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
  Future<bool> sendEmailOtp(String email) async {
    try {
      final response = await apiClient.dio.post(
        '/Auth/otp/send',
        data: {'email': email},
      );
      return response.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AuthResult> verifyEmailOtp(String email, String code) async {
    try {
      final response = await apiClient.dio.post(
        '/Auth/otp/verify',
        data: {'email': email, 'code': code},
      );

      final result = AuthResult.fromJson(response.data);
      
      if (result.success && result.token != null) {
        await _saveTokens(result.token!, result.refreshToken);
      }
      
      return result;
    } on DioException catch (e) {
      return AuthResult(
        success: false,
        message: e.response?.data['message'] ?? 'Xác thực OTP thất bại',
      );
    }
  }

  @override
  Future<TokenResult> refreshToken() async {
    try {
      final accessToken = await tokenStorage.getAccessToken();
      final refreshToken = await tokenStorage.getRefreshToken();
      
      if (accessToken == null || refreshToken == null) {
        return TokenResult(success: false, message: 'Chưa có token được lưu');
      }

      final response = await apiClient.dio.post(
        '/Auth/refresh-token',
        data: {
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        },
      );

      final result = TokenResult.fromJson(response.data);
      
      if (result.success && result.accessToken != null) {
        await _saveTokens(result.accessToken!, result.refreshToken);
      }
      
      return result;
    } on DioException catch (e) {
      return TokenResult(
        success: false,
        message: e.response?.data['message'] ?? 'Làm mới token thất bại',
      );
    }
  }

  @override
  Future<UserModel?> validateToken() async {
    try {
      final response = await apiClient.dio.get('/Auth/validate');
      if (response.data['success'] == true && response.data['user'] != null) {
        return UserModel.fromJson(response.data['user']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveTokens(String accessToken, String? refreshToken) async {
    await tokenStorage.saveAccessToken(accessToken);
    if (refreshToken != null) {
      await tokenStorage.saveRefreshToken(refreshToken);
    }
  }
}

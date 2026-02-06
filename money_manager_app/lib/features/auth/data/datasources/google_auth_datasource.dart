import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/auth/token_storage.dart';
import '../models/user_model.dart';

/// Google Sign-In Data Source
/// 
/// Setup required:
/// 1. Add to pubspec.yaml: google_sign_in: ^6.2.1
/// 2. Google Cloud Console: Create OAuth 2.0 Client ID
/// 3. Android: Add SHA-1/SHA-256 fingerprints
/// 4. iOS: Add GoogleService-Info.plist and URL schemes

abstract class GoogleAuthDataSource {
  Future<AuthResult> signInWithGoogle();
  Future<void> signOutGoogle();
  Future<AuthResult> linkGoogleAccount();
  Future<AuthResult> unlinkGoogleAccount();
}

class AuthResult {
  final bool success;
  final String? message;
  final String? token;
  final String? refreshToken;
  final UserModel? user;
  final bool requiresTwoFactor;
  final String? twoFactorToken;
  final bool requiresEmailVerification;

  AuthResult({
    required this.success,
    this.message,
    this.token,
    this.refreshToken,
    this.user,
    this.requiresTwoFactor = false,
    this.twoFactorToken,
    this.requiresEmailVerification = false,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      success: json['success'] ?? false,
      message: json['message'],
      token: json['token'],
      refreshToken: json['refreshToken'],
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      requiresTwoFactor: json['requiresTwoFactor'] ?? false,
      twoFactorToken: json['twoFactorToken'],
      requiresEmailVerification:
          json['requiresEmailVerification'] ?? json['requires_email_verification'] ?? false,
    );
  }
}

class GoogleAuthDataSourceImpl implements GoogleAuthDataSource {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  
  // Web Client ID from Google Cloud Console
  static const String _webClientId = '102977095452-b6aa3p376tnp2gm2shol140k1stfrj4u.apps.googleusercontent.com';
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    serverClientId: _webClientId,
  );

  GoogleAuthDataSourceImpl({
    required this.apiClient,
    required this.tokenStorage,
  });

  Future<void> _safeDisconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // Ignore disconnect failures (common in dev or when not connected)
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Force account picker by clearing previous session
      await _googleSignIn.signOut();
      await _safeDisconnect();

      // Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult(
          success: false,
          message: 'Đăng nhập Google đã bị hủy',
        );
      }

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        return AuthResult(
          success: false,
          message: 'Không thể lấy Google ID token',
        );
      }

      // Send to backend for verification and JWT issuance
      final response = await apiClient.dio.post(
        '/Auth/google-login',
        data: {
          'idToken': googleAuth.idToken,
          'accessToken': googleAuth.accessToken,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return AuthResult(
          success: false,
          message: data?.toString() ?? 'Đăng nhập Google thất bại',
        );
      }
      final result = AuthResult.fromJson(data);
      
      // Store tokens if login successful (and no 2FA required)
      if (result.success &&
          result.token != null &&
          !result.requiresTwoFactor &&
          !result.requiresEmailVerification) {
        await tokenStorage.saveAccessToken(result.token!);
        if (result.refreshToken != null) {
          await tokenStorage.saveRefreshToken(result.refreshToken!);
        }
      }
      
      return result;
    } on DioException catch (e) {
      // Handle DioException to get error message from response
      final message = e.response?.data?['message'] ?? e.message ?? 'Đăng nhập Google thất bại';
      return AuthResult(
        success: false,
        message: message,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  @override
  Future<void> signOutGoogle() async {
    await _googleSignIn.signOut();
  }

  @override
  Future<AuthResult> linkGoogleAccount() async {
    try {
      await _googleSignIn.signOut();
      await _safeDisconnect();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult(
          success: false,
          message: 'Đăng nhập Google đã bị hủy',
        );
      }

      final googleAuth = await googleUser.authentication;
      
      final response = await apiClient.dio.post(
        '/Auth/link-google',
        data: {
          'idToken': googleAuth.idToken,
        },
      );

      return AuthResult(
        success: response.statusCode == 200,
        message: response.data['message'],
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  @override
  Future<AuthResult> unlinkGoogleAccount() async {
    try {
      final response = await apiClient.dio.post('/Auth/unlink-google');
      if (response.statusCode == 200) {
        await _safeDisconnect();
        return AuthResult(
          success: true,
          message: response.data['message'] ?? 'Đã hủy liên kết tài khoản Google',
        );
      }
      return AuthResult(
        success: false,
        message: response.data['message'] ?? 'Hủy liên kết tài khoản Google thất bại',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: e.toString(),
      );
    }
  }
}

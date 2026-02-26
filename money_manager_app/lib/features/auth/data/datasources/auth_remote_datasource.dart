import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../models/auth_request_models.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> register(String email, String password, String fullName);
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
  Future<void> forgotPassword(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    final request = LoginRequest(email: email, password: password);
    final response = await apiClient.post('/Auth/login', data: request.toJson());

    if (response.data is! Map<String, dynamic>) {
      return AuthResponseModel(
        success: false,
        message: response.data?.toString() ?? 'Đăng nhập thất bại',
      );
    }
    final authResponse = AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
    if (authResponse.success && authResponse.accessToken != null) {
      final expiry = _resolveExpiry(
        authResponse.expiresIn,
        authResponse.accessToken!,
      );
      await apiClient.saveTokens(
        accessToken: authResponse.accessToken!,
        refreshToken: authResponse.refreshToken,
        expiry: expiry,
      );
    }
    return authResponse;
  }

  @override
  Future<AuthResponseModel> register(String email, String password, String fullName) async {
    final request = RegisterRequest(
      email: email,
      password: password,
      fullName: fullName,
    );
    final response = await apiClient.post('/Auth/register', data: request.toJson());

    if (response.data is! Map<String, dynamic>) {
      return AuthResponseModel(
        success: false,
        message: response.data?.toString() ?? 'Đăng ký thất bại',
      );
    }
    final authResponse = AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
    if (authResponse.success && authResponse.accessToken != null) {
      final expiry = _resolveExpiry(
        authResponse.expiresIn,
        authResponse.accessToken!,
      );
      await apiClient.saveTokens(
        accessToken: authResponse.accessToken!,
        refreshToken: authResponse.refreshToken,
        expiry: expiry,
      );
    }
    return authResponse;
  }

  @override
  Future<void> logout() async {
    await apiClient.clearToken();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await apiClient.get('/user/me');
      if (response.data != null) {
        return UserModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    await apiClient.post('/Auth/forgot-password', data: {'email': email});
  }

  DateTime? _resolveExpiry(int? expiresIn, String accessToken) {
    if (expiresIn != null) {
      return DateTime.now().add(Duration(seconds: expiresIn));
    }
    return _parseJwtExpiry(accessToken);
  }

  DateTime? _parseJwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final data = jsonDecode(payload);
      final exp = data['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      if (exp is String) {
        final asInt = int.tryParse(exp);
        if (asInt != null) {
          return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

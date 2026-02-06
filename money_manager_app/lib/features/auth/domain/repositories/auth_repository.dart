import '../entities/user.dart';

abstract class AuthRepository {
  Future<AuthResult> login(String email, String password);
  Future<AuthResult> register(String email, String password, String fullName);
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<bool> isLoggedIn();
  Future<void> saveUserLocally(User user);
  Future<void> forgotPassword(String email);
}

class AuthResult {
  final bool success;
  final String? message;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final User? user;
  final bool requiresEmailVerification;

  AuthResult({
    required this.success,
    this.message,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.user,
    this.requiresEmailVerification = false,
  });
}

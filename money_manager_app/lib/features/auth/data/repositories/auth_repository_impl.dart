import '../../../../core/network/network_info.dart';
import '../../../../core/auth/token_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final TokenStorage tokenStorage;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    TokenStorage? tokenStorage,
  }) : tokenStorage = tokenStorage ?? const TokenStorage();

  @override
  Future<AuthResult> login(String email, String password) async {
    if (!await networkInfo.checkConnection()) {
      return AuthResult(success: false, message: 'Không có kết nối mạng');
    }

    try {
      final response = await remoteDataSource.login(email, password);
      UserModel? user = response.user;
      if (response.success && user == null) {
        user = await remoteDataSource.getCurrentUser();
      }
      if (response.success && user != null) {
        await localDataSource.saveUser(user);
      }
      return AuthResult(
        success: response.success,
        message: response.message,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        expiresIn: response.expiresIn,
        user: user,
        requiresEmailVerification: response.requiresEmailVerification,
      );
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  @override
  Future<AuthResult> register(String email, String password, String fullName) async {
    if (!await networkInfo.checkConnection()) {
      return AuthResult(success: false, message: 'Không có kết nối mạng');
    }

    try {
      final response = await remoteDataSource.register(email, password, fullName);
      UserModel? user = response.user;
      if (response.success && user == null) {
        user = await remoteDataSource.getCurrentUser();
      }
      if (response.success && user != null) {
        await localDataSource.saveUser(user);
      }
      return AuthResult(
        success: response.success,
        message: response.message,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        expiresIn: response.expiresIn,
        user: user,
        requiresEmailVerification: response.requiresEmailVerification,
      );
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await remoteDataSource.logout();
    } catch (_) {
      // Ignore errors - still clear local data
    }
    await tokenStorage.clearTokens();
    await localDataSource.deleteUser();
  }

  @override
  Future<User?> getCurrentUser() async {
    // FIRST: Check if we have a valid token
    final hasToken = await tokenStorage.hasValidToken();
    if (!hasToken) {
      // No valid token - clear local data and return null
      await localDataSource.deleteUser();
      return null;
    }

    // If connected, verify with server first
    if (await networkInfo.checkConnection()) {
      try {
        final remoteUser = await remoteDataSource.getCurrentUser();
        if (remoteUser != null) {
          await localDataSource.saveUser(remoteUser);
          return remoteUser;
        } else {
          // Token invalid on server - clear everything
          await tokenStorage.clearTokens();
          await localDataSource.deleteUser();
          return null;
        }
      } catch (e) {
        // Network error but we have token - try local
        final localUser = await localDataSource.getUser();
        return localUser;
      }
    }

    // Offline mode - use local user if available
    final localUser = await localDataSource.getUser();
    return localUser;
  }

  @override
  Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }

  @override
  Future<void> saveUserLocally(User user) async {
    await localDataSource.saveUser(UserModel.fromEntity(user));
  }

  @override
  Future<void> forgotPassword(String email) async {
    if (!await networkInfo.checkConnection()) {
      throw Exception('Không có kết nối mạng');
    }
    await remoteDataSource.forgotPassword(email);
  }
}

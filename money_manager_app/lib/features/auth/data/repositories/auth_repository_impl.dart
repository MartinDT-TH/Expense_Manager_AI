import '../../../../core/network/network_info.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

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
      );
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  @override
  Future<void> logout() async {
    await remoteDataSource.logout();
    await localDataSource.deleteUser();
  }

  @override
  Future<User?> getCurrentUser() async {
    // Try local first
    final localUser = await localDataSource.getUser();
    if (localUser != null) {
      return localUser;
    }

    // If connected, try remote
    if (await networkInfo.checkConnection()) {
      try {
        final remoteUser = await remoteDataSource.getCurrentUser();
        if (remoteUser != null) {
          await localDataSource.saveUser(remoteUser);
        }
        return remoteUser;
      } catch (e) {
        return null;
      }
    }
    return null;
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

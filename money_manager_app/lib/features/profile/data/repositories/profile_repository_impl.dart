import '../../../../core/network/network_info.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<ProfileResponse> getProfile() async {
    final hasConnection = await networkInfo.checkConnection();
    if (!hasConnection) {
      return ProfileResponse(
        success: false,
        message: 'Không có kết nối mạng',
      );
    }

    final result = await remoteDataSource.getProfile();
    return ProfileResponse(
      success: result.success,
      message: result.message,
      profile: result.profile?.toEntity(),
    );
  }

  @override
  Future<ProfileResponse> updateProfile({
    String? fullName,
    String? phone,
    String? address,
  }) async {
    final hasConnection = await networkInfo.checkConnection();
    if (!hasConnection) {
      return ProfileResponse(
        success: false,
        message: 'Không có kết nối mạng',
      );
    }

    final result = await remoteDataSource.updateProfile(
      fullName: fullName,
      phone: phone,
      address: address,
    );
    return ProfileResponse(
      success: result.success,
      message: result.message,
      profile: result.profile?.toEntity(),
    );
  }

  @override
  Future<OperationResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final hasConnection = await networkInfo.checkConnection();
    if (!hasConnection) {
      return OperationResponse(
        success: false,
        message: 'Không có kết nối mạng',
      );
    }

    final result = await remoteDataSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    return OperationResponse(
      success: result.success,
      message: result.message,
    );
  }

  @override
  Future<ProfileResponse> updateAvatar(String avatarUrl) async {
    final hasConnection = await networkInfo.checkConnection();
    if (!hasConnection) {
      return ProfileResponse(
        success: false,
        message: 'Không có kết nối mạng',
      );
    }

    final result = await remoteDataSource.updateAvatar(avatarUrl);
    return ProfileResponse(
      success: result.success,
      message: result.message,
      profile: result.profile?.toEntity(),
    );
  }

  @override
  Future<OperationResponse> deleteAvatar() async {
    final hasConnection = await networkInfo.checkConnection();
    if (!hasConnection) {
      return OperationResponse(
        success: false,
        message: 'Không có kết nối mạng',
      );
    }

    final result = await remoteDataSource.deleteAvatar();
    return OperationResponse(
      success: result.success,
      message: result.message,
    );
  }
}

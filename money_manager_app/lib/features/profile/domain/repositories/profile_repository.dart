import '../../../auth/domain/entities/user.dart';

abstract class ProfileRepository {
  Future<ProfileResponse> getProfile();
  Future<ProfileResponse> updateProfile({
    String? fullName,
    String? phone,
    String? address,
  });
  Future<OperationResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<ProfileResponse> updateAvatar(String avatarUrl);
  Future<OperationResponse> deleteAvatar();
}

class ProfileResponse {
  final bool success;
  final String? message;
  final User? profile;

  ProfileResponse({
    required this.success,
    this.message,
    this.profile,
  });
}

class OperationResponse {
  final bool success;
  final String message;

  OperationResponse({
    required this.success,
    required this.message,
  });
}

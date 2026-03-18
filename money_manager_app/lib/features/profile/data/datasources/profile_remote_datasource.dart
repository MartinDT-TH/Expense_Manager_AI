import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileResult> getProfile();
  Future<ProfileResult> updateProfile({
    String? fullName,
    String? phone,
    String? address,
  });
  Future<ProfileOperationResult> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<ProfileResult> updateAvatar(String avatarUrl);
  Future<ProfileOperationResult> deleteAvatar();
}

class ProfileResult {
  final bool success;
  final String? message;
  final UserModel? profile;

  ProfileResult({
    required this.success,
    this.message,
    this.profile,
  });

  factory ProfileResult.fromJson(Map<String, dynamic> json) {
    return ProfileResult(
      success: json['success'] ?? false,
      message: json['message'],
      profile: json['profile'] != null 
          ? UserModel.fromJson(json['profile']) 
          : null,
    );
  }
}

class ProfileOperationResult {
  final bool success;
  final String message;

  ProfileOperationResult({
    required this.success,
    required this.message,
  });

  factory ProfileOperationResult.fromJson(Map<String, dynamic> json) {
    return ProfileOperationResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final ApiClient apiClient;

  ProfileRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<ProfileResult> getProfile() async {
    try {
      final response = await apiClient.dio.get('/User/profile');
      return ProfileResult.fromJson(response.data);
    } on DioException catch (e) {
      return ProfileResult(
        success: false,
        message: e.response?.data['message'] ?? 'Không thể tải hồ sơ',
      );
    }
  }

  @override
  Future<ProfileResult> updateProfile({
    String? fullName,
    String? phone,
    String? address,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['fullName'] = fullName;
      if (phone != null) data['phone'] = phone;
      if (address != null) data['address'] = address;

      final response = await apiClient.dio.put('/User/profile', data: data);
      return ProfileResult.fromJson(response.data);
    } on DioException catch (e) {
      return ProfileResult(
        success: false,
        message: e.response?.data['message'] ?? 'Không thể cập nhật hồ sơ',
      );
    }
  }

  @override
  Future<ProfileOperationResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await apiClient.dio.post('/User/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': newPassword,
      });
      return ProfileOperationResult.fromJson(response.data);
    } on DioException catch (e) {
      return ProfileOperationResult(
        success: false,
        message: e.response?.data['message'] ?? 'Không thể đổi mật khẩu',
      );
    }
  }

  @override
  Future<ProfileResult> updateAvatar(String avatarUrl) async {
    try {
      final response = await apiClient.dio.post('/User/avatar', data: {
        'avatarUrl': avatarUrl,
      });
      return ProfileResult.fromJson(response.data);
    } on DioException catch (e) {
      return ProfileResult(
        success: false,
        message: e.response?.data['message'] ?? 'Không thể cập nhật ảnh đại diện',
      );
    }
  }

  @override
  Future<ProfileOperationResult> deleteAvatar() async {
    try {
      final response = await apiClient.dio.delete('/User/avatar');
      return ProfileOperationResult.fromJson(response.data);
    } on DioException catch (e) {
      return ProfileOperationResult(
        success: false,
        message: e.response?.data['message'] ?? 'Không thể xóa ảnh đại diện',
      );
    }
  }
}

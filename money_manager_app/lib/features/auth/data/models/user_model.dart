import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    required super.role,
    super.avatarUrl,
    super.isPremium,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      role: json['role'] ?? 'Member',
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
      isPremium: json['isPremium'] ?? json['is_premium'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role,
      'avatarUrl': avatarUrl,
      'isPremium': isPremium,
    };
  }

  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      role: user.role,
      avatarUrl: user.avatarUrl,
      isPremium: user.isPremium,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'avatar_url': avatarUrl,
      'is_premium': isPremium ? 1 : 0,
    };
  }

  factory UserModel.fromDatabase(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'],
      fullName: map['full_name'],
      role: map['role'],
      avatarUrl: map['avatar_url'],
      isPremium: map['is_premium'] == 1,
    );
  }
}

class AuthResponseModel {
  final bool success;
  final String? message;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final UserModel? user;

  AuthResponseModel({
    required this.success,
    this.message,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final rawExpiresIn = json['expiresIn'] ?? json['expires_in'];
    int? expiresIn;
    if (rawExpiresIn is int) {
      expiresIn = rawExpiresIn;
    } else if (rawExpiresIn is String) {
      expiresIn = int.tryParse(rawExpiresIn);
    }

    return AuthResponseModel(
      success: json['success'] ?? false,
      message: json['message'],
      accessToken: json['accessToken'] ?? json['token'] ?? json['access_token'],
      refreshToken: json['refreshToken'] ?? json['refresh_token'],
      expiresIn: expiresIn,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }
}

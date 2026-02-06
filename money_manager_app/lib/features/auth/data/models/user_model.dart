import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    required super.role,
    super.avatarUrl,
    super.phone,
    super.address,
    super.isPremium,
    super.twoFactorEnabled,
    super.isGoogleLinked,
    super.googleEmail,
    super.hasPassword,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      role: json['role'] ?? 'Member',
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
      phone: json['phone'],
      address: json['address'],
      isPremium: json['isPremium'] ?? json['is_premium'] ?? false,
      twoFactorEnabled: json['twoFactorEnabled'] ?? json['two_factor_enabled'] ?? false,
      isGoogleLinked: json['isGoogleLinked'] ?? json['is_google_linked'] ?? false,
      googleEmail: json['googleEmail'] ?? json['google_email'],
      hasPassword: json['hasPassword'] ?? json['has_password'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role,
      'avatarUrl': avatarUrl,
      'phone': phone,
      'address': address,
      'isPremium': isPremium,
      'twoFactorEnabled': twoFactorEnabled,
      'isGoogleLinked': isGoogleLinked,
      'googleEmail': googleEmail,
      'hasPassword': hasPassword,
    };
  }

  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      role: user.role,
      avatarUrl: user.avatarUrl,
      phone: user.phone,
      address: user.address,
      isPremium: user.isPremium,
      twoFactorEnabled: user.twoFactorEnabled,
      isGoogleLinked: user.isGoogleLinked,
      googleEmail: user.googleEmail,
      hasPassword: user.hasPassword,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'avatar_url': avatarUrl,
      'phone': phone,
      'address': address,
      'is_premium': isPremium ? 1 : 0,
      'two_factor_enabled': twoFactorEnabled ? 1 : 0,
      'is_google_linked': isGoogleLinked ? 1 : 0,
      'google_email': googleEmail,
      'has_password': hasPassword ? 1 : 0,
    };
  }

  factory UserModel.fromDatabase(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'],
      fullName: map['full_name'],
      role: map['role'],
      avatarUrl: map['avatar_url'],
      phone: map['phone'],
      address: map['address'],
      isPremium: map['is_premium'] == 1,
      twoFactorEnabled: map['two_factor_enabled'] == 1,
      isGoogleLinked: map['is_google_linked'] == 1,
      googleEmail: map['google_email'],
      hasPassword: map['has_password'] == 1,
    );
  }

  User toEntity() {
    return User(
      id: id,
      email: email,
      fullName: fullName,
      role: role,
      avatarUrl: avatarUrl,
      phone: phone,
      address: address,
      isPremium: isPremium,
      twoFactorEnabled: twoFactorEnabled,
      isGoogleLinked: isGoogleLinked,
      googleEmail: googleEmail,
      hasPassword: hasPassword,
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
  final bool requiresEmailVerification;

  AuthResponseModel({
    required this.success,
    this.message,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.user,
    this.requiresEmailVerification = false,
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
      requiresEmailVerification:
          json['requiresEmailVerification'] ?? json['requires_email_verification'] ?? false,
    );
  }
}

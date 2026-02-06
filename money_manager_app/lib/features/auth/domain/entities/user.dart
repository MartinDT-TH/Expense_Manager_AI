import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final String? phone;
  final String? address;
  final bool isPremium;
  final bool twoFactorEnabled;
  final bool isGoogleLinked;
  final String? googleEmail;
  final bool hasPassword;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.address,
    this.isPremium = false,
    this.twoFactorEnabled = false,
    this.isGoogleLinked = false,
    this.googleEmail,
    this.hasPassword = true,
  });

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? avatarUrl,
    String? phone,
    String? address,
    bool? isPremium,
    bool? twoFactorEnabled,
    bool? isGoogleLinked,
    String? googleEmail,
    bool? hasPassword,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      isPremium: isPremium ?? this.isPremium,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      isGoogleLinked: isGoogleLinked ?? this.isGoogleLinked,
      googleEmail: googleEmail ?? this.googleEmail,
      hasPassword: hasPassword ?? this.hasPassword,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        role,
        avatarUrl,
        phone,
        address,
        isPremium,
        twoFactorEnabled,
        isGoogleLinked,
        googleEmail,
        hasPassword,
      ];
}

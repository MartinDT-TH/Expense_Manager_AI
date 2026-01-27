import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final bool isPremium;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.isPremium = false,
  });

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? avatarUrl,
    bool? isPremium,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  @override
  List<Object?> get props => [id, email, fullName, role, avatarUrl, isPremium];
}

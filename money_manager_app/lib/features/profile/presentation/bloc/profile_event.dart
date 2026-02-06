import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadProfile extends ProfileEvent {}

class UpdateProfile extends ProfileEvent {
  final String? fullName;
  final String? phone;
  final String? address;

  const UpdateProfile({
    this.fullName,
    this.phone,
    this.address,
  });

  @override
  List<Object?> get props => [fullName, phone, address];
}

class ChangePassword extends ProfileEvent {
  final String currentPassword;
  final String newPassword;

  const ChangePassword({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword];
}

class UpdateAvatar extends ProfileEvent {
  final String avatarUrl;

  const UpdateAvatar({required this.avatarUrl});

  @override
  List<Object?> get props => [avatarUrl];
}

class DeleteAvatar extends ProfileEvent {}

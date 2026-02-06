import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository repository;

  ProfileBloc({required this.repository}) : super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateProfile>(_onUpdateProfile);
    on<ChangePassword>(_onChangePassword);
    on<UpdateAvatar>(_onUpdateAvatar);
    on<DeleteAvatar>(_onDeleteAvatar);
  }

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final result = await repository.getProfile();
      if (result.success && result.profile != null) {
        emit(ProfileLoaded(profile: result.profile!));
      } else {
        emit(ProfileError(message: result.message ?? 'Failed to load profile'));
      }
    } catch (e) {
      emit(ProfileError(message: e.toString()));
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final result = await repository.updateProfile(
        fullName: event.fullName,
        phone: event.phone,
        address: event.address,
      );
      if (result.success && result.profile != null) {
        emit(ProfileUpdated(
          profile: result.profile!,
          message: result.message ?? 'Profile updated successfully',
        ));
      } else {
        emit(ProfileError(message: result.message ?? 'Failed to update profile'));
      }
    } catch (e) {
      emit(ProfileError(message: e.toString()));
    }
  }

  Future<void> _onChangePassword(
    ChangePassword event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final result = await repository.changePassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );
      if (result.success) {
        emit(PasswordChanged(message: result.message));
      } else {
        emit(ProfileError(message: result.message));
      }
    } catch (e) {
      emit(ProfileError(message: e.toString()));
    }
  }

  Future<void> _onUpdateAvatar(
    UpdateAvatar event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final result = await repository.updateAvatar(event.avatarUrl);
      if (result.success && result.profile != null) {
        emit(ProfileUpdated(
          profile: result.profile!,
          message: result.message ?? 'Avatar updated successfully',
        ));
      } else {
        emit(ProfileError(message: result.message ?? 'Failed to update avatar'));
      }
    } catch (e) {
      emit(ProfileError(message: e.toString()));
    }
  }

  Future<void> _onDeleteAvatar(
    DeleteAvatar event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    try {
      final result = await repository.deleteAvatar();
      if (result.success) {
        // Reload profile to get updated data
        add(LoadProfile());
      } else {
        emit(ProfileError(message: result.message));
      }
    } catch (e) {
      emit(ProfileError(message: e.toString()));
    }
  }
}

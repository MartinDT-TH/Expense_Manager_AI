import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/auth_event_bus.dart';
import '../../data/datasources/google_auth_datasource.dart';
import '../../data/datasources/two_factor_datasource.dart';
import '../../data/datasources/auth_remote_datasource_v2.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/forgot_password_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final ForgotPasswordUseCase forgotPasswordUseCase;
  final GoogleAuthDataSource? googleAuthDataSource;
  final TwoFactorDataSource? twoFactorDataSource;
  final AuthRemoteDataSourceV2? authRemoteDataSourceV2;
  final void Function()? onSyncRequested;
  
  StreamSubscription<AuthErrorEvent>? _authEventSubscription;

  AuthBloc({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
    required this.forgotPasswordUseCase,
    this.googleAuthDataSource,
    this.twoFactorDataSource,
    this.authRemoteDataSourceV2,
    this.onSyncRequested,
  }) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<RegisterSubmitted>(_onRegisterSubmitted);
    on<ForgotPasswordSubmitted>(_onForgotPasswordSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<GoogleLinkRequested>(_onGoogleLinkRequested);
    on<GoogleUnlinkRequested>(_onGoogleUnlinkRequested);
    on<TwoFactorSetupRequested>(_onTwoFactorSetupRequested);
    on<VerifyTwoFactorSubmitted>(_onVerifyTwoFactorSubmitted);
    on<TwoFactorDisableRequested>(_onTwoFactorDisableRequested);
    on<SendEmailOtpRequested>(_onSendEmailOtpRequested);
    on<VerifyEmailOtpSubmitted>(_onVerifyEmailOtpSubmitted);
    on<TokenRefreshRequested>(_onTokenRefreshRequested);
    on<ResendVerificationEmailRequested>(_onResendVerificationEmailRequested);
    on<SessionExpiredEvent>(_onSessionExpired);
    
    // Listen for auth events from ApiClient
    _authEventSubscription = AuthEventBus.instance.stream.listen((event) {
      if (event.shouldLogout && state is Authenticated) {
        add(SessionExpiredEvent(message: event.message));
      }
    });
  }

  Future<void> _onSessionExpired(
    SessionExpiredEvent event,
    Emitter<AuthState> emit,
  ) async {
    // Clear local data
    await logoutUseCase();
    emit(SessionExpired(message: event.message ?? 'Phiên đăng nhập đã hết hạn.'));
  }

  @override
  Future<void> close() {
    _authEventSubscription?.cancel();
    return super.close();
  }

  Future<void> _onAppStarted(
    AppStarted event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = await getCurrentUserUseCase();
      if (user != null) {
        emit(Authenticated(user: user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(Unauthenticated());
    }
  }

  Future<void> _onResendVerificationEmailRequested(
    ResendVerificationEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (authRemoteDataSourceV2 == null) {
      emit(const AuthError(message: 'Chưa cấu hình API resend verification'));
      return;
    }

    try {
      final sent = await authRemoteDataSourceV2!.resendVerificationEmail(event.email);
      if (sent) {
        emit(EmailVerificationResent(
          email: event.email,
          message: 'Email xác thực đã được gửi. Vui lòng kiểm tra hộp thư.',
        ));
      } else {
        emit(const AuthError(message: 'Gửi lại email xác thực thất bại'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await loginUseCase(event.email, event.password);
      if (result.requiresEmailVerification) {
        emit(EmailVerificationRequired(
          email: event.email,
          message: result.message ?? 'Vui lòng xác thực email trước khi đăng nhập',
        ));
        return;
      }
      if (result.success) {
        final user = result.user ?? await getCurrentUserUseCase();
        if (user != null) {
          emit(Authenticated(user: user));
          onSyncRequested?.call();
          return;
        }
      } else {
        emit(AuthError(message: result.message ?? 'Đăng nhập thất bại'));
        return;
      }
      emit(AuthError(message: 'Không lấy được thông tin người dùng'));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onRegisterSubmitted(
    RegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await registerUseCase(event.email, event.password, event.fullName);
      if (result.success) {
        // Clear any existing session/token so we don't stay logged in with an old user
        await logoutUseCase();
        emit(RegistrationSuccess(
          message: result.message ?? 'Đăng ký thành công, vui lòng đăng nhập',
        ));
      } else {
        emit(AuthError(message: result.message ?? 'Đăng ký thất bại'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onForgotPasswordSubmitted(
    ForgotPasswordSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await forgotPasswordUseCase(event.email);
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await logoutUseCase();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(message: 'Đăng xuất thất bại'));
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (googleAuthDataSource == null) {
      emit(const AuthError(message: 'Google Sign-In chưa được cấu hình'));
      return;
    }

    emit(AuthLoading());
    try {
      final result = await googleAuthDataSource!.signInWithGoogle();

      if (result.requiresEmailVerification) {
        emit(EmailVerificationRequired(
          email: result.user?.email ?? '',
          message: result.message ?? 'Vui lòng xác thực email trước khi đăng nhập',
        ));
        return;
      }
      
      if (!result.success) {
        emit(AuthError(message: result.message ?? 'Đăng nhập Google thất bại'));
        return;
      }

      // Check if 2FA is required
      if (result.requiresTwoFactor && result.twoFactorToken != null) {
        emit(TwoFactorRequired(
          twoFactorToken: result.twoFactorToken!,
          email: result.user?.email,
        ));
        return;
      }

      // Login successful
      if (result.user != null) {
        emit(Authenticated(user: result.user!.toEntity()));
        onSyncRequested?.call();
      } else {
        // Try to get user from API
        final user = await getCurrentUserUseCase();
        if (user != null) {
          emit(Authenticated(user: user));
          onSyncRequested?.call();
        } else {
          emit(const AuthError(message: 'Không lấy được thông tin người dùng'));
        }
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onGoogleLinkRequested(
    GoogleLinkRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (googleAuthDataSource == null) {
      emit(const AuthError(message: 'Google Sign-In chưa được cấu hình'));
      return;
    }

    emit(AuthLoading());
    try {
      final result = await googleAuthDataSource!.linkGoogleAccount();
      
      if (result.success) {
        // Refresh user data
        final user = await getCurrentUserUseCase();
        if (user != null) {
          emit(Authenticated(user: user));
        }
      } else {
        emit(AuthError(message: result.message ?? 'Không thể liên kết Google'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onGoogleUnlinkRequested(
    GoogleUnlinkRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (googleAuthDataSource == null) {
      emit(const AuthError(message: 'Google Sign-In chưa được cấu hình'));
      return;
    }

    final prevStateForUnlink = state;
    emit(AuthLoading());
    try {
      final result = await googleAuthDataSource!.unlinkGoogleAccount();
      
      if (result.success) {
        // Refresh user data
        final user = await getCurrentUserUseCase();
        if (user != null) {
          emit(Authenticated(user: user));
        }
      } else {
        if (prevStateForUnlink is Authenticated) {
          emit(prevStateForUnlink);
        }
        emit(AuthError(message: result.message ?? 'Không thể hủy liên kết Google'));
      }
    } catch (e) {
      if (prevStateForUnlink is Authenticated) {
        emit(prevStateForUnlink);
      }
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onTwoFactorSetupRequested(
    TwoFactorSetupRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (twoFactorDataSource == null) {
      emit(const AuthError(message: '2FA chưa được cấu hình'));
      return;
    }

    emit(AuthLoading());
    try {
      final result = await twoFactorDataSource!.setupTOTP();
      
      if (result.success && result.secret != null && result.qrCodeUrl != null) {
        emit(TwoFactorSetupInProgress(
          secret: result.secret!,
          qrCodeUrl: result.qrCodeUrl!,
          backupCodes: result.backupCodes ?? [],
        ));
      } else {
        emit(AuthError(message: result.errorMessage ?? 'Không thể thiết lập 2FA'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onVerifyTwoFactorSubmitted(
    VerifyTwoFactorSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    if (authRemoteDataSourceV2 == null) {
      emit(const AuthError(message: '2FA chưa được cấu hình'));
      return;
    }

    emit(AuthLoading());
    try {
      final result = await authRemoteDataSourceV2!.verifyTwoFactor(
        event.twoFactorToken,
        event.code,
        isSetup: event.isSetupConfirmation,
      );
      
      if (result.success) {
        if (event.isSetupConfirmation) {
          emit(const TwoFactorSetupSuccess(message: '2FA đã được bật thành công!'));
          // Refresh user data
          final user = await getCurrentUserUseCase();
          if (user != null) {
            emit(Authenticated(user: user));
          }
        } else {
          // Login successful after 2FA
          if (result.user != null) {
            emit(Authenticated(user: result.user!.toEntity()));
            onSyncRequested?.call();
          } else {
            final user = await getCurrentUserUseCase();
            if (user != null) {
              emit(Authenticated(user: user));
              onSyncRequested?.call();
            } else {
              emit(const AuthError(message: 'Không lấy được thông tin người dùng'));
            }
          }
        }
      } else {
        emit(AuthError(message: result.message ?? 'Mã OTP không đúng'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onTwoFactorDisableRequested(
    TwoFactorDisableRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (authRemoteDataSourceV2 == null) {
      emit(const AuthError(message: '2FA chưa được cấu hình'));
      return;
    }

    emit(AuthLoading());
    try {
      final success = await authRemoteDataSourceV2!.disableTwoFactor(event.code);
      
      if (success) {
        // Refresh user data
        final user = await getCurrentUserUseCase();
        if (user != null) {
          emit(Authenticated(user: user));
        }
      } else {
        emit(const AuthError(message: 'Mã OTP không đúng'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onSendEmailOtpRequested(
    SendEmailOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (authRemoteDataSourceV2 == null) {
      emit(const AuthError(message: 'Email OTP chưa được cấu hình'));
      return;
    }

    emit(AuthLoading());
    try {
      final success = await authRemoteDataSourceV2!.sendEmailOtp(event.email);
      
      if (success) {
        emit(EmailOtpSent(
          email: event.email,
          message: 'Mã OTP đã được gửi đến email của bạn',
        ));
      } else {
        emit(const AuthError(message: 'Không thể gửi mã OTP'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onVerifyEmailOtpSubmitted(
    VerifyEmailOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    if (authRemoteDataSourceV2 == null) {
      emit(const AuthError(message: 'Email OTP chưa được cấu hình'));
      return;
    }

    emit(AuthLoading());
    try {
      final result = await authRemoteDataSourceV2!.verifyEmailOtp(
        event.email,
        event.code,
      );
      
      if (result.success) {
        if (result.user != null) {
          emit(Authenticated(user: result.user!.toEntity()));
          onSyncRequested?.call();
        } else {
          final user = await getCurrentUserUseCase();
          if (user != null) {
            emit(Authenticated(user: user));
            onSyncRequested?.call();
          } else {
            emit(const AuthError(message: 'Không lấy được thông tin người dùng'));
          }
        }
      } else {
        emit(AuthError(message: result.message ?? 'Mã OTP không đúng'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onTokenRefreshRequested(
    TokenRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (authRemoteDataSourceV2 == null) {
      return;
    }

    try {
      final result = await authRemoteDataSourceV2!.refreshToken();
      
      if (!result.success) {
        // Token refresh failed, logout user
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(Unauthenticated());
    }
  }
}

import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final User user;

  const Authenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

/// State when session expired (different from normal logout)
/// This allows UI to show appropriate message
class SessionExpired extends AuthState {
  final String message;

  const SessionExpired({
    this.message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
  });

  @override
  List<Object?> get props => [message];
}

class AuthError extends AuthState {
  final String message;
  final bool isNetworkError;
  final bool isServerError;
  final int? statusCode;

  const AuthError({
    required this.message,
    this.isNetworkError = false,
    this.isServerError = false,
    this.statusCode,
  });

  @override
  List<Object?> get props => [message, isNetworkError, isServerError, statusCode];
}

// ===== Two-Factor Authentication States =====

/// State khi login thành công nhưng cần verify 2FA
class TwoFactorRequired extends AuthState {
  final String twoFactorToken;
  final String? email; // For email OTP

  const TwoFactorRequired({
    required this.twoFactorToken,
    this.email,
  });

  @override
  List<Object?> get props => [twoFactorToken, email];
}

/// State khi đang setup 2FA
class TwoFactorSetupInProgress extends AuthState {
  final String secret;
  final String qrCodeUrl;
  final List<String> backupCodes;

  const TwoFactorSetupInProgress({
    required this.secret,
    required this.qrCodeUrl,
    required this.backupCodes,
  });

  @override
  List<Object?> get props => [secret, qrCodeUrl, backupCodes];
}

/// State khi 2FA setup thành công
class TwoFactorSetupSuccess extends AuthState {
  final String message;

  const TwoFactorSetupSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

// ===== Email OTP States =====

class EmailOtpSent extends AuthState {
  final String email;
  final String message;

  const EmailOtpSent({required this.email, required this.message});

  @override
  List<Object?> get props => [email, message];
}

// ===== Email Verification States =====

/// State khi đăng ký thành công và cần xác thực email
class EmailVerificationRequired extends AuthState {
  final String email;
  final String message;

  const EmailVerificationRequired({
    required this.email,
    required this.message,
  });

  @override
  List<Object?> get props => [email, message];
}

/// State khi email verification link đã gửi lại thành công
class EmailVerificationResent extends AuthState {
  final String email;
  final String message;

  const EmailVerificationResent({
    required this.email,
    required this.message,
  });

  @override
  List<Object?> get props => [email, message];
}

/// State khi xác thực email thành công
class EmailVerificationSuccess extends AuthState {
  final String message;

  const EmailVerificationSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

/// State khi đăng ký thành công và yêu cầu đăng nhập lại
class RegistrationSuccess extends AuthState {
  final String message;

  const RegistrationSuccess({this.message = 'Đăng ký thành công, vui lòng đăng nhập'});

  @override
  List<Object?> get props => [message];
}

// ===== Subscription States =====

/// State khi đang verify purchase
class PurchaseVerifying extends AuthState {}

/// State khi verify purchase thành công
class PurchaseVerified extends AuthState {
  final bool isPremium;
  final DateTime? expiryDate;
  final String message;

  const PurchaseVerified({
    required this.isPremium,
    this.expiryDate,
    required this.message,
  });

  @override
  List<Object?> get props => [isPremium, expiryDate, message];
}

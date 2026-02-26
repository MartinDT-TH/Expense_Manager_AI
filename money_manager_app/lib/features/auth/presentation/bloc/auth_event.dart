import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

// ===== Basic Auth =====

class LoginSubmitted extends AuthEvent {
  final String email;
  final String password;

  const LoginSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class RegisterSubmitted extends AuthEvent {
  final String email;
  final String password;
  final String fullName;

  const RegisterSubmitted({
    required this.email,
    required this.password,
    required this.fullName,
  });

  @override
  List<Object?> get props => [email, password, fullName];
}

class ForgotPasswordSubmitted extends AuthEvent {
  final String email;

  const ForgotPasswordSubmitted({required this.email});

  @override
  List<Object?> get props => [email];
}

class LogoutRequested extends AuthEvent {}

// ===== Google OAuth =====

class GoogleSignInRequested extends AuthEvent {}

class GoogleLinkRequested extends AuthEvent {}

class GoogleUnlinkRequested extends AuthEvent {}

// ===== Two-Factor Authentication =====

class TwoFactorSetupRequested extends AuthEvent {}

class VerifyTwoFactorSubmitted extends AuthEvent {
  final String twoFactorToken;
  final String code;
  final bool isSetupConfirmation;

  const VerifyTwoFactorSubmitted({
    required this.twoFactorToken,
    required this.code,
    this.isSetupConfirmation = false,
  });

  @override
  List<Object?> get props => [twoFactorToken, code, isSetupConfirmation];
}

class TwoFactorDisableRequested extends AuthEvent {
  final String code;

  const TwoFactorDisableRequested({required this.code});

  @override
  List<Object?> get props => [code];
}

// ===== Email OTP =====

class SendEmailOtpRequested extends AuthEvent {
  final String email;

  const SendEmailOtpRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class VerifyEmailOtpSubmitted extends AuthEvent {
  final String email;
  final String code;

  const VerifyEmailOtpSubmitted({required this.email, required this.code});

  @override
  List<Object?> get props => [email, code];
}

// ===== Token Management =====

class TokenRefreshRequested extends AuthEvent {}

/// Event fired when session expires (from ApiClient interceptor)
class SessionExpiredEvent extends AuthEvent {
  final String? message;

  const SessionExpiredEvent({this.message});

  @override
  List<Object?> get props => [message];
}

// ===== Email Verification =====

class ResendVerificationEmailRequested extends AuthEvent {
  final String email;

  const ResendVerificationEmailRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class ConfirmEmailRequested extends AuthEvent {
  final String token;
  final String email;

  const ConfirmEmailRequested({required this.token, required this.email});

  @override
  List<Object?> get props => [token, email];
}

// ===== Subscription/Premium =====

class VerifyGooglePlayPurchaseRequested extends AuthEvent {
  final String purchaseToken;
  final String productId;
  final String packageName;
  final String? orderId;

  const VerifyGooglePlayPurchaseRequested({
    required this.purchaseToken,
    required this.productId,
    required this.packageName,
    this.orderId,
  });

  @override
  List<Object?> get props => [purchaseToken, productId, packageName, orderId];
}

class CheckSubscriptionStatusRequested extends AuthEvent {}

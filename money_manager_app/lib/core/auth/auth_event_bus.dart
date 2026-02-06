import 'dart:async';

/// Error codes for different auth failure scenarios
enum AuthErrorCode {
  tokenExpired,
  tokenInvalid,
  refreshFailed,
  sessionExpired,
  unauthorized,
  forbidden,
  networkError,
  serverError,
  timeout,
  invalidOtp,
  tooManyAttempts,
  unknown,
}

/// Event fired when auth-related error occurs
class AuthErrorEvent {
  final AuthErrorCode code;
  final String message;
  final bool shouldLogout;
  final int? statusCode;
  final dynamic originalError;

  const AuthErrorEvent({
    required this.code,
    required this.message,
    this.shouldLogout = false,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'AuthErrorEvent(code: $code, message: $message, shouldLogout: $shouldLogout)';
}

/// Singleton event bus for auth-related events
/// Allows ApiClient to communicate with AuthBloc without direct dependency
class AuthEventBus {
  AuthEventBus._();
  static final AuthEventBus instance = AuthEventBus._();

  final _controller = StreamController<AuthErrorEvent>.broadcast();
  
  /// Stream of auth error events
  Stream<AuthErrorEvent> get stream => _controller.stream;

  /// Fire an auth error event
  void fire(AuthErrorEvent event) {
    _controller.add(event);
  }

  /// Convenience method for session expiry
  void fireSessionExpired({String? message}) {
    fire(AuthErrorEvent(
      code: AuthErrorCode.sessionExpired,
      message: message ?? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      shouldLogout: true,
      statusCode: 401,
    ));
  }

  /// Convenience method for network errors (don't logout)
  void fireNetworkError({String? message}) {
    fire(AuthErrorEvent(
      code: AuthErrorCode.networkError,
      message: message ?? 'Không có kết nối mạng. Vui lòng kiểm tra lại.',
      shouldLogout: false,
    ));
  }

  /// Convenience method for server errors (don't logout)
  void fireServerError({String? message, int? statusCode}) {
    fire(AuthErrorEvent(
      code: AuthErrorCode.serverError,
      message: message ?? 'Lỗi server. Vui lòng thử lại sau.',
      shouldLogout: false,
      statusCode: statusCode,
    ));
  }

  void dispose() {
    _controller.close();
  }
}

/// Error codes for categorizing exceptions
enum AppErrorCode {
  // Network errors
  networkError,
  timeout,
  connectionRefused,
  
  // Auth errors
  unauthorized,
  tokenExpired,
  tokenInvalid,
  refreshFailed,
  invalidCredentials,
  invalidOtp,
  tooManyAttempts,
  
  // Permission errors
  forbidden,
  
  // Server errors
  serverError,
  notFound,
  
  // Validation errors
  validationError,
  
  // Cache errors
  cacheError,
  
  // Unknown
  unknown,
}

class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  final AppErrorCode errorCode;

  AppException({
    required this.message,
    this.statusCode,
    this.data,
    this.errorCode = AppErrorCode.unknown,
  });

  /// Whether this error should trigger a logout
  bool get shouldLogout => errorCode == AppErrorCode.tokenExpired ||
      errorCode == AppErrorCode.tokenInvalid ||
      errorCode == AppErrorCode.refreshFailed;

  /// Whether this is a network-related error
  bool get isNetworkError => errorCode == AppErrorCode.networkError ||
      errorCode == AppErrorCode.timeout ||
      errorCode == AppErrorCode.connectionRefused;

  /// Whether this is a server-side error
  bool get isServerError => errorCode == AppErrorCode.serverError;

  @override
  String toString() => message;
}

class ServerException extends AppException {
  ServerException({
    required super.message,
    super.statusCode,
    super.data,
    super.errorCode = AppErrorCode.serverError,
  });
}

class NetworkException extends AppException {
  NetworkException({
    super.message = 'Không có kết nối mạng',
    super.statusCode,
    super.errorCode = AppErrorCode.networkError,
  });
}

class TimeoutException extends AppException {
  TimeoutException({
    super.message = 'Kết nối quá thời gian. Vui lòng thử lại.',
    super.statusCode,
    super.errorCode = AppErrorCode.timeout,
  });
}

class CacheException extends AppException {
  CacheException({
    super.message = 'Lỗi dữ liệu cục bộ',
    super.statusCode,
    super.errorCode = AppErrorCode.cacheError,
  });
}

class AuthException extends AppException {
  AuthException({
    super.message = 'Lỗi xác thực',
    super.statusCode,
    super.errorCode = AppErrorCode.unauthorized,
  });
}

class TokenExpiredException extends AuthException {
  TokenExpiredException({
    super.message = 'Phiên đăng nhập đã hết hạn.',
    super.statusCode = 401,
    super.errorCode = AppErrorCode.tokenExpired,
  });
}

class RefreshTokenFailedException extends AuthException {
  RefreshTokenFailedException({
    super.message = 'Không thể làm mới phiên đăng nhập. Vui lòng đăng nhập lại.',
    super.statusCode = 401,
    super.errorCode = AppErrorCode.refreshFailed,
  });
}

class ForbiddenException extends AppException {
  ForbiddenException({
    super.message = 'Bạn không có quyền truy cập.',
    super.statusCode = 403,
    super.errorCode = AppErrorCode.forbidden,
  });
}

class ValidationException extends AppException {
  final Map<String, List<String>>? errors;
  ValidationException({
    required super.message,
    this.errors,
    super.statusCode,
    super.errorCode = AppErrorCode.validationError,
  });
}

class InvalidOtpException extends AppException {
  InvalidOtpException({
    super.message = 'Mã OTP không đúng hoặc đã hết hạn.',
    super.statusCode = 400,
    super.errorCode = AppErrorCode.invalidOtp,
  });
}

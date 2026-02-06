import 'dart:async';
import 'package:dio/dio.dart';
import '../auth/token_storage.dart';
import '../auth/auth_event_bus.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart';

class ApiClient {
  late Dio _dio;
  final TokenStorage _tokenStorage = const TokenStorage();
  Completer<String?>? _refreshCompleter;
  bool _isRefreshing = false;

  Dio get dio => _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        // Dùng IP thật - hoạt động cho cả emulator và thiết bị thật
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final skipAuth = options.extra['skipAuth'] == true;
        if (!skipAuth) {
          final token = await _tokenStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final path = error.requestOptions.path;
        final isRetried = error.requestOptions.extra['retried'] == true;
        
        // Handle 401 - Unauthorized
        if (statusCode == 401 && !_isAuthEndpoint(path) && !isRetried) {
          final retried = await _tryRefreshAndRetry(error);
          if (retried != null) {
            return handler.resolve(retried);
          }
          // Refresh failed - clear tokens and notify
          await _handleSessionExpired();
          return handler.next(error);
        }
        
        // For other errors, just pass through
        // The error will be converted to AppException in _handleError
        return handler.next(error);
      },
    ));
  }

  /// Handle session expiry - clear tokens and notify listeners
  Future<void> _handleSessionExpired() async {
    await _tokenStorage.clearTokens();
    AuthEventBus.instance.fireSessionExpired();
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  AppException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        final exception = TimeoutException(
          message: 'Kết nối quá thời gian. Vui lòng thử lại.',
        );
        // Notify for timeout but DON'T logout
        AuthEventBus.instance.fire(AuthErrorEvent(
          code: AuthErrorCode.timeout,
          message: exception.message,
          shouldLogout: false,
        ));
        return exception;
        
      case DioExceptionType.connectionError:
        final exception = NetworkException(
          message: 'Không có kết nối mạng. Vui lòng kiểm tra lại.',
        );
        // Notify for network error but DON'T logout
        AuthEventBus.instance.fireNetworkError(message: exception.message);
        return exception;
        
      case DioExceptionType.badResponse:
        return _handleResponseError(error.response);
        
      case DioExceptionType.cancel:
        return ServerException(
          message: 'Yêu cầu đã bị hủy.',
          errorCode: AppErrorCode.unknown,
        );
        
      default:
        return ServerException(
          message: 'Lỗi kết nối đến server.',
          errorCode: AppErrorCode.networkError,
        );
    }
  }

  AppException _handleResponseError(Response? response) {
    final statusCode = response?.statusCode ?? 500;
    final data = response?.data;

    String message = 'Đã xảy ra lỗi. Vui lòng thử lại.';
    String? errorCode;
    
    if (data is Map<String, dynamic>) {
      message = data['message'] ?? data['title'] ?? message;
      errorCode = data['errorCode'] as String?;
      
      // Handle validation errors
      if (data['errors'] != null) {
        return ValidationException(
          message: message,
          errors: Map<String, List<String>>.from(
            (data['errors'] as Map).map(
              (key, value) => MapEntry(key, List<String>.from(value)),
            ),
          ),
          statusCode: statusCode,
        );
      }
      
      // Check for specific error codes from backend
      if (errorCode != null) {
        return _mapErrorCodeToException(errorCode, message, statusCode);
      }
    }

    switch (statusCode) {
      case 400:
        // Check if it's OTP-related
        if (message.toLowerCase().contains('otp')) {
          return InvalidOtpException(message: message);
        }
        return ValidationException(
          message: message,
          statusCode: statusCode,
          errorCode: AppErrorCode.validationError,
        );
        
      case 401:
        // Don't fire event here - interceptor already handles 401
        return TokenExpiredException(message: message);
        
      case 403:
        return ForbiddenException(message: message);
        
      case 404:
        return ServerException(
          message: 'Không tìm thấy dữ liệu.',
          statusCode: statusCode,
          errorCode: AppErrorCode.notFound,
        );
        
      case 429:
        final exception = ServerException(
          message: 'Quá nhiều yêu cầu. Vui lòng thử lại sau.',
          statusCode: statusCode,
          errorCode: AppErrorCode.tooManyAttempts,
        );
        AuthEventBus.instance.fire(AuthErrorEvent(
          code: AuthErrorCode.tooManyAttempts,
          message: exception.message,
          shouldLogout: false,
          statusCode: statusCode,
        ));
        return exception;
        
      case 500:
      case 502:
      case 503:
        final exception = ServerException(
          message: 'Lỗi server. Vui lòng thử lại sau.',
          statusCode: statusCode,
          errorCode: AppErrorCode.serverError,
        );
        // Notify for server error but DON'T logout
        AuthEventBus.instance.fireServerError(
          message: exception.message,
          statusCode: statusCode,
        );
        return exception;
        
      default:
        return ServerException(
          message: message,
          statusCode: statusCode,
          errorCode: AppErrorCode.unknown,
        );
    }
  }

  /// Map backend error codes to specific exceptions
  AppException _mapErrorCodeToException(String code, String message, int statusCode) {
    switch (code) {
      case 'INVALID_OTP':
      case 'OTP_EXPIRED':
        return InvalidOtpException(message: message);
      case 'TOKEN_EXPIRED':
        return TokenExpiredException(message: message);
      case 'TOKEN_INVALID':
        return AuthException(
          message: message,
          statusCode: statusCode,
          errorCode: AppErrorCode.tokenInvalid,
        );
      case 'INVALID_CREDENTIALS':
        return AuthException(
          message: message,
          statusCode: statusCode,
          errorCode: AppErrorCode.invalidCredentials,
        );
      case 'TOO_MANY_ATTEMPTS':
        return ServerException(
          message: message,
          statusCode: statusCode,
          errorCode: AppErrorCode.tooManyAttempts,
        );
      default:
        return ServerException(
          message: message,
          statusCode: statusCode,
          errorCode: AppErrorCode.unknown,
        );
    }
  }

  Future<void> saveToken(String token) async {
    await _tokenStorage.saveTokens(accessToken: token);
  }

  Future<String?> getToken() async {
    return _tokenStorage.getAccessToken();
  }

  Future<void> clearToken() async {
    await _tokenStorage.clearTokens();
  }

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiry,
  }) async {
    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiry: expiry,
    );
  }

  Future<String?> getRefreshToken() async {
    return _tokenStorage.getRefreshToken();
  }

  bool _isAuthEndpoint(String path) {
    final normalized = path.toLowerCase();
    return normalized.contains('/auth/login') ||
        normalized.contains('/auth/register') ||
        normalized.contains('/auth/refresh-token') ||
        normalized.contains('/auth/forgot-password');
  }

  Future<Response?> _tryRefreshAndRetry(DioException error) async {
    // Prevent concurrent refresh attempts
    if (_isRefreshing) {
      // Wait for ongoing refresh
      if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
        final token = await _refreshCompleter!.future;
        if (token != null && token.isNotEmpty) {
          return _retryRequest(error, token);
        }
        return null;
      }
      return null;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(null);
        _isRefreshing = false;
        return null;
      }

      final refreshResponse = await _dio.post(
        '/Auth/refresh-token',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );

      final data = refreshResponse.data;
      if (data is! Map<String, dynamic>) {
        _refreshCompleter!.complete(null);
        _isRefreshing = false;
        return null;
      }

      // Check if refresh was successful
      final success = data['success'] as bool? ?? true;
      if (!success) {
        _refreshCompleter!.complete(null);
        _isRefreshing = false;
        return null;
      }

      final accessToken =
          data['accessToken'] ?? data['token'] ?? data['access_token'];
      final newRefreshToken =
          data['refreshToken'] ?? data['refresh_token'] ?? refreshToken;
      final expiresIn = data['expiresIn'] ?? data['expires_in'];
      final expiry = _parseExpiry(expiresIn);

      if (accessToken is! String || accessToken.isEmpty) {
        _refreshCompleter!.complete(null);
        _isRefreshing = false;
        return null;
      }

      await _tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken is String ? newRefreshToken : null,
        expiry: expiry,
      );
      _refreshCompleter!.complete(accessToken);
      _isRefreshing = false;

      return _retryRequest(error, accessToken);
    } catch (e) {
      _refreshCompleter!.complete(null);
      _isRefreshing = false;
      return null;
    }
  }

  /// Retry the original request with new token
  Future<Response?> _retryRequest(DioException error, String token) async {
    final request = error.requestOptions;
    final options = Options(
      method: request.method,
      headers: Map<String, dynamic>.from(request.headers)
        ..['Authorization'] = 'Bearer $token',
    );

    try {
      return await _dio.request(
        request.path,
        data: request.data,
        queryParameters: request.queryParameters,
        options: options..extra = {...request.extra, 'retried': true},
      );
    } catch (e) {
      return null;
    }
  }

  DateTime? _parseExpiry(dynamic expiresIn) {
    if (expiresIn == null) return null;
    if (expiresIn is int) {
      return DateTime.now().add(Duration(seconds: expiresIn));
    }
    if (expiresIn is String) {
      final asInt = int.tryParse(expiresIn);
      if (asInt != null) {
        return DateTime.now().add(Duration(seconds: asInt));
      }
      return DateTime.tryParse(expiresIn);
    }
    return null;
  }
}

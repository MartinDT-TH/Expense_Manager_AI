import 'dart:async';
import 'package:dio/dio.dart';
import '../auth/token_storage.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart';

class ApiClient {
  late Dio _dio;
  final TokenStorage _tokenStorage = const TokenStorage();
  Completer<String?>? _refreshCompleter;

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
        if (error.response?.statusCode == 401 &&
            !_isAuthEndpoint(error.requestOptions.path) &&
            !(error.requestOptions.extra['retried'] == true)) {
          final retried = await _tryRefreshAndRetry(error);
          if (retried != null) {
            return handler.resolve(retried);
          }
          await _tokenStorage.clearTokens();
        }
        return handler.next(error);
      },
    ));
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
        return NetworkException(message: 'Kết nối quá thời gian. Vui lòng thử lại.');
      case DioExceptionType.connectionError:
        return NetworkException();
      case DioExceptionType.badResponse:
        return _handleResponseError(error.response);
      case DioExceptionType.cancel:
        return ServerException(message: 'Yêu cầu đã bị hủy.');
      default:
        return ServerException(message: 'Lỗi kết nối đến server.');
    }
  }

  AppException _handleResponseError(Response? response) {
    final statusCode = response?.statusCode ?? 500;
    final data = response?.data;

    String message = 'Đã xảy ra lỗi. Vui lòng thử lại.';
    if (data is Map<String, dynamic>) {
      message = data['message'] ?? data['title'] ?? message;
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
    }

    switch (statusCode) {
      case 400:
        return ValidationException(message: message, statusCode: statusCode);
      case 401:
        return AuthException(message: 'Phiên đăng nhập đã hết hạn.');
      case 403:
        return ServerException(message: 'Bạn không có quyền truy cập.', statusCode: statusCode);
      case 404:
        return ServerException(message: 'Không tìm thấy dữ liệu.', statusCode: statusCode);
      case 500:
        return ServerException(message: 'Lỗi server. Vui lòng thử lại sau.', statusCode: statusCode);
      default:
        return ServerException(message: message, statusCode: statusCode);
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
    _refreshCompleter ??= Completer<String?>();
    if (!_refreshCompleter!.isCompleted) {
      try {
        final refreshToken = await _tokenStorage.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          _refreshCompleter!.complete(null);
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
          return null;
        }

        await _tokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: newRefreshToken is String ? newRefreshToken : null,
          expiry: expiry,
        );
        _refreshCompleter!.complete(accessToken);
      } catch (_) {
        _refreshCompleter!.complete(null);
      }
    }

    final token = await _refreshCompleter!.future;
    _refreshCompleter = null;
    if (token == null || token.isEmpty) {
      return null;
    }

    final request = error.requestOptions;
    final options = Options(
      method: request.method,
      headers: Map<String, dynamic>.from(request.headers)
        ..['Authorization'] = 'Bearer $token',
    );

    return _dio.request(
      request.path,
      data: request.data,
      queryParameters: request.queryParameters,
      options: options..extra = {...request.extra, 'retried': true},
    );
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

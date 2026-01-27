class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  AppException({required this.message, this.statusCode, this.data});

  @override
  String toString() => message;
}

class ServerException extends AppException {
  ServerException({required super.message, super.statusCode, super.data});
}

class NetworkException extends AppException {
  NetworkException({super.message = 'Không có kết nối mạng', super.statusCode});
}

class CacheException extends AppException {
  CacheException({super.message = 'Lỗi dữ liệu cục bộ', super.statusCode});
}

class AuthException extends AppException {
  AuthException({super.message = 'Lỗi xác thực', super.statusCode});
}

class ValidationException extends AppException {
  final Map<String, List<String>>? errors;
  ValidationException({required super.message, this.errors, super.statusCode});
}

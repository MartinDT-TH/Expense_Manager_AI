abstract class Failure {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Không có kết nối mạng. Vui lòng kiểm tra lại.', super.statusCode});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Lỗi dữ liệu cục bộ.', super.statusCode});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'Không tìm thấy dữ liệu.', super.statusCode});
}

class AuthFailure extends Failure {
  const AuthFailure({super.message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.', super.statusCode});
}

class ValidationFailure extends Failure {
  final Map<String, List<String>>? errors;
  const ValidationFailure({required super.message, this.errors, super.statusCode});
}

class PermissionFailure extends Failure {
  const PermissionFailure({super.message = 'Bạn không có quyền thực hiện thao tác này.', super.statusCode});
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'Đã xảy ra lỗi. Vui lòng thử lại.', super.statusCode});
}

class RegisterRequest {
  final String email;
  final String password;
  final String? fullName;

  RegisterRequest({
    required this.email,
    required this.password,
    this.fullName,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      if (fullName != null) 'fullName': fullName,
    };
  }
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class RefreshTokenRequest {
  final String refreshToken;

  RefreshTokenRequest({required this.refreshToken});

  Map<String, dynamic> toJson() {
    return {
      'refreshToken': refreshToken,
    };
  }
}


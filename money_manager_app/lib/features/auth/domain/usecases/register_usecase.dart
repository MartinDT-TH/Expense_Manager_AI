import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<AuthResult> call(String email, String password, String fullName) {
    return repository.register(email, password, fullName);
  }
}

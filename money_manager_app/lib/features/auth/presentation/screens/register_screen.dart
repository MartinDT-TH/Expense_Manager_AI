import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_text_field.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(RegisterSubmitted(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          } else if (state is EmailVerificationRequired) {
            // Navigate to email verification screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<AuthBloc>(),
                  child: EmailVerificationScreen(email: state.email),
                ),
              ),
            );
          } else if (state is RegistrationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            // Quay về màn hình đăng nhập
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (state is Authenticated) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tạo tài khoản',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng ký để quản lý chi tiêu hiệu quả',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: secondaryTextColor,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Full Name Field
                  AuthTextField(
                    controller: _fullNameController,
                    labelText: 'Họ và tên',
                    hintText: 'Nhập họ và tên',
                    prefixIcon: Icons.person_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập họ và tên';
                      }
                      if (value.length < 2) {
                        return 'Họ tên quá ngắn';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  AuthTextField(
                    controller: _emailController,
                    labelText: 'Email',
                    hintText: 'Nhập email của bạn',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập email';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  AuthTextField(
                    controller: _passwordController,
                    labelText: 'Mật khẩu',
                    hintText: 'Nhập mật khẩu',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outlined,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: secondaryTextColor,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      if (value.length < 6) {
                        return 'Mật khẩu phải có ít nhất 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  AuthTextField(
                    controller: _confirmPasswordController,
                    labelText: 'Xác nhận mật khẩu',
                    hintText: 'Nhập lại mật khẩu',
                    obscureText: _obscureConfirmPassword,
                    prefixIcon: Icons.lock_outlined,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: secondaryTextColor,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng xác nhận mật khẩu';
                      }
                      if (value != _passwordController.text) {
                        return 'Mật khẩu không khớp';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Register Button
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return ElevatedButton(
                        onPressed: state is AuthLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: state is AuthLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Đăng ký',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Terms
                  Text(
                    'Bằng việc đăng ký, bạn đồng ý với Điều khoản dịch vụ và Chính sách bảo mật của chúng tôi',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondaryTextColor,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

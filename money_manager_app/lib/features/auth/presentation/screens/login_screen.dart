import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_text_field.dart';
import 'register_screen.dart';
import 'otp_verification_screen.dart';
import 'email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(LoginSubmitted(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ));
    }
  }

  void _forgotPassword() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email để khôi phục mật khẩu')),
      );
      return;
    }
    context.read<AuthBloc>().add(ForgotPasswordSubmitted(email: email));
  }

  void _googleSignIn() {
    context.read<AuthBloc>().add(GoogleSignInRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<AuthBloc>(),
                  child: EmailVerificationScreen(email: state.email),
                ),
              ),
            );
          } else if (state is TwoFactorRequired) {
            // Navigate to OTP verification screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<AuthBloc>(),
                  child: OtpVerificationScreen(
                    twoFactorToken: state.twoFactorToken,
                    email: state.email,
                  ),
                ),
              ),
            );
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Icon(
                      Icons.account_balance_wallet,
                      size: 80,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Smart Money',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quản lý chi tiêu thông minh',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

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
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white60 
                              : AppColors.textSecondary,
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
                    const SizedBox(height: 8),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Login Button
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return ElevatedButton(
                          onPressed: state is AuthLoading ? null : _login,
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
                                  'Đăng nhập',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'hoặc',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white60 
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Google Sign-In Button
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return OutlinedButton.icon(
                          onPressed: state is AuthLoading ? null : _googleSignIn,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white30
                                  : Colors.grey.shade300,
                            ),
                          ),
                          icon: Image.network(
                            'https://www.google.com/favicon.ico',
                            height: 24,
                            width: 24,
                            errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
                          ),
                          label: Text(
                            'Đăng nhập với Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Chưa có tài khoản? ',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white70 
                                : AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: const Text('Đăng ký ngay'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

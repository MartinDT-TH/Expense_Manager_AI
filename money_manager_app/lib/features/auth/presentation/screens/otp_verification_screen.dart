import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// OTP Verification Screen
/// Hiển thị khi user bật 2FA và cần nhập OTP code
class OtpVerificationScreen extends StatefulWidget {
  final String twoFactorToken;
  final String? email;
  final bool isEmailOtp;

  const OtpVerificationScreen({
    super.key,
    required this.twoFactorToken,
    this.email,
    this.isEmailOtp = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = 
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = 
      List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          } else if (state is AuthError) {
            setState(() {
              _isLoading = false;
              _errorMessage = state.message;
            });
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Icon(
                  Icons.security,
                  size: 64,
                  color: Color(0xFF6C5CE7),
                ),
                const SizedBox(height: 24),
                
                Text(
                  widget.isEmailOtp ? 'Xác thực OTP Email' : 'Xác thực hai lớp',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                
                Text(
                  widget.isEmailOtp
                      ? 'Nhập mã 6 số đã gửi tới ${widget.email}'
                      : 'Nhập mã 6 số từ ứng dụng xác thực',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : const Color(0xFF636E72),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // OTP Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 50,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF6C5CE7),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          }
                          if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          
                          // Auto-submit when all digits entered
                          if (_otpCode.length == 6) {
                            _verifyOtp();
                          }
                          
                          // Clear error when typing
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                      ),
                    );
                  }),
                ),
                
                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading || _otpCode.length != 6 ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Xác thực',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Resend / Use backup code options
                if (widget.isEmailOtp) ...[
                  Center(
                    child: TextButton(
                      onPressed: _resendEmailOtp,
                      child: const Text(
                        'Gửi lại mã',
                        style: TextStyle(
                          color: Color(0xFF6C5CE7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Center(
                    child: TextButton(
                      onPressed: _useBackupCode,
                      child: const Text(
                        'Dùng mã dự phòng',
                        style: TextStyle(
                          color: Color(0xFF6C5CE7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _verifyOtp() {
    if (_otpCode.length != 6) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.isEmailOtp && widget.email != null) {
      context.read<AuthBloc>().add(
        VerifyEmailOtpSubmitted(email: widget.email!, code: _otpCode),
      );
    } else {
      context.read<AuthBloc>().add(
        VerifyTwoFactorSubmitted(
          twoFactorToken: widget.twoFactorToken,
          code: _otpCode,
        ),
      );
    }
  }

  void _resendEmailOtp() {
    if (widget.email != null) {
      context.read<AuthBloc>().add(SendEmailOtpRequested(email: widget.email!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi lại mã OTP')),
      );
    }
  }

  void _useBackupCode() {
    // Show dialog to enter backup code
    showDialog(
      context: context,
      builder: (context) => _BackupCodeDialog(
        onSubmit: (code) {
          Navigator.pop(context);
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });
          
          context.read<AuthBloc>().add(
            VerifyTwoFactorSubmitted(
              twoFactorToken: widget.twoFactorToken,
              code: code,
            ),
          );
        },
      ),
    );
  }
}

class _BackupCodeDialog extends StatefulWidget {
  final Function(String) onSubmit;

  const _BackupCodeDialog({required this.onSubmit});

  @override
  State<_BackupCodeDialog> createState() => _BackupCodeDialogState();
}

class _BackupCodeDialogState extends State<_BackupCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nhập mã dự phòng'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        maxLength: 8,
        decoration: const InputDecoration(
          hintText: 'Mã dự phòng 8 chữ số',
          counterText: '',
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.length == 8) {
              widget.onSubmit(_controller.text);
            }
          },
          child: const Text('Xác thực'),
        ),
      ],
    );
  }
}

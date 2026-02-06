import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/image_picker_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/screens/two_factor_setup_screen.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import 'change_password_screen.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  String? _avatarUrl;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    
    // Load profile data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileBloc>().add(LoadProfile());
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _updateFormFromProfile(profile) {
    _fullNameController.text = profile.fullName ?? '';
    _phoneController.text = profile.phone ?? '';
    _addressController.text = profile.address ?? '';
    _avatarUrl = profile.avatarUrl;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return MultiBlocListener(
      listeners: [
        BlocListener<ProfileBloc, ProfileState>(
          listener: (context, state) {
            if (state is ProfileLoading) {
              setState(() => _isLoading = true);
            } else if (state is ProfileLoaded) {
              setState(() => _isLoading = false);
              _updateFormFromProfile(state.profile);
            } else if (state is ProfileUpdated) {
              setState(() => _isLoading = false);
              _updateFormFromProfile(state.profile);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is ProfileError) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthLoading) {
              setState(() => _isLoading = true);
            } else if (state is Authenticated) {
              setState(() => _isLoading = false);
              // Refresh profile data
              context.read<ProfileBloc>().add(LoadProfile());
            } else if (state is AuthError) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
        appBar: AppBar(
          backgroundColor: const Color(0xFF6C5CE7),
          elevation: 0,
          title: const Text(
            'Chỉnh sửa hồ sơ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: const Text(
                'Lưu',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        body: _isLoading && _fullNameController.text.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Avatar Section
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Colors.purple.shade300, Colors.purple.shade600],
                                ),
                                image: _avatarUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_avatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _isUploadingAvatar
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    )
                                  : _avatarUrl == null
                                      ? Center(
                                          child: Text(
                                            _fullNameController.text.isNotEmpty
                                                ? _fullNameController.text[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 48,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _isUploadingAvatar ? null : _pickImage,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C5CE7),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Form Fields
                      _buildTextField(
                        controller: _fullNameController,
                        label: 'Họ và tên',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập họ tên';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Số điện thoại',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _addressController,
                        label: 'Địa chỉ',
                        icon: Icons.location_on,
                        maxLines: 2,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Change Password Button
                      _buildActionButton(
                        icon: Icons.lock_outline,
                        title: 'Đổi mật khẩu',
                        onTap: _changePassword,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Setup 2FA Button
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          final isTwoFactorEnabled = state is Authenticated 
                              ? state.user.twoFactorEnabled 
                              : false;
                          return _buildActionButton(
                            icon: Icons.security,
                            title: isTwoFactorEnabled 
                                ? 'Xác thực 2 bước (Đã bật)'
                                : 'Thiết lập xác thực 2 bước',
                            subtitle: isTwoFactorEnabled
                                ? 'Tài khoản của bạn đã được bảo vệ'
                                : 'Tăng cường bảo mật cho tài khoản',
                            onTap: () => _setup2FA(isTwoFactorEnabled),
                            trailing: isTwoFactorEnabled
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                          );
                        },
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Link Google Account Button
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          final isGoogleLinked = state is Authenticated 
                              ? state.user.isGoogleLinked 
                              : false;
                          final googleEmail = state is Authenticated 
                              ? state.user.googleEmail 
                              : null;
                          return _buildActionButton(
                            icon: Icons.g_mobiledata,
                            title: isGoogleLinked 
                                ? 'Đã liên kết Google'
                                : 'Liên kết tài khoản Google',
                            subtitle: isGoogleLinked 
                                ? googleEmail ?? 'Đã kết nối'
                                : 'Đăng nhập nhanh hơn với Google',
                            onTap: () => _toggleGoogleLink(isGoogleLinked),
                            trailing: isGoogleLinked
                                ? const Icon(Icons.link_off, color: Colors.red)
                                : const Icon(Icons.link, color: Color(0xFF6C5CE7)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6C5CE7)),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF6C5CE7), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF2D3436),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF636E72),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    // Show options dialog
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Máy ảnh'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Thư viện'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );
    
    if (source == null) return;
    
    setState(() => _isUploadingAvatar = true);
    
    try {
      final imagePickerService = sl<ImagePickerService>();
      final result = source == 'camera'
          ? await imagePickerService.pickAndUploadFromCamera(folder: 'avatars')
          : await imagePickerService.pickAndUploadFromGallery(folder: 'avatars');
      
      if (result != null && result.secureUrl != null) {
        // Update avatar via API
        context.read<ProfileBloc>().add(UpdateAvatar(avatarUrl: result.secureUrl!));
        setState(() => _avatarUrl = result.secureUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    context.read<ProfileBloc>().add(UpdateProfile(
      fullName: _fullNameController.text,
      phone: _phoneController.text,
      address: _addressController.text,
    ));
  }

  void _changePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BlocProvider.value(
        value: context.read<ProfileBloc>(),
        child: const ChangePasswordScreen(),
      )),
    );
  }

  void _setup2FA(bool isEnabled) async {
    if (isEnabled) {
      // Show dialog to disable 2FA
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tắt 2FA'),
          content: const Text(
            'Bạn có chắc muốn tắt xác thực 2 bước không? '
            'Thao tác này sẽ làm tài khoản kém an toàn hơn.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Tắt'),
            ),
          ],
        ),
      );
      
      if (result == true) {
        // Show OTP input dialog
        _showDisable2FADialog();
      }
    } else {
      // Navigate to 2FA setup screen
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => BlocProvider.value(
          value: context.read<AuthBloc>(),
          child: const TwoFactorSetupScreen(),
        )),
      );
      
      if (result == true && mounted) {
        // Refresh auth state
        context.read<AuthBloc>().add(AppStarted());
      }
    }
  }

  void _showDisable2FADialog() {
    final codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập mã OTP'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: 'Nhập mã 6 chữ số',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              if (codeController.text.length == 6) {
                Navigator.pop(context);
                this.context.read<AuthBloc>().add(
                  TwoFactorDisableRequested(code: codeController.text),
                );
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _toggleGoogleLink(bool isLinked) async {
    if (isLinked) {
      // Confirm unlink
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hủy liên kết Google'),
          content: const Text(
            'Bạn có chắc muốn hủy liên kết tài khoản Google không? '
            'Bạn sẽ không thể đăng nhập bằng Google nữa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hủy liên kết'),
            ),
          ],
        ),
      );
      
      if (result == true) {
        context.read<AuthBloc>().add(GoogleUnlinkRequested());
      }
    } else {
      // Link Google account
      context.read<AuthBloc>().add(GoogleLinkRequested());
    }
  }
}

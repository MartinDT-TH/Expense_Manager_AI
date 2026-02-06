import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/auth_event_bus.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';

/// Global error handler that shows snackbars/dialogs for various errors
/// Wrap your app with this widget to enable global error notifications
class GlobalErrorHandler extends StatefulWidget {
  final Widget child;

  const GlobalErrorHandler({super.key, required this.child});

  @override
  State<GlobalErrorHandler> createState() => _GlobalErrorHandlerState();
}

class _GlobalErrorHandlerState extends State<GlobalErrorHandler> {
  StreamSubscription<AuthErrorEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    // Listen for auth error events that DON'T require logout
    // (those that require logout are handled by AuthBloc)
    _subscription = AuthEventBus.instance.stream.listen(_handleAuthError);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleAuthError(AuthErrorEvent event) {
    // Only show notification if we're NOT logging out
    // (logout will navigate to login screen, so no need for snackbar)
    if (!event.shouldLogout && mounted) {
      _showErrorSnackbar(event);
    }
  }

  void _showErrorSnackbar(AuthErrorEvent event) {
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger == null) return;

    final color = _getColorForError(event.code);
    final icon = _getIconForError(event.code);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                event.message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: _getDurationForError(event.code),
        action: _getActionForError(event, scaffoldMessenger),
      ),
    );
  }

  Color _getColorForError(AuthErrorCode code) {
    switch (code) {
      case AuthErrorCode.networkError:
      case AuthErrorCode.timeout:
        return Colors.orange.shade700;
      case AuthErrorCode.serverError:
        return Colors.red.shade700;
      case AuthErrorCode.invalidOtp:
      case AuthErrorCode.tooManyAttempts:
        return Colors.amber.shade800;
      default:
        return Colors.red.shade600;
    }
  }

  IconData _getIconForError(AuthErrorCode code) {
    switch (code) {
      case AuthErrorCode.networkError:
        return Icons.wifi_off_rounded;
      case AuthErrorCode.timeout:
        return Icons.timer_off_rounded;
      case AuthErrorCode.serverError:
        return Icons.cloud_off_rounded;
      case AuthErrorCode.invalidOtp:
        return Icons.password_rounded;
      case AuthErrorCode.tooManyAttempts:
        return Icons.block_rounded;
      case AuthErrorCode.forbidden:
        return Icons.lock_rounded;
      default:
        return Icons.error_outline_rounded;
    }
  }

  Duration _getDurationForError(AuthErrorCode code) {
    switch (code) {
      case AuthErrorCode.networkError:
      case AuthErrorCode.serverError:
        return const Duration(seconds: 5);
      default:
        return const Duration(seconds: 4);
    }
  }

  SnackBarAction? _getActionForError(
    AuthErrorEvent event,
    ScaffoldMessengerState messenger,
  ) {
    if (event.code == AuthErrorCode.networkError) {
      return SnackBarAction(
        label: 'Đóng',
        textColor: Colors.white,
        onPressed: () => messenger.hideCurrentSnackBar(),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Handle SessionExpired state - show dialog then navigate
        if (state is SessionExpired) {
          _showSessionExpiredDialog(context, state.message);
        }
        // Handle AuthError state
        else if (state is AuthError) {
          _showAuthErrorSnackbar(context, state);
        }
      },
      child: widget.child,
    );
  }

  void _showSessionExpiredDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          Icons.timer_off_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Phiên đăng nhập hết hạn'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đăng nhập lại'),
          ),
        ],
      ),
    );
  }

  void _showAuthErrorSnackbar(BuildContext context, AuthError state) {
    final color = state.isNetworkError
        ? Colors.orange.shade700
        : state.isServerError
            ? Colors.red.shade700
            : Colors.red.shade600;

    final icon = state.isNetworkError
        ? Icons.wifi_off_rounded
        : state.isServerError
            ? Icons.cloud_off_rounded
            : Icons.error_outline_rounded;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

/// Extension for showing error snackbars from anywhere
extension ErrorSnackbarExtension on BuildContext {
  void showErrorSnackbar(String message, {IconData? icon, Color? color}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ?? Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: color ?? Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showNetworkErrorSnackbar([String? message]) {
    showErrorSnackbar(
      message ?? 'Không có kết nối mạng. Vui lòng kiểm tra lại.',
      icon: Icons.wifi_off_rounded,
      color: Colors.orange.shade700,
    );
  }

  void showServerErrorSnackbar([String? message]) {
    showErrorSnackbar(
      message ?? 'Lỗi server. Vui lòng thử lại sau.',
      icon: Icons.cloud_off_rounded,
      color: Colors.red.shade700,
    );
  }
}

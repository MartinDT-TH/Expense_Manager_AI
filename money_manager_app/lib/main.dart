import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/di/injection_container.dart' as di;
import 'core/ads/ad_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/theme_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/global_error_handler.dart';
import 'core/widgets/sync_status_badge.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.initDependencies();
  await MobileAds.instance.initialize();
  await di.sl<AdService>().init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late SyncService _syncService;
  bool _syncInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncService = di.sl<SyncService>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Trigger sync when app comes to foreground
    if (state == AppLifecycleState.resumed && _syncInitialized) {
      _syncService.syncNow();
    }
  }

  void _initializeSyncService() {
    if (!_syncInitialized) {
      _syncService.initialize();
      _syncInitialized = true;
    }
  }
  
  void _resetSyncService() {
    if (_syncInitialized) {
      _syncService.reset();
      _syncInitialized = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()..add(AppStarted())),
        BlocProvider(create: (_) => di.sl<ProfileBloc>()),
      ],
      child: ListenableBuilder(
        listenable: di.sl<ThemeService>(),
        builder: (context, child) {
          return MaterialApp(
            title: 'Smart Money',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: di.sl<ThemeService>().themeMode,
            // Wrap with GlobalErrorHandler for snackbar notifications
            builder: (context, child) {
              return GlobalErrorHandler(child: child ?? const SizedBox());
            },
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is AuthInitial) {
                  return const SplashScreen();
                }
                if (state is Authenticated) {
                  // Initialize sync service after successful authentication
                  _initializeSyncService();
                  return _AuthenticatedHome(syncService: _syncService);
                }
                // Reset sync service when user is not authenticated
                _resetSyncService();
                // Handle SessionExpired - show login with message
                if (state is SessionExpired) {
                  return LoginScreen(sessionExpiredMessage: state.message);
                }
                return const LoginScreen();
              },
            ),
          );
        },
      ),
    );
  }
}

/// Wrapper for authenticated home that shows sync status banner and listens for auto-sync toast.
class _AuthenticatedHome extends StatefulWidget {
  final SyncService syncService;

  const _AuthenticatedHome({required this.syncService});

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  StreamSubscription? _syncToastSubscription;

  @override
  void initState() {
    super.initState();
    _syncToastSubscription = widget.syncService.syncToastStream.listen(_showSyncToast);
  }

  @override
  void dispose() {
    _syncToastSubscription?.cancel();
    super.dispose();
  }

  void _showSyncToast(SyncToastEvent event) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              event.success ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(event.message)),
          ],
        ),
        backgroundColor: event.success ? Colors.green.shade600 : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleSyncPressed(BuildContext context) async {
    final result = await widget.syncService.syncNow();
    if (!context.mounted) return;
    _showSyncToast(SyncToastEvent(result.message, result.success));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.syncService,
      builder: (context, _) {
        final showBanner = widget.syncService.pendingCount > 0 || widget.syncService.isSyncing;
        if (!showBanner) {
          return const HomeScreen();
        }
        return Stack(
          children: [
            const HomeScreen(),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: PendingSyncBanner(
                  pendingCount: widget.syncService.pendingCount,
                  isSyncing: widget.syncService.isSyncing,
                  onSyncPressed: () => _handleSyncPressed(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Smart Money',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

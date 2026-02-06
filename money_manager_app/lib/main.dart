import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/di/injection_container.dart' as di;
import 'core/ads/ad_service.dart';
import 'core/services/theme_service.dart';
import 'core/theme/app_theme.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is AuthInitial) {
                  return const SplashScreen();
                }
                if (state is Authenticated) {
                  return const HomeScreen();
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

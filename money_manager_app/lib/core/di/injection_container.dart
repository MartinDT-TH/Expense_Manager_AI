import 'package:get_it/get_it.dart';
import '../database/local_database.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../sync/sync_queue_processor.dart';
import '../ads/ad_service.dart';
import '../services/cloudinary_service.dart';
import '../services/image_picker_service.dart';
import '../services/ocr_service.dart';
import '../services/signalr_service.dart';
import '../services/subscription_service.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource_v2.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/google_auth_datasource.dart';
import '../../features/auth/data/datasources/two_factor_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../auth/token_storage.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/forgot_password_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/profile/data/datasources/profile_remote_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../../features/wallet/data/datasources/wallet_local_datasource.dart';
import '../../features/wallet/data/datasources/wallet_remote_datasource.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/repositories/wallet_repository.dart';
import '../../features/wallet/domain/usecases/wallet_usecases.dart';
import '../../features/wallet/presentation/bloc/wallet_bloc.dart';
import '../../features/category/data/datasources/category_local_datasource.dart';
import '../../features/category/data/datasources/category_remote_datasource.dart';
import '../../features/category/data/repositories/category_repository_impl.dart';
import '../../features/category/domain/repositories/category_repository.dart';
import '../../features/category/domain/usecases/category_usecases.dart';
import '../../features/category/presentation/bloc/category_bloc.dart';
import '../../features/transaction/data/datasources/transaction_local_datasource.dart';
import '../../features/transaction/data/datasources/transaction_remote_datasource.dart';
import '../../features/transaction/data/repositories/transaction_repository_impl.dart';
import '../../features/transaction/domain/repositories/transaction_repository.dart';
import '../../features/transaction/presentation/bloc/transaction_bloc.dart';
import '../../features/budget/data/datasources/budget_datasource.dart';
import '../../features/budget/data/datasources/budget_local_datasource.dart';
import '../../features/budget/data/datasources/budget_remote_datasource.dart';
import '../../features/budget/data/repositories/budget_repository_impl.dart';
import '../../features/budget/domain/repositories/budget_repository.dart';
import '../../features/budget/presentation/bloc/budget_bloc.dart';
import '../../features/group/data/datasources/group_remote_datasource.dart';
import '../../features/group/data/datasources/group_local_datasource.dart';
import '../../features/group/data/repositories/group_repository_impl.dart';
import '../../features/group/domain/repositories/group_repository.dart';
import '../../features/group/presentation/bloc/group_bloc.dart';
import '../../features/reports/data/datasources/report_remote_datasource.dart';
import '../../features/reports/data/repositories/report_repository_impl.dart';
import '../../features/reports/domain/repositories/report_repository.dart';
import '../../features/reports/presentation/bloc/report_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Core
  sl.registerLazySingleton<ApiClient>(() => ApiClient());
  sl.registerLazySingleton<LocalDatabase>(() => LocalDatabase());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfo());
  
  // Sync Queue Processor (for offline-first sync)
  sl.registerLazySingleton<SyncQueueProcessor>(
    () => SyncQueueProcessor(
      database: sl(),
      apiClient: sl(),
      networkInfo: sl(),
    ),
  );

  // Services
  sl.registerLazySingleton<CloudinaryService>(() => CloudinaryService());
  sl.registerLazySingleton<ImagePickerService>(
    () => ImagePickerService(cloudinaryService: sl()),
  );
  sl.registerLazySingleton<OcrService>(
    () => OcrService(apiClient: sl()),
  );

  // Ads Service (AdMob)
  sl.registerLazySingleton<AdService>(() => AdService());
  
  // SignalR Service (singleton for real-time updates)
  sl.registerLazySingleton<SignalRService>(() => SignalRService());

  // Theme Service (singleton for app-wide theme management)
  final themeService = ThemeService();
  await themeService.loadTheme();
  sl.registerSingleton<ThemeService>(themeService);

  // Subscription Service (for in-app purchases)
  sl.registerLazySingleton<SubscriptionService>(
    () => SubscriptionService(apiClient: sl()),
  );

  // Auth Feature
  _initAuthFeature();

  // Profile Feature
  _initProfileFeature();

  // Wallet Feature
  _initWalletFeature();

  // Category Feature
  _initCategoryFeature();

  // Transaction Feature
  _initTransactionFeature();

  // Budget Feature
  _initBudgetFeature();

  // Group Feature
  _initGroupFeature();

  // Report Feature
  _initReportFeature();

  // Sync Service (depends on TransactionRepository, so init after features)
  _initSyncService();
}

void _initSyncService() {
  sl.registerLazySingleton<SyncService>(
    () => SyncService(
      networkInfo: sl(),
      syncQueueProcessor: sl(),
    ),
  );
}

void _initCategoryFeature() {
  // Bloc
  sl.registerFactory(() => CategoryBloc(
        getCategoriesUseCase: sl(),
        getExpenseCategoriesUseCase: sl(),
        getIncomeCategoriesUseCase: sl(),
        createCategoryUseCase: sl(),
        updateCategoryUseCase: sl(),
        deleteCategoryUseCase: sl(),
      ));

  // UseCases
  sl.registerLazySingleton(() => GetCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetExpenseCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetIncomeCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetCategoryByIdUseCase(sl()));
  sl.registerLazySingleton(() => CreateCategoryUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCategoryUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCategoryUseCase(sl()));

  // Repository
  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // DataSources
  sl.registerLazySingleton<CategoryRemoteDataSource>(
    () => CategoryRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<CategoryLocalDataSource>(
    () => CategoryLocalDataSourceImpl(database: sl()),
  );
}

void _initWalletFeature() {
  // Bloc
  sl.registerFactory(() => WalletBloc(
        getWalletsUseCase: sl(),
        createWalletUseCase: sl(),
        updateWalletUseCase: sl(),
        deleteWalletUseCase: sl(),
        getTotalBalanceUseCase: sl(),
      ));

  // UseCases
  sl.registerLazySingleton(() => GetWalletsUseCase(sl()));
  sl.registerLazySingleton(() => GetWalletByIdUseCase(sl()));
  sl.registerLazySingleton(() => CreateWalletUseCase(sl()));
  sl.registerLazySingleton(() => UpdateWalletUseCase(sl()));
  sl.registerLazySingleton(() => DeleteWalletUseCase(sl()));
  sl.registerLazySingleton(() => GetTotalBalanceUseCase(sl()));

  // Repository
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // DataSources
  sl.registerLazySingleton<WalletRemoteDataSource>(
    () => WalletRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<WalletLocalDataSource>(
    () => WalletLocalDataSourceImpl(database: sl()),
  );
}

void _initAuthFeature() {
  // Token Storage
  sl.registerLazySingleton<TokenStorage>(() => const TokenStorage());

  // Bloc
  sl.registerFactory(() => AuthBloc(
        loginUseCase: sl(),
        registerUseCase: sl(),
        logoutUseCase: sl(),
        getCurrentUserUseCase: sl(),
        forgotPasswordUseCase: sl(),
        googleAuthDataSource: sl<GoogleAuthDataSource>(),
        twoFactorDataSource: sl<TwoFactorDataSource>(),
        authRemoteDataSourceV2: sl<AuthRemoteDataSourceV2>(),
        onSyncRequested: () {},
      ));

  // UseCases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => ForgotPasswordUseCase(sl()));

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
      tokenStorage: sl(),
      localDatabase: sl(),
    ),
  );

  // DataSources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSourceV2>(
    () => AuthRemoteDataSourceV2Impl(
      apiClient: sl(),
      tokenStorage: sl(),
    ),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(database: sl()),
  );
  sl.registerLazySingleton<GoogleAuthDataSource>(
    () => GoogleAuthDataSourceImpl(
      apiClient: sl(),
      tokenStorage: sl(),
    ),
  );
  sl.registerLazySingleton<TwoFactorDataSource>(
    () => TwoFactorDataSourceImpl(
      apiClient: sl(),
      tokenStorage: sl(),
    ),
  );
}

void _initProfileFeature() {
  // Bloc
  sl.registerFactory(() => ProfileBloc(
        repository: sl(),
      ));

  // Repository
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // DataSources
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(apiClient: sl()),
  );
}

void _initTransactionFeature() {
  // Bloc
  sl.registerFactory(() => TransactionBloc(repository: sl()));

  // Repository (offline-first)
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
      syncQueue: sl(),
    ),
  );

  // DataSources
  sl.registerLazySingleton<TransactionRemoteDataSource>(
    () => TransactionRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<TransactionLocalDataSource>(
    () => TransactionLocalDataSourceImpl(database: sl()),
  );
}

void _initBudgetFeature() {
  // Bloc
  sl.registerFactory(() => BudgetBloc(repository: sl()));

  // Repository
  sl.registerLazySingleton<BudgetRepository>(
    () => BudgetRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // DataSources
  sl.registerLazySingleton<BudgetRemoteDataSource>(
    () => BudgetRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<BudgetLocalDataSource>(
    () => BudgetLocalDataSourceImpl(database: sl()),
  );
}

void _initGroupFeature() {
  // Bloc
  sl.registerFactory(() => GroupBloc(repository: sl()));

  // Repository
  sl.registerLazySingleton<GroupRepository>(
    () => GroupRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // DataSources
  sl.registerLazySingleton<GroupRemoteDataSource>(
    () => GroupRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<GroupLocalDataSource>(
    () => GroupLocalDataSourceImpl(database: sl()),
  );
}

void _initReportFeature() {
  // Bloc
  sl.registerFactory(() => ReportBloc(repository: sl()));

  // Repository
  sl.registerLazySingleton<ReportRepository>(
    () => ReportRepositoryImpl(remoteDataSource: sl()),
  );

  // DataSources
  sl.registerLazySingleton<ReportRemoteDataSource>(
    () => ReportRemoteDataSource(apiClient: sl()),
  );
}

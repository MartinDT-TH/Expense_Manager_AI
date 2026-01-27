import 'package:get_it/get_it.dart';
import '../database/local_database.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../services/cloudinary_service.dart';
import '../services/image_picker_service.dart';
import '../services/ocr_service.dart';
import '../services/signalr_service.dart';
import '../services/theme_service.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/forgot_password_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
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
import '../../features/transaction/data/datasources/transaction_remote_datasource.dart';
import '../../features/transaction/data/repositories/transaction_repository_impl.dart';
import '../../features/transaction/domain/repositories/transaction_repository.dart';
import '../../features/transaction/presentation/bloc/transaction_bloc.dart';
import '../../features/budget/data/datasources/budget_datasource.dart';
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

  // Services
  sl.registerLazySingleton<CloudinaryService>(() => CloudinaryService());
  sl.registerLazySingleton<ImagePickerService>(
    () => ImagePickerService(cloudinaryService: sl()),
  );
  sl.registerLazySingleton<OcrService>(
    () => OcrService(apiClient: sl()),
  );
  
  // SignalR Service (singleton for real-time updates)
  sl.registerLazySingleton<SignalRService>(() => SignalRService());

  // Theme Service (singleton for app-wide theme management)
  final themeService = ThemeService();
  await themeService.loadTheme();
  sl.registerSingleton<ThemeService>(themeService);

  // Auth Feature
  _initAuthFeature();

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
  // Bloc
  sl.registerFactory(() => AuthBloc(
        loginUseCase: sl(),
        registerUseCase: sl(),
        logoutUseCase: sl(),
        getCurrentUserUseCase: sl(),
        forgotPasswordUseCase: sl(),
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
    ),
  );

  // DataSources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(database: sl()),
  );
}

void _initTransactionFeature() {
  // Bloc
  sl.registerFactory(() => TransactionBloc(repository: sl()));

  // Repository
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(remoteDataSource: sl()),
  );

  // DataSources
  sl.registerLazySingleton<TransactionRemoteDataSource>(
    () => TransactionRemoteDataSourceImpl(apiClient: sl()),
  );
}

void _initBudgetFeature() {
  // Bloc
  sl.registerFactory(() => BudgetBloc(repository: sl()));

  // Repository
  sl.registerLazySingleton<BudgetRepository>(
    () => BudgetRepositoryImpl(remoteDataSource: sl()),
  );

  // DataSources
  sl.registerLazySingleton<BudgetRemoteDataSource>(
    () => BudgetRemoteDataSourceImpl(apiClient: sl()),
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

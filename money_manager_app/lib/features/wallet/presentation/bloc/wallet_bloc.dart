import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/usecases/wallet_usecases.dart';
import 'wallet_event.dart';
import 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final GetWalletsUseCase getWalletsUseCase;
  final CreateWalletUseCase createWalletUseCase;
  final UpdateWalletUseCase updateWalletUseCase;
  final DeleteWalletUseCase deleteWalletUseCase;
  final GetTotalBalanceUseCase getTotalBalanceUseCase;

  WalletBloc({
    required this.getWalletsUseCase,
    required this.createWalletUseCase,
    required this.updateWalletUseCase,
    required this.deleteWalletUseCase,
    required this.getTotalBalanceUseCase,
  }) : super(WalletInitial()) {
    on<WalletsLoadRequested>(_onLoadRequested);
    on<WalletCreateRequested>(_onCreateRequested);
    on<WalletUpdateRequested>(_onUpdateRequested);
    on<WalletDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(
    WalletsLoadRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletLoading());
    try {
      final wallets = await getWalletsUseCase();
      final totalBalance = await getTotalBalanceUseCase();
      emit(WalletLoaded(wallets: wallets, totalBalance: totalBalance));
    } catch (e) {
      emit(WalletError(message: 'Không thể tải danh sách ví: ${e.toString()}'));
    }
  }

  Future<void> _onCreateRequested(
    WalletCreateRequested event,
    Emitter<WalletState> emit,
  ) async {
    final currentWallets = _getCurrentWallets();
    emit(WalletLoading());
    
    try {
      final newWallet = Wallet(
        id: '',
        name: event.name,
        initialBalance: event.initialBalance,
        balance: event.initialBalance, // Balance bằng initialBalance khi tạo mới
        currency: event.currency,
        type: event.type,
        lastUpdatedAt: DateTime.now(),
      );
      
      await createWalletUseCase(newWallet);
      final wallets = await getWalletsUseCase();
      final totalBalance = await getTotalBalanceUseCase();
      
      emit(WalletOperationSuccess(
        message: 'Tạo ví thành công!',
        wallets: wallets,
        totalBalance: totalBalance,
      ));
    } catch (e) {
      emit(WalletError(
        message: 'Không thể tạo ví: ${e.toString()}',
        previousWallets: currentWallets,
      ));
    }
  }

  Future<void> _onUpdateRequested(
    WalletUpdateRequested event,
    Emitter<WalletState> emit,
  ) async {
    final currentWallets = _getCurrentWallets();
    emit(WalletLoading());
    
    try {
      await updateWalletUseCase(event.wallet);
      final wallets = await getWalletsUseCase();
      final totalBalance = await getTotalBalanceUseCase();
      
      emit(WalletOperationSuccess(
        message: 'Cập nhật ví thành công!',
        wallets: wallets,
        totalBalance: totalBalance,
      ));
    } catch (e) {
      emit(WalletError(
        message: 'Không thể cập nhật ví: ${e.toString()}',
        previousWallets: currentWallets,
      ));
    }
  }

  Future<void> _onDeleteRequested(
    WalletDeleteRequested event,
    Emitter<WalletState> emit,
  ) async {
    final currentWallets = _getCurrentWallets();
    emit(WalletLoading());
    
    try {
      await deleteWalletUseCase(event.id);
      final wallets = await getWalletsUseCase();
      final totalBalance = await getTotalBalanceUseCase();
      
      emit(WalletOperationSuccess(
        message: 'Xóa ví thành công!',
        wallets: wallets,
        totalBalance: totalBalance,
      ));
    } catch (e) {
      emit(WalletError(
        message: 'Không thể xóa ví: ${e.toString()}',
        previousWallets: currentWallets,
      ));
    }
  }

  List<Wallet>? _getCurrentWallets() {
    final currentState = state;
    if (currentState is WalletLoaded) {
      return currentState.wallets;
    } else if (currentState is WalletOperationSuccess) {
      return currentState.wallets;
    }
    return null;
  }
}

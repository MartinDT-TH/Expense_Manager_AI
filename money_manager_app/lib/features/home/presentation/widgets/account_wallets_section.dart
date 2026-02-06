import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/extensions.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../../wallet/domain/entities/wallet.dart';
import '../../../wallet/presentation/screens/wallet_detail_screen.dart';
import '../../../wallet/presentation/screens/wallets_screen_v2.dart';

class AccountWalletsSection extends StatelessWidget {
  const AccountWalletsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        List<Wallet> wallets = [];
        
        if (state is WalletLoaded) {
          wallets = state.wallets;
        } else if (state is WalletOperationSuccess) {
          wallets = state.wallets;
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tài khoản của tôi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D3436),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WalletsScreenV2(),
                      ),
                    ).then((_) {
                      // Refresh wallets when returning from WalletsScreenV2
                      if (context.mounted) {
                        context.read<WalletBloc>().add(WalletsLoadRequested());
                      }
                    });
                  },
                  child: const Text(
                    'Xem tất cả',
                    style: TextStyle(
                      color: Color(0xFF6C5CE7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Wallet Cards Horizontal Scroll
            if (wallets.isEmpty)
              _buildEmptyState(context, isDark)
            else
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = wallets[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < wallets.length - 1 ? 12 : 0,
                      ),
                      child: _buildWalletMiniCard(context, wallet, isDark),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWalletMiniCard(BuildContext context, Wallet wallet, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WalletDetailScreen(wallet: wallet),
          ),
        ).then((_) {
          // Refresh wallets when returning from WalletDetailScreen
          if (context.mounted) {
            context.read<WalletBloc>().add(WalletsLoadRequested());
          }
        });
      },
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getWalletGradient(wallet.type),
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _getWalletPrimaryColor(wallet.type).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Pattern
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon and Type
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getWalletIcon(wallet.type),
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    Text(
                      _getWalletTypeName(wallet.type),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
                // Balance and Name
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.balance.toCurrency(wallet.currency),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wallet.name,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WalletsScreenV2(),
          ),
        ).then((_) {
          // Refresh wallets when returning from WalletsScreenV2
          if (context.mounted) {
            context.read<WalletBloc>().add(WalletsLoadRequested());
          }
        });
      },
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Color(0xFF6C5CE7),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Thêm ví đầu tiên',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nhấn để tạo',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getWalletGradient(String type) {
    switch (type.toUpperCase()) {
      case 'BANK':
        return [const Color(0xFF667EEA), const Color(0xFF764BA2)];
      case 'E_WALLET':
        return [const Color(0xFF11998E), const Color(0xFF38EF7D)];
      case 'CREDIT_CARD':
        return [const Color(0xFFFF416C), const Color(0xFFFF4B2B)];
      case 'CASH':
      default:
        return [const Color(0xFF6C5CE7), const Color(0xFF8B7CF7)];
    }
  }

  Color _getWalletPrimaryColor(String type) {
    switch (type.toUpperCase()) {
      case 'BANK':
        return const Color(0xFF667EEA);
      case 'E_WALLET':
        return const Color(0xFF11998E);
      case 'CREDIT_CARD':
        return const Color(0xFFFF416C);
      case 'CASH':
      default:
        return const Color(0xFF6C5CE7);
    }
  }

  IconData _getWalletIcon(String type) {
    switch (type.toUpperCase()) {
      case 'BANK':
        return Icons.account_balance;
      case 'E_WALLET':
        return Icons.phone_android;
      case 'CREDIT_CARD':
        return Icons.credit_card;
      case 'CASH':
      default:
        return Icons.payments;
    }
  }

  String _getWalletTypeName(String type) {
    switch (type.toUpperCase()) {
      case 'BANK':
        return 'Ngân hàng';
      case 'E_WALLET':
        return 'Ví điện tử';
      case 'CREDIT_CARD':
        return 'Thẻ tín dụng';
      case 'CASH':
      default:
        return 'Tiền mặt';
    }
  }
}

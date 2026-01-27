import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/extensions.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import '../widgets/add_wallet_bottom_sheet.dart';
import '../widgets/beautiful_wallet_card.dart';
import 'wallet_detail_screen.dart';
import '../../domain/entities/wallet.dart';

class WalletsScreenV2 extends StatelessWidget {
  const WalletsScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<WalletBloc>()..add(WalletsLoadRequested()),
      child: const _WalletsView(),
    );
  }
}

class _WalletsView extends StatefulWidget {
  const _WalletsView();

  @override
  State<_WalletsView> createState() => _WalletsViewState();
}

class _WalletsViewState extends State<_WalletsView> {
  late PageController _pageController;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.75, // Card chiếm 75% màn hình, để lộ 2 bên
      initialPage: 0,
    );
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      body: BlocConsumer<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is WalletOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF00B894),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          } else if (state is WalletError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
        builder: (context, state) {
          List<Wallet> wallets = [];
          double totalBalance = 0;

          if (state is WalletLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7)));
          }

          if (state is WalletLoaded) {
            wallets = state.wallets;
            totalBalance = state.totalBalance;
          } else if (state is WalletOperationSuccess) {
            wallets = state.wallets;
            totalBalance = state.totalBalance;
          } else if (state is WalletError && state.previousWallets != null) {
            wallets = state.previousWallets!;
          }

          return CustomScrollView(
            slivers: [
              // Custom App Bar
              SliverToBoxAdapter(
                child: _buildHeader(context, isDark, totalBalance),
              ),
              
              // Beautiful Card Carousel
              if (wallets.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildCardCarousel(context, wallets, isDark),
                ),
              
              // Page Indicator
              if (wallets.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildPageIndicator(wallets.length, isDark),
                ),
              
              // Empty State
              if (wallets.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context, isDark),
                ),
              
              // All Wallets List Header
              if (wallets.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18 * scale, 20 * scale, 18 * scale, 10 * scale),
                    child: Text(
                      'All Wallets',
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2D3436),
                      ),
                    ),
                  ),
                ),
              
              // Wallets List
              if (wallets.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final wallet = wallets[index];
                      return _buildWalletListItem(context, wallet, isDark);
                    },
                    childCount: wallets.length,
                  ),
                ),
              
              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWalletDialog(context),
        backgroundColor: const Color(0xFF6C5CE7),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Wallet',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13 * scale,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, double totalBalance) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Container(
      padding: EdgeInsets.fromLTRB(18 * scale, 12 * scale, 18 * scale, 20 * scale),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6C5CE7),
            Color(0xFF8B7CF7),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'My Wallets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    context.read<WalletBloc>().add(WalletsLoadRequested());
                  },
                ),
              ],
            ),
            SizedBox(height: 20 * scale),
            
            // Total Balance Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16 * scale),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6 * scale),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 10 * scale),
                      const Text(
                        'Total Balance',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12 * scale),
                  Text(
                    totalBalance.toVND(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardCarousel(BuildContext context, List<Wallet> wallets, bool isDark) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Container(
      margin: EdgeInsets.only(top: 20 * scale),
      height: 200 * scale, // Chiều cao đủ để card không bị overflow
      child: PageView.builder(
        controller: _pageController,
        itemCount: wallets.length,
        itemBuilder: (context, index) {
          final wallet = wallets[index];
          
          // Tính toán scale và opacity dựa trên vị trí
          double scale = 1.0;
          double opacity = 1.0;
          
          if (_pageController.position.haveDimensions) {
            double diff = (index - _currentPage).abs();
            scale = 1 - (diff * 0.15).clamp(0.0, 0.3); // Card bên cạnh nhỏ hơn 15%
            opacity = 1 - (diff * 0.3).clamp(0.0, 0.5); // Card bên cạnh mờ hơn
          }
          
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: scale, end: scale),
            duration: const Duration(milliseconds: 150),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: opacity,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WalletDetailScreen(wallet: wallet),
                        ),
                      ).then((_) {
                        if (mounted) {
                          context.read<WalletBloc>().add(WalletsLoadRequested());
                        }
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 8 * scale),
                      child: BeautifulWalletCard(
                        wallet: wallet,
                        height: 180 * scale,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPageIndicator(int count, bool isDark) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Padding(
      padding: EdgeInsets.only(top: 12 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (index) {
            double diff = (_currentPage - index).abs();
            double width = diff < 0.5 ? 24 : 8;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 3 * scale),
              width: width * scale,
              height: 7 * scale,
              decoration: BoxDecoration(
                color: diff < 0.5
                    ? const Color(0xFF6C5CE7)
                    : (isDark ? Colors.grey[700] : Colors.grey[300]),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWalletListItem(BuildContext context, Wallet wallet, bool isDark) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WalletDetailScreen(wallet: wallet),
          ),
        ).then((_) {
          context.read<WalletBloc>().add(WalletsLoadRequested());
        });
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 6 * scale),
        padding: EdgeInsets.all(14 * scale),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44 * scale,
              height: 44 * scale,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getWalletGradient(wallet.type),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getWalletIcon(wallet.type),
                color: Colors.white,
                size: 22 * scale,
              ),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF2D3436),
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    _getWalletTypeName(wallet.type),
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  wallet.balance.toCurrency(wallet.currency),
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.bold,
                    color: wallet.balance >= 0 
                        ? const Color(0xFF00B894) 
                        : const Color(0xFFE17055),
                  ),
                ),
                SizedBox(height: 4 * scale),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                  size: 18 * scale,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20 * scale),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: Color(0xFF6C5CE7),
            ),
          ),
          SizedBox(height: 16 * scale),
          Text(
            'No Wallets Yet',
            style: TextStyle(
              fontSize: 18 * scale,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2D3436),
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            'Create your first wallet to start\ntracking your finances',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12 * scale,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          SizedBox(height: 24 * scale),
          ElevatedButton.icon(
            onPressed: () => _showAddWalletDialog(context),
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text('Create Wallet', style: TextStyle(color: Colors.white, fontSize: 13 * scale)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              padding: EdgeInsets.symmetric(horizontal: 28 * scale, vertical: 12 * scale),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWalletDialog(BuildContext context) {
    AddWalletBottomSheet.show(context);
  }

  List<Color> _getWalletGradient(String type) {
    switch (type.toUpperCase()) {
      case 'BANK':
        return [const Color(0xFF2196F3), const Color(0xFF1565C0)];
      case 'E_WALLET':
        return [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)];
      case 'CREDIT_CARD':
        return [const Color(0xFFFF6B35), const Color(0xFFE53935)];
      case 'CASH':
      default:
        return [const Color(0xFF66BB6A), const Color(0xFF43A047)];
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
        return 'Bank Account';
      case 'E_WALLET':
        return 'E-Wallet';
      case 'CREDIT_CARD':
        return 'Credit Card';
      case 'CASH':
      default:
        return 'Cash';
    }
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/utils/extensions.dart';
import '../../domain/entities/wallet.dart';

class BeautifulWalletCard extends StatelessWidget {
  final Wallet wallet;
  final VoidCallback? onTap;
  final double? height;

  const BeautifulWalletCard({
    super.key,
    required this.wallet,
    this.onTap,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height ?? 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getWalletGradient(wallet.type),
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _getWalletPrimaryColor(wallet.type).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background Pattern - Decorative Elements
              ..._buildBackgroundPattern(),
              
              // Main Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Wallet Type Icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getWalletIcon(wallet.type),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        // Card Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getWalletTypeName(wallet.type),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Card Number (for bank/credit cards)
                    if (wallet.type.toUpperCase() == 'BANK' || 
                        wallet.type.toUpperCase() == 'CREDIT_CARD')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '•••• •••• •••• ${_generateCardSuffix(wallet.id)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            letterSpacing: 3,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    
                    // Balance
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        wallet.balance.toCurrency(wallet.currency),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Wallet Name
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            wallet.name,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // View Arrow
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundPattern() {
    final type = wallet.type.toUpperCase();
    
    switch (type) {
      case 'BANK':
        return _buildBankPattern();
      case 'E_WALLET':
        return _buildEWalletPattern();
      case 'CREDIT_CARD':
        return _buildCreditCardPattern();
      case 'CASH':
      default:
        return _buildCashPattern();
    }
  }

  // Pattern cho ví Tiền mặt - Vòng tròn đồng tâm
  List<Widget> _buildCashPattern() {
    return [
      // Large circle top right
      Positioned(
        right: -40,
        top: -40,
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 2,
            ),
          ),
        ),
      ),
      Positioned(
        right: -20,
        top: -20,
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 2,
            ),
          ),
        ),
      ),
      // Bottom left circle
      Positioned(
        left: -30,
        bottom: -30,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      // Currency symbol
      Positioned(
        right: 20,
        bottom: 60,
        child: Text(
          _getCurrencySymbol(wallet.currency),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.1),
            fontSize: 80,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ];
  }

  // Pattern cho Bank - Wave pattern
  List<Widget> _buildBankPattern() {
    return [
      // Wave curves
      Positioned(
        right: -50,
        top: 20,
        child: Transform.rotate(
          angle: -0.3,
          child: Container(
            width: 200,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: -30,
        top: 50,
        child: Transform.rotate(
          angle: -0.3,
          child: Container(
            width: 180,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 2,
              ),
            ),
          ),
        ),
      ),
      // Bank icon watermark
      Positioned(
        right: 15,
        bottom: 55,
        child: Icon(
          Icons.account_balance,
          size: 70,
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      // Chip pattern
      Positioned(
        left: 20,
        top: 60,
        child: Container(
          width: 45,
          height: 35,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              colors: [
                Colors.amber.withValues(alpha: 0.4),
                Colors.amber.withValues(alpha: 0.2),
              ],
            ),
          ),
          child: GridView.count(
            crossAxisCount: 4,
            padding: const EdgeInsets.all(4),
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              12,
              (i) => Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  // Pattern cho E-Wallet - Modern geometric
  List<Widget> _buildEWalletPattern() {
    return [
      // Hexagon pattern simulation
      Positioned(
        right: -20,
        top: -10,
        child: Transform.rotate(
          angle: math.pi / 6,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 30,
        top: 40,
        child: Transform.rotate(
          angle: math.pi / 6,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
      ),
      // Lightning bolt icon
      Positioned(
        right: 20,
        bottom: 50,
        child: Icon(
          Icons.bolt,
          size: 80,
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      // QR code pattern
      Positioned(
        left: 15,
        bottom: 50,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(3),
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              9,
              (i) => Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: (i % 2 == 0) 
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  // Pattern cho Credit Card - Premium stripe
  List<Widget> _buildCreditCardPattern() {
    return [
      // Diagonal stripes
      Positioned(
        right: -80,
        top: -30,
        child: Transform.rotate(
          angle: -0.5,
          child: Container(
            width: 200,
            height: 40,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      Positioned(
        right: -60,
        top: 10,
        child: Transform.rotate(
          angle: -0.5,
          child: Container(
            width: 200,
            height: 20,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      // Chip
      Positioned(
        left: 20,
        top: 55,
        child: Container(
          width: 50,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber.withValues(alpha: 0.5),
                Colors.amber.withValues(alpha: 0.3),
              ],
            ),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(
                16,
                (i) => Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      // Contactless symbol
      Positioned(
        left: 80,
        top: 58,
        child: Icon(
          Icons.wifi,
          size: 24,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ),
      // Mastercard/Visa circles
      Positioned(
        right: 20,
        bottom: 50,
        child: Row(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.4),
              ),
            ),
            Transform.translate(
              offset: const Offset(-15, 0),
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Color> _getWalletGradient(String type) {
    switch (type.toUpperCase()) {
      case 'BANK':
        return [const Color(0xFF2196F3), const Color(0xFF1565C0), const Color(0xFF0D47A1)];
      case 'E_WALLET':
        return [const Color(0xFF9C27B0), const Color(0xFF7B1FA2), const Color(0xFF4A148C)];
      case 'CREDIT_CARD':
        return [const Color(0xFFFF6B35), const Color(0xFFE53935), const Color(0xFFB71C1C)];
      case 'CASH':
      default:
        return [const Color(0xFF66BB6A), const Color(0xFF43A047), const Color(0xFF2E7D32)];
    }
  }

  Color _getWalletPrimaryColor(String type) {
    switch (type.toUpperCase()) {
      case 'BANK':
        return const Color(0xFF1976D2);
      case 'E_WALLET':
        return const Color(0xFF8E24AA);
      case 'CREDIT_CARD':
        return const Color(0xFFE53935);
      case 'CASH':
      default:
        return const Color(0xFF43A047);
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
        return 'NGÂN HÀNG';
      case 'E_WALLET':
        return 'VÍ ĐIỆN TỬ';
      case 'CREDIT_CARD':
        return 'THẺ TÍN DỤNG';
      case 'CASH':
      default:
        return 'TIỀN MẶT';
    }
  }

  String _generateCardSuffix(String id) {
    if (id.length >= 4) {
      return id.substring(id.length - 4).toUpperCase();
    }
    return id.padLeft(4, '0').toUpperCase();
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'VND':
        return '₫';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return currency;
    }
  }
}

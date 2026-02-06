import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/subscription_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late SubscriptionService _subscriptionService;
  SubscriptionStatus _status = SubscriptionStatus.free;
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _subscriptionService = sl<SubscriptionService>();
    _setupCallbacks();
    _loadData();
  }

  void _setupCallbacks() {
    _subscriptionService.onPurchaseVerified = (result) {
      setState(() => _isPurchasing = false);
      
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Chúc mừng! Bạn đã trở thành Premium!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _loadStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    };

    _subscriptionService.onPurchaseError = (error) {
      setState(() => _isPurchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
    };

    _subscriptionService.onPurchasePending = () {
      setState(() => _isPurchasing = true);
    };
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    await _subscriptionService.initialize();
    await _loadStatus();
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadStatus() async {
    final status = await _subscriptionService.getSubscriptionStatus();
    setState(() => _status = status);
  }

  Future<void> _purchase(String productId) async {
    setState(() => _isPurchasing = true);
    
    if (productId == ProductIds.premiumLifetime) {
      await _subscriptionService.purchaseLifetime();
    } else {
      await _subscriptionService.purchaseSubscription(productId);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isPurchasing = true);
    
    try {
      await _subscriptionService.restorePurchases();
      await _loadStatus();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã khôi phục giao dịch thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khôi phục: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Header
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: const Color(0xFF6C5CE7),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.workspace_premium,
                                size: 48,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Smart Money Premium',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current status
                        if (_status.isPremium) _buildCurrentStatusCard(),

                        // Features
                        const Text(
                          'Tính năng Premium',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureItem(Icons.all_inclusive, 'Không giới hạn ví và danh mục'),
                        _buildFeatureItem(Icons.analytics, 'Báo cáo và phân tích nâng cao'),
                        _buildFeatureItem(Icons.cloud_sync, 'Đồng bộ đa thiết bị'),
                        _buildFeatureItem(Icons.notifications_active, 'Thông báo thông minh'),
                        _buildFeatureItem(Icons.group, 'Quản lý nhóm không giới hạn'),
                        _buildFeatureItem(Icons.block, 'Không quảng cáo'),
                        _buildFeatureItem(Icons.support_agent, 'Hỗ trợ ưu tiên'),

                        const SizedBox(height: 32),

                        // Pricing plans
                        if (!_status.isPremium) ...[
                          const Text(
                            'Chọn gói của bạn',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._buildPricingCards(),
                          
                          const SizedBox(height: 24),
                          
                          // Restore purchases
                          Center(
                            child: TextButton.icon(
                              onPressed: _isPurchasing ? null : _restorePurchases,
                              icon: const Icon(Icons.restore),
                              label: const Text('Khôi phục giao dịch'),
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCurrentStatusCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1C40F), Color(0xFFF39C12)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.star,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⭐ Premium đang hoạt động',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (_status.expiryDate != null)
                  Text(
                    'Hết hạn: ${_formatDate(_status.expiryDate!)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                if (_status.daysUntilExpiry != null && _status.daysUntilExpiry! > 0)
                  Text(
                    'Còn ${_status.daysUntilExpiry} ngày',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF6C5CE7), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF00B894), size: 20),
        ],
      ),
    );
  }

  List<Widget> _buildPricingCards() {
    final products = _subscriptionService.products;
    
    if (products.isEmpty) {
      return [
        const Center(
          child: Text(
            'Không thể tải gói Premium. Vui lòng thử lại sau.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }

    return products.map((product) {
      final isPopular = product.id == ProductIds.premiumYearly;
      final isLifetime = product.id == ProductIds.premiumLifetime;
      
      String period = '';
      String savings = '';
      
      if (product.id == ProductIds.premiumMonthly) {
        period = '/ tháng';
      } else if (product.id == ProductIds.premiumYearly) {
        period = '/ năm';
        savings = 'Tiết kiệm 40%';
      } else if (isLifetime) {
        period = 'Trọn đời';
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPopular ? const Color(0xFF6C5CE7) : Colors.grey.shade200,
            width: isPopular ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPopular ? const Color(0xFF6C5CE7) : Colors.grey).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (isPopular)
              Positioned(
                top: 0,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6C5CE7),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Phổ biến',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title.replaceAll('(Smart Money)', '').trim(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        product.price,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isPopular ? const Color(0xFF6C5CE7) : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          period,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (savings.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        savings,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isPurchasing ? null : () => _purchase(product.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPopular 
                            ? const Color(0xFF6C5CE7) 
                            : Colors.grey[200],
                        foregroundColor: isPopular ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isPurchasing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isLifetime ? 'Mua ngay' : 'Đăng ký',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}


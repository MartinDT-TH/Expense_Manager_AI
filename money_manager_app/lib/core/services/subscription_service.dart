import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../network/api_client.dart';

/// Product IDs - must match Google Play Console
class ProductIds {
  static const String premiumMonthly = 'premium_monthly';
  static const String premiumYearly = 'premium_yearly';
  static const String premiumLifetime = 'premium_lifetime';
  
  static const List<String> subscriptionIds = [premiumMonthly, premiumYearly];
  static const List<String> consumableIds = [premiumLifetime];
  static const List<String> allProductIds = [premiumMonthly, premiumYearly, premiumLifetime];
}

/// Subscription status model
class SubscriptionStatus {
  final bool isPremium;
  final bool isActive;
  final String? productId;
  final DateTime? expiryDate;
  final int? daysUntilExpiry;

  const SubscriptionStatus({
    required this.isPremium,
    required this.isActive,
    this.productId,
    this.expiryDate,
    this.daysUntilExpiry,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isPremium: json['isPremium'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
      productId: json['productId'] as String?,
      expiryDate: json['expiryDate'] != null 
          ? DateTime.parse(json['expiryDate'] as String) 
          : null,
      daysUntilExpiry: json['daysUntilExpiry'] as int?,
    );
  }

  static const free = SubscriptionStatus(isPremium: false, isActive: false);
}

/// Purchase verification result
class PurchaseVerificationResult {
  final bool success;
  final String message;
  final bool isPremium;
  final DateTime? expiryDate;

  const PurchaseVerificationResult({
    required this.success,
    required this.message,
    required this.isPremium,
    this.expiryDate,
  });

  factory PurchaseVerificationResult.fromJson(Map<String, dynamic> json) {
    return PurchaseVerificationResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      isPremium: json['isValid'] as bool? ?? false,
      expiryDate: json['expiryDate'] != null 
          ? DateTime.parse(json['expiryDate'] as String) 
          : null,
    );
  }
}

/// Service for handling in-app purchases and subscriptions
class SubscriptionService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final ApiClient _apiClient;
  
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  
  // Callbacks
  Function(PurchaseVerificationResult)? onPurchaseVerified;
  Function(String)? onPurchaseError;
  Function()? onPurchasePending;

  SubscriptionService({required ApiClient apiClient}) : _apiClient = apiClient;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;

  /// Initialize the service and start listening to purchases
  Future<void> initialize() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    
    if (!_isAvailable) {
      debugPrint('Mua hàng trong ứng dụng không khả dụng');
      return;
    }

    // Listen to purchase updates
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        debugPrint('Lỗi luồng mua hàng: $error');
      },
    );

    // Load products
    await loadProducts();
  }

  /// Load available products from the store
  Future<void> loadProducts() async {
    if (!_isAvailable) return;

    final response = await _inAppPurchase.queryProductDetails(
      ProductIds.allProductIds.toSet(),
    );

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Không tìm thấy sản phẩm: ${response.notFoundIDs}');
    }

    _products = response.productDetails;
    debugPrint('Đã tải ${_products.length} sản phẩm');
  }

  /// Get product by ID
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(String productId) async {
    final product = getProduct(productId);
    if (product == null) {
      onPurchaseError?.call('Không tìm thấy sản phẩm');
      return false;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    
    try {
      final success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      return success;
    } catch (e) {
      debugPrint('Lỗi mua hàng: $e');
      onPurchaseError?.call('Mua hàng thất bại: $e');
      return false;
    }
  }

  /// Purchase a consumable (lifetime)
  Future<bool> purchaseLifetime() async {
    final product = getProduct(ProductIds.premiumLifetime);
    if (product == null) {
      onPurchaseError?.call('Không tìm thấy sản phẩm');
      return false;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    
    try {
      final success = await _inAppPurchase.buyConsumable(
        purchaseParam: purchaseParam,
      );
      return success;
    } catch (e) {
      debugPrint('Lỗi mua hàng: $e');
      onPurchaseError?.call('Mua hàng thất bại: $e');
      return false;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  /// Handle purchase updates
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      _handlePurchase(purchaseDetails);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    debugPrint('Cập nhật mua hàng: ${purchaseDetails.status} cho ${purchaseDetails.productID}');

    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        onPurchasePending?.call();
        break;
        
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        // Verify with backend
        await _verifyPurchase(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        onPurchaseError?.call(purchaseDetails.error?.message ?? 'Mua hàng thất bại');
        break;
        
      case PurchaseStatus.canceled:
        onPurchaseError?.call('Đã hủy mua hàng');
        break;
    }

    // Complete the purchase if pending completion
    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  /// Verify purchase with backend
  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      String? purchaseToken;
      String? orderId;

      // Get platform-specific purchase data
      if (Platform.isAndroid) {
        final androidDetails = purchaseDetails as GooglePlayPurchaseDetails;
        purchaseToken = androidDetails.billingClientPurchase.purchaseToken;
        orderId = androidDetails.billingClientPurchase.orderId;
      } else if (Platform.isIOS) {
        // For iOS, the verification data is in the server verification data
        purchaseToken = purchaseDetails.verificationData.serverVerificationData;
      }

      if (purchaseToken == null) {
        onPurchaseError?.call('Không thể lấy token mua hàng');
        return;
      }

      // Send to backend for verification
      final endpoint = Platform.isAndroid 
          ? '/Subscription/verify/google-play'
          : '/Subscription/verify/app-store';

      final response = await _apiClient.post(
        endpoint,
        data: {
          'purchaseToken': purchaseToken,
          'productId': purchaseDetails.productID,
          'packageName': 'com.moneymanager.money_manager',
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'orderId': orderId,
        },
      );

      final result = PurchaseVerificationResult.fromJson(
        response.data as Map<String, dynamic>,
      );

      onPurchaseVerified?.call(result);
    } catch (e) {
      debugPrint('Lỗi xác thực: $e');
      onPurchaseError?.call('Xác thực thất bại: $e');
    }
  }

  /// Get subscription status from backend
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    try {
      final response = await _apiClient.get('/Subscription/status');
      return SubscriptionStatus.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Lỗi lấy trạng thái gói: $e');
      return SubscriptionStatus.free;
    }
  }

  /// Dispose of the service
  void dispose() {
    _subscription?.cancel();
  }
}

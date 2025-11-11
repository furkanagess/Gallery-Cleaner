import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'preferences_service.dart';

/// Premium product ID for Android/iOS
const String _premiumProductId = 'lifetime_gallery_cleaner_premium';

/// Callback type for purchase completion
typedef PurchaseCompletionCallback = void Function(bool success);

/// Callback type for restore purchases completion
typedef RestoreCompletionCallback = void Function(bool success, bool hasRestored);

/// In-app purchase service for handling premium purchases
class InAppPurchaseService {
  static InAppPurchaseService? _instance;
  static InAppPurchaseService get instance {
    _instance ??= InAppPurchaseService._();
    return _instance!;
  }

  InAppPurchaseService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _purchasePending = false;
  String? _queryProductError;
  PurchaseCompletionCallback? _purchaseCompletionCallback;
  RestoreCompletionCallback? _restoreCompletionCallback;
  bool _isRestoring = false;

  /// Initialize the in-app purchase service
  Future<bool> initialize() async {
    try {
      _isAvailable = await _iap.isAvailable();
      
      if (!_isAvailable) {
        debugPrint('⚠️ [InAppPurchase] Store not available');
        return false;
      }

      // Listen to purchase updates
      _purchaseSubscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _purchaseSubscription?.cancel(),
        onError: (error) => debugPrint('❌ [InAppPurchase] Purchase stream error: $error'),
      );

      // Load products
      await loadProducts();

      debugPrint('✅ [InAppPurchase] Service initialized');
      return true;
    } catch (e) {
      debugPrint('❌ [InAppPurchase] Initialization error: $e');
      return false;
    }
  }

  /// Load available products
  Future<void> loadProducts() async {
    try {
      final Set<String> productIds = {_premiumProductId};
      final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        _queryProductError = response.error!.message;
        debugPrint('❌ [InAppPurchase] Query error: ${response.error!.message}');
        return;
      }

      if (response.productDetails.isEmpty) {
        debugPrint('⚠️ [InAppPurchase] No products found');
        return;
      }

      _products = response.productDetails;
      debugPrint('✅ [InAppPurchase] Products loaded: ${_products.length}');
      
      for (final product in _products) {
        debugPrint('   - ${product.id}: ${product.title} (${product.price})');
      }
    } catch (e) {
      debugPrint('❌ [InAppPurchase] Load products error: $e');
    }
  }

  /// Get premium product details
  ProductDetails? getPremiumProduct() {
    try {
      return _products.firstWhere(
        (product) => product.id == _premiumProductId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if store is available
  bool get isAvailable => _isAvailable;

  /// Check if purchase is pending
  bool get isPurchasePending => _purchasePending;

  /// Get query error
  String? get queryError => _queryProductError;

  /// Purchase premium product
  Future<bool> purchasePremium({PurchaseCompletionCallback? onComplete}) async {
    try {
      final product = getPremiumProduct();
      if (product == null) {
        debugPrint('❌ [InAppPurchase] Premium product not found');
        return false;
      }

      _purchasePending = true;
      _purchaseCompletionCallback = onComplete;
      
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      if (Platform.isAndroid) {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else if (Platform.isIOS) {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }

      debugPrint('✅ [InAppPurchase] Purchase initiated');
      return true;
    } catch (e) {
      _purchasePending = false;
      _purchaseCompletionCallback = null;
      debugPrint('❌ [InAppPurchase] Purchase error: $e');
      return false;
    }
  }

  /// Handle purchase updates
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    bool hasRestoredPurchase = false;
    
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('⏳ [InAppPurchase] Purchase pending: ${purchaseDetails.productID}');
        _purchasePending = true;
      } else {
        _purchasePending = false;
        
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('❌ [InAppPurchase] Purchase error: ${purchaseDetails.error}');
          await _handlePurchaseError(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.purchased) {
          debugPrint('✅ [InAppPurchase] Purchase successful: ${purchaseDetails.productID}');
          await _handlePurchaseSuccess(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.restored) {
          debugPrint('✅ [InAppPurchase] Purchase restored: ${purchaseDetails.productID}');
          hasRestoredPurchase = true;
          await _handlePurchaseSuccess(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          debugPrint('⚠️ [InAppPurchase] Purchase canceled: ${purchaseDetails.productID}');
        }

        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
    
    // If we were restoring and found restored purchases, notify callback
    if (_isRestoring && hasRestoredPurchase) {
      _restoreCompletionCallback?.call(true, true);
      _restoreCompletionCallback = null;
      _isRestoring = false;
    } else if (_isRestoring && purchaseDetailsList.isNotEmpty) {
      // Restore completed but no purchases found
      _isRestoring = false;
      // Don't call callback yet, wait for all updates
    }
  }

  /// Handle successful purchase
  Future<void> _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
    try {
      if (purchaseDetails.productID == _premiumProductId) {
        // Set premium status
        final prefsService = PreferencesService();
        await prefsService.setPremium(true);
        debugPrint('✅ [InAppPurchase] Premium status set to true');
        
        // Notify callback
        _purchaseCompletionCallback?.call(true);
        _purchaseCompletionCallback = null;
      }
    } catch (e) {
      debugPrint('❌ [InAppPurchase] Handle purchase success error: $e');
      _purchaseCompletionCallback?.call(false);
      _purchaseCompletionCallback = null;
    }
  }

  /// Handle purchase error
  Future<void> _handlePurchaseError(PurchaseDetails purchaseDetails) async {
    try {
      debugPrint('❌ [InAppPurchase] Purchase error: ${purchaseDetails.error?.message}');
      _purchaseCompletionCallback?.call(false);
      _purchaseCompletionCallback = null;
      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    } catch (e) {
      debugPrint('❌ [InAppPurchase] Handle purchase error: $e');
      _purchaseCompletionCallback?.call(false);
      _purchaseCompletionCallback = null;
    }
  }

  /// Restore purchases
  Future<void> restorePurchases({RestoreCompletionCallback? onComplete}) async {
    try {
      _isRestoring = true;
      _restoreCompletionCallback = onComplete;
      
      await _iap.restorePurchases();
      debugPrint('✅ [InAppPurchase] Restore purchases initiated');
      
      // Set a timeout to handle case where no purchases are restored
      // iOS restore can take some time, so we wait a bit longer
      Future.delayed(const Duration(seconds: 3), () {
        if (_isRestoring && _restoreCompletionCallback != null) {
          _isRestoring = false;
          _restoreCompletionCallback?.call(false, false);
          _restoreCompletionCallback = null;
          debugPrint('⚠️ [InAppPurchase] Restore purchases timeout - no purchases found');
        }
      });
    } catch (e) {
      _isRestoring = false;
      if (_restoreCompletionCallback != null) {
        _restoreCompletionCallback?.call(false, false);
        _restoreCompletionCallback = null;
      }
      debugPrint('❌ [InAppPurchase] Restore purchases error: $e');
    }
  }
  
  /// Check if restoring purchases
  bool get isRestoring => _isRestoring;

  /// Dispose the service
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }
}


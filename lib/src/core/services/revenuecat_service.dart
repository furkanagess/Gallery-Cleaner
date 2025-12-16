// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'preferences_service.dart';

/// RevenueCat purchase service wrapper
///
/// This service centralizes initialization and common operations
/// so the rest of the app can stay clean and provider-friendly.
class RevenueCatService {
  static RevenueCatService? _instance;
  static RevenueCatService get instance {
    _instance ??= RevenueCatService._();
    return _instance!;
  }

  RevenueCatService._();

  bool _configured = false;

  /// RevenueCat identifiers and public SDK keys
  static const String revenueCatAppId = 'app761199cb15';

  /// RevenueCat public SDK keys (platform-specific).
  /// NOTE: These are PUBLIC keys (safe for client apps). For production,
  /// consider injecting via build-time config.
  static const String _androidPublicKey = 'goog_RDHXtiyMMTNFGrseBxSNVpiLrfB';
  static const String _iosPublicKey = 'appl_oKgzJzDDTXyZunWhwqbociivoVP';

  /// Your identifiers from RevenueCat dashboard:
  /// Offering identifier: gallery_cleaner_299
  /// Display Name: Gallery Cleaner Plus
  /// Lifetime package identifier (standard): $rc_lifetime
  /// Android Product: gallery_cleaner_ab_test_4.99
  /// iOS Product: gallery_cleaner_499
  static const String offeringId = 'gallery_cleaner_499';
  static const String lifetimePackageId = '\$rc_lifetime';
  static const String entitlementId = 'premium'; // must match RC entitlement id

  Future<void> initialize() async {
    if (_configured) return;
    try {
      debugPrint('🟦 [RevenueCat] initialize() starting...');
      final selectedKey = Platform.isAndroid
          ? _androidPublicKey
          : _iosPublicKey;
      final configuration = PurchasesConfiguration(selectedKey);
      await Purchases.configure(configuration);
      _configured = true;
      final maskedKey = selectedKey.length > 6
          ? '${selectedKey.substring(0, 6)}…${selectedKey.substring(selectedKey.length - 3)}'
          : selectedKey;
      debugPrint(
        '✅ [RevenueCat] configured | platform=${Platform.isAndroid ? 'android' : 'ios'} '
        'appId=$revenueCatAppId offeringId=$offeringId entitlementId=$entitlementId key=$maskedKey',
      );
    } catch (e) {
      debugPrint('❌ [RevenueCat] configure error: $e');
    }
  }

  Future<Offerings?> getOfferings() async {
    try {
      debugPrint('🟦 [RevenueCat] getOfferings()...');
      final o = await Purchases.getOfferings();
      if (o.current == null || o.current!.availablePackages.isEmpty) {
        debugPrint(
          '⚠️ [RevenueCat] No offerings found. Please configure offerings in RevenueCat dashboard.',
        );
        debugPrint('   📝 Steps:');
        debugPrint('   1. Go to RevenueCat Dashboard > Offerings');
        debugPrint('   2. Create offering with ID: $offeringId');
        debugPrint('   3. Add package with identifier: $lifetimePackageId');
        debugPrint('   4. Ensure products are active in stores');
      } else {
        debugPrint(
          '✅ [RevenueCat] offerings loaded | current=${o.current?.identifier} '
          'packages=${o.current?.availablePackages.length ?? 0}',
        );
      }
      return o;
    } on PlatformException catch (e) {
      if (e.code == '23' || e.message?.contains('ConfigurationError') == true) {
        debugPrint(
          '⚠️ [RevenueCat] Configuration Error - Offerings not configured in dashboard',
        );
        debugPrint(
          '   💡 This is expected if you haven\'t set up offerings yet.',
        );
        debugPrint('   📖 Guide: https://rev.cat/how-to-configure-offerings');
      } else {
        debugPrint('❌ [RevenueCat] getOfferings error: $e');
      }
      return null;
    } catch (e) {
      debugPrint('❌ [RevenueCat] getOfferings error: $e');
      return null;
    }
  }

  Future<Package?> _findLifetimePackage(Offerings offerings) async {
    Offering? targetOffering;
    final current = offerings.current;

    // Try to find the specified offering first
    if (offeringId.isNotEmpty && offerings.all.containsKey(offeringId)) {
      targetOffering = offerings.all[offeringId];
      debugPrint('✅ [RevenueCat] Using specified offering: $offeringId');
    } else if (current != null && current.identifier == offeringId) {
      targetOffering = current;
      debugPrint(
        '✅ [RevenueCat] Using current offering: ${current.identifier}',
      );
    } else {
      // Fallback to current offering if specified offering not found
      targetOffering = current;
      if (targetOffering == null && offerings.all.isNotEmpty) {
        targetOffering = offerings.all.values.first;
        debugPrint(
          '⚠️ [RevenueCat] Specified offering "$offeringId" not found, using first available: ${targetOffering.identifier}',
        );
      }
    }

    if (targetOffering == null) {
      debugPrint(
        '❌ [RevenueCat] No offering found. current=${current?.identifier} '
        'requested=$offeringId all=${offerings.all.keys.toList()}',
      );
      return null;
    }

    Package? pkg = targetOffering.lifetime;
    if (pkg == null) {
      final list = targetOffering.availablePackages;
      final byType = list.where((p) => p.packageType == PackageType.lifetime);
      pkg = byType.isNotEmpty
          ? byType.first
          : (list.isNotEmpty ? list.first : null);
    }
    if (pkg == null) {
      debugPrint(
        '❌ [RevenueCat] Lifetime package not found in offering "${targetOffering.identifier}".',
      );
    } else {
      debugPrint(
        '✅ [RevenueCat] Lifetime package found | offering=${targetOffering.identifier} '
        'price=${pkg.storeProduct.priceString}',
      );
    }
    return pkg;
  }

  Future<Package?> fetchLifetimePackage() async {
    await initialize();
    final offerings = await getOfferings();
    if (offerings == null) return null;
    return _findLifetimePackage(offerings);
  }

  Future<StoreProduct?> fetchLifetimeProduct() async {
    final package = await fetchLifetimePackage();
    final product = package?.storeProduct;
    if (product != null) {
      debugPrint(
        '✅ [RevenueCat] Lifetime product loaded '
        '| id=${product.identifier} price=${product.priceString} currency=${product.currencyCode}',
      );
    }
    return product;
  }

  Future<bool> purchaseLifetime() async {
    try {
      debugPrint('🟦 [RevenueCat] purchaseLifetime()...');
      final pkg = await fetchLifetimePackage();
      if (pkg == null) {
        debugPrint(
          '❌ [RevenueCat] Offerings not available. Please configure in dashboard.',
        );
        return false;
      }

      debugPrint(
        '🟩 [RevenueCat] purchasing package '
        '| offering=${pkg.offeringIdentifier} '
        'packageType=${pkg.packageType} '
        'productId=${pkg.storeProduct.identifier} '
        'price=${pkg.storeProduct.priceString}',
      );
      final purchaseResult = await Purchases.purchasePackage(pkg);
      final active = await _markPremiumIfActive(purchaseResult.customerInfo);
      if (active) return true;

      // Entitlement might take a moment; re-fetch latest info before failing.
      final refreshedInfo = await Purchases.getCustomerInfo();
      final refreshedActive = await _markPremiumIfActive(refreshedInfo);
      if (refreshedActive) {
        debugPrint('✅ [RevenueCat] Entitlement activated after refresh.');
        return true;
      }

      debugPrint(
        '⚠️ [RevenueCat] Purchase completed but entitlement "$entitlementId" is not active yet.',
      );
      return false;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);

      // Handle user cancelled error - simülatörde bazen yanlış pozitif olabilir
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('⚠️ [RevenueCat] Purchase was cancelled by user.');
        // Simülatörde bazen bu hata yanlış oluşabiliyor,
        // o yüzden bir kez daha premium durumunu kontrol edelim
        final premium = await isPremium();
        if (premium) {
          debugPrint(
            '✅ [RevenueCat] Premium is active despite cancellation error (possible simulator false positive).',
          );
          return true;
        }
        return false;
      }

      // Handle already purchased error
      if (errorCode == PurchasesErrorCode.productAlreadyPurchasedError) {
        debugPrint(
          'ℹ️ [RevenueCat] Product already purchased. Attempting restore.',
        );
        final restored = await restore();
        if (restored) return true;
        final premium = await isPremium();
        if (premium) return true;
      }

      debugPrint(
        '⚠️ [RevenueCat] purchase platform error: $errorCode | message=${e.message} | details=${e.details}',
      );
      return false;
    } catch (e) {
      debugPrint('❌ [RevenueCat] purchase error: $e');
      // Genel hata durumunda da premium durumunu kontrol edelim
      final premium = await isPremium();
      if (premium) {
        debugPrint('✅ [RevenueCat] Premium is active despite error.');
        return true;
      }
      return false;
    }
  }

  Future<bool> restore() async {
    try {
      debugPrint('🟦 [RevenueCat] restorePurchases()...');
      final info = await Purchases.restorePurchases();
      var active = await _markPremiumIfActive(info);
      if (active) return true;

      final refreshedInfo = await Purchases.getCustomerInfo();
      active = await _markPremiumIfActive(refreshedInfo);
      debugPrint(
        '✅ [RevenueCat] restore result after refresh | premiumActive=$active',
      );
      return active;
    } catch (e) {
      debugPrint('❌ [RevenueCat] restore error: $e');
      return false;
    }
  }

  Future<bool> isPremium() async {
    try {
      debugPrint('🟦 [RevenueCat] isPremium() check...');
      final info = await Purchases.getCustomerInfo();
      final active = info.entitlements.all[entitlementId]?.isActive == true;
      debugPrint('✅ [RevenueCat] isPremium=$active');
      return active;
    } catch (e) {
      debugPrint('❌ [RevenueCat] getCustomerInfo error: $e');
      return false;
    }
  }

  void addCustomerInfoListener(VoidCallback onChange) {
    debugPrint('🟦 [RevenueCat] addCustomerInfoUpdateListener() registered');
    Purchases.addCustomerInfoUpdateListener((info) {
      final active = info.entitlements.all[entitlementId]?.isActive == true;
      debugPrint(
        '🔁 [RevenueCat] customerInfo updated | premiumActive=$active',
      );
      onChange();
    });
  }

  Future<bool> _markPremiumIfActive(CustomerInfo info) async {
    final active = _hasActiveEntitlement(info);
    if (active) {
      await PreferencesService().setPremium(true);
      debugPrint(
        '💾 [RevenueCat] Local premium flag persisted (entitlement active).',
      );
    }
    return active;
  }

  bool _hasActiveEntitlement(CustomerInfo info) {
    final premiumActive =
        info.entitlements.all[entitlementId]?.isActive == true;
    final anyActive = info.entitlements.active.isNotEmpty;
    return premiumActive || anyActive;
  }
}

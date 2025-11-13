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

  /// Your identifiers from RevenueCat dashboard (based on screenshots):
  /// Offering identifier: gallerycleanerpremiumoffering
  /// Lifetime package identifier (standard): $rc_lifetime
  /// Product identifier in stores: lifetime_gallery_cleaner_premium
  static const String offeringId = 'gallerycleanerpremiumoffering';
  static const String lifetimePackageId = '\$rc_lifetime';
  static const String entitlementId = 'premium'; // must match RC entitlement id

  Future<void> initialize() async {
    if (_configured) return;
    try {
      debugPrint('🟦 [RevenueCat] initialize() starting...');
      final selectedKey = Platform.isAndroid ? _androidPublicKey : _iosPublicKey;
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
        debugPrint('⚠️ [RevenueCat] No offerings found. Please configure offerings in RevenueCat dashboard.');
        debugPrint('   📝 Steps:');
        debugPrint('   1. Go to RevenueCat Dashboard > Offerings');
        debugPrint('   2. Create offering with ID: $offeringId');
        debugPrint('   3. Add product ID: lifetime_gallery_cleaner_premium');
        debugPrint('   4. Ensure product is active in Google Play Console');
      } else {
        debugPrint('✅ [RevenueCat] offerings loaded | current=${o.current?.identifier} '
            'packages=${o.current?.availablePackages.length ?? 0}');
      }
      return o;
    } on PlatformException catch (e) {
      if (e.code == '23' || e.message?.contains('ConfigurationError') == true) {
        debugPrint('⚠️ [RevenueCat] Configuration Error - Offerings not configured in dashboard');
        debugPrint('   💡 This is expected if you haven\'t set up offerings yet.');
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

    if (current != null && (offeringId.isEmpty || current.identifier == offeringId)) {
      targetOffering = current;
    } else {
      targetOffering = offerings.all[offeringId];
      targetOffering ??= current;
      targetOffering ??= offerings.all.isNotEmpty ? offerings.all.values.first : null;
    }

    if (targetOffering == null) {
      debugPrint('❌ [RevenueCat] No offering found. current=${current?.identifier} '
          'requested=$offeringId all=${offerings.all.keys.toList()}');
      return null;
    }

    Package? pkg = targetOffering.lifetime;
    if (pkg == null) {
      final list = targetOffering.availablePackages;
      final byType = list.where((p) => p.packageType == PackageType.lifetime);
      pkg = byType.isNotEmpty ? byType.first : (list.isNotEmpty ? list.first : null);
    }
    if (pkg == null) {
      debugPrint(
        '❌ [RevenueCat] Lifetime package not found in offering "${targetOffering.identifier}".',
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
        debugPrint('❌ [RevenueCat] Offerings not available. Please configure in dashboard.');
        return false;
      }

      debugPrint('🟩 [RevenueCat] purchasing package '
          '| offering=${pkg.offeringIdentifier} '
          'packageType=${pkg.packageType} '
          'productId=${pkg.storeProduct.identifier} '
          'price=${pkg.storeProduct.priceString}');
      final purchaseResult = await Purchases.purchasePackage(pkg);
      final active = purchaseResult.customerInfo.entitlements.all[entitlementId]?.isActive == true;
      debugPrint('✅ [RevenueCat] purchase result | premiumActive=$active');
      if (active) {
        await PreferencesService().setPremium(true);
        debugPrint('💾 [RevenueCat] Local premium flag persisted (purchase).');
      }
      return active;
    } on PurchasesErrorCode catch (e) {
      debugPrint('⚠️ [RevenueCat] purchase cancelled/error: $e');
      return false;
    } catch (e) {
      debugPrint('❌ [RevenueCat] purchase error: $e');
      return false;
    }
  }

  Future<bool> restore() async {
    try {
      debugPrint('🟦 [RevenueCat] restorePurchases()...');
      final info = await Purchases.restorePurchases();
      final active = info.entitlements.all[entitlementId]?.isActive == true;
      debugPrint('✅ [RevenueCat] restore result | premiumActive=$active');
      if (active) {
        await PreferencesService().setPremium(true);
        debugPrint('💾 [RevenueCat] Local premium flag persisted (restore).');
      }
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
      debugPrint('🔁 [RevenueCat] customerInfo updated | premiumActive=$active');
      onChange();
    });
  }
}



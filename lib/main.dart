import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app/app.dart';
import 'src/core/services/rewarded_ads_service.dart';
import 'src/core/services/revenuecat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Mobile Ads SDK with error handling
  try {
    await RewardedAdsService.initialize();
    // Preload all ad types after initialization
    await Future.delayed(const Duration(seconds: 2));
    // Reklamlar artık sadece dialog açıldığında yüklenecek
    // await RewardedAdsService.preloadAllAds();
  } catch (e) {
    debugPrint('⚠️ [main] Failed to initialize ads service: $e');
    // Continue app startup even if ads fail to initialize
  }

  // Initialize RevenueCat
  try {
    await RevenueCatService.instance.initialize();
  } catch (e) {
    debugPrint('⚠️ [main] Failed to initialize RevenueCat: $e');
    // Continue app startup even if purchases fail to initialize
  }

  runApp(const ProviderScope(child: App()));
}

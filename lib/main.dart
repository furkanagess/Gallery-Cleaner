import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app/app.dart';
import 'src/core/services/rewarded_ads_service.dart';
import 'src/core/services/in_app_purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Mobile Ads SDK with error handling
  try {
    await RewardedAdsService.initialize();
  } catch (e) {
    debugPrint('⚠️ [main] Failed to initialize ads service: $e');
    // Continue app startup even if ads fail to initialize
  }

  // Initialize In-App Purchase service
  try {
    await InAppPurchaseService.instance.initialize();
  } catch (e) {
    debugPrint('⚠️ [main] Failed to initialize in-app purchase service: $e');
    // Continue app startup even if in-app purchase fails to initialize
  }

  runApp(const ProviderScope(child: App()));
}

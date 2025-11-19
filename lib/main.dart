import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app/app.dart';
import 'src/core/services/interstitial_ads_service.dart';
import 'src/core/services/revenuecat_service.dart';
import 'src/core/services/rewarded_ads_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ [main] .env file loaded');
  } catch (e) {
    debugPrint('⚠️ [main] Failed to load .env file: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  } catch (e) {
    debugPrint('⚠️ [main] Failed to initialize Firebase: $e');
  }

  // Initialize Mobile Ads SDK with error handling
  try {
    await RewardedAdsService.initialize();
    // Preload all ad types after initialization (bir kere initialize et)
    await Future.delayed(const Duration(seconds: 2));
    await RewardedAdsService.preloadAllAds();

    // Preload interstitial ads after initialization
    await Future.delayed(const Duration(milliseconds: 500));
    await InterstitialAdsService.instance.loadAd();
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

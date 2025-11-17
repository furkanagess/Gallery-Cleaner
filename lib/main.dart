import 'dart:io' show Platform;
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'firebase_options.dart';
import 'src/app/app.dart';
import 'src/core/services/interstitial_ads_service.dart';
import 'src/core/services/revenuecat_service.dart';
import 'src/core/services/rewarded_ads_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // iOS için PhotoManager'ın initialize olması için gecikme ekle
  // İlk girişte PhotoManager henüz hazır olmayabilir
  if (Platform.isIOS) {
    try {
      // PhotoManager'ın initialize olması için ilk çağrıyı yap
      await pm.PhotoManager.requestPermissionExtend();
      // iOS'ta native initialization için kısa bir gecikme
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('⚠️ [main] Failed to pre-initialize PhotoManager: $e');
      // Hata olsa bile devam et, PhotoManager kendi initialize edecektir
    }
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

import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app/app.dart';
import 'src/core/services/ads_initializer.dart';
import 'src/core/services/apple_search_ads_service.dart';
import 'src/core/services/revenuecat_service.dart';

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

  await AdsInitializer.instance.initializeOnLaunch();

  // Initialize RevenueCat
  try {
    await RevenueCatService.instance.initialize();

    // Initialize Apple Search Ads attribution (iOS only)
    // This should be called after RevenueCat is initialized
    try {
      await AppleSearchAdsService.instance.initialize();
    } catch (e) {
      debugPrint('⚠️ [main] Failed to initialize Apple Search Ads: $e');
      // Continue app startup even if attribution fails
    }
  } catch (e) {
    debugPrint('⚠️ [main] Failed to initialize RevenueCat: $e');
    // Continue app startup even if purchases fail to initialize
  }

  runApp(const ProviderScope(child: App()));
}

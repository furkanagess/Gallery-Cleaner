import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'interstitial_ads_service.dart';
import 'preferences_service.dart';
import 'rewarded_ads_service.dart';

/// Handles initializing and warming up ads whenever the app launches
/// or returns to the foreground.
class AdsInitializer with WidgetsBindingObserver {
  AdsInitializer._();
  static final AdsInitializer instance = AdsInitializer._();

  bool _sdkInitialized = false;
  bool _isWarmingUp = false;
  Completer<void>? _warmupCompleter;

  /// Call once from `main` to initialize ads and start lifecycle listening.
  Future<void> initializeOnLaunch() async {
    WidgetsBinding.instance.addObserver(this);
    await _warmUpAds();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _warmUpAds();
    }
  }

  Future<void> _warmUpAds() async {
    if (_isWarmingUp) {
      await _warmupCompleter?.future;
      return;
    }

    _isWarmingUp = true;
    _warmupCompleter = Completer<void>();

    try {
      final prefs = PreferencesService();
      final isPremium = await prefs.isPremium();
      if (isPremium) {
        debugPrint(
          '💎 [AdsInitializer] Premium user detected, skipping ad warm-up.',
        );
        _warmupCompleter?.complete();
        return;
      }

      if (!_sdkInitialized) {
        debugPrint('📱 [AdsInitializer] Initializing Mobile Ads SDK...');
        await RewardedAdsService.initialize();
        _sdkInitialized = true;
      }

      debugPrint(
        '📱 [AdsInitializer] Warming up rewarded and interstitial ads...',
      );
      await RewardedAdsService.preloadAllAds();
      await Future.delayed(const Duration(milliseconds: 500));
      await InterstitialAdsService.instance.loadAd();
      debugPrint('✅ [AdsInitializer] Ads are warmed up and ready.');
      _warmupCompleter?.complete();
    } catch (e, stackTrace) {
      debugPrint('❌ [AdsInitializer] Failed to warm up ads: $e');
      debugPrint('❌ [AdsInitializer] Stack trace: $stackTrace');
      _warmupCompleter?.completeError(e, stackTrace);
    } finally {
      _isWarmingUp = false;
    }
  }
}

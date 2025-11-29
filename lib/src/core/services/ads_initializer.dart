import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'interstitial_ads_service.dart';
import 'preferences_service.dart';

/// Handles initializing and warming up ads whenever the app launches
/// or returns to the foreground.
class AdsInitializer with WidgetsBindingObserver {
  AdsInitializer._();
  static final AdsInitializer instance = AdsInitializer._();

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

      debugPrint('📱 [AdsInitializer] Warming up interstitial ads...');
      await InterstitialAdsService.instance.loadAd();
      debugPrint(
        '✅ [AdsInitializer] Interstitial ads are warmed up and ready.',
      );
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

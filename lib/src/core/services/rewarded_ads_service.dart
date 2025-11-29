import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_unit_ids.dart';

/// Ad unit types for different features
enum AdUnitType {
  deleteLimit, // Delete rights reward
  blurScanLimit, // Blur scan rights reward
  duplicateScanLimit, // Duplicate scan rights reward
}

class RewardedAdsService {
  // Singleton instance
  static RewardedAdsService? _instance;
  static RewardedAdsService get instance {
    _instance ??= RewardedAdsService._();
    return _instance!;
  }

  RewardedAdsService._();

  // Ad Unit IDs for different features
  // Test Ad Unit IDs (use these for development)
  // Test rewarded interstitial ad unit ID (same for Android and iOS)
  static const String _testAdUnitId =
      'ca-app-pub-3940256099942544/5354046379'; // Test rewarded interstitial ad

  // Use test ads in debug mode
  // Set to false for production to use real ad units
  static const bool _useTestAds =
      kDebugMode; // Use test ads in debug mode, real ads in production

  // Map to store ads for each type
  final Map<AdUnitType, _RewardedAdWrapper?> _ads = {};
  final Map<AdUnitType, bool> _isLoading = {};
  final Map<AdUnitType, bool> _isShowing = {};
  final Map<AdUnitType, Completer<bool>?> _showCompleters = {};
  final Map<AdUnitType, bool> _rewardEarned = {};
  bool _isDisposed = false;
  final Set<AdUnitType> _forceStandardRewarded = {};
  final Map<AdUnitType, Timer?> _retryTimers = {}; // Retry timer'ları sakla

  /// Preload all ad types when app starts
  static Future<void> preloadAllAds() async {
    try {
      debugPrint('📱 [RewardedAdsService] Preloading all ad types...');
      final service = instance;
      if (service._isDisposed) return;
      await service.loadRewardedAd(AdUnitType.deleteLimit);
      if (service._isDisposed) return;
      await Future.delayed(const Duration(milliseconds: 500));
      if (service._isDisposed) return;
      await service.loadRewardedAd(AdUnitType.blurScanLimit);
      if (service._isDisposed) return;
      await Future.delayed(const Duration(milliseconds: 500));
      if (service._isDisposed) return;
      await service.loadRewardedAd(AdUnitType.duplicateScanLimit);
      if (service._isDisposed) return;
      debugPrint('✅ [RewardedAdsService] All ad types preload initiated');
    } catch (e) {
      debugPrint('❌ [RewardedAdsService] Error preloading ads: $e');
    }
  }

  /// Initialize Mobile Ads SDK
  static Future<void> initialize() async {
    try {
      final initializationStatus = await MobileAds.instance.initialize();
      debugPrint('📱 [RewardedAdsService] Mobile Ads SDK initialized');

      // Log adapter statuses
      for (var entry in initializationStatus.adapterStatuses.entries) {
        final adapterStatus = entry.value;
        debugPrint(
          '📱 [RewardedAdsService] Adapter: ${entry.key}, State: ${adapterStatus.state}, Latency: ${adapterStatus.latency}ms',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        '❌ [RewardedAdsService] Failed to initialize Mobile Ads SDK: $e',
      );
      debugPrint('❌ [RewardedAdsService] Stack trace: $stackTrace');
    }
  }

  /// Get ad unit ID for a specific type and platform
  String _getAdUnitId(AdUnitType type) {
    final isAndroid = Platform.isAndroid;
    // Use test ads if _useTestAds is true (which is true in debug mode)
    if (_useTestAds) {
      debugPrint(
        '📱 [RewardedAdsService] Using test ad unit ID for type: $type (Debug mode)',
      );
      return _testAdUnitId;
    }

    // Use production ad unit IDs retrieved from .env
    switch (type) {
      case AdUnitType.deleteLimit:
        final adUnitId = isAndroid
            ? AdUnitIds.deleteLimitAndroid
            : AdUnitIds.deleteLimitIos;
        debugPrint(
          '📱 [RewardedAdsService] Using DELETE LIMIT ad unit: $adUnitId (Swipe Tab)',
        );
        return adUnitId;
      case AdUnitType.blurScanLimit:
        final adUnitId = isAndroid
            ? AdUnitIds.blurScanLimitAndroid
            : AdUnitIds.blurScanLimitIos;
        debugPrint(
          '📱 [RewardedAdsService] Using BLUR SCAN LIMIT ad unit: $adUnitId (Blur Tab)',
        );
        return adUnitId;
      case AdUnitType.duplicateScanLimit:
        final adUnitId = isAndroid
            ? AdUnitIds.duplicateScanLimitAndroid
            : AdUnitIds.duplicateScanLimitIos;
        debugPrint(
          '📱 [RewardedAdsService] Using DUPLICATE SCAN LIMIT ad unit: $adUnitId (Duplicate Tab)',
        );
        return adUnitId;
    }
  }

  /// Load a rewarded interstitial ad for a specific type
  Future<void> loadRewardedAd(AdUnitType type) async {
    if (_isDisposed) {
      debugPrint(
        '⚠️ [RewardedAdsService] Service is disposed, cannot load ad for type: $type',
      );
      return;
    }

    // If already loading or already loaded, return
    if (_isLoading[type] == true) {
      debugPrint(
        '⚠️ [RewardedAdsService] Ad is already loading for type: $type',
      );
      return;
    }

    if (_ads[type] != null) {
      debugPrint(
        '⚠️ [RewardedAdsService] Ad is already loaded for type: $type',
      );
      return;
    }

    try {
      // Ensure ads SDK is initialized
      try {
        await MobileAds.instance.initialize();
        debugPrint('✅ [RewardedAdsService] Mobile Ads SDK initialized');
      } catch (e) {
        debugPrint('⚠️ [RewardedAdsService] Ads SDK initialization check: $e');
      }

      _isLoading[type] = true;
      final adUnitId = _getAdUnitId(type);

      debugPrint(
        '📱 [RewardedAdsService] Loading ad for type: $type, adUnitId: $adUnitId',
      );

      if (_forceStandardRewarded.contains(type)) {
        await _loadStandardRewardedAd(type, adUnitId);
        return;
      }

      await _loadRewardedInterstitial(type, adUnitId);
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      debugPrint(
        '❌ [RewardedAdsService] Exception while loading ad for type: $type, error: $e',
      );
      debugPrint('❌ [RewardedAdsService] Stack trace: $stackTrace');
      _isLoading[type] = false;
      _ads[type]?.dispose();
      _ads[type] = null;
    }
  }

  Future<void> _loadRewardedInterstitial(
    AdUnitType type,
    String adUnitId,
  ) async {
    if (_isDisposed) return;
    
    try {
      await RewardedInterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (RewardedInterstitialAd ad) {
            if (_isDisposed) {
              try {
                ad.dispose();
              } catch (e) {
                // Ad zaten dispose edilmiş olabilir, sessizce yok say
              }
              return;
            }
            debugPrint(
              '✅ [RewardedAdsService] Rewarded interstitial ad loaded successfully for type: $type',
            );
            final wrapper = _RewardedAdWrapper.interstitial(ad);
            _ads[type]?.dispose();
            _ads[type] = wrapper;
            _isLoading[type] = false;
            _rewardEarned[type] = false;
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (_isDisposed) return;
            debugPrint(
              '❌ [RewardedAdsService] Failed to load rewarded interstitial ad for type: $type',
            );
            debugPrint(
              '❌ [RewardedAdsService] Error code: ${error.code}, message: ${error.message}',
            );
            debugPrint('❌ [RewardedAdsService] Domain: ${error.domain}');
            if (error.responseInfo != null) {
              debugPrint(
                '❌ [RewardedAdsService] Response ID: ${error.responseInfo?.responseId}',
              );
              debugPrint(
                '❌ [RewardedAdsService] Mediation adapter: ${error.responseInfo?.mediationAdapterClassName}',
              );
            }
            if (_isDisposed) return;
            _isLoading[type] = false;
            _ads[type]?.dispose();
            _ads[type] = null;

            if (_isDisposed) return;
            if (Platform.isIOS) {
              debugPrint(
                'ℹ️ [RewardedAdsService] Falling back to standard rewarded ad for type: $type (iOS)',
              );
              _forceStandardRewarded.add(type);
              _loadStandardRewardedAd(type, adUnitId);
            } else {
              _scheduleRetry(type);
            }
          },
        ),
      );
    } catch (e) {
      if (_isDisposed) return;
      debugPrint(
        '❌ [RewardedAdsService] Exception in _loadRewardedInterstitial for type: $type, error: $e',
      );
      _isLoading[type] = false;
      _ads[type]?.dispose();
      _ads[type] = null;
    }
  }

  Future<void> _loadStandardRewardedAd(AdUnitType type, String adUnitId) async {
    if (_isDisposed) return;
    _isLoading[type] = true;
    
    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            if (_isDisposed) {
              try {
                ad.dispose();
              } catch (e) {
                // Ad zaten dispose edilmiş olabilir, sessizce yok say
              }
              return;
            }
            debugPrint(
              '✅ [RewardedAdsService] Standard rewarded ad loaded successfully for type: $type',
            );
            final wrapper = _RewardedAdWrapper.rewarded(ad);
            _ads[type]?.dispose();
            _ads[type] = wrapper;
            _isLoading[type] = false;
            _rewardEarned[type] = false;
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (_isDisposed) return;
            debugPrint(
              '❌ [RewardedAdsService] Failed to load standard rewarded ad for type: $type',
            );
            debugPrint(
              '❌ [RewardedAdsService] Error code: ${error.code}, message: ${error.message}',
            );
            debugPrint('❌ [RewardedAdsService] Domain: ${error.domain}');
            if (_isDisposed) return;
            _isLoading[type] = false;
            _ads[type]?.dispose();
            _ads[type] = null;
            _scheduleRetry(type);
          },
        ),
      );
    } catch (e) {
      if (_isDisposed) return;
      debugPrint(
        '❌ [RewardedAdsService] Exception in _loadStandardRewardedAd for type: $type, error: $e',
      );
      _isLoading[type] = false;
      _ads[type]?.dispose();
      _ads[type] = null;
    }
  }

  void _scheduleRetry(AdUnitType type) {
    if (_isDisposed) return;
    
    // Önceki timer'ı iptal et
    _retryTimers[type]?.cancel();
    
    _retryTimers[type] = Timer(const Duration(seconds: 10), () {
      if (_isDisposed) {
        _retryTimers[type] = null;
        return;
      }
      if (_ads[type] == null && _isLoading[type] != true) {
        debugPrint(
          '🔄 [RewardedAdsService] Retrying to load ad for type: $type',
        );
        loadRewardedAd(type);
      }
      _retryTimers[type] = null;
    });
  }

  /// Show rewarded interstitial ad for a specific type and return whether user earned reward
  Future<bool> showRewardedAd({
    required AdUnitType type,
    required Function() onRewarded,
    Function(String)? onError,
  }) async {
    if (_isDisposed) {
      onError?.call('Service is disposed');
      return false;
    }

    // Prevent multiple simultaneous show attempts for this type
    if (_isShowing[type] == true) {
      debugPrint(
        '⚠️ [RewardedAdsService] Ad is already being shown for type: $type',
      );
      onError?.call('Ad is already being shown');
      return false;
    }

    try {
      if (_ads[type] == null) {
        debugPrint(
          '⚠️ [RewardedAdsService] No ad loaded for type: $type, loading now...',
        );
        await loadRewardedAd(type);

        // Wait for ad to load with timeout (max 15 seconds)
        int waitCount = 0;
        const maxWaitCount = 30; // 30 * 500ms = 15 seconds
        while (_ads[type] == null && !_isDisposed && waitCount < maxWaitCount) {
          await Future.delayed(const Duration(milliseconds: 500));
          waitCount++;
          if (_isLoading[type] == false && _ads[type] == null) {
            // Loading failed, break early
            break;
          }
        }

        if (_ads[type] == null || _isDisposed) {
          onError?.call('Ad is not ready yet. Please try again in a moment.');
          debugPrint(
            '❌ [RewardedAdsService] Ad failed to load after waiting, type: $type',
          );
          return false;
        }
        debugPrint(
          '✅ [RewardedAdsService] Ad loaded successfully after waiting, type: $type',
        );
      }

      _showCompleters[type] = Completer<bool>();
      _rewardEarned[type] = false;
      _isShowing[type] = true;

      final currentAd = _ads[type];
      if (currentAd == null || _isDisposed) {
        _isShowing[type] = false;
        _showCompleters[type]?.complete(false);
        _showCompleters[type] = null;
        onError?.call('Ad is not available');
        return false;
      }

      currentAd.setFullScreenCallbacks(
        onDismissed: () {
          debugPrint(
            '📱 [RewardedAdsService] Rewarded ad dismissed for type: $type',
          );
          _handleAdDismissed(type);
        },
        onFailedToShow: (AdError error) {
          debugPrint(
            '❌ [RewardedAdsService] Rewarded ad failed to show for type: $type, error: $error',
          );
          _handleAdFailed(type, error, onError);
        },
        onShowed: () {
          debugPrint(
            '📱 [RewardedAdsService] Rewarded ad showed for type: $type',
          );
        },
      );

      currentAd.show(
        onUserEarnedReward: (RewardItem reward) {
          debugPrint(
            '🎉 [RewardedAdsService] User earned reward for type: $type, amount: ${reward.amount}, type: ${reward.type}',
          );
          _rewardEarned[type] = true;
          try {
            onRewarded();
          } catch (e) {
            debugPrint(
              '❌ [RewardedAdsService] Error in onRewarded callback for type: $type, error: $e',
            );
          }
        },
      );

      final result = await _showCompleters[type]!.future;
      return result;
    } catch (e) {
      debugPrint(
        '❌ [RewardedAdsService] Exception while showing ad for type: $type, error: $e',
      );
      _isShowing[type] = false;
      _showCompleters[type]?.complete(false);
      _showCompleters[type] = null;
      onError?.call('Failed to show ad: ${e.toString()}');
      return false;
    }
  }

  void _handleAdDismissed(AdUnitType type) {
    if (_isDisposed) return;

    try {
      _ads[type]?.dispose();
      _ads[type] = null;
      _isShowing[type] = false;

      if (_showCompleters[type] != null &&
          !_showCompleters[type]!.isCompleted) {
        _showCompleters[type]!.complete(_rewardEarned[type] ?? false);
      }
      _showCompleters[type] = null;

      // Load next ad for this type (sadece dispose edilmediyse)
      if (!_isDisposed) {
        loadRewardedAd(type);
      }
    } catch (e) {
      debugPrint(
        '❌ [RewardedAdsService] Error handling ad dismissal for type: $type, error: $e',
      );
    }
  }

  void _handleAdFailed(
    AdUnitType type,
    AdError error,
    Function(String)? onError,
  ) {
    if (_isDisposed) return;

    try {
      _ads[type]?.dispose();
      _ads[type] = null;
      _isShowing[type] = false;

      if (_showCompleters[type] != null &&
          !_showCompleters[type]!.isCompleted) {
        _showCompleters[type]!.complete(false);
      }
      _showCompleters[type] = null;

      onError?.call('Failed to show ad: ${error.message}');

      // Try to load next ad for this type (sadece dispose edilmediyse)
      if (!_isDisposed) {
        loadRewardedAd(type);
      }
    } catch (e) {
      debugPrint(
        '❌ [RewardedAdsService] Error handling ad failure for type: $type, error: $e',
      );
    }
  }

  /// Check if ad is ready for a specific type
  bool isAdReady(AdUnitType type) => _ads[type] != null && !_isDisposed;

  /// Check if ad is currently loading for a specific type
  bool isAdLoading(AdUnitType type) => _isLoading[type] == true && !_isDisposed;

  /// Check if ad is ready or loading for a specific type
  bool isAdReadyOrLoading(AdUnitType type) =>
      (isAdReady(type) || isAdLoading(type));

  /// Dispose resources
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;

    try {
      // Tüm retry timer'ları iptal et
      for (var timer in _retryTimers.values) {
        timer?.cancel();
      }
      _retryTimers.clear();

      // Dispose all ads
      for (var entry in _ads.entries) {
        entry.value?.dispose();
      }
      _ads.clear();

      // Clear all state
      _isLoading.clear();
      _isShowing.clear();

      // Complete all pending completers
      for (var entry in _showCompleters.entries) {
        if (entry.value != null && !entry.value!.isCompleted) {
          entry.value!.complete(false);
        }
      }
      _showCompleters.clear();
      _rewardEarned.clear();
    } catch (e) {
      debugPrint('❌ [RewardedAdsService] Error during dispose: $e');
    }
  }
}

class _RewardedAdWrapper {
  _RewardedAdWrapper.interstitial(this._interstitial) : _rewarded = null;
  _RewardedAdWrapper.rewarded(this._rewarded) : _interstitial = null;

  final RewardedInterstitialAd? _interstitial;
  final RewardedAd? _rewarded;

  void setFullScreenCallbacks({
    required VoidCallback onDismissed,
    required void Function(AdError error) onFailedToShow,
    required VoidCallback onShowed,
  }) {
    final interstitial = _interstitial;
    final rewarded = _rewarded;

    if (interstitial != null) {
      interstitial.fullScreenContentCallback =
          FullScreenContentCallback<RewardedInterstitialAd>(
            onAdDismissedFullScreenContent: (ad) => onDismissed(),
            onAdFailedToShowFullScreenContent: (ad, error) =>
                onFailedToShow(error),
            onAdShowedFullScreenContent: (ad) => onShowed(),
          );
    } else if (rewarded != null) {
      rewarded.fullScreenContentCallback =
          FullScreenContentCallback<RewardedAd>(
            onAdDismissedFullScreenContent: (ad) => onDismissed(),
            onAdFailedToShowFullScreenContent: (ad, error) =>
                onFailedToShow(error),
            onAdShowedFullScreenContent: (ad) => onShowed(),
          );
    }
  }

  void show({required void Function(RewardItem reward) onUserEarnedReward}) {
    final interstitial = _interstitial;
    final rewarded = _rewarded;

    if (interstitial != null) {
      interstitial.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          onUserEarnedReward(reward);
        },
      );
    } else if (rewarded != null) {
      rewarded.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          onUserEarnedReward(reward);
        },
      );
    }
  }

  void dispose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
  }
}

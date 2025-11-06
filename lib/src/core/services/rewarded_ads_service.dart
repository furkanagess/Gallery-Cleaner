import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdsService {
  static const String _androidAdUnitId = 'ca-app-pub-3499593115543692/1575404766';
  static const String _iosAdUnitId = 'ca-app-pub-3499593115543692/2388248395';
  
  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  bool _isShowing = false;
  Completer<bool>? _showCompleter;
  bool _rewardEarned = false;
  bool _isDisposed = false;

  /// Initialize Mobile Ads SDK
  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      debugPrint('📱 [RewardedAdsService] Mobile Ads SDK initialized');
    } catch (e) {
      debugPrint('❌ [RewardedAdsService] Failed to initialize Mobile Ads SDK: $e');
    }
  }

  /// Load a rewarded ad
  Future<void> loadRewardedAd() async {
    if (_isDisposed) return;
    if (_isLoading || _rewardedAd != null) return;
    
    try {
      // Check if ads SDK is initialized
      try {
        await MobileAds.instance.initialize();
      } catch (e) {
        debugPrint('⚠️ [RewardedAdsService] Ads SDK already initialized or error: $e');
      }
      
      _isLoading = true;
      final adUnitId = Platform.isAndroid ? _androidAdUnitId : _iosAdUnitId;
      
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            if (_isDisposed) {
              ad.dispose();
              return;
            }
            debugPrint('✅ [RewardedAdsService] Rewarded ad loaded');
            _rewardedAd = ad;
            _isLoading = false;
            _rewardEarned = false;
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (_isDisposed) return;
            debugPrint('❌ [RewardedAdsService] Failed to load rewarded ad: $error');
            _isLoading = false;
          },
        ),
      );
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      debugPrint('❌ [RewardedAdsService] Exception while loading ad: $e');
      debugPrint('❌ [RewardedAdsService] Stack trace: $stackTrace');
      _isLoading = false;
    }
  }

  /// Show rewarded ad and return whether user earned reward
  Future<bool> showRewardedAd({
    required Function() onRewarded,
    Function(String)? onError,
  }) async {
    if (_isDisposed) {
      onError?.call('Service is disposed');
      return false;
    }

    // Prevent multiple simultaneous show attempts
    if (_isShowing) {
      debugPrint('⚠️ [RewardedAdsService] Ad is already being shown');
      onError?.call('Ad is already being shown');
      return false;
    }

    try {
      if (_rewardedAd == null) {
        debugPrint('⚠️ [RewardedAdsService] No ad loaded, loading now...');
        await loadRewardedAd();
        // Wait a bit for ad to load
        await Future.delayed(const Duration(seconds: 1));
        if (_rewardedAd == null || _isDisposed) {
          onError?.call('Ad is not ready yet. Please try again in a moment.');
          return false;
        }
      }

      _showCompleter = Completer<bool>();
      _rewardEarned = false;
      _isShowing = true;
      
      final currentAd = _rewardedAd;
      if (currentAd == null || _isDisposed) {
        _isShowing = false;
        _showCompleter?.complete(false);
        onError?.call('Ad is not available');
        return false;
      }

      // Set full screen content callbacks
      currentAd.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          debugPrint('📱 [RewardedAdsService] Ad dismissed');
          _handleAdDismissed(ad);
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          debugPrint('❌ [RewardedAdsService] Ad failed to show: $error');
          _handleAdFailed(ad, error, onError);
        },
        onAdShowedFullScreenContent: (RewardedAd ad) {
          debugPrint('📱 [RewardedAdsService] Ad showed');
        },
      );
      
      currentAd.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          debugPrint('🎉 [RewardedAdsService] User earned reward: ${reward.amount} ${reward.type}');
          _rewardEarned = true;
          try {
            onRewarded();
          } catch (e) {
            debugPrint('❌ [RewardedAdsService] Error in onRewarded callback: $e');
          }
        },
      );

      final result = await _showCompleter!.future;
      return result;
    } catch (e) {
      debugPrint('❌ [RewardedAdsService] Exception while showing ad: $e');
      _isShowing = false;
      _showCompleter?.complete(false);
      onError?.call('Failed to show ad: ${e.toString()}');
      return false;
    }
  }

  void _handleAdDismissed(RewardedAd ad) {
    if (_isDisposed) return;
    
    try {
      ad.dispose();
      _rewardedAd = null;
      _isShowing = false;
      
      if (_showCompleter != null && !_showCompleter!.isCompleted) {
        _showCompleter!.complete(_rewardEarned);
      }
      _showCompleter = null;
      
      // Load next ad
      loadRewardedAd();
    } catch (e) {
      debugPrint('❌ [RewardedAdsService] Error handling ad dismissal: $e');
    }
  }

  void _handleAdFailed(RewardedAd ad, AdError error, Function(String)? onError) {
    if (_isDisposed) return;
    
    try {
      ad.dispose();
      _rewardedAd = null;
      _isShowing = false;
      
      if (_showCompleter != null && !_showCompleter!.isCompleted) {
        _showCompleter!.complete(false);
      }
      _showCompleter = null;
      
      onError?.call('Failed to show ad: ${error.message}');
      
      // Try to load next ad
      loadRewardedAd();
    } catch (e) {
      debugPrint('❌ [RewardedAdsService] Error handling ad failure: $e');
    }
  }

  /// Check if ad is ready
  bool get isAdReady => _rewardedAd != null && !_isDisposed;

  /// Dispose resources
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _isShowing = false;
    
    try {
      _rewardedAd?.dispose();
      _rewardedAd = null;
      _isLoading = false;
      
      if (_showCompleter != null && !_showCompleter!.isCompleted) {
        _showCompleter!.complete(false);
      }
      _showCompleter = null;
    } catch (e) {
      debugPrint('❌ [RewardedAdsService] Error during dispose: $e');
    }
  }
}


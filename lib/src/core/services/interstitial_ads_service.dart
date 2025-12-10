import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_unit_ids.dart';
import 'preferences_service.dart';

class InterstitialAdsService {
  // Singleton instance
  static InterstitialAdsService? _instance;
  static InterstitialAdsService get instance {
    _instance ??= InterstitialAdsService._();
    return _instance!;
  }
  
  InterstitialAdsService._();
  
  // Callback for when premium dialog should be shown (after 3 ads)
  Function()? onPremiumDialogTrigger;
  
  // Ad Unit IDs
  // Test Ad Unit ID (use for development)
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test interstitial ad
  
  // Use test ads in debug mode
  static const bool _useTestAds = kDebugMode;
  
  InterstitialAd? _ad;
  bool _isLoading = false;
  bool _isShowing = false;
  bool _isDisposed = false;
  Completer<bool>? _showCompleter; // Ad kapatılmasını beklemek için
  static bool _sdkInitialized = false; // MobileAds.instance.initialize() sadece 1 kez çağrılsın
  
  /// Get ad unit ID based on platform
  String get _adUnitId {
    if (_useTestAds) {
      return _testAdUnitId;
    }
    
    if (Platform.isAndroid) {
      return AdUnitIds.interstitialAndroid;
    } else if (Platform.isIOS) {
      return AdUnitIds.interstitialIos;
    } else {
      return _testAdUnitId;
    }
  }
  
  /// Load interstitial ad
  Future<void> loadAd() async {
    if (_isDisposed) {
      debugPrint('⚠️ [InterstitialAdsService] Service is disposed, cannot load ad');
      return;
    }
    
    // If already loading or already loaded, return
    if (_isLoading) {
      debugPrint('⚠️ [InterstitialAdsService] Ad is already loading');
      return;
    }
    
    if (_ad != null) {
      debugPrint('⚠️ [InterstitialAdsService] Ad is already loaded');
      return;
    }
    
    try {
      // Ensure ads SDK is initialized (sadece bir kez)
      if (!_sdkInitialized) {
      try {
        await MobileAds.instance.initialize();
          _sdkInitialized = true;
        debugPrint('✅ [InterstitialAdsService] Mobile Ads SDK initialized');
      } catch (e) {
        debugPrint('⚠️ [InterstitialAdsService] Ads SDK initialization check: $e');
        }
      }
      
      _isLoading = true;
      final adUnitId = _adUnitId;
      
      debugPrint('📱 [InterstitialAdsService] Loading interstitial ad, adUnitId: $adUnitId');
      
      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            if (_isDisposed) {
              try {
                ad.dispose();
              } catch (e) {
                // Ad zaten dispose edilmiş olabilir, sessizce yok say
              }
              return;
            }
            debugPrint('✅ [InterstitialAdsService] Interstitial ad loaded successfully');
            _ad = ad;
            _isLoading = false;
            
            // Set full screen content callbacks (henüz gösterilmedi, callback'ler showAd'da set edilecek)
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (_isDisposed) return;
            debugPrint('❌ [InterstitialAdsService] Failed to load interstitial ad');
            debugPrint('❌ [InterstitialAdsService] Error code: ${error.code}, message: ${error.message}');
            debugPrint('❌ [InterstitialAdsService] Domain: ${error.domain}');
            if (error.responseInfo != null) {
              debugPrint('❌ [InterstitialAdsService] Response ID: ${error.responseInfo?.responseId}');
            }
            if (_isDisposed) return;
            _isLoading = false;
            _ad = null;
          },
        ),
      );
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      debugPrint('❌ [InterstitialAdsService] Exception while loading ad, error: $e');
      debugPrint('❌ [InterstitialAdsService] Stack trace: $stackTrace');
      _isLoading = false;
      _ad = null;
    }
  }
  
  /// Show interstitial ad
  /// Returns true if ad was shown, false otherwise
  /// Waits for ad to be dismissed before returning
  Future<bool> showAd() async {
    if (_isDisposed) {
      debugPrint('⚠️ [InterstitialAdsService] Service is disposed, cannot show ad');
      return false;
    }
    
    // Prevent multiple simultaneous show attempts
    if (_isShowing) {
      debugPrint('⚠️ [InterstitialAdsService] Ad is already being shown');
      return false;
    }
    
    try {
      if (_ad == null) {
        debugPrint('⚠️ [InterstitialAdsService] No ad loaded, attempting to load...');
        await loadAd();
        // Wait a bit for ad to load
        await Future.delayed(const Duration(milliseconds: 500));
        if (_ad == null) {
          debugPrint('❌ [InterstitialAdsService] Ad not available after loading attempt');
          return false;
        }
      }
      
      final currentAd = _ad!;
      _ad = null; // Clear reference before showing
      _isShowing = true;
      
      // Create completer to wait for ad dismissal
      _showCompleter = Completer<bool>();
      
      // Set full screen content callbacks before showing
      currentAd.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          debugPrint('📱 [InterstitialAdsService] Interstitial ad dismissed');
          _handleAdDismissed(ad);
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          debugPrint('❌ [InterstitialAdsService] Interstitial ad failed to show, error: $error');
          _handleAdFailed(ad, error);
        },
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          debugPrint('📱 [InterstitialAdsService] Interstitial ad showed');
        },
      );
      
      debugPrint('📱 [InterstitialAdsService] Showing interstitial ad');
      
      currentAd.show();
      
      // Wait for ad to be dismissed (with timeout to prevent infinite wait)
      final result = await _showCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⚠️ [InterstitialAdsService] Ad dismissal timeout, completing completer');
          if (_showCompleter != null && !_showCompleter!.isCompleted) {
            _showCompleter!.complete(true);
            _showCompleter = null;
          }
          return true;
        },
      );
      return result;
    } catch (e) {
      debugPrint('❌ [InterstitialAdsService] Exception while showing ad, error: $e');
      _isShowing = false;
      _ad?.dispose();
      _ad = null;
      _showCompleter?.complete(false);
      _showCompleter = null;
      return false;
    }
  }
  
  void _handleAdDismissed(InterstitialAd ad) async {
    if (_isDisposed) {
      ad.dispose();
      return;
    }
    debugPrint('📱 [InterstitialAdsService] Ad dismissed, disposing and loading new ad');
    _isShowing = false;
    ad.dispose();
    _ad = null;
    
    // Complete the completer to signal that ad was dismissed
    if (_showCompleter != null && !_showCompleter!.isCompleted) {
      _showCompleter!.complete(true);
      _showCompleter = null;
    }
    
    // Interstisial ad sayısını artır ve premium dialog kontrolü yap
    try {
      final prefsService = PreferencesService();
      final shouldShowPremiumDialog = await prefsService.incrementInterstitialAdCount();
      
      if (shouldShowPremiumDialog && onPremiumDialogTrigger != null) {
        debugPrint('💰 [InterstitialAdsService] 3 reklam tamamlandı, premium dialog tetikleniyor');
        // Kısa bir delay ile callback'i çağır (ad kapatıldıktan sonra)
        Future.delayed(const Duration(milliseconds: 500), () {
          onPremiumDialogTrigger?.call();
        });
      }
    } catch (e) {
      debugPrint('❌ [InterstitialAdsService] Ad sayacı güncellenirken hata: $e');
    }
    
    // Preload next ad (sadece dispose edilmediyse)
    if (!_isDisposed) {
      loadAd();
    }
  }
  
  void _handleAdFailed(InterstitialAd ad, AdError error) {
    if (_isDisposed) {
      ad.dispose();
      return;
    }
    debugPrint('❌ [InterstitialAdsService] Ad failed, disposing');
    _isShowing = false;
    ad.dispose();
    _ad = null;
    
    // Complete the completer to signal that ad failed
    if (_showCompleter != null && !_showCompleter!.isCompleted) {
      _showCompleter!.complete(false);
      _showCompleter = null;
    }
  }
  
  /// Dispose service
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _ad?.dispose();
    _ad = null;
    _isLoading = false;
    _isShowing = false;
    _showCompleter?.complete(false);
    _showCompleter = null;
    debugPrint('🗑️ [InterstitialAdsService] Service disposed');
  }
}


import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdUnitIds {
  const AdUnitIds._();

  // Fallback values are the previous hard-coded IDs
  static const String _interstitialAndroidFallback =
      'ca-app-pub-3499593115543692/9975836638';
  static const String _interstitialIosFallback =
      'ca-app-pub-3499593115543692/7729657687';

  static const String _deleteLimitAndroidFallback =
      'ca-app-pub-3499593115543692/1575404766';
  static const String _deleteLimitIosFallback =
      'ca-app-pub-3499593115543692/2388248395';

  static const String _blurScanLimitAndroidFallback =
      'ca-app-pub-3499593115543692/1034023877';
  static const String _blurScanLimitIosFallback =
      'ca-app-pub-3499593115543692/7683192707';

  static const String _duplicateScanLimitAndroidFallback =
      'ca-app-pub-3499593115543692/9608741799';
  static const String _duplicateScanLimitIosFallback =
      'ca-app-pub-3499593115543692/1924148305';

  static String get interstitialAndroid => _envOrDefault(
        'AD_INTERSTITIAL_ANDROID',
        _interstitialAndroidFallback,
      );

  static String get interstitialIos => _envOrDefault(
        'AD_INTERSTITIAL_IOS',
        _interstitialIosFallback,
      );

  static String get deleteLimitAndroid => _envOrDefault(
        'AD_DELETE_LIMIT_ANDROID',
        _deleteLimitAndroidFallback,
      );

  static String get deleteLimitIos => _envOrDefault(
        'AD_DELETE_LIMIT_IOS',
        _deleteLimitIosFallback,
      );

  static String get blurScanLimitAndroid => _envOrDefault(
        'AD_BLUR_SCAN_LIMIT_ANDROID',
        _blurScanLimitAndroidFallback,
      );

  static String get blurScanLimitIos => _envOrDefault(
        'AD_BLUR_SCAN_LIMIT_IOS',
        _blurScanLimitIosFallback,
      );

  static String get duplicateScanLimitAndroid => _envOrDefault(
        'AD_DUPLICATE_SCAN_LIMIT_ANDROID',
        _duplicateScanLimitAndroidFallback,
      );

  static String get duplicateScanLimitIos => _envOrDefault(
        'AD_DUPLICATE_SCAN_LIMIT_IOS',
        _duplicateScanLimitIosFallback,
      );

  static String _envOrDefault(String key, String fallback) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      debugPrint(
        '⚠️ [AdUnitIds] Missing value for $key in .env, falling back to default.',
      );
      return fallback;
    }
    return value;
  }
}





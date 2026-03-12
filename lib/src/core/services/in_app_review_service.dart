import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import 'preferences_service.dart';

/// App Store ID (iOS/macOS) - in_app_review için
const String _appStoreId = '6754893118';

const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.furkanages.gallerycleaner';
const String _appStoreUrl =
    'https://apps.apple.com/us/app/gallery-cleaner-swipe-photo/id$_appStoreId';

/// url_launcher ile mağaza sayfasını aç (in_app_review başarısız olduğunda fallback)
Future<bool> _openStoreViaUrl() async {
  final url = Platform.isAndroid ? _playStoreUrl : _appStoreUrl;
  final uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
  } catch (e) {
    debugPrint('❌ [InAppReview] url_launcher fallback hatası: $e');
  }
  return false;
}

/// in_app_review ile native değerlendirme istemi göster.
/// 10 swipe sonrası tetiklenir; native in-app review varsa onu, yoksa store sayfasını açar.
Future<void> requestInAppReview() async {
  final prefsService = PreferencesService();
  final inAppReview = InAppReview.instance;

  try {
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
      debugPrint('✅ [InAppReview] Native değerlendirme istemi gösterildi');
    } else {
      final ok = await _tryOpenStore(inAppReview);
      if (!ok) await _openStoreViaUrl();
    }
  } catch (e) {
    debugPrint('❌ [InAppReview] Hata: $e');
    await _openStoreViaUrl();
  } finally {
    await prefsService.setRateUsDialogShown();
  }
}

Future<bool> _tryOpenStore(InAppReview inAppReview) async {
  try {
    await inAppReview.openStoreListing(appStoreId: _appStoreId);
    return true;
  } catch (e) {
    debugPrint('❌ [InAppReview] openStoreListing hatası: $e');
    return false;
  }
}

/// Uygulama içi değerlendirme dialogunu göster (ayarlar "Bizi değerlendir" butonu için).
/// Önce native in-app review (requestReview) dener; yoksa store sayfasına yönlendirir.
Future<void> openStoreForReview() async {
  final prefsService = PreferencesService();
  final inAppReview = InAppReview.instance;

  try {
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
      debugPrint('✅ [InAppReview] Uygulama içi değerlendirme dialogu gösterildi');
      return;
    }
  } catch (e) {
    debugPrint('❌ [InAppReview] requestReview hatası: $e');
  } finally {
    // Kullanıcıya değerlendirme isteği gösterildi; tekrar göstermemek için işaretle
    await prefsService.setRateUsDialogShown();
  }

  final ok = await _tryOpenStore(inAppReview);
  if (!ok) {
    await _openStoreViaUrl();
  }
}

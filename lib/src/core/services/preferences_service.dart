import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/settings/application/theme_controller.dart';
import '../models/gallery_stats.dart';

class PreferencesService {
  // Secure Storage instance (Keychain/Keystore)
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Android'de backup'a dahil edilir (Google backup açıksa)
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      // iOS'ta iCloud Keychain sync açıksa veriler korunur
    ),
  );

  // Migration flag key
  static const String _migrationCompletedKey = 'secure_storage_migration_completed';

  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _firstPaywallShownKey = 'first_paywall_shown';
  static const String _themeModeKey = 'theme_mode';
  static const String _localeKey = 'locale';
  static const String _galleryStatsCacheKey = 'gallery_stats_cache';
  static const String _cleaningStartedKey = 'cleaning_started';
  static const String _deleteLimitKey = 'delete_limit';
  static const String _deleteLimitLastResetKey = 'delete_limit_last_reset';
  static const String _isPremiumKey = 'is_premium';
  static const String _previousGalleryStatsKey = 'previous_gallery_stats';
  static const String _firstAnalysisCompletedKey = 'first_analysis_completed';
  static const String _scanLimitKey = 'scan_limit';
  static const String _scanLimitLastResetKey = 'scan_limit_last_reset';
  static const String _duplicateScanLimitKey = 'duplicate_scan_limit';
  static const String _duplicateScanLimitLastResetKey = 'duplicate_scan_limit_last_reset';
  static const String _blurScanLimitKey = 'blur_scan_limit';
  static const String _blurScanLimitLastResetKey = 'blur_scan_limit_last_reset';
  static const String _swipeIndexKey = 'swipe_index';
  static const String _swipeAlbumIdKey = 'swipe_album_id';
  static const String _autoAnalyzeOnLaunchKey = 'auto_analyze_on_launch';
  static const String _interstitialAdCountKey = 'interstitial_ad_count';
  static const String _scanSoundEnabledKey = 'scan_sound_enabled';
  static const String _deleteCountForPaywallKey = 'delete_count_for_paywall';
  static const int _defaultDeleteLimit = 100;
  static const int _defaultScanLimit = 1000;
  static const int _premiumDialogThreshold = 3; // 3 reklam sonrası premium dialog göster
  static const int _paywallAfterDeleteThreshold = 3; // 3 silme sonrası paywall dialog göster

  /// Secure storage'dan integer değer oku
  Future<int?> _getSecureInt(String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value == null) return null;
      return int.tryParse(value);
    } catch (e) {
      debugPrint('❌ [PreferencesService] Secure storage okuma hatası ($key): $e');
      return null;
    }
  }

  /// Secure storage'a integer değer yaz
  Future<void> _setSecureInt(String key, int value) async {
    try {
      await _secureStorage.write(key: key, value: value.toString());
      debugPrint('💾 [PreferencesService] Secure storage\'a kaydedildi ($key): $value');
    } catch (e) {
      debugPrint('❌ [PreferencesService] Secure storage yazma hatası ($key): $e');
    }
  }

  /// Secure storage'dan string değer oku
  Future<String?> _getSecureString(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      debugPrint('❌ [PreferencesService] Secure storage okuma hatası ($key): $e');
      return null;
    }
  }

  /// Secure storage'a string değer yaz
  Future<void> _setSecureString(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      debugPrint('💾 [PreferencesService] Secure storage\'a kaydedildi ($key): $value');
    } catch (e) {
      debugPrint('❌ [PreferencesService] Secure storage yazma hatası ($key): $e');
    }
  }

  /// Secure storage'dan bool değer oku
  Future<bool?> _getSecureBool(String key) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value == null) return null;
      return value == 'true';
    } catch (e) {
      debugPrint('❌ [PreferencesService] Secure storage okuma hatası ($key): $e');
      return null;
    }
  }

  /// Secure storage'a bool değer yaz
  Future<void> _setSecureBool(String key, bool value) async {
    try {
      await _secureStorage.write(key: key, value: value.toString());
      debugPrint('💾 [PreferencesService] Secure storage\'a kaydedildi ($key): $value');
    } catch (e) {
      debugPrint('❌ [PreferencesService] Secure storage yazma hatası ($key): $e');
    }
  }

  /// Mevcut SharedPreferences verilerini secure storage'a migrate et
  Future<void> _migrateToSecureStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrationCompleted = prefs.getBool(_migrationCompletedKey) ?? false;
      
      if (migrationCompleted) {
        debugPrint('💾 [PreferencesService] Migration zaten tamamlanmış');
        return;
      }

      debugPrint('💾 [PreferencesService] SharedPreferences\'dan secure storage\'a migration başlıyor...');

      // Delete limit'i migrate et
      final deleteLimit = prefs.getInt(_deleteLimitKey);
      if (deleteLimit != null) {
        await _setSecureInt(_deleteLimitKey, deleteLimit);
      }

      // Delete limit last reset'i migrate et
      final deleteLimitLastReset = prefs.getString(_deleteLimitLastResetKey);
      if (deleteLimitLastReset != null) {
        await _setSecureString(_deleteLimitLastResetKey, deleteLimitLastReset);
      }

      // Scan limit'i migrate et
      final scanLimit = prefs.getInt(_scanLimitKey);
      if (scanLimit != null) {
        await _setSecureInt(_scanLimitKey, scanLimit);
      }

      // Scan limit last reset'i migrate et
      final scanLimitLastReset = prefs.getString(_scanLimitLastResetKey);
      if (scanLimitLastReset != null) {
        await _setSecureString(_scanLimitLastResetKey, scanLimitLastReset);
      }

      // Premium durumunu migrate et
      final isPremium = prefs.getBool(_isPremiumKey);
      if (isPremium != null) {
        await _setSecureBool(_isPremiumKey, isPremium);
      }

      // Migration tamamlandı olarak işaretle
      await prefs.setBool(_migrationCompletedKey, true);
      debugPrint('💾 [PreferencesService] Migration tamamlandı');
    } catch (e) {
      debugPrint('❌ [PreferencesService] Migration hatası: $e');
    }
  }

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, completed);
  }

  /// İlk paywall gösterildi mi kontrol et
  Future<bool> isFirstPaywallShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstPaywallShownKey) ?? false;
  }

  /// İlk paywall gösterildi olarak işaretle
  Future<void> setFirstPaywallShown(bool shown) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstPaywallShownKey, shown);
  }

  Future<AppThemeMode?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString(_themeModeKey);
    if (modeString == null) return null;
    switch (modeString) {
      case 'AppThemeMode.light':
        return AppThemeMode.light;
      case 'AppThemeMode.dark':
        return AppThemeMode.dark;
      case 'AppThemeMode.system':
        return AppThemeMode.system;
      default:
        return AppThemeMode.system;
    }
  }

  Future<void> saveThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = mode.toString(); // "AppThemeMode.light" formatında
    await prefs.setString(_themeModeKey, modeString);
  }

  Future<Locale?> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeString = prefs.getString(_localeKey);
    if (localeString == null) return null;
    return Locale(localeString);
  }

  Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  /// Galeri istatistiklerini cache'e kaydet
  Future<void> cacheGalleryStats(GalleryStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(stats.toJson());
      await prefs.setString(_galleryStatsCacheKey, json);
      debugPrint('💾 [PreferencesService] GalleryStats cache\'e kaydedildi');
    } catch (e) {
      debugPrint('❌ [PreferencesService] GalleryStats cache kaydedilemedi: $e');
    }
  }

  /// Cache'den galeri istatistiklerini oku
  Future<GalleryStats?> getCachedGalleryStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_galleryStatsCacheKey);
      if (jsonString == null) {
        debugPrint('💾 [PreferencesService] Cache\'de GalleryStats bulunamadı');
        return null;
      }
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final stats = GalleryStats.fromJson(json);
      debugPrint('💾 [PreferencesService] GalleryStats cache\'den okundu: ${stats.albumCount} albüm, ${stats.mediaCount} medya');
      return stats;
    } catch (e) {
      debugPrint('❌ [PreferencesService] GalleryStats cache okunamadı: $e');
      return null;
    }
  }

  /// Cache'i temizle
  Future<void> clearGalleryStatsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_galleryStatsCacheKey);
      debugPrint('💾 [PreferencesService] GalleryStats cache temizlendi');
    } catch (e) {
      debugPrint('❌ [PreferencesService] GalleryStats cache temizlenemedi: $e');
    }
  }

  /// Önceki galeri istatistiklerini kaydet
  Future<void> savePreviousGalleryStats(GalleryStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(stats.toJson());
      await prefs.setString(_previousGalleryStatsKey, json);
      debugPrint('💾 [PreferencesService] Önceki GalleryStats kaydedildi');
    } catch (e) {
      debugPrint('❌ [PreferencesService] Önceki GalleryStats kaydedilemedi: $e');
    }
  }

  /// Önceki galeri istatistiklerini al
  Future<GalleryStats?> getPreviousGalleryStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_previousGalleryStatsKey);
      if (jsonString == null) {
        return null;
      }
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return GalleryStats.fromJson(json);
    } catch (e) {
      debugPrint('❌ [PreferencesService] Önceki GalleryStats okunamadı: $e');
      return null;
    }
  }

  /// Temizlemeye başlandığını işaretle
  Future<void> setCleaningStarted(bool started) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cleaningStartedKey, started);
    debugPrint('💾 [PreferencesService] Cleaning started: $started');
  }

  /// Temizlemeye başlanıp başlanmadığını kontrol et
  Future<bool> isCleaningStarted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cleaningStartedKey) ?? false;
  }

  /// Silme hakkını al (günlük reset kontrolü ile)
  Future<int> getDeleteLimit() async {
    // İlk çalıştırmada migration yap
    await _migrateToSecureStorage();
    
    final premiumStatus = await isPremium();
    if (premiumStatus) {
      return 999999999; // Premium için sınırsız
    }
    
    final lastReset = await _getSecureString(_deleteLimitLastResetKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayString = today.toIso8601String().split('T')[0];
    
    // Eğer bugün reset edilmemişse, limiti sıfırla
    if (lastReset == null || lastReset != todayString) {
      await _setSecureInt(_deleteLimitKey, _defaultDeleteLimit);
      await _setSecureString(_deleteLimitLastResetKey, todayString);
      return _defaultDeleteLimit;
    }
    
    final limit = await _getSecureInt(_deleteLimitKey);
    return limit ?? _defaultDeleteLimit;
  }

  /// Silme hakkını kaydet
  Future<void> setDeleteLimit(int limit) async {
    await _setSecureInt(_deleteLimitKey, limit);
    // SharedPreferences'a da yaz (backward compatibility)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_deleteLimitKey, limit);
  }

  /// Silme hakkını azalt
  Future<int> decreaseDeleteLimit(int amount) async {
    final premiumStatus = await isPremium();
    if (premiumStatus) {
      return 999999999; // Premium kullanıcılar için limit düşürme yok
    }
    
    // İlk çalıştırmada migration yap
    await _migrateToSecureStorage();
    
    // Günlük reset kontrolü yapmadan direkt secure storage'dan oku
    final lastReset = await _getSecureString(_deleteLimitLastResetKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayString = today.toIso8601String().split('T')[0];
    
    int currentLimit;
    
    // Eğer bugün reset edilmemişse, limiti sıfırla
    if (lastReset == null || lastReset != todayString) {
      currentLimit = _defaultDeleteLimit;
      await _setSecureInt(_deleteLimitKey, _defaultDeleteLimit);
      await _setSecureString(_deleteLimitLastResetKey, todayString);
    } else {
      // Secure storage'dan direkt oku (getDeleteLimit metodundaki reset kontrolü olmadan)
      final limit = await _getSecureInt(_deleteLimitKey);
      currentLimit = limit ?? _defaultDeleteLimit;
    }
    
    final newLimit = (currentLimit - amount).clamp(0, 999999999);
    
    // Secure storage'a yaz
    await _setSecureInt(_deleteLimitKey, newLimit);
    // SharedPreferences'a da yaz (backward compatibility)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_deleteLimitKey, newLimit);
    
    // Yazma işleminin tamamlandığından emin ol
    await Future.delayed(const Duration(milliseconds: 10));
    
    debugPrint('💾 [PreferencesService] Delete limit azaltıldı: $currentLimit -> $newLimit (azaltılan: $amount)');
    
    // Doğrulama: Yazdığımız değeri okuyarak kontrol et
    final verifiedLimit = await _getSecureInt(_deleteLimitKey);
    if (verifiedLimit != newLimit) {
      debugPrint('⚠️ [PreferencesService] UYARI: Yazılan değer doğrulanamadı! Beklenen: $newLimit, Okunan: $verifiedLimit');
      // Tekrar dene
      await _setSecureInt(_deleteLimitKey, newLimit);
      await prefs.setInt(_deleteLimitKey, newLimit);
    }
    
    return newLimit;
  }

  /// Silme hakkını artır (reklam izleyerek)
  Future<int> increaseDeleteLimit(int amount) async {
    final currentLimit = await getDeleteLimit();
    final newLimit = currentLimit + amount;
    await setDeleteLimit(newLimit);
    debugPrint('💾 [PreferencesService] Delete limit artırıldı: $currentLimit -> $newLimit');
    return newLimit;
  }

  /// Premium kullanıcı mı?
  Future<bool> isPremium() async {
    // İlk çalıştırmada migration yap
    await _migrateToSecureStorage();
    
    final premiumStatus = await _getSecureBool(_isPremiumKey);
    return premiumStatus ?? false;
  }

  /// Premium durumunu ayarla
  Future<void> setPremium(bool isPremium) async {
    await _setSecureBool(_isPremiumKey, isPremium);
    // SharedPreferences'a da yaz (backward compatibility)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPremiumKey, isPremium);
  }

  /// İlk analiz tamamlandı mı?
  Future<bool> isFirstAnalysisCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstAnalysisCompletedKey) ?? false;
  }

  /// İlk analizi tamamlandı olarak işaretle
  Future<void> setFirstAnalysisCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstAnalysisCompletedKey, completed);
    debugPrint('💾 [PreferencesService] İlk analiz tamamlandı: $completed');
  }

  /// Otomatik analiz açık mı? (varsayılan: false)
  Future<bool> isAutoAnalyzeOnLaunchEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_autoAnalyzeOnLaunchKey);
    // Eğer değer hiç set edilmemişse (null), false olarak set et ve döndür
    if (value == null) {
      await prefs.setBool(_autoAnalyzeOnLaunchKey, false);
      return false; // Varsayılan olarak kapalı
    }
    return value;
  }

  /// Otomatik analiz ayarını değiştir
  Future<void> setAutoAnalyzeOnLaunch(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoAnalyzeOnLaunchKey, enabled);
    debugPrint('💾 [PreferencesService] Otomatik analiz: $enabled');
  }

  /// Scan limit'ini al (günlük reset kontrolü ile)
  Future<int> getScanLimit() async {
    // İlk çalıştırmada migration yap
    await _migrateToSecureStorage();
    
    final premiumStatus = await isPremium();
    if (premiumStatus) {
      return 999999999; // Premium için sınırsız
    }
    
    final lastReset = await _getSecureString(_scanLimitLastResetKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayString = today.toIso8601String().split('T')[0];
    
    // Eğer bugün reset edilmemişse, limiti kontrol et
    if (lastReset == null || lastReset != todayString) {
      final currentLimit = await _getSecureInt(_scanLimitKey) ?? _defaultScanLimit;
      // Günlük reset: Eğer limit 1000'den azsa, 1000'e çıkar
      // Reklam izleyerek kazanılan limit'ler (1000'den fazla) korunur
      final newLimit = currentLimit < _defaultScanLimit ? _defaultScanLimit : currentLimit;
      await _setSecureInt(_scanLimitKey, newLimit);
      await _setSecureString(_scanLimitLastResetKey, todayString);
      debugPrint('💾 [PreferencesService] Günlük reset: $currentLimit -> $newLimit');
      return newLimit;
    }
    
    final limit = await _getSecureInt(_scanLimitKey);
    return limit ?? _defaultScanLimit;
  }

  /// Scan limit'ini kaydet
  Future<void> setScanLimit(int limit) async {
    await _setSecureInt(_scanLimitKey, limit);
    // SharedPreferences'a da yaz (backward compatibility)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scanLimitKey, limit);
  }

  /// Scan limit'ini azalt
  Future<int> decreaseScanLimit(int amount) async {
    final premiumStatus = await isPremium();
    if (premiumStatus) {
      return 999999999; // Premium kullanıcılar için limit düşürme yok
    }
    
    final currentLimit = await getScanLimit();
    final newLimit = (currentLimit - amount).clamp(0, _defaultScanLimit);
    await setScanLimit(newLimit);
    debugPrint('💾 [PreferencesService] Scan limit azaltıldı: $currentLimit -> $newLimit (kullanılan: $amount)');
    return newLimit;
  }

  /// Scan limit'ini artır (reklam izleyerek)
  Future<int> increaseScanLimit(int amount) async {
    final premiumStatus = await isPremium();
    if (premiumStatus) {
      return 999999999; // Premium kullanıcılar için limit artırma yok (zaten sınırsız)
    }
    
    final currentLimit = await getScanLimit();
    // Reklam izleyerek limit artırılabilir (günlük reset mekanizması sadece 1000'e sıfırlar)
    final newLimit = currentLimit + amount;
    await setScanLimit(newLimit);
    debugPrint('💾 [PreferencesService] Scan limit artırıldı: $currentLimit -> $newLimit (kazanılan: $amount)');
    return newLimit;
  }

  /// Duplicate scan limit'ini al (günlük reset kontrolü ile)
  Future<int> getDuplicateScanLimit() async {
    await _migrateToSecureStorage();
    
    final premiumStatus = await isPremium();
    if (premiumStatus) {
      return 999999999; // Premium için sınırsız
    }
    
    final lastReset = await _getSecureString(_duplicateScanLimitLastResetKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayString = today.toIso8601String().split('T')[0];
    
    // Eğer bugün reset edilmemişse, limiti kontrol et
    if (lastReset == null || lastReset != todayString) {
      final currentLimit = await _getSecureInt(_duplicateScanLimitKey) ?? _defaultScanLimit;
      final newLimit = currentLimit < _defaultScanLimit ? _defaultScanLimit : currentLimit;
      await _setSecureInt(_duplicateScanLimitKey, newLimit);
      await _setSecureString(_duplicateScanLimitLastResetKey, todayString);
      debugPrint('💾 [PreferencesService] Duplicate scan limit günlük reset: $currentLimit -> $newLimit');
      return newLimit;
    }
    
    final limit = await _getSecureInt(_duplicateScanLimitKey);
    return limit ?? _defaultScanLimit;
  }

  /// Duplicate scan limit'ini kaydet
  Future<void> setDuplicateScanLimit(int limit) async {
    await _setSecureInt(_duplicateScanLimitKey, limit);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_duplicateScanLimitKey, limit);
  }

  /// Duplicate scan limit'ini azalt
  Future<int> decreaseDuplicateScanLimit(int amount) async {
    final premiumStatus = await isPremium();
    if (premiumStatus) {
      return 999999999;
    }
    
    final currentLimit = await getDuplicateScanLimit();
    final newLimit = (currentLimit - amount).clamp(0, 999999999);
    await setDuplicateScanLimit(newLimit);
    debugPrint('💾 [PreferencesService] Duplicate scan limit azaltıldı: $currentLimit -> $newLimit (kullanılan: $amount)');
    return newLimit;
  }

  /// Duplicate scan limit'ini artır (reklam izleyerek)
  Future<int> increaseDuplicateScanLimit(int amount) async {
    final premiumStatus = await isPremium();
    if (premiumStatus) {
      return 999999999;
    }
    
    final currentLimit = await getDuplicateScanLimit();
    final newLimit = currentLimit + amount;
    await setDuplicateScanLimit(newLimit);
    debugPrint('💾 [PreferencesService] Duplicate scan limit artırıldı: $currentLimit -> $newLimit (kazanılan: $amount)');
    return newLimit;
  }

  /// Blur scan limit'ini al
  Future<int> getBlurScanLimit() async {
    await _migrateToSecureStorage();
    
    final premiumStatus = await isPremium();
    if (premiumStatus) {
      return 999999999; // Premium için sınırsız
    }
    
    // Blur scan limit, sadece ilk kurulumda set edilir
    final limit = await _getSecureInt(_blurScanLimitKey);
    if (limit == null) {
      // İlk kurulum: default limit'i set et
      await _setSecureInt(_blurScanLimitKey, _defaultScanLimit);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_blurScanLimitKey, _defaultScanLimit);
      debugPrint('💾 [PreferencesService] Blur scan limit ilk kurulum: $_defaultScanLimit');
      return _defaultScanLimit;
    }
    
    return limit;
  }

  /// Blur scan limit'ini kaydet (sadece artırma için)
  Future<void> setBlurScanLimit(int limit) async {
    await _setSecureInt(_blurScanLimitKey, limit);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_blurScanLimitKey, limit);
  }

  /// Blur scan limit'ini azalt (tarama yapıldığında)
  Future<int> decreaseBlurScanLimit(int amount) async {
    final premiumStatus = await isPremium();
    if (premiumStatus) {
      return 999999999;
    }
    
    final currentLimit = await getBlurScanLimit();
    final newLimit = (currentLimit - amount).clamp(0, 999999999);
    await setBlurScanLimit(newLimit);
    debugPrint('💾 [PreferencesService] Blur scan limit azaltıldı: $currentLimit -> $newLimit (kullanılan: $amount)');
    return newLimit;
  }

  /// Blur scan limit'ini artır (reklam izleyerek)
  Future<int> increaseBlurScanLimit(int amount) async {
    final premiumStatus = await isPremium();
    if (premiumStatus) {
      return 999999999;
    }
    
    final currentLimit = await getBlurScanLimit();
    final newLimit = currentLimit + amount;
    await setBlurScanLimit(newLimit);
    debugPrint('💾 [PreferencesService] Blur scan limit artırıldı: $currentLimit -> $newLimit (kazanılan: $amount)');
    return newLimit;
  }

  /// Swipe index'ini kaydet (album ID ile birlikte)
  Future<void> saveSwipeIndex(int index, String? albumId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_swipeIndexKey, index);
      if (albumId != null) {
        await prefs.setString(_swipeAlbumIdKey, albumId);
      } else {
        await prefs.remove(_swipeAlbumIdKey);
      }
      debugPrint('💾 [PreferencesService] Swipe index kaydedildi: $index (album: $albumId)');
    } catch (e) {
      debugPrint('❌ [PreferencesService] Swipe index kaydedilemedi: $e');
    }
  }

  /// Swipe index'ini al
  Future<int?> getSwipeIndex(String? albumId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAlbumId = prefs.getString(_swipeAlbumIdKey);
      
      // Eğer album ID eşleşmiyorsa, index'i sıfırla
      if (albumId != null && savedAlbumId != albumId) {
        debugPrint('💾 [PreferencesService] Album ID eşleşmiyor, swipe index sıfırlanıyor');
        await prefs.remove(_swipeIndexKey);
        await prefs.remove(_swipeAlbumIdKey);
        return null;
      }
      
      final index = prefs.getInt(_swipeIndexKey);
      debugPrint('💾 [PreferencesService] Swipe index okundu: $index (album: $albumId)');
      return index;
    } catch (e) {
      debugPrint('❌ [PreferencesService] Swipe index okunamadı: $e');
      return null;
    }
  }

  /// Swipe index'ini temizle
  Future<void> clearSwipeIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_swipeIndexKey);
      await prefs.remove(_swipeAlbumIdKey);
      debugPrint('💾 [PreferencesService] Swipe index temizlendi');
    } catch (e) {
      debugPrint('❌ [PreferencesService] Swipe index temizlenemedi: $e');
    }
  }

  /// Interstisial reklam sayısını al
  Future<int> getInterstitialAdCount() async {
    final count = await _getSecureInt(_interstitialAdCountKey);
    return count ?? 0;
  }

  /// Interstisial reklam sayısını artır ve premium dialog gösterilmesi gerekip gerekmediğini kontrol et
  /// Returns true if premium dialog should be shown (after 3 ads)
  Future<bool> incrementInterstitialAdCount() async {
    final currentCount = await getInterstitialAdCount();
    final newCount = currentCount + 1;
    await _setSecureInt(_interstitialAdCountKey, newCount);
    debugPrint('💾 [PreferencesService] Interstisial ad sayısı artırıldı: $currentCount -> $newCount');
    
    // 3 reklam görüldükten sonra premium dialog göster
    if (newCount >= _premiumDialogThreshold) {
      // Sayacı sıfırla (bir sonraki 3 reklam için)
      await _setSecureInt(_interstitialAdCountKey, 0);
      debugPrint('💾 [PreferencesService] Premium dialog gösterilecek (3 reklam tamamlandı)');
      return true;
    }
    return false;
  }

  /// Interstisial reklam sayısını sıfırla
  Future<void> resetInterstitialAdCount() async {
    await _setSecureInt(_interstitialAdCountKey, 0);
    debugPrint('💾 [PreferencesService] Interstisial ad sayısı sıfırlandı');
  }

  /// Scan sesinin açık olup olmadığını kontrol et (varsayılan: true)
  Future<bool> isScanSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scanSoundEnabledKey) ?? true;
  }

  /// Scan sesini aç/kapa
  Future<void> setScanSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scanSoundEnabledKey, enabled);
  }

  /// Silme sayacını al (paywall dialog için)
  Future<int> getDeleteCountForPaywall() async {
    final count = await _getSecureInt(_deleteCountForPaywallKey);
    return count ?? 0;
  }

  /// Silme sayacını artır ve paywall dialog gösterilmesi gerekip gerekmediğini kontrol et
  /// Returns true if paywall dialog should be shown (after 3 deletes)
  Future<bool> incrementDeleteCountForPaywall() async {
    final currentCount = await getDeleteCountForPaywall();
    final newCount = currentCount + 1;
    await _setSecureInt(_deleteCountForPaywallKey, newCount);
    debugPrint('💾 [PreferencesService] Silme sayacı artırıldı: $currentCount -> $newCount');
    
    // 3 silme işleminden sonra paywall dialog göster
    if (newCount >= _paywallAfterDeleteThreshold) {
      // Sayacı sıfırla (bir sonraki 3 silme için)
      await _setSecureInt(_deleteCountForPaywallKey, 0);
      debugPrint('💾 [PreferencesService] Paywall dialog gösterilecek (3 silme tamamlandı)');
      return true;
    }
    return false;
  }

  /// Silme sayacını sıfırla
  Future<void> resetDeleteCountForPaywall() async {
    await _setSecureInt(_deleteCountForPaywallKey, 0);
    debugPrint('💾 [PreferencesService] Silme sayacı sıfırlandı');
  }
}


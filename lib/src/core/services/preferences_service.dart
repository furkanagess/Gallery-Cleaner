import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/settings/application/theme_controller.dart';
import '../models/gallery_stats.dart';

class PreferencesService {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _themeModeKey = 'theme_mode';
  static const String _localeKey = 'locale';
  static const String _galleryStatsCacheKey = 'gallery_stats_cache';
  static const String _cleaningStartedKey = 'cleaning_started';
  static const String _deleteLimitKey = 'delete_limit';
  static const String _deleteLimitLastResetKey = 'delete_limit_last_reset';
  static const int _defaultDeleteLimit = 100;

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, completed);
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
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getString(_deleteLimitLastResetKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Eğer bugün reset edilmemişse, limiti sıfırla
    if (lastReset == null || lastReset != today.toIso8601String().split('T')[0]) {
      await prefs.setInt(_deleteLimitKey, _defaultDeleteLimit);
      await prefs.setString(_deleteLimitLastResetKey, today.toIso8601String().split('T')[0]);
      return _defaultDeleteLimit;
    }
    
    return prefs.getInt(_deleteLimitKey) ?? _defaultDeleteLimit;
  }

  /// Silme hakkını kaydet
  Future<void> setDeleteLimit(int limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_deleteLimitKey, limit);
    debugPrint('💾 [PreferencesService] Delete limit kaydedildi: $limit');
  }

  /// Silme hakkını azalt
  Future<int> decreaseDeleteLimit(int amount) async {
    final currentLimit = await getDeleteLimit();
    final newLimit = (currentLimit - amount).clamp(0, _defaultDeleteLimit);
    await setDeleteLimit(newLimit);
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
}


import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/gallery_stats.dart';
import '../../../core/services/preferences_service.dart';
import '../application/gallery_providers.dart';
import '../../onboarding/application/permissions_controller.dart';

/// Galeri istatistiklerini cache ile birlikte yönetir
class GalleryStatsState {
  final GalleryStats? stats;
  final bool isLoading;
  final Object? error;
  final bool isFromCache;

  const GalleryStatsState({
    this.stats,
    this.isLoading = false,
    this.error,
    this.isFromCache = false,
  });

  GalleryStatsState copyWith({
    GalleryStats? stats,
    bool? isLoading,
    Object? error,
    bool? isFromCache,
  }) {
    return GalleryStatsState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error : this.error,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }
}

class GalleryStatsNotifier extends StateNotifier<GalleryStatsState> {
  GalleryStatsNotifier(this.ref) : super(const GalleryStatsState()) {
    _init();
  }

  final Ref ref;
  Timer? _refreshTimer;

  Future<void> _init() async {
    // İlk yüklemede cache'den oku ve hemen göster
    await _loadFromCache();
    
    // İzin durumunu dinle
    ref.listen<GalleryPermissionStatus>(
      permissionsControllerProvider,
      (previous, next) {
        if (next == GalleryPermissionStatus.authorized) {
          _refreshStats(useCache: false);
        } else {
          state = const GalleryStatsState();
        }
      },
    );
  }

  /// Cache'den istatistikleri yükle
  Future<void> _loadFromCache() async {
    try {
      final prefsService = ref.read(preferencesServiceProvider);
      final cachedStats = await prefsService.getCachedGalleryStats();
      
      if (cachedStats != null) {
        debugPrint('📊 [GalleryStats] Cache\'den yüklendi: ${cachedStats.albumCount} albüm, ${cachedStats.mediaCount} medya');
        state = GalleryStatsState(
          stats: cachedStats,
          isFromCache: true,
        );
        
        // İzin varsa arka planda güncelle
        final permission = ref.read(permissionsControllerProvider);
        if (permission == GalleryPermissionStatus.authorized) {
          // Cache'den gösterdikten sonra arka planda güncelle
          _refreshStats(useCache: false);
        }
      }
    } catch (e) {
      debugPrint('❌ [GalleryStats] Cache okuma hatası: $e');
    }
  }

  /// İstatistikleri yenile (cache kullanarak veya tamamen yeniden yükleyerek)
  Future<void> _refreshStats({bool useCache = true}) async {
    final permission = ref.read(permissionsControllerProvider);
    if (permission != GalleryPermissionStatus.authorized) {
      state = const GalleryStatsState();
      return;
    }

    // Eğer cache kullan ve cache varsa, arka planda güncelle
    if (useCache && state.stats != null && state.isFromCache) {
      // Cache'den göster ama arka planda güncelle
      _refreshInBackground();
      return;
    }

    // Tamamen yeniden yükle
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final service = ref.read(mediaLibraryServiceProvider);
      final stats = await service.fetchGalleryStats();
      
      // Cache'e kaydet
      final prefsService = ref.read(preferencesServiceProvider);
      final statsWithCacheTime = stats.copyWith(cachedAt: DateTime.now());
      await prefsService.cacheGalleryStats(statsWithCacheTime);
      
      debugPrint('📊 [GalleryStats] İstatistikler güncellendi: ${stats.albumCount} albüm, ${stats.mediaCount} medya');
      
      state = GalleryStatsState(
        stats: statsWithCacheTime,
        isLoading: false,
        isFromCache: false,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [GalleryStats] Hata oluştu: $e');
      debugPrint('❌ [GalleryStats] Stack trace: $stackTrace');
      
      // Hata durumunda cache'deki veriyi tut
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
    }
  }

  /// Arka planda istatistikleri güncelle (UI'ı bloklamadan)
  void _refreshInBackground() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 500), () {
      _refreshStats(useCache: false).ignore();
    });
  }

  /// Manuel olarak yenile
  Future<void> refresh() async {
    await _refreshStats(useCache: false);
  }

  /// Cache'i temizle
  Future<void> clearCache() async {
    final prefsService = ref.read(preferencesServiceProvider);
    await prefsService.clearGalleryStatsCache();
    state = const GalleryStatsState();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

// PreferencesService provider
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

/// Galeri istatistikleri provider (cache destekli)
final galleryStatsProvider =
    StateNotifierProvider<GalleryStatsNotifier, GalleryStatsState>((ref) {
  return GalleryStatsNotifier(ref);
});

/// FutureProvider uyumluluğu için wrapper (eski kodlarla uyumlu olması için)
final galleryStatsFutureProvider = Provider<Future<GalleryStats?>>((ref) async {
  final state = ref.watch(galleryStatsProvider);
  
  if (state.error != null) {
    throw state.error!;
  }
  
  if (state.isLoading && state.stats == null) {
    // İlk yükleme devam ediyor, tamamlanmasını bekle
    await ref.watch(galleryStatsProvider.notifier).refresh();
    final newState = ref.read(galleryStatsProvider);
    return newState.stats;
  }
  
  return state.stats;
});


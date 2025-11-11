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
  final GalleryStats? previousStats;
  final bool isLoading;
  final Object? error;
  final bool isFromCache;
  final bool isScanning;

  const GalleryStatsState({
    this.stats,
    this.previousStats,
    this.isLoading = false,
    this.error,
    this.isFromCache = false,
    this.isScanning = false,
  });

  GalleryStatsState copyWith({
    GalleryStats? stats,
    GalleryStats? previousStats,
    bool? isLoading,
    Object? error,
    bool? isFromCache,
    bool? isScanning,
    bool clearPreviousStats = false,
  }) {
    return GalleryStatsState(
      stats: stats ?? this.stats,
      previousStats: clearPreviousStats ? null : (previousStats ?? this.previousStats),
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error : this.error,
      isFromCache: isFromCache ?? this.isFromCache,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class GalleryStatsNotifier extends StateNotifier<GalleryStatsState> {
  GalleryStatsNotifier(this.ref) : super(const GalleryStatsState()) {
    _init();
  }

  final Ref ref;
  Timer? _refreshTimer;
  bool _isCancelled = false;

  Future<void> _init() async {
    // İlk yüklemede cache'den oku ve hemen göster
    await _loadFromCache();
    
    // İlk defa uygulama indirildiğinde ve izin verilmişse otomatik analiz başlat
    final permission = ref.read(permissionsControllerProvider);
    if (permission == GalleryPermissionStatus.authorized) {
      final prefsService = ref.read(preferencesServiceProvider);
      final isFirstAnalysisCompleted = await prefsService.isFirstAnalysisCompleted();
      final hasCachedStats = state.stats != null;
      
      // Cache yoksa ve ilk analiz tamamlanmamışsa otomatik analiz başlat
      if (!hasCachedStats && !isFirstAnalysisCompleted) {
        debugPrint('📊 [GalleryStats] İlk analiz başlatılıyor...');
        // Kısa bir gecikme ile başlat (UI'nin yüklenmesi için)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isCancelled) {
            refresh();
          }
        });
      }
    }
    
    // İzin durumunu dinle
    ref.listen<GalleryPermissionStatus>(
      permissionsControllerProvider,
      (previous, next) {
        if (next != GalleryPermissionStatus.authorized) {
          state = const GalleryStatsState();
        } else if (previous != GalleryPermissionStatus.authorized && next == GalleryPermissionStatus.authorized) {
          // İzin yeni verildiyse ve ilk analiz tamamlanmamışsa otomatik başlat
          final prefsService = ref.read(preferencesServiceProvider);
          prefsService.isFirstAnalysisCompleted().then((isCompleted) {
            if (!isCompleted && !_isCancelled) {
              debugPrint('📊 [GalleryStats] İzin verildi, ilk analiz başlatılıyor...');
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!_isCancelled) {
                  refresh();
                }
              });
            }
          });
        }
      },
    );
  }

  /// Cache'den istatistikleri yükle
  Future<void> _loadFromCache() async {
    try {
      final prefsService = ref.read(preferencesServiceProvider);
      final cachedStats = await prefsService.getCachedGalleryStats();
      final previousStats = await prefsService.getPreviousGalleryStats();
      
      if (cachedStats != null) {
        debugPrint('📊 [GalleryStats] Cache\'den yüklendi: ${cachedStats.albumCount} albüm, ${cachedStats.mediaCount} medya');
        state = GalleryStatsState(
          stats: cachedStats,
          previousStats: previousStats,
          isFromCache: true,
        );
        // Otomatik tarama yapılmıyor - kullanıcı butona basmalı
      } else if (previousStats != null) {
        // Cache yok ama önceki stats varsa onu göster
        state = GalleryStatsState(
          stats: previousStats,
          previousStats: null,
          isFromCache: true,
        );
      }
    } catch (e) {
      debugPrint('❌ [GalleryStats] Cache okuma hatası: $e');
    }
  }

  /// İstatistikleri yenile (cache kullanarak veya tamamen yeniden yükleyerek)
  Future<void> _refreshStats({bool useCache = true, bool savePrevious = true}) async {
    final permission = ref.read(permissionsControllerProvider);
    if (permission != GalleryPermissionStatus.authorized) {
      state = const GalleryStatsState();
      return;
    }

    // Otomatik arka plan güncellemesi kaldırıldı - kullanıcı butona basmalı
    // useCache parametresi artık kullanılmıyor, her zaman manuel refresh yapılıyor

    // Önceki istatistikleri al - mevcut stats varsa onu kullan
    final prefsService = ref.read(preferencesServiceProvider);
    GalleryStats? previousStats = state.stats;
    if (previousStats == null) {
      // Önceki istatistikleri preferences'ten al
      previousStats = await prefsService.getPreviousGalleryStats();
    }

    // Mevcut stats'ı previous olarak kaydet (tarama başlamadan önce)
    final currentStatsBeforeScan = state.stats;
    if (savePrevious && currentStatsBeforeScan != null) {
      await prefsService.savePreviousGalleryStats(currentStatsBeforeScan);
      previousStats = currentStatsBeforeScan;
    }

    // Tamamen yeniden yükle (incremental updates ile)
    // Her analizde 0'dan başla - state'i sıfırla
    _isCancelled = false;
    state = GalleryStatsState(
      stats: GalleryStats(
        albumCount: 0,
        mediaCount: 0,
        totalSizeMB: 0.0,
        albumDetails: [],
        cachedAt: null,
      ),
      previousStats: previousStats,
      isLoading: true,
      error: null,
      isFromCache: false,
      isScanning: true,
    );
    
    try {
      final service = ref.read(mediaLibraryServiceProvider);
      
      // Incremental updates için callback
      final stats = await service.fetchGalleryStats(
        shouldCancel: () => _isCancelled,
        onProgress: (partialStats) {
          // İptal edildiyse güncelleme yapma
          if (_isCancelled) return;
          
          // Her veri geldiğinde state'i güncelle (StateNotifier'da mounted yok, direkt güncelle)
          state = GalleryStatsState(
            stats: partialStats,
            previousStats: previousStats,
            isLoading: true,
            isFromCache: false,
            isScanning: true,
          );
        },
      );
      
      // İptal edildiyse çık
      if (_isCancelled) {
        debugPrint('🛑 [GalleryStats] Tarama iptal edildi');
        state = state.copyWith(
          isLoading: false,
          isScanning: false,
        );
        return;
      }
      
      // Cache'e kaydet
      final statsWithCacheTime = stats.copyWith(cachedAt: DateTime.now());
      await prefsService.cacheGalleryStats(statsWithCacheTime);
      
      // İlk analiz tamamlandı olarak işaretle
      await prefsService.setFirstAnalysisCompleted(true);
      
      debugPrint('📊 [GalleryStats] İstatistikler güncellendi: ${stats.albumCount} albüm, ${stats.mediaCount} medya');
      if (previousStats != null) {
        debugPrint('📊 [GalleryStats] Önceki istatistikler: ${previousStats.albumCount} albüm, ${previousStats.mediaCount} medya');
      }
      
      state = GalleryStatsState(
        stats: statsWithCacheTime,
        previousStats: previousStats,
        isLoading: false,
        isFromCache: false,
        isScanning: false,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [GalleryStats] Hata oluştu: $e');
      debugPrint('❌ [GalleryStats] Stack trace: $stackTrace');
      
      // Hata durumunda cache'deki veriyi tut
      state = state.copyWith(
        isLoading: false,
        error: e,
        isScanning: false,
      );
    }
  }

  /// Manuel olarak yenile (kullanıcı butona bastığında)
  Future<void> refresh() async {
    await _refreshStats(useCache: false);
  }

  /// Taramayı iptal et
  void cancel() {
    debugPrint('🛑 [GalleryStats] Tarama iptal ediliyor...');
    _isCancelled = true;
    state = state.copyWith(
      isScanning: false,
      isLoading: false,
    );
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
/// NOT: Otomatik refresh yapılmıyor - kullanıcı manuel olarak refresh yapmalı
final galleryStatsFutureProvider = Provider<Future<GalleryStats?>>((ref) async {
  final state = ref.watch(galleryStatsProvider);
  
  if (state.error != null) {
    throw state.error!;
  }
  
  // Otomatik refresh kaldırıldı - sadece cache'den yükleme yapılıyor
  // Eğer state isLoading ise, zaten bir analiz devam ediyor demektir
  // Bu durumda state'i beklemek yeterli, otomatik refresh yapılmıyor
  
  return state.stats;
});


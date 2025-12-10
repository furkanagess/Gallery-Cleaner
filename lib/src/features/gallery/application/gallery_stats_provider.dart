import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/gallery_stats.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/media_library_service.dart';
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
      previousStats: clearPreviousStats
          ? null
          : (previousStats ?? this.previousStats),
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isFromCache: isFromCache ?? this.isFromCache,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class GalleryStatsCubit extends Cubit<GalleryStatsState> {
  GalleryStatsCubit({
    required MediaLibraryService mediaLibraryService,
    required PreferencesService preferencesService,
    required PermissionsCubit permissionsCubit,
  }) : _mediaLibraryService = mediaLibraryService,
       _preferencesService = preferencesService,
       _permissionsCubit = permissionsCubit,
       super(const GalleryStatsState()) {
    _init();
  }

  final MediaLibraryService _mediaLibraryService;
  final PreferencesService _preferencesService;
  final PermissionsCubit _permissionsCubit;
  StreamSubscription<GalleryPermissionStatus>? _permissionSubscription;
  GalleryPermissionStatus? _lastPermission;
  bool _isCancelled = false;

  Future<void> _init() async {
    // İlk yüklemede cache'den oku ve hemen göster
    await _loadFromCache();

    // İzin verilmişse otomatik analiz kontrolü yap
    final permission = _permissionsCubit.state;
    if (permission == GalleryPermissionStatus.authorized) {
      final isAutoAnalyzeEnabled = await _preferencesService
          .isAutoAnalyzeOnLaunchEnabled();

      // Otomatik analiz açıksa her girişte analiz yap
      if (isAutoAnalyzeEnabled) {
        debugPrint(
          '📊 [GalleryStats] Otomatik analiz açık, analiz başlatılıyor...',
        );
        // Kısa bir gecikme ile başlat (UI'nin yüklenmesi için)
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!_isCancelled) {
            refresh();
          }
        });
      } else {
        // Otomatik analiz kapalıysa, sadece ilk analiz kontrolü yap
        final isFirstAnalysisCompleted = await _preferencesService
            .isFirstAnalysisCompleted();
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
    }

    // İzin durumunu dinle
    _lastPermission = permission;
    _permissionSubscription = _permissionsCubit.stream.listen((next) {
      final previous = _lastPermission;
      _lastPermission = next;
      if (next != GalleryPermissionStatus.authorized) {
        emit(const GalleryStatsState());
      } else if (previous != GalleryPermissionStatus.authorized &&
          next == GalleryPermissionStatus.authorized) {
        _preferencesService.isFirstAnalysisCompleted().then((isCompleted) {
          if (!isCompleted && !_isCancelled) {
            debugPrint(
              '📊 [GalleryStats] İzin verildi, ilk analiz başlatılıyor...',
            );
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!_isCancelled) {
                refresh();
              }
            });
          }
        });
      }
    });
  }

  /// Cache'den istatistikleri yükle
  Future<void> _loadFromCache() async {
    try {
      final cachedStats = await _preferencesService.getCachedGalleryStats();
      final previousStats = await _preferencesService.getPreviousGalleryStats();

      if (cachedStats != null) {
        debugPrint(
          '📊 [GalleryStats] Cache\'den yüklendi: ${cachedStats.albumCount} albüm, ${cachedStats.mediaCount} medya',
        );
        emit(
          GalleryStatsState(
            stats: cachedStats,
            previousStats: previousStats,
            isFromCache: true,
          ),
        );
        // Otomatik tarama yapılmıyor - kullanıcı butona basmalı
      } else if (previousStats != null) {
        // Cache yok ama önceki stats varsa onu göster
        emit(
          GalleryStatsState(
            stats: previousStats,
            previousStats: null,
            isFromCache: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [GalleryStats] Cache okuma hatası: $e');
    }
  }

  /// İstatistikleri yenile (cache kullanarak veya tamamen yeniden yükleyerek)
  Future<void> _refreshStats({
    bool useCache = true,
    bool savePrevious = true,
  }) async {
    final permission = _permissionsCubit.state;
    if (permission != GalleryPermissionStatus.authorized) {
      emit(const GalleryStatsState());
      return;
    }

    GalleryStats? previousStats = state.stats;
    previousStats ??= await _preferencesService.getPreviousGalleryStats();

    final currentStatsBeforeScan = state.stats;
    if (savePrevious && currentStatsBeforeScan != null) {
      await _preferencesService.savePreviousGalleryStats(
        currentStatsBeforeScan,
      );
      previousStats = currentStatsBeforeScan;
    }

    _isCancelled = false;
    emit(
      GalleryStatsState(
        stats: GalleryStats(
          albumCount: 0,
          mediaCount: 0,
          photoCount: 0,
          videoCount: 0,
          totalSizeMB: 0.0,
          photoSizeMB: 0.0,
          videoSizeMB: 0.0,
          albumDetails: [],
          cachedAt: null,
        ),
        previousStats: previousStats,
        isLoading: true,
        error: null,
        isFromCache: false,
        isScanning: true,
      ),
    );

    try {
      final stats = await _mediaLibraryService.fetchGalleryStats(
        shouldCancel: () => _isCancelled,
        onProgress: (partialStats) {
          if (_isCancelled) return;
          emit(
            GalleryStatsState(
              stats: partialStats,
              previousStats: previousStats,
              isLoading: true,
              isFromCache: false,
              isScanning: true,
            ),
          );
        },
      );

      if (_isCancelled) {
        debugPrint('🛑 [GalleryStats] Tarama iptal edildi');
        emit(state.copyWith(isLoading: false, isScanning: false));
        return;
      }

      final statsWithCacheTime = stats.copyWith(cachedAt: DateTime.now());
      await _preferencesService.cacheGalleryStats(statsWithCacheTime);
      await _preferencesService.setFirstAnalysisCompleted(true);

      debugPrint(
        '📊 [GalleryStats] İstatistikler güncellendi: ${stats.albumCount} albüm, ${stats.mediaCount} medya',
      );
      if (previousStats != null) {
        debugPrint(
          '📊 [GalleryStats] Önceki istatistikler: ${previousStats.albumCount} albüm, ${previousStats.mediaCount} medya',
        );
      }

      emit(
        GalleryStatsState(
          stats: statsWithCacheTime,
          previousStats: previousStats,
          isLoading: false,
          isFromCache: false,
          isScanning: false,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [GalleryStats] Hata oluştu: $e');
      debugPrint('❌ [GalleryStats] Stack trace: $stackTrace');

      emit(state.copyWith(isLoading: false, error: e, isScanning: false));
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
    emit(state.copyWith(isScanning: false, isLoading: false));
  }

  /// Cache'i temizle
  Future<void> clearCache() async {
    await _preferencesService.clearGalleryStatsCache();
    emit(const GalleryStatsState());
  }

  @override
  Future<void> close() {
    _permissionSubscription?.cancel();
    return super.close();
  }
}

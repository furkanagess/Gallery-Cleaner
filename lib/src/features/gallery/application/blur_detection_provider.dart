import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import '../../../core/services/blur_detection_service.dart';
import '../../../core/models/blur_photo.dart';
import '../../onboarding/application/permissions_controller.dart';
import '../../onboarding/application/onboarding_controller.dart';
import 'gallery_providers.dart';

final blurDetectionServiceProvider = Provider<BlurDetectionService>((ref) {
  return BlurDetectionService();
});

/// Blur detection state
class BlurDetectionState {
  final Map<String, List<BlurPhoto>> blurryPhotosByAlbum;
  final bool isScanning;
  final double progress;
  final String? currentAlbum;
  final Object? error;
  final double blurThreshold;
  final bool hasCompletedScan; // Tarama tamamlandı mı?
  final int processedCount; // Mevcut albümde işlenen fotoğraf sayısı
  final int totalCount; // Mevcut albümdeki toplam fotoğraf sayısı
  final int
  plannedSampleCount; // Mevcut albümde analiz edilmesi planlanan fotoğraf sayısı

  const BlurDetectionState({
    this.blurryPhotosByAlbum = const {},
    this.isScanning = false,
    this.progress = 0.0,
    this.currentAlbum,
    this.error,
    this.blurThreshold =
        0.5, // Daha fazla blur tespit etmek için 0.4'ten 0.5'e artırıldı
    this.hasCompletedScan = false,
    this.processedCount = 0,
    this.totalCount = 0,
    this.plannedSampleCount = 0,
  });

  BlurDetectionState copyWith({
    Map<String, List<BlurPhoto>>? blurryPhotosByAlbum,
    bool? isScanning,
    double? progress,
    String? currentAlbum,
    Object? error,
    bool clearError = false,
    double? blurThreshold,
    bool? hasCompletedScan,
    int? processedCount,
    int? totalCount,
    int? plannedSampleCount,
  }) {
    return BlurDetectionState(
      blurryPhotosByAlbum: blurryPhotosByAlbum ?? this.blurryPhotosByAlbum,
      isScanning: isScanning ?? this.isScanning,
      progress: progress ?? this.progress,
      currentAlbum: currentAlbum ?? this.currentAlbum,
      error: clearError ? null : (error ?? this.error),
      blurThreshold: blurThreshold ?? this.blurThreshold,
      hasCompletedScan: hasCompletedScan ?? this.hasCompletedScan,
      processedCount: processedCount ?? this.processedCount,
      totalCount: totalCount ?? this.totalCount,
      plannedSampleCount: plannedSampleCount ?? this.plannedSampleCount,
    );
  }

  /// Toplam blurlu fotoğraf sayısı
  int get totalBlurryPhotos {
    return blurryPhotosByAlbum.values.fold<int>(
      0,
      (sum, photos) => sum + photos.length,
    );
  }

  /// Toplam kazanılacak alan (MB)
  double get totalSpaceToSaveMB {
    return blurryPhotosByAlbum.values.fold<double>(
      0.0,
      (sum, photos) =>
          sum +
          photos.fold<double>(
            0.0,
            (photoSum, photo) => photoSum + photo.estimatedSizeMB,
          ),
    );
  }
}

class BlurDetectionNotifier extends StateNotifier<BlurDetectionState> {
  BlurDetectionNotifier(this.ref) : super(const BlurDetectionState());

  final Ref ref;
  bool _isCancelled = false;

  // Progress callback throttling - %1 artışlarla güncelleme
  DateTime? _lastProgressUpdate;
  int _lastProgressPercent = -1; // Son gösterilen yüzde değeri
  static const _progressThrottleMs = 50; // Her 50ms'de bir kontrol et

  /// Belirli albümlerde blur taraması yap
  Future<void> scanAlbums(
    List<pm.AssetPathEntity> albums, {
    double? blurThreshold,
  }) async {
    debugPrint(
      '🚀 [BlurDetection] scanAlbums çağrıldı - Albüm sayısı: ${albums.length}',
    );

    final permission = ref.read(permissionsControllerProvider);
    debugPrint('🔐 [BlurDetection] İzin durumu: $permission');

    if (permission != GalleryPermissionStatus.authorized) {
      debugPrint('❌ [BlurDetection] İzin yok! Tarama durduruldu.');
      state = state.copyWith(
        error: 'Permission not granted',
        isScanning: false,
      );
      return;
    }

    debugPrint('✅ [BlurDetection] İzin var, tarama başlatılıyor...');

    final threshold = blurThreshold ?? state.blurThreshold;

    _isCancelled = false;
    _lastProgressPercent = -1; // Progress takibini sıfırla
    _lastProgressUpdate = null; // Zaman takibini sıfırla
    state = state.copyWith(
      isScanning: true,
      progress: 0.0,
      clearError: true,
      blurryPhotosByAlbum: {},
      blurThreshold: threshold,
      hasCompletedScan: false, // Yeni tarama başladığında false yap
      processedCount: 0,
      totalCount: 0,
      plannedSampleCount: 0,
      currentAlbum: null, // Başlangıçta albüm bilgisi yok
    );

    try {
      debugPrint('📦 [BlurDetection] Service alınıyor...');
      final service = ref.read(blurDetectionServiceProvider);
      debugPrint('📦 [BlurDetection] Service alındı: ${service.runtimeType}');

      // Premium kontrolü
      final prefsService = ref.read(preferencesServiceProvider);
      final isPremium = await prefsService.isPremium();
      debugPrint('💎 [BlurDetection] Premium durumu: $isPremium');

      // Kalan blur scan hakkını al (premium değilse)
      int remainingScanLimit = 999999999; // Premium için sınırsız
      if (!isPremium) {
        remainingScanLimit = await prefsService.getBlurScanLimit();
        debugPrint(
          '📊 [BlurDetection] Kalan blur scan hakkı: $remainingScanLimit',
        );
      }

      debugPrint(
        '🔍 [BlurDetection] findBlurryPhotosInAlbums çağrılıyor... (threshold: $threshold, maxScanLimit: $remainingScanLimit)',
      );
      final scanResult = await service.findBlurryPhotosInAlbums(
        albums,
        blurThreshold: threshold,
        maxScanLimit: remainingScanLimit,
        progressCallback:
            (
              albumName,
              progress,
              processedCount,
              plannedCount,
              albumTotalCount,
            ) {
              if (_isCancelled) return;

              // Progress'i %1 artışlarla güncelle (0%, 1%, 2%, 3% şeklinde)
              final currentProgressPercent = (progress * 100)
                  .floor(); // Yüzdeyi tam sayıya yuvarla
              final now = DateTime.now();
              final timeDelta = _lastProgressUpdate != null
                  ? now.difference(_lastProgressUpdate!).inMilliseconds
                  : _progressThrottleMs + 1;

              // %1 artış olduğunda veya zaman aşımında güncelle
              if (currentProgressPercent > _lastProgressPercent ||
                  timeDelta >= _progressThrottleMs) {
                _lastProgressUpdate = now;
                _lastProgressPercent = currentProgressPercent;

                // State güncellemesini frame callback ile yap (UI thread'i bloklamamak için)
                SchedulerBinding.instance.scheduleFrameCallback((_) {
                  if (!_isCancelled) {
                    final displayTotalCount = albumTotalCount > 0
                        ? albumTotalCount
                        : plannedCount;
                    final normalizedProgress = displayTotalCount > 0
                        ? (processedCount / displayTotalCount).clamp(0.0, 1.0)
                        : progress.clamp(0.0, 1.0);
                    state = state.copyWith(
                      progress: normalizedProgress,
                      currentAlbum: albumName,
                      processedCount: processedCount,
                      totalCount: displayTotalCount,
                      plannedSampleCount: plannedCount,
                    );
                  }
                });
              }
            },
        shouldCancel: () => _isCancelled,
        isPremium: isPremium,
      );

      final results = scanResult.results;
      final scannedPhotoCount = scanResult.scannedPhotoCount;

      if (_isCancelled) {
        debugPrint('⚠️ [BlurDetection] Tarama iptal edildi');
        state = state.copyWith(
          isScanning: false,
          progress: 0.0,
          currentAlbum: null,
          processedCount: 0,
          totalCount: 0,
          plannedSampleCount: 0,
        );
        return;
      }

      debugPrint(
        '✅ [BlurDetection] Tarama tamamlandı! Bulunan albüm sayısı: ${results.length}, Scan edilen fotoğraf: $scannedPhotoCount',
      );

      // Boş olmayan sonuçları filtrele
      final filteredResults = <String, List<BlurPhoto>>{};
      int totalPhotos = 0;

      for (final entry in results.entries) {
        if (entry.value.isNotEmpty) {
          filteredResults[entry.key] = entry.value;
          totalPhotos += entry.value.length;

          debugPrint(
            '   📁 ${entry.key}: ${entry.value.length} blurlu fotoğraf',
          );
          for (final photo in entry.value.take(3)) {
            debugPrint(
              '      - Fotoğraf: score=${photo.blurScore.toStringAsFixed(2)}, ${photo.blurLevel}',
            );
          }
        }
      }

      debugPrint('📊 [BlurDetection] Toplam istatistikler:');
      debugPrint('   - Orijinal albüm sayısı: ${results.length}');
      debugPrint('   - Filtrelenmiş albüm sayısı: ${filteredResults.length}');
      debugPrint('   - Toplam blurlu fotoğraf: $totalPhotos');

      // Blur scan limit'i düşür - SADECE sonuç bulunduysa
      final hasResults = filteredResults.isNotEmpty && totalPhotos > 0;
      if (!isPremium && scannedPhotoCount > 0 && hasResults) {
        try {
          await prefsService.decreaseBlurScanLimit(scannedPhotoCount);
          ref.invalidate(blurScanLimitProvider);
          debugPrint(
            '💾 [BlurDetection] Blur scan limit düşürüldü: $scannedPhotoCount fotoğraf (sonuç bulundu)',
          );
        } catch (e) {
          debugPrint('⚠️ [BlurDetection] Blur scan limit düşürülemedi: $e');
        }
      } else if (!hasResults) {
        debugPrint(
          '✅ [BlurDetection] Sonuç bulunamadı, blur scan limit azaltılmadı',
        );
      }

      // State'i güncelle - YENİ Map oluştur (Riverpod için önemli)
      final newResultsMap = <String, List<BlurPhoto>>{};
      for (final entry in filteredResults.entries) {
        // Her liste için de yeni bir liste oluştur
        newResultsMap[entry.key] = List<BlurPhoto>.from(entry.value);
      }

      debugPrint('✅ [BlurDetection] Yeni Map oluşturuldu:');
      debugPrint('   - Map size: ${newResultsMap.length}');
      for (final entry in newResultsMap.entries) {
        debugPrint('     - ${entry.key}: ${entry.value.length} fotoğraf');
      }

      final newState = BlurDetectionState(
        blurryPhotosByAlbum: newResultsMap,
        isScanning: false,
        progress: 1.0,
        currentAlbum: null,
        error: null,
        blurThreshold: threshold,
        hasCompletedScan: true, // Tarama tamamlandı
        processedCount: 0,
        totalCount: 0,
        plannedSampleCount: 0,
      );

      debugPrint('✅ [BlurDetection] Yeni state oluşturuldu:');
      debugPrint(
        '   - blurryPhotosByAlbum size: ${newState.blurryPhotosByAlbum.length}',
      );
      debugPrint('   - totalBlurryPhotos: ${newState.totalBlurryPhotos}');
      debugPrint(
        '   - totalSpaceToSaveMB: ${newState.totalSpaceToSaveMB.toStringAsFixed(2)}',
      );

      // State güncellemesinden önce bir kontrol
      if (filteredResults.isEmpty) {
        debugPrint('   ⚠️ [BlurDetection] Filtrelenmiş sonuçlar boş!');
      } else {
        debugPrint(
          '   ✅ [BlurDetection] Filtrelenmiş sonuçlar dolu, state güncelleniyor...',
        );
        debugPrint('   📊 [BlurDetection] State güncellemesi öncesi:');
        debugPrint(
          '      - Eski state: ${state.blurryPhotosByAlbum.length} albüm',
        );
        debugPrint(
          '      - Yeni state: ${newState.blurryPhotosByAlbum.length} albüm',
        );
      }

      // State'i güncelle - bu Riverpod'ı notify edecek
      state = newState;
      debugPrint('✅ [BlurDetection] State başarıyla güncellendi!');

      // State güncellemesinden sonra bir kez daha kontrol et
      Future.microtask(() {
        debugPrint('🔍 [BlurDetection] Microtask - State kontrolü:');
        debugPrint(
          '   - blurryPhotosByAlbum.length: ${state.blurryPhotosByAlbum.length}',
        );
        debugPrint('   - totalBlurryPhotos: ${state.totalBlurryPhotos}');

        // Her albüm için fotoğraf sayısını göster
        for (final entry in state.blurryPhotosByAlbum.entries) {
          debugPrint('     - ${entry.key}: ${entry.value.length} fotoğraf');
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ [BlurDetection] Hata: $e');
      debugPrint('❌ [BlurDetection] Stack trace: $stackTrace');
      state = state.copyWith(
        error: e,
        isScanning: false,
        currentAlbum: null,
        processedCount: 0,
        totalCount: 0,
        plannedSampleCount: 0,
      );
    }
  }

  /// Blurlu fotoğrafları topluca sil
  Future<int> deleteBlurryPhotos(List<BlurPhoto> photos) async {
    if (photos.isEmpty) return 0;

    final service = ref.read(mediaLibraryServiceProvider);

    // Tüm fotoğraf ID'lerini topla
    final photoIds = photos.map((photo) => photo.asset.id).toList();

    debugPrint(
      '🗑️ [BlurDetection] Toplu silme başlatılıyor: ${photoIds.length} fotoğraf',
    );

    try {
      // Toplu silme işlemi
      final deletedIds = await service.deleteBatch(photoIds);
      final deletedCount = deletedIds.length;

      debugPrint(
        '✅ [BlurDetection] ${deletedCount}/${photoIds.length} fotoğraf başarıyla silindi',
      );

      // Silinen fotoğrafları state'ten kaldır
      final deletedIdsSet = Set<String>.from(deletedIds);
      final updatedMap = <String, List<BlurPhoto>>{};

      for (final entry in state.blurryPhotosByAlbum.entries) {
        final remainingPhotos = entry.value
            .where((photo) => !deletedIdsSet.contains(photo.asset.id))
            .toList();
        if (remainingPhotos.isNotEmpty) {
          updatedMap[entry.key] = remainingPhotos;
        }
      }

      // State'i güncelle
      state = state.copyWith(blurryPhotosByAlbum: updatedMap);

      debugPrint(
        '💾 [BlurDetection] State güncellendi: ${updatedMap.length} albüm kaldı',
      );

      return deletedCount;
    } catch (e) {
      debugPrint('❌ [BlurDetection] Toplu silme hatası: $e');
      return 0;
    }
  }

  /// Tüm blurlu fotoğrafları sil
  Future<int> deleteAllBlurryPhotos() async {
    final allPhotos = state.blurryPhotosByAlbum.values
        .expand((photos) => photos)
        .toList();
    return await deleteBlurryPhotos(allPhotos);
  }

  /// Taramayı iptal et
  void cancel() {
    debugPrint('🛑 [BlurDetection] Tarama iptal ediliyor...');
    _isCancelled = true;
    state = state.copyWith(
      isScanning: false,
      progress: 0.0,
      currentAlbum: null,
      processedCount: 0,
      totalCount: 0,
      plannedSampleCount: 0,
    );
  }

  /// State'i temizle
  void clear() {
    _isCancelled = false;
    state = const BlurDetectionState();
  }
}

final blurDetectionProvider =
    StateNotifierProvider<BlurDetectionNotifier, BlurDetectionState>((ref) {
      return BlurDetectionNotifier(ref);
    });

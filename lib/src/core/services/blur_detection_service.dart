import 'dart:math' as math;
import 'package:photo_manager/photo_manager.dart' as pm;
import '../models/blur_photo.dart';
import '../utils/app_logger.dart';
import 'blur_detection_isolate.dart';

/// Blur detection servisi - Laplacian variance kullanarak
class BlurDetectionService {
  /// Pixelation score hesapla (0.0 = pixelleşmiş değil, 1.0 = çok pixelleşmiş)
  /// Task 2: Isolate içinde çalıştır
  Future<double> calculatePixelationScore(pm.AssetEntity asset) async {
    try {
      // Thumbnail al (Task 1: 128x128)
      final thumbnail = await asset.thumbnailDataWithSize(
        const pm.ThumbnailSize(128, 128),
        quality: 80,
      );

      if (thumbnail == null || thumbnail.isEmpty) {
        return 0.0;
      }

      // Task 2: Isolate içinde hesapla
      final result = await analyzeBlurInIsolate(thumbnail);
      return result.pixelationScore;
    } catch (e) {
      AppLogger.w('⚠️ [BlurDetection] Pixelation score hesaplama hatası: $e');
      return 0.0;
    }
  }

  /// Blur score hesapla (0.0 = çok blurlu, 1.0 = keskin)
  /// Task 2: Isolate içinde çalıştır
  /// Task 3: Basit Laplacian variance kullan (karmaşık multi-method yerine)
  Future<double> calculateBlurScore(pm.AssetEntity asset) async {
    try {
      // Thumbnail boyutu: 128x128 (performans optimizasyonu - task 1)
      final thumbnail = await asset.thumbnailDataWithSize(
        const pm.ThumbnailSize(128, 128),
        quality: 80, // Kalite ve hız dengesi
      );

      if (thumbnail == null || thumbnail.isEmpty) {
        AppLogger.w('⚠️ [BlurDetection] Thumbnail alınamadı (ID: ${asset.id})');
        return 0.5; // Bilinmeyen durum için orta değer
      }

      // Task 2: Isolate içinde hesapla
      // Task 3: Basit Laplacian variance kullan
      final result = await analyzeBlurInIsolate(thumbnail);
      return result.blurScore;
    } catch (e) {
      AppLogger.e(
        '⚠️ [BlurDetection] Blur score hesaplama hatası (ID: ${asset.id}): $e',
      );
      return 0.5;
    }
  }

  Future<
    ({List<BlurPhoto> blurryPhotos, int scannedPhotoCount, int targetCount})
  >
  findBlurryPhotosInAlbum(
    pm.AssetPathEntity album, {
    double blurThreshold =
        0.5, // Daha fazla blur tespit etmek için 0.4'ten 0.5'e artırıldı
    void Function(
      double progress,
      int processedCount,
      int sampleTarget,
      int albumTotalCount,
    )?
    progressCallback,
    bool Function()? shouldCancel,
    bool isPremium = false,
    int maxScanLimit = 999999999,
  }) async {
    AppLogger.i(
      '🔍 [BlurDetection] findBlurryPhotosInAlbum başladı: ${album.name} (ID: ${album.id})',
    );

    final blurryPhotos = <BlurPhoto>[];
    // Optimize sayfa boyutu: daha büyük sayfa = daha az I/O = daha hızlı
    const pageSize = 1000; // 1000 medya/sayfa (memory-safe, daha hızlı I/O)
    const batchSize =
        50; // Paralel işlenecek asset sayısı (performans için optimize edildi - 20'den 50'ye artırıldı)
    int totalProcessed = 0;
    int totalAssets = 0;
    int imageCount = 0;
    final random = math.Random();
    int sampleTarget = 0;

    try {
      // Gerçek toplam asset sayısını al
      AppLogger.d('📊 [BlurDetection] Toplam asset sayısı alınıyor...');
      try {
        totalAssets = await album.assetCountAsync;
        AppLogger.d('📊 [BlurDetection] Gerçek toplam asset: $totalAssets');
      } catch (e) {
        // Eğer assetCountAsync çalışmazsa, tahmin et
        AppLogger.w(
          '⚠️ [BlurDetection] assetCountAsync çalışmadı, tahmin ediliyor: $e',
        );
        final firstPage = await album.getAssetListPaged(
          page: 0,
          size: pageSize,
        );
        totalAssets = firstPage.length >= pageSize
            ? firstPage.length * 10
            : firstPage.length;
        totalAssets = totalAssets > 0 ? totalAssets : 500;
        AppLogger.d('📊 [BlurDetection] Tahmini toplam asset: $totalAssets');
      }

      AppLogger.d('💎 [BlurDetection] Premium durumu: $isPremium');
      AppLogger.d('📊 [BlurDetection] Max scan limit: $maxScanLimit');

      // 1000 fotoğraf limit kontrolü (premium olsa bile)
      const maxPhotosPerScan = 1000;
      final effectiveMaxLimit = isPremium
          ? maxPhotosPerScan // Premium olsa bile 1000 limit
          : math.min(maxScanLimit, maxPhotosPerScan);
      sampleTarget = totalAssets > 0
          ? math.min(totalAssets, effectiveMaxLimit)
          : effectiveMaxLimit;

      if (sampleTarget <= 0) {
        AppLogger.w('⚠️ [BlurDetection] Scan limiti 0, tarama yapılmadı.');
        return (
          blurryPhotos: <BlurPhoto>[],
          scannedPhotoCount: 0,
          targetCount: 0,
        );
      }

      final int totalPages = totalAssets > 0
          ? ((totalAssets + pageSize - 1) ~/ pageSize)
          : 1;
      final pageIndices = List.generate(totalPages, (index) => index)
        ..shuffle(random);

      // Tüm asset'leri kontrol et
      AppLogger.i(
        '🔄 [BlurDetection] Rastgele blur taraması başlıyor (hedef: $sampleTarget fotoğraf, toplam albüm asset: $totalAssets)',
      );
      for (final pageIndex in pageIndices) {
        if (imageCount >= sampleTarget) {
          break;
        }

        // İptal kontrolü
        if (shouldCancel != null && shouldCancel()) {
          AppLogger.w('🛑 [BlurDetection] Tarama iptal edildi');
          return (
            blurryPhotos: blurryPhotos,
            scannedPhotoCount: imageCount,
            targetCount: sampleTarget,
          );
        }

        final assets = await album.getAssetListPaged(
          page: pageIndex,
          size: pageSize,
        );
        if (assets.isEmpty) continue;

        // Sadece image asset'leri filtrele
        final imageAssets =
            assets.where((a) => a.type == pm.AssetType.image).toList()
              ..shuffle(random);
        if (imageAssets.isEmpty) continue;

        // Paralel batch processing: asset'leri batch'ler halinde işle
        for (var i = 0; i < imageAssets.length; i += batchSize) {
          if (imageCount >= sampleTarget) {
            break;
          }

          // İptal kontrolü (her batch'te)
          if (shouldCancel != null && shouldCancel()) {
            AppLogger.w('🛑 [BlurDetection] Tarama iptal edildi');
            return (
              blurryPhotos: blurryPhotos,
              scannedPhotoCount: imageCount,
              targetCount: sampleTarget,
            );
          }

          var batch = imageAssets.skip(i).take(batchSize).toList();
          final remainingNeeded = sampleTarget - imageCount;
          if (remainingNeeded <= 0) {
            break;
          }
          if (batch.length > remainingNeeded) {
            batch = batch.sublist(0, remainingNeeded);
          }
          if (batch.isEmpty) {
            continue;
          }

          // Batch'i paralel işle
          final batchResults = await Future.wait(
            batch.map((asset) async {
              try {
                // İptal kontrolü
                if (shouldCancel != null && shouldCancel()) {
                  return null;
                }

                // Limit kontrolü
                if (imageCount >= sampleTarget) {
                  return null;
                }

                // Blur ve pixelation score'ları paralel hesapla
                final results = await Future.wait([
                  calculateBlurScore(asset),
                  calculatePixelationScore(asset),
                ]);

                final blurScore = results[0];
                final pixelationScore = results[1];

                // Blurlu veya pixelleşmiş fotoğrafları filtrele
                final isBlurry = blurScore < blurThreshold;
                final isPixelated =
                    pixelationScore > 0.5; // Pixelation threshold

                // Debug: Tespit edilen problemli fotoğrafları logla
                if (isBlurry || isPixelated) {
                  AppLogger.d(
                    '✅ [BlurDetection] Problemli fotoğraf tespit edildi: Asset ${asset.id}, BlurScore=${blurScore.toStringAsFixed(3)} (threshold: $blurThreshold), PixelationScore=${pixelationScore.toStringAsFixed(3)}, isBlurry=$isBlurry, isPixelated=$isPixelated',
                  );
                }

                if (isBlurry || isPixelated) {
                  // Boyutu hesapla (metadata-based, hızlı)
                  double estimatedSizeMB = 0;
                  try {
                    final size = asset.size;
                    final estimatedBytes = size.width * size.height * 3;
                    estimatedSizeMB = estimatedBytes / (1024 * 1024);
                  } catch (_) {
                    // Hata durumunda devam et
                  }

                  return BlurPhoto(
                    asset: asset,
                    blurScore: blurScore,
                    pixelationScore: pixelationScore,
                    albumName: album.name,
                    estimatedSizeMB: estimatedSizeMB,
                  );
                }
                return null;
              } catch (e) {
                AppLogger.e('⚠️ [BlurDetection] İşleme hatası: $e');
                return null;
              }
            }),
          );

          // Batch sonuçlarını ekle
          for (final result in batchResults) {
            if (result != null) {
              blurryPhotos.add(result);
            }
          }

          imageCount += batch.length;
          totalProcessed += batch.length;

          // İlerleme callback (throttled - her 100 asset'te bir - performans için optimize edildi)
          // UI thread'i bloklamamak için callback'leri azalt
          if (progressCallback != null &&
              (totalProcessed % 100 == 0 || imageCount >= sampleTarget)) {
            final progress = (totalProcessed / sampleTarget).clamp(0.0, 1.0);
            // Async olarak çağır (UI thread'i bloklamamak için)
            Future.microtask(() {
              progressCallback(
                progress,
                totalProcessed,
                sampleTarget,
                totalAssets,
              );
            });
          }

          // Her 500 asset'te bir yield (UI thread'e nefes vermek için - performans için optimize edildi)
          if (totalProcessed % 500 == 0) {
            await Future.delayed(const Duration(milliseconds: 1));
          }

          // Debug log (her 50 fotoğrafta bir)
          if (imageCount % 50 == 0) {
            AppLogger.d(
              '🖼️ [BlurDetection] $imageCount fotoğraf işlendi, ${blurryPhotos.length} problem bulundu...',
            );
          }
        }

        if (imageCount >= sampleTarget) {
          break;
        }
      }

      // Blur score'a göre sırala (en blurludan en az blurluya)
      blurryPhotos.sort((a, b) => a.blurScore.compareTo(b.blurScore));

      AppLogger.i(
        '✅ [BlurDetection] ${blurryPhotos.length} blurlu fotoğraf bulundu (${album.name})',
      );
      AppLogger.i(
        '📊 [BlurDetection] Toplam scan edilen fotoğraf: $imageCount',
      );

      return (
        blurryPhotos: blurryPhotos,
        scannedPhotoCount: imageCount,
        targetCount: sampleTarget,
      );
    } catch (e, stackTrace) {
      AppLogger.e('❌ [BlurDetection] Hata: $e', e, stackTrace);
      return (
        blurryPhotos: <BlurPhoto>[],
        scannedPhotoCount: 0,
        targetCount: sampleTarget,
      );
    }
  }

  /// Birden fazla albümde blurlu fotoğrafları tespit et
  Future<
    ({
      Map<String, List<BlurPhoto>> results,
      int scannedPhotoCount,
      int targetCount,
    })
  >
  findBlurryPhotosInAlbums(
    List<pm.AssetPathEntity> albums, {
    double blurThreshold = 0.5,
    void Function(
      String albumName,
      double progress,
      int processedCount,
      int sampleTarget,
      int albumTotalCount,
    )?
    progressCallback,
    bool Function()? shouldCancel,
    bool isPremium = false,
    int maxScanLimit = 999999999,
  }) async {
    AppLogger.i(
      '🔍 [BlurDetection] findBlurryPhotosInAlbums başladı - ${albums.length} albüm',
    );
    final results = <String, List<BlurPhoto>>{};
    int totalScannedPhotos = 0;
    int totalTargetPhotos = 0;

    for (int i = 0; i < albums.length; i++) {
      // İptal kontrolü
      if (shouldCancel != null && shouldCancel()) {
        AppLogger.w('🛑 [BlurDetection] Tarama iptal edildi');
        return (
          results: results,
          scannedPhotoCount: totalScannedPhotos,
          targetCount: totalTargetPhotos,
        );
      }

      // Kalan scan limit kontrolü (premium değilse)
      if (!isPremium && totalScannedPhotos >= maxScanLimit) {
        AppLogger.w(
          '⚠️ [BlurDetection] Scan limit aşıldı: $totalScannedPhotos/$maxScanLimit fotoğraf scan edildi',
        );
        break;
      }

      final album = albums[i];
      AppLogger.d(
        '📁 [BlurDetection] Albüm ${i + 1}/${albums.length}: ${album.name} (ID: ${album.id})',
      );

      // Kalan scan limit'i hesapla
      final remainingScanLimit = isPremium
          ? 999999999
          : (maxScanLimit - totalScannedPhotos).clamp(0, maxScanLimit);

      final albumResult = await findBlurryPhotosInAlbum(
        album,
        blurThreshold: blurThreshold,
        progressCallback:
            (
              albumProgress,
              albumProcessedCount,
              albumPlannedCount,
              albumTotalCount,
            ) {
              if (progressCallback != null) {
                progressCallback(
                  album.name,
                  albumProgress.clamp(0.0, 1.0),
                  albumProcessedCount,
                  albumPlannedCount,
                  albumTotalCount,
                );
              }
            },
        shouldCancel: shouldCancel,
        isPremium: isPremium,
        maxScanLimit: remainingScanLimit,
      );

      final blurryPhotos = albumResult.blurryPhotos;
      final albumScannedCount = albumResult.scannedPhotoCount;
      totalTargetPhotos += albumResult.targetCount;

      // İptal edildiyse sonuçları döndür
      if (shouldCancel != null && shouldCancel()) {
        AppLogger.w('🛑 [BlurDetection] Tarama iptal edildi');
        return (
          results: results,
          scannedPhotoCount: totalScannedPhotos,
          targetCount: totalTargetPhotos,
        );
      }

      totalScannedPhotos += albumScannedCount;

      if (blurryPhotos.isNotEmpty) {
        results[album.name] = blurryPhotos;
      }

      // Scan limit aşıldıysa dur
      if (!isPremium && totalScannedPhotos >= maxScanLimit) {
        AppLogger.w(
          '⚠️ [BlurDetection] Scan limit aşıldı: $totalScannedPhotos/$maxScanLimit fotoğraf scan edildi',
        );
        break;
      }
    }

    AppLogger.i(
      '🎉 [BlurDetection] Tüm albümler taranı! Toplam sonuç: ${results.length} albüm, Toplam scan edilen: $totalScannedPhotos fotoğraf',
    );
    return (
      results: results,
      scannedPhotoCount: totalScannedPhotos,
      targetCount: totalTargetPhotos == 0
          ? totalScannedPhotos
          : totalTargetPhotos,
    );
  }
}

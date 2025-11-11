import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart' as pm;
import '../models/blur_photo.dart';

/// Blur detection servisi - Laplacian variance kullanarak
class BlurDetectionService {
  /// Pixelation score hesapla (0.0 = pixelleşmiş değil, 1.0 = çok pixelleşmiş)
  /// Block-based method kullanır - pixelleşmiş görüntülerde benzer renklerin bloklar halinde gruplanması
  Future<double> calculatePixelationScore(pm.AssetEntity asset) async {
    try {
      // Thumbnail al
      final thumbnail = await asset.thumbnailDataWithSize(
        const pm.ThumbnailSize(200, 200),
        quality: 85,
      );

      if (thumbnail == null || thumbnail.isEmpty) {
        return 0.0;
      }

      final image = img.decodeImage(thumbnail);
      if (image == null) {
        return 0.0;
      }

      // Block-based pixelation detection
      // Pixelleşmiş görüntülerde küçük bloklar halinde benzer renkler olur
      final blockSize = 4; // 4x4 bloklar
      final width = image.width;
      final height = image.height;
      
      int blockCount = 0;
      double totalVariance = 0.0;

      // Görüntüyü bloklara böl
      for (int by = 0; by < height - blockSize; by += blockSize) {
        for (int bx = 0; bx < width - blockSize; bx += blockSize) {
          blockCount++;
          
          // Bloğun içindeki renkleri topla
          final colors = <int>[];
          for (int y = by; y < by + blockSize && y < height; y++) {
            for (int x = bx; x < bx + blockSize && x < width; x++) {
              final pixel = image.getPixel(x, y);
              // RGB'yi tek bir değere çevir (basit hash)
              final r = pixel.r.toInt();
              final g = pixel.g.toInt();
              final b = pixel.b.toInt();
              final color = (r << 16) | (g << 8) | b;
              colors.add(color);
            }
          }

          // Bloğun içindeki renk varyansını hesapla
          if (colors.isNotEmpty) {
            final mean = colors.reduce((a, b) => a + b) / colors.length;
            final variance = colors
                .map((c) => (c - mean) * (c - mean))
                .reduce((a, b) => a + b) / colors.length;
            totalVariance += variance;
          }
        }
      }

      if (blockCount == 0) return 0.0;

      // Ortalama varyans
      final avgVariance = totalVariance / blockCount;
      
      // Düşük varyans = pixelleşmiş (bloklar içinde benzer renkler)
      // Yüksek varyans = pixelleşmiş değil (bloklar içinde farklı renkler)
      // Pixelation score: 0.0 = pixelleşmiş değil, 1.0 = çok pixelleşmiş
      
      // Normalize et (variance değerleri deneyerek ayarlanabilir)
      // Düşük varyans (<1000) = pixelleşmiş
      // Yüksek varyans (>10000) = pixelleşmiş değil
      const minVariance = 0.0;
      const maxVariance = 50000.0;
      
      final normalizedVariance = (avgVariance - minVariance) / (maxVariance - minVariance);
      final pixelationScore = (1.0 - normalizedVariance.clamp(0.0, 1.0));
      
      return pixelationScore;
    } catch (e) {
      debugPrint('   ⚠️ [BlurDetection] Pixelation score hesaplama hatası: $e');
      return 0.0;
    }
  }

  /// Blur score hesapla (0.0 = çok blurlu, 1.0 = keskin)
  /// Laplacian variance metodunu kullanır
  Future<double> calculateBlurScore(pm.AssetEntity asset) async {
    try {
      // Thumbnail al (blur tespiti için küçük boyut yeterli)
      final thumbnail = await asset.thumbnailDataWithSize(
        const pm.ThumbnailSize(200, 200),
        quality: 85,
      );

      if (thumbnail == null || thumbnail.isEmpty) {
        debugPrint('   ⚠️ [BlurDetection] Thumbnail alınamadı (ID: ${asset.id})');
        return 0.5; // Bilinmeyen durum için orta değer
      }

      // Image decode et
      final image = img.decodeImage(thumbnail);
      if (image == null) {
        debugPrint('   ⚠️ [BlurDetection] Image decode edilemedi (ID: ${asset.id})');
        return 0.5;
      }

      // Gri tonlamaya çevir (performans için)
      final grayImage = img.grayscale(image);

      // Laplacian kernel uygula
      final laplacianKernel = [
        [0, -1, 0],
        [-1, 4, -1],
        [0, -1, 0],
      ];

      final width = grayImage.width;
      final height = grayImage.height;
      final variance = _calculateLaplacianVariance(
        grayImage,
        laplacianKernel,
        width,
        height,
      );

      // Variance'ı normalize et (0-1 arası)
      // Düşük variance = blur, yüksek variance = keskin
      // Threshold değerleri deneyerek ayarlanabilir
      final normalizedScore = _normalizeVariance(variance);

      // Debug sadece blurlu veya şüpheli fotoğraflar için
      if (normalizedScore < 0.4) {
        debugPrint(
          '   📊 [BlurDetection] Asset ${asset.id}: variance=${variance.toStringAsFixed(2)}, score=${normalizedScore.toStringAsFixed(2)} (BLURLU)',
        );
      }

      return normalizedScore;
    } catch (e) {
      debugPrint('   ⚠️ [BlurDetection] Blur score hesaplama hatası (ID: ${asset.id}): $e');
      return 0.5;
    }
  }

  /// Laplacian variance hesapla
  double _calculateLaplacianVariance(
    img.Image image,
    List<List<int>> kernel,
    int width,
    int height,
  ) {
    final laplacianValues = <int>[];

    // Kernel'i uygula (border'ları atla)
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        int sum = 0;
        
        // Kernel convolution
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            // Pixel'den RGB değerlerini al
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();
            // Luminance hesapla: 0.299*R + 0.587*G + 0.114*B
            final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
            final kernelValue = kernel[ky + 1][kx + 1];
            sum += (gray * kernelValue);
          }
        }
        
        laplacianValues.add(sum.abs());
      }
    }

    if (laplacianValues.isEmpty) return 0.0;

    // Variance hesapla
    final mean = laplacianValues.reduce((a, b) => a + b) / laplacianValues.length;
    final variance = laplacianValues
        .map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b) /
        laplacianValues.length;

    return variance;
  }

  /// Variance'ı 0-1 arası normalize et
  /// Bu değerler deneyerek ayarlanabilir
  double _normalizeVariance(double variance) {
    // Laplacian variance genellikle 0-500 arası değerler alır
    // Düşük değerler (<50) = çok blurlu
    // Orta değerler (50-200) = biraz blurlu  
    // Yüksek değerler (>200) = keskin
    
    // Linear mapping kullan
    // Variance değerleri genellikle 0-500 arası
    const minVariance = 0.0;
    const maxVariance = 500.0;
    
    // Variance'ı clamp et
    final clampedVariance = variance.clamp(minVariance, maxVariance);
    
    // Linear interpolation
    final score = clampedVariance / maxVariance;
    
    // Score: 0.0 = çok blurlu (variance 0), 1.0 = çok keskin (variance 500)
    // Ancak gerçek dünyada variance genellikle 0-200 arası olur
    // Bu yüzden daha hassas bir mapping kullanabiliriz
    
    // Daha iyi bir mapping: square root kullan (daha yumuşak geçiş)
    final sqrtScore = math.sqrt(score).clamp(0.0, 1.0);
    
    return sqrtScore;
  }

  /// Albüm içinde blurlu fotoğrafları tespit et
  /// Returns: ({blurryPhotos: List<BlurPhoto>, scannedPhotoCount: int})
  Future<({List<BlurPhoto> blurryPhotos, int scannedPhotoCount})> findBlurryPhotosInAlbum(
    pm.AssetPathEntity album, {
    double blurThreshold = 0.3,
    void Function(double progress, int processedCount, int totalCount)? progressCallback,
    bool Function()? shouldCancel,
    bool isPremium = false,
    int maxScanLimit = 999999999,
  }) async {
    debugPrint(
      '🔍 [BlurDetection] findBlurryPhotosInAlbum başladı: ${album.name} (ID: ${album.id})',
    );

    final blurryPhotos = <BlurPhoto>[];
    // Optimize sayfa boyutu: daha büyük sayfa = daha az I/O = daha hızlı
    const pageSize = 500; // 500 medya/sayfa (memory-safe, hızlı)
    const batchSize = 20; // Paralel işlenecek asset sayısı (blur detection için)
    int page = 0;
    int totalProcessed = 0;
    int totalAssets = 0;
    int imageCount = 0;

    try {
      // Gerçek toplam asset sayısını al
      debugPrint('📊 [BlurDetection] Toplam asset sayısı alınıyor...');
      try {
        totalAssets = await album.assetCountAsync;
        debugPrint('📊 [BlurDetection] Gerçek toplam asset: $totalAssets');
      } catch (e) {
        // Eğer assetCountAsync çalışmazsa, tahmin et
        debugPrint('⚠️ [BlurDetection] assetCountAsync çalışmadı, tahmin ediliyor: $e');
        final firstPage = await album.getAssetListPaged(page: 0, size: pageSize);
        totalAssets = firstPage.length >= pageSize ? firstPage.length * 10 : firstPage.length;
        totalAssets = totalAssets > 0 ? totalAssets : 500;
        debugPrint('📊 [BlurDetection] Tahmini toplam asset: $totalAssets');
      }

      debugPrint('💎 [BlurDetection] Premium durumu: $isPremium');
      debugPrint('📊 [BlurDetection] Max scan limit: $maxScanLimit');

      // Kalan scan hakkı kadar fotoğraf scan et
      final int maxImagesToProcess = isPremium ? 999999999 : maxScanLimit;
      
      // Toplam sayıyı maxImagesToProcess ile sınırla (premium değilse)
      if (!isPremium && totalAssets > maxImagesToProcess) {
        totalAssets = maxImagesToProcess;
        debugPrint('📊 [BlurDetection] Toplam sayı limit ile sınırlandı: $totalAssets');
      }

      // Tüm asset'leri kontrol et
      debugPrint('🔄 [BlurDetection] Blur tespiti yapılıyor (hızlı mod)...');
      while (true) {
        // İptal kontrolü
        if (shouldCancel != null && shouldCancel()) {
          debugPrint('   🛑 [BlurDetection] Tarama iptal edildi');
          return (blurryPhotos: blurryPhotos, scannedPhotoCount: imageCount);
        }

        // Premium olmayan kullanıcılar için limit kontrolü
        if (!isPremium && imageCount >= maxImagesToProcess) {
          debugPrint(
            '   ⚠️ [BlurDetection] Premium olmayan kullanıcı için limit aşıldı: $imageCount/$maxImagesToProcess fotoğraf işlendi',
          );
          break;
        }

        final assets = await album.getAssetListPaged(page: page, size: pageSize);
        if (assets.isEmpty) break;

        // Sadece image asset'leri filtrele
        final imageAssets = assets.where((a) => a.type == pm.AssetType.image).toList();
        
        // Paralel batch processing: asset'leri batch'ler halinde işle
        for (var i = 0; i < imageAssets.length; i += batchSize) {
          // İptal kontrolü (her batch'te)
          if (shouldCancel != null && shouldCancel()) {
            debugPrint('   🛑 [BlurDetection] Tarama iptal edildi');
            return (blurryPhotos: blurryPhotos, scannedPhotoCount: imageCount);
          }

          // Premium olmayan kullanıcılar için limit kontrolü
          if (!isPremium && imageCount >= maxImagesToProcess) {
            break;
          }

          final batch = imageAssets.skip(i).take(batchSize).toList();
          
          // Batch'i paralel işle
          final batchResults = await Future.wait(
            batch.map((asset) async {
              try {
                // İptal kontrolü
                if (shouldCancel != null && shouldCancel()) {
                  return null;
                }

                // Premium olmayan kullanıcılar için limit kontrolü
                if (!isPremium && imageCount >= maxImagesToProcess) {
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
              final isPixelated = pixelationScore > 0.5; // Pixelation threshold
              
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
                debugPrint('   ⚠️ [BlurDetection] İşleme hatası: $e');
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

          // İlerleme callback (her batch'te)
          if (progressCallback != null && totalAssets > 0) {
            final progress = (totalProcessed / totalAssets).clamp(0.0, 1.0);
            progressCallback(progress, totalProcessed, totalAssets);
          }

          // Debug log (her 50 fotoğrafta bir)
          if (imageCount % 50 == 0) {
            debugPrint('   🖼️ [BlurDetection] $imageCount fotoğraf işlendi, ${blurryPhotos.length} problem bulundu...');
            }
        }

        // Premium olmayan kullanıcılar için limit kontrolü (loop dışında)
        if (!isPremium && imageCount >= maxImagesToProcess) {
          break;
        }

        if (assets.length < pageSize) break;
        page++;
      }

      // Blur score'a göre sırala (en blurludan en az blurluya)
      blurryPhotos.sort((a, b) => a.blurScore.compareTo(b.blurScore));

      debugPrint(
        '✅ [BlurDetection] ${blurryPhotos.length} blurlu fotoğraf bulundu (${album.name})',
      );
      debugPrint(
        '📊 [BlurDetection] Toplam scan edilen fotoğraf: $imageCount',
      );

      return (blurryPhotos: blurryPhotos, scannedPhotoCount: imageCount);
    } catch (e, stackTrace) {
      debugPrint('❌ [BlurDetection] Hata: $e');
      debugPrint('❌ [BlurDetection] Stack trace: $stackTrace');
      return (blurryPhotos: <BlurPhoto>[], scannedPhotoCount: 0);
    }
  }

  /// Birden fazla albümde blurlu fotoğrafları tespit et
  /// Returns: ({results: Map<String, List<BlurPhoto>>, scannedPhotoCount: int})
  Future<({Map<String, List<BlurPhoto>> results, int scannedPhotoCount})> findBlurryPhotosInAlbums(
    List<pm.AssetPathEntity> albums, {
    double blurThreshold = 0.3,
    void Function(String albumName, double progress, int processedCount, int totalCount)? progressCallback,
    bool Function()? shouldCancel,
    bool isPremium = false,
    int maxScanLimit = 999999999,
  }) async {
    debugPrint(
      '🔍 [BlurDetection] findBlurryPhotosInAlbums başladı - ${albums.length} albüm',
    );
    final results = <String, List<BlurPhoto>>{};
    int totalScannedPhotos = 0;

    for (int i = 0; i < albums.length; i++) {
      // İptal kontrolü
      if (shouldCancel != null && shouldCancel()) {
        debugPrint('   🛑 [BlurDetection] Tarama iptal edildi');
        return (results: results, scannedPhotoCount: totalScannedPhotos);
      }

      // Kalan scan limit kontrolü (premium değilse)
      if (!isPremium && totalScannedPhotos >= maxScanLimit) {
        debugPrint(
          '   ⚠️ [BlurDetection] Scan limit aşıldı: $totalScannedPhotos/$maxScanLimit fotoğraf scan edildi',
        );
        break;
      }

      final album = albums[i];
      debugPrint(
        '📁 [BlurDetection] Albüm ${i + 1}/${albums.length}: ${album.name} (ID: ${album.id})',
      );

      // Kalan scan limit'i hesapla
      final remainingScanLimit = isPremium 
          ? 999999999 
          : (maxScanLimit - totalScannedPhotos).clamp(0, maxScanLimit);

      final albumResult = await findBlurryPhotosInAlbum(
        album,
        blurThreshold: blurThreshold,
        progressCallback: (albumProgress, albumProcessedCount, albumTotalCount) {
          // Genel ilerleme hesapla (tüm albümler için)
          final overallProcessedCount = totalScannedPhotos + albumProcessedCount;
          final overallTotalCount = totalScannedPhotos + albumTotalCount;
          final overallProgress = albums.length > 1 
              ? (i + albumProgress) / albums.length 
              : albumProgress;
          
          if (progressCallback != null) {
            progressCallback(album.name, overallProgress, overallProcessedCount, overallTotalCount);
          }
        },
        shouldCancel: shouldCancel,
        isPremium: isPremium,
        maxScanLimit: remainingScanLimit,
      );

      final blurryPhotos = albumResult.blurryPhotos;
      final albumScannedCount = albumResult.scannedPhotoCount;

      // İptal edildiyse sonuçları döndür
      if (shouldCancel != null && shouldCancel()) {
        debugPrint('   🛑 [BlurDetection] Tarama iptal edildi');
        return (results: results, scannedPhotoCount: totalScannedPhotos);
      }

      totalScannedPhotos += albumScannedCount;

      if (blurryPhotos.isNotEmpty) {
        results[album.name] = blurryPhotos;
      }

      // Scan limit aşıldıysa dur
      if (!isPremium && totalScannedPhotos >= maxScanLimit) {
        debugPrint(
          '   ⚠️ [BlurDetection] Scan limit aşıldı: $totalScannedPhotos/$maxScanLimit fotoğraf scan edildi',
        );
        break;
      }
    }

    debugPrint(
      '🎉 [BlurDetection] Tüm albümler taranı! Toplam sonuç: ${results.length} albüm, Toplam scan edilen: $totalScannedPhotos fotoğraf',
    );
    return (results: results, scannedPhotoCount: totalScannedPhotos);
  }
}


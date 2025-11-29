import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
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
      AppLogger.e('⚠️ [BlurDetection] Blur score hesaplama hatası (ID: ${asset.id}): $e');
      return 0.5;
    }
  }

  /// Laplacian variance hesapla (optimize edilmiş - sampling sadece büyük görüntüler için)
  double _calculateLaplacianVariance(
    img.Image image,
    List<List<int>> kernel,
    int width,
    int height,
  ) {
    final laplacianValues = <int>[];

    // Sampling: Sadece çok büyük görüntüler için (250x250'den büyükse)
    // Küçük görüntülerde tüm pixel'leri kontrol et (daha doğru blur detection)
    // 250x250 = 62500, bu yüzden sampling'i sadece daha büyük görüntüler için kullan
    final useSampling = (width * height) > 62500; // 250x250 = 62500
    final samplingStep = useSampling ? 2 : 1;

    // Kernel'i uygula (border'ları atla)
    for (int y = 1; y < height - 1; y += samplingStep) {
      for (int x = 1; x < width - 1; x += samplingStep) {
        int sum = 0;

        // Kernel convolution
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            // Pixel'den RGB değerlerini al
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();
            // Luminance hesapla: 0.299*R + 0.587*G + 0.114*B (optimize: integer math)
            final gray = ((299 * r + 587 * g + 114 * b) ~/ 1000).round();
            final kernelValue = kernel[ky + 1][kx + 1];
            sum += (gray * kernelValue);
          }
        }

        laplacianValues.add(sum.abs());
      }
    }

    if (laplacianValues.isEmpty) return 0.0;

    // Variance hesapla (optimize: tek geçişte)
    var sum = 0;
    for (final value in laplacianValues) {
      sum += value;
    }
    final mean = sum / laplacianValues.length;

    var varianceSum = 0.0;
    for (final value in laplacianValues) {
      final diff = value - mean;
      varianceSum += diff * diff;
    }
    final variance = varianceSum / laplacianValues.length;

    return variance;
  }

  /// Sobel edge detection variance hesapla (optimize edilmiş - sampling sadece büyük görüntüler için)
  double _calculateSobelVariance(img.Image image, int width, int height) {
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];
    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    final gradientMagnitudes = <double>[];

    // Sampling: Sadece çok büyük görüntüler için (250x250'den büyükse)
    // Küçük görüntülerde tüm pixel'leri kontrol et (daha doğru blur detection)
    // 250x250 = 62500, bu yüzden sampling'i sadece daha büyük görüntüler için kullan
    final useSampling = (width * height) > 62500; // 250x250 = 62500
    final samplingStep = useSampling ? 2 : 1;

    // Sobel operator uygula
    for (int y = 1; y < height - 1; y += samplingStep) {
      for (int x = 1; x < width - 1; x += samplingStep) {
        double gx = 0;
        double gy = 0;

        // Sobel X ve Y'yi birlikte hesapla (tek döngü, daha verimli)
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            // Optimize: integer math kullan
            final gray =
                ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000)
                    .round();
            gx += gray * sobelX[ky + 1][kx + 1];
            gy += gray * sobelY[ky + 1][kx + 1];
          }
        }

        // Gradient magnitude
        final magnitude = math.sqrt(gx * gx + gy * gy);
        gradientMagnitudes.add(magnitude);
      }
    }

    if (gradientMagnitudes.isEmpty) return 0.0;

    // Variance hesapla (optimize: tek geçişte)
    var sum = 0.0;
    for (final value in gradientMagnitudes) {
      sum += value;
    }
    final mean = sum / gradientMagnitudes.length;

    var varianceSum = 0.0;
    for (final value in gradientMagnitudes) {
      final diff = value - mean;
      varianceSum += diff * diff;
    }
    final variance = varianceSum / gradientMagnitudes.length;

    return variance;
  }

  /// Scharr operator variance hesapla (Sobel'den daha hassas, özellikle diagonal edge'ler için)
  double _calculateScharrVariance(img.Image image, int width, int height) {
    final scharrX = [
      [-3, 0, 3],
      [-10, 0, 10],
      [-3, 0, 3],
    ];
    final scharrY = [
      [-3, -10, -3],
      [0, 0, 0],
      [3, 10, 3],
    ];

    final gradientMagnitudes = <double>[];
    final useSampling = (width * height) > 160000; // 400x400 = 160000
    final samplingStep = useSampling ? 2 : 1;

    for (int y = 1; y < height - 1; y += samplingStep) {
      for (int x = 1; x < width - 1; x += samplingStep) {
        double gx = 0;
        double gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final gray =
                ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000)
                    .round();
            gx += gray * scharrX[ky + 1][kx + 1];
            gy += gray * scharrY[ky + 1][kx + 1];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy);
        gradientMagnitudes.add(magnitude);
      }
    }

    if (gradientMagnitudes.isEmpty) return 0.0;

    var sum = 0.0;
    for (final value in gradientMagnitudes) {
      sum += value;
    }
    final mean = sum / gradientMagnitudes.length;

    var varianceSum = 0.0;
    for (final value in gradientMagnitudes) {
      final diff = value - mean;
      varianceSum += diff * diff;
    }
    final variance = varianceSum / gradientMagnitudes.length;

    return variance;
  }

  /// Prewitt operator variance hesapla (basit ama etkili)
  double _calculatePrewittVariance(img.Image image, int width, int height) {
    final prewittX = [
      [-1, 0, 1],
      [-1, 0, 1],
      [-1, 0, 1],
    ];
    final prewittY = [
      [-1, -1, -1],
      [0, 0, 0],
      [1, 1, 1],
    ];

    final gradientMagnitudes = <double>[];
    final useSampling = (width * height) > 160000;
    final samplingStep = useSampling ? 2 : 1;

    for (int y = 1; y < height - 1; y += samplingStep) {
      for (int x = 1; x < width - 1; x += samplingStep) {
        double gx = 0;
        double gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final gray =
                ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000)
                    .round();
            gx += gray * prewittX[ky + 1][kx + 1];
            gy += gray * prewittY[ky + 1][kx + 1];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy);
        gradientMagnitudes.add(magnitude);
      }
    }

    if (gradientMagnitudes.isEmpty) return 0.0;

    var sum = 0.0;
    for (final value in gradientMagnitudes) {
      sum += value;
    }
    final mean = sum / gradientMagnitudes.length;

    var varianceSum = 0.0;
    for (final value in gradientMagnitudes) {
      final diff = value - mean;
      varianceSum += diff * diff;
    }
    final variance = varianceSum / gradientMagnitudes.length;

    return variance;
  }

  /// Gradient magnitude histogram analizi (blur detection için çok etkili)
  /// Blurlu görüntülerde yüksek gradient değerleri azalır
  double _calculateGradientHistogramScore(
    img.Image image,
    int width,
    int height,
  ) {
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];
    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    final gradientMagnitudes = <double>[];
    final useSampling = (width * height) > 160000;
    final samplingStep = useSampling
        ? 3
        : 2; // Histogram için daha az sampling yeterli

    for (int y = 1; y < height - 1; y += samplingStep) {
      for (int x = 1; x < width - 1; x += samplingStep) {
        double gx = 0;
        double gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final gray =
                ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000)
                    .round();
            gx += gray * sobelX[ky + 1][kx + 1];
            gy += gray * sobelY[ky + 1][kx + 1];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy);
        gradientMagnitudes.add(magnitude);
      }
    }

    if (gradientMagnitudes.isEmpty) return 0.0;

    // Histogram oluştur (10 bin)
    final histogram = List<int>.filled(10, 0);
    final maxMagnitude = gradientMagnitudes.reduce((a, b) => a > b ? a : b);

    if (maxMagnitude == 0) return 0.0;

    for (final magnitude in gradientMagnitudes) {
      final bin = ((magnitude / maxMagnitude) * 9).round().clamp(0, 9);
      histogram[bin]++;
    }

    // Yüksek gradient değerlerinin oranını hesapla (son 3 bin = yüksek gradient)
    // Keskin görüntülerde yüksek gradient değerleri daha fazla olur
    final totalPixels = gradientMagnitudes.length;
    final highGradientCount = histogram[7] + histogram[8] + histogram[9];
    final highGradientRatio = highGradientCount / totalPixels;

    // Normalize et (0.0-1.0 arası) - daha fazla blur tespit için threshold artırıldı
    // Keskin görüntülerde highGradientRatio genelde 0.15-0.30 arası
    // Blurlu görüntülerde 0.05'ten az
    final score = (highGradientRatio * 7.0).clamp(
      0.0,
      1.0,
    ); // 6.0'dan 7.0'a artırıldı (daha fazla blur tespit)
    return score;
  }

  /// Edge density analizi (blurlu görüntülerde edge sayısı azalır)
  double _calculateEdgeDensityScore(img.Image image, int width, int height) {
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];
    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    int edgeCount = 0;
    final useSampling = (width * height) > 160000;
    final samplingStep = useSampling ? 3 : 2;
    final edgeThreshold = 30.0; // Edge threshold

    for (int y = 1; y < height - 1; y += samplingStep) {
      for (int x = 1; x < width - 1; x += samplingStep) {
        double gx = 0;
        double gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final gray =
                ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000)
                    .round();
            gx += gray * sobelX[ky + 1][kx + 1];
            gy += gray * sobelY[ky + 1][kx + 1];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy);
        if (magnitude > edgeThreshold) {
          edgeCount++;
        }
      }
    }

    final totalPixels =
        ((width - 2) / samplingStep) * ((height - 2) / samplingStep);
    if (totalPixels == 0) return 0.0;

    // Edge density (edge sayısı / toplam pixel sayısı)
    final edgeDensity = edgeCount / totalPixels;

    // Normalize et - daha fazla blur tespit için threshold artırıldı
    // Keskin görüntülerde edge density genelde 0.15-0.35 arası
    // Blurlu görüntülerde 0.05'ten az
    final score = (edgeDensity * 4.0).clamp(
      0.0,
      1.0,
    ); // 3.5'ten 4.0'a artırıldı (daha fazla blur tespit)
    return score;
  }

  /// Local variance analizi (bölgesel blur tespiti)
  /// Görüntüyü küçük bloklara bölerek her bloğun variance'ını hesaplar
  double _calculateLocalVarianceScore(img.Image image, int width, int height) {
    const blockSize = 32; // 32x32 bloklar
    final blockVariances = <double>[];

    for (int by = 0; by < height - blockSize; by += blockSize) {
      for (int bx = 0; bx < width - blockSize; bx += blockSize) {
        final blockPixels = <int>[];

        // Bloğun içindeki pixel değerlerini topla
        for (int y = by; y < by + blockSize && y < height; y++) {
          for (int x = bx; x < bx + blockSize && x < width; x++) {
            final pixel = image.getPixel(x, y);
            final gray =
                ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000)
                    .round();
            blockPixels.add(gray);
          }
        }

        if (blockPixels.isEmpty) continue;

        // Bloğun variance'ını hesapla
        var sum = 0;
        for (final value in blockPixels) {
          sum += value;
        }
        final mean = sum / blockPixels.length;

        var varianceSum = 0.0;
        for (final value in blockPixels) {
          final diff = value - mean;
          varianceSum += diff * diff;
        }
        final variance = varianceSum / blockPixels.length;
        blockVariances.add(variance);
      }
    }

    if (blockVariances.isEmpty) return 0.0;

    // Ortalama local variance
    var totalVariance = 0.0;
    for (final variance in blockVariances) {
      totalVariance += variance;
    }
    final avgLocalVariance = totalVariance / blockVariances.length;

    // Normalize et - daha fazla blur tespit için threshold düşürüldü
    // Yüksek local variance = keskin görüntü (detaylar var)
    // Düşük local variance = blurlu görüntü (detaylar yok)
    const maxVariance =
        1300.0; // 1500'den 1300'e düşürüldü (daha fazla blur tespit - 32x32 bloklar için)
    final score = (avgLocalVariance / maxVariance).clamp(0.0, 1.0);
    return score;
  }

  /// Multi-scale blur analysis (farklı boyutlarda analiz)
  double _calculateMultiScaleBlur(img.Image image, int width, int height) {
    // Orijinal boyutta analiz
    final originalScore = _calculateSingleScaleBlur(image, width, height);

    // Yarı boyutta analiz (downscale)
    if (width >= 100 && height >= 100) {
      final halfWidth = width ~/ 2;
      final halfHeight = height ~/ 2;
      final resized = img.copyResize(
        image,
        width: halfWidth,
        height: halfHeight,
      );
      final halfScore = _calculateSingleScaleBlur(
        resized,
        halfWidth,
        halfHeight,
      );

      // İki skorun ortalaması (blurlu görüntüler her ölçekte düşük skor verir)
      return (originalScore + halfScore) / 2.0;
    }

    return originalScore;
  }

  /// Tek ölçekte blur skoru hesapla
  double _calculateSingleScaleBlur(img.Image image, int width, int height) {
    // Basit Laplacian variance
    final laplacianKernel = [
      [-1, -1, -1],
      [-1, 8, -1],
      [-1, -1, -1],
    ];
    final variance = _calculateLaplacianVariance(
      image,
      laplacianKernel,
      width,
      height,
    );
    return _normalizeVariance(variance);
  }

  /// Variance'ı 0-1 arası normalize et (eski versiyon - geriye dönük uyumluluk için)
  double _normalizeVariance(double variance) {
    const minVariance = 0.0;
    const maxVariance = 400.0;
    final clampedVariance = variance.clamp(minVariance, maxVariance);
    final score = clampedVariance / maxVariance;
    return score.clamp(0.0, 1.0);
  }

  /// Gelişmiş variance normalizasyonu (adaptive threshold ve sigmoid mapping)
  /// Farklı operator'ler için farklı threshold'lar kullanır
  /// Daha hassas blur tespiti için threshold'lar düşürüldü
  double _normalizeVarianceAdvanced(double variance, String operatorType) {
    // Operator tipine göre threshold'lar (daha fazla blur tespit için daha da düşürüldü)
    double minVariance, maxVariance;
    switch (operatorType) {
      case 'laplacian':
        minVariance = 0.0;
        maxVariance =
            350.0; // 400'den 350'ye düşürüldü (daha fazla blur tespit)
        break;
      case 'sobel':
        minVariance = 0.0;
        maxVariance = 480.0; // 550'den 480'e düşürüldü (daha fazla blur tespit)
        break;
      case 'scharr':
        minVariance = 0.0;
        maxVariance = 600.0; // 700'den 600'e düşürüldü (daha fazla blur tespit)
        break;
      case 'prewitt':
        minVariance = 0.0;
        maxVariance =
            450.0; // 500'den 450'ye düşürüldü (daha fazla blur tespit)
        break;
      default:
        minVariance = 0.0;
        maxVariance = 350.0; // 400'den 350'ye düşürüldü
    }

    // Clamp variance
    final clampedVariance = variance.clamp(minVariance, maxVariance);

    // Sigmoid mapping (daha fazla blur tespit için k değeri artırıldı)
    // Sigmoid: 1 / (1 + e^(-k*(x - midpoint)))
    // k = steepness, midpoint = maxVariance / 2
    final midpoint = maxVariance / 2.0;
    final k =
        14.0 /
        maxVariance; // Steepness factor artırıldı (12'den 14'e - daha fazla blur tespit)
    final normalized = (clampedVariance - midpoint) * k;
    final sigmoidScore = 1.0 / (1.0 + math.exp(-normalized));

    return sigmoidScore.clamp(0.0, 1.0);
  }

  /// Albüm içinde blurlu fotoğrafları tespit et
  /// Returns: ({blurryPhotos: List<BlurPhoto>, scannedPhotoCount: int})
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
    AppLogger.i('🔍 [BlurDetection] findBlurryPhotosInAlbum başladı: ${album.name} (ID: ${album.id})');

    final blurryPhotos = <BlurPhoto>[];
    // Optimize sayfa boyutu: daha büyük sayfa = daha az I/O = daha hızlı
    const pageSize = 500; // 500 medya/sayfa (memory-safe, daha hızlı I/O)
    const batchSize =
        20; // Paralel işlenecek asset sayısı (performans için optimize edildi)
    int totalProcessed = 0;
    int totalAssets = 0;
    int imageCount = 0;
    final random = math.Random();
    final processingStart = DateTime.now();
    const targetMsPerPhoto = 30; // 1000 foto ≈ 30sn hedef
    int sampleTarget = 0;

    try {
      // Gerçek toplam asset sayısını al
      AppLogger.d('📊 [BlurDetection] Toplam asset sayısı alınıyor...');
      try {
        totalAssets = await album.assetCountAsync;
        AppLogger.d('📊 [BlurDetection] Gerçek toplam asset: $totalAssets');
      } catch (e) {
        // Eğer assetCountAsync çalışmazsa, tahmin et
        AppLogger.w('⚠️ [BlurDetection] assetCountAsync çalışmadı, tahmin ediliyor: $e');
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
      AppLogger.i('🔄 [BlurDetection] Rastgele blur taraması başlıyor (hedef: $sampleTarget fotoğraf, toplam albüm asset: $totalAssets)');
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
                  AppLogger.d('✅ [BlurDetection] Problemli fotoğraf tespit edildi: Asset ${asset.id}, BlurScore=${blurScore.toStringAsFixed(3)} (threshold: $blurThreshold), PixelationScore=${pixelationScore.toStringAsFixed(3)}, isBlurry=$isBlurry, isPixelated=$isPixelated');
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

          // Hedef süreyi yakalamak için adaptif gecikme
          final expectedDurationMs = imageCount * targetMsPerPhoto;
          final elapsedMs = DateTime.now()
              .difference(processingStart)
              .inMilliseconds;
          final remainingMs = expectedDurationMs - elapsedMs;
          if (remainingMs > 3) {
            final delayMs = remainingMs.clamp(3, 80).toInt();
            await Future.delayed(Duration(milliseconds: delayMs));
          }

          // İlerleme callback (throttled - her 50 asset'te bir veya her 500ms'de bir)
          // UI thread'i bloklamamak için callback'leri azalt
          if (progressCallback != null &&
              (totalProcessed % 50 == 0 || imageCount >= sampleTarget)) {
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

          // Her 100 asset'te bir yield (UI thread'e nefes vermek için)
          if (totalProcessed % 100 == 0) {
            await Future.delayed(const Duration(milliseconds: 1));
          }

          // Her 200 asset'te bir memory temizliği (GC'yi tetikle)
          if (totalProcessed % 200 == 0) {
            // Force garbage collection hint
            await Future.delayed(const Duration(milliseconds: 5));
          }

          // Debug log (her 50 fotoğrafta bir)
          if (imageCount % 50 == 0) {
            AppLogger.d('🖼️ [BlurDetection] $imageCount fotoğraf işlendi, ${blurryPhotos.length} problem bulundu...');
          }
        }

        if (imageCount >= sampleTarget) {
          break;
        }
      }

      // Blur score'a göre sırala (en blurludan en az blurluya)
      blurryPhotos.sort((a, b) => a.blurScore.compareTo(b.blurScore));

      AppLogger.i('✅ [BlurDetection] ${blurryPhotos.length} blurlu fotoğraf bulundu (${album.name})');
      AppLogger.i('📊 [BlurDetection] Toplam scan edilen fotoğraf: $imageCount');

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
  /// Returns: ({results: Map<String, List<BlurPhoto>>, scannedPhotoCount: int, targetCount: int})
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
    AppLogger.i('🔍 [BlurDetection] findBlurryPhotosInAlbums başladı - ${albums.length} albüm');
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
        AppLogger.w('⚠️ [BlurDetection] Scan limit aşıldı: $totalScannedPhotos/$maxScanLimit fotoğraf scan edildi');
        break;
      }

      final album = albums[i];
      AppLogger.d('📁 [BlurDetection] Albüm ${i + 1}/${albums.length}: ${album.name} (ID: ${album.id})');

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
        AppLogger.w('⚠️ [BlurDetection] Scan limit aşıldı: $totalScannedPhotos/$maxScanLimit fotoğraf scan edildi');
        break;
      }
    }

    AppLogger.i('🎉 [BlurDetection] Tüm albümler taranı! Toplam sonuç: ${results.length} albüm, Toplam scan edilen: $totalScannedPhotos fotoğraf');
    return (
      results: results,
      scannedPhotoCount: totalScannedPhotos,
      targetCount: totalTargetPhotos == 0
          ? totalScannedPhotos
          : totalTargetPhotos,
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart' as pm;
import '../models/blur_photo.dart';

/// Blur detection servisi - Laplacian variance kullanarak
class BlurDetectionService {
  /// Pixelation score hesapla (0.0 = pixelleşmiş değil, 1.0 = çok pixelleşmiş)
  /// Block-based method kullanır - pixelleşmiş görüntülerde benzer renklerin bloklar halinde gruplanması
  /// Optimize edilmiş: daha küçük thumbnail, daha düşük kalite
  Future<double> calculatePixelationScore(pm.AssetEntity asset) async {
    try {
      // Optimize edilmiş thumbnail: daha küçük boyut ve düşük kalite (pixelation tespiti için yeterli)
      final thumbnail = await asset.thumbnailDataWithSize(
        const pm.ThumbnailSize(150, 150), // 200x200'den 150x150'e düşürüldü
        quality: 70, // 85'ten 70'e düşürüldü
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
      // Optimize: daha büyük bloklar = daha hızlı hesaplama
      final blockSize = 6; // 6x6 bloklar (4x4'ten daha hızlı, yeterince doğru)
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
  /// Gelişmiş multi-method approach: Laplacian + Sobel + Scharr + Prewitt + Gradient Histogram + Edge Density + Local Variance
  /// Performans optimizasyonları: adaptive sampling, early exit, conditional multi-scale
  Future<double> calculateBlurScore(pm.AssetEntity asset) async {
    try {
      // Thumbnail boyutu: 400x400 (daha doğru blur detection için artırıldı)
      final thumbnail = await asset.thumbnailDataWithSize(
        const pm.ThumbnailSize(400, 400),
        quality: 85, // Kalite ve hız dengesi (80'den 85'e artırıldı)
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

      final width = grayImage.width;
      final height = grayImage.height;

      // 1. Gelişmiş Laplacian variance (8-connected kernel) - İlk kontrol (en hızlı)
      final laplacianKernel8 = [
        [-1, -1, -1],
        [-1, 8, -1],
        [-1, -1, -1],
      ];
      final laplacianVariance = _calculateLaplacianVariance(
        grayImage,
        laplacianKernel8,
        width,
        height,
      );
      final laplacianScore = _normalizeVarianceAdvanced(laplacianVariance, 'laplacian');

      // Early exit: Eğer Laplacian score çok yüksekse (keskin görünüyorsa),
      // diğer pahalı hesaplamaları atla (performans optimizasyonu)
      const earlyExitThreshold = 0.85; // 0.85'ten yüksekse keskin kabul et
      if (laplacianScore > earlyExitThreshold) {
        // Keskin görünüyor, diğer hesaplamaları atla
        debugPrint(
          '   ✅ [BlurDetection] Early exit: Asset ${asset.id}, LaplacianScore=${laplacianScore.toStringAsFixed(3)} (KESKIN)',
        );
        return laplacianScore;
      }

      // 2. Sobel edge detection variance (kenar tespiti)
      final sobelVariance = _calculateSobelVariance(grayImage, width, height);
      final sobelScore = _normalizeVarianceAdvanced(sobelVariance, 'sobel');

      // 3. Scharr operator (Sobel'den daha hassas, özellikle diagonal edge'ler için)
      final scharrVariance = _calculateScharrVariance(grayImage, width, height);
      final scharrScore = _normalizeVarianceAdvanced(scharrVariance, 'scharr');

      // 4. Prewitt operator (basit ama etkili)
      final prewittVariance = _calculatePrewittVariance(grayImage, width, height);
      final prewittScore = _normalizeVarianceAdvanced(prewittVariance, 'prewitt');

      // 5. Gradient magnitude histogram analizi (blur detection için çok etkili)
      final gradientHistogramScore = _calculateGradientHistogramScore(grayImage, width, height);

      // 6. Edge density analizi (blurlu görüntülerde edge sayısı azalır)
      final edgeDensityScore = _calculateEdgeDensityScore(grayImage, width, height);

      // 7. Local variance analizi (bölgesel blur tespiti)
      final localVarianceScore = _calculateLocalVarianceScore(grayImage, width, height);

      // 8. Multi-scale analysis - Sadece çok şüpheli durumlarda
      double multiScaleScore = 0.0;
      final avgBasicScore = (laplacianScore + sobelScore) / 2.0;
      if (avgBasicScore < 0.5) {
        // Temel skorlar düşük, multi-scale analiz yap
        multiScaleScore = _calculateMultiScaleBlur(grayImage, width, height);
      } else {
        // Multi-scale'e gerek yok, ortalama skor kullan
        multiScaleScore = avgBasicScore;
      }

      // Kombine skor: ağırlıklı ortalama (gelişmiş algoritma)
      // Laplacian: %25, Sobel: %15, Scharr: %15, Prewitt: %10, Gradient Histogram: %15, Edge Density: %10, Local Variance: %5, Multi-scale: %5
      final combinedScore = (laplacianScore * 0.25) + 
                           (sobelScore * 0.15) + 
                           (scharrScore * 0.15) +
                           (prewittScore * 0.10) +
                           (gradientHistogramScore * 0.15) +
                           (edgeDensityScore * 0.10) +
                           (localVarianceScore * 0.05) +
                           (multiScaleScore * 0.05);

      // Final score'u clamp et
      final finalScore = combinedScore.clamp(0.0, 1.0);

      // Debug: Tüm sonuçları logla (sadece blur tespit edildiğinde veya çok keskin olduğunda)
      if (finalScore < 0.4 || finalScore > 0.9) {
      debugPrint(
          '   📊 [BlurDetection] Asset ${asset.id}: L=${laplacianScore.toStringAsFixed(3)}, S=${sobelScore.toStringAsFixed(3)}, Sch=${scharrScore.toStringAsFixed(3)}, P=${prewittScore.toStringAsFixed(3)}, GH=${gradientHistogramScore.toStringAsFixed(3)}, ED=${edgeDensityScore.toStringAsFixed(3)}, LV=${localVarianceScore.toStringAsFixed(3)}, MS=${multiScaleScore.toStringAsFixed(3)}, Final=${finalScore.toStringAsFixed(3)}',
      );
      }
      
      if (finalScore < 0.3) {
        debugPrint(
          '   🔴 [BlurDetection] BLURLU TESPİT EDİLDİ: Asset ${asset.id}, FinalScore=${finalScore.toStringAsFixed(3)}',
        );
      }

      return finalScore;
    } catch (e) {
      debugPrint('   ⚠️ [BlurDetection] Blur score hesaplama hatası (ID: ${asset.id}): $e');
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
            final gray = ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000).round();
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
            final gray = ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000).round();
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
            final gray = ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000).round();
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
  double _calculateGradientHistogramScore(img.Image image, int width, int height) {
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
    final samplingStep = useSampling ? 3 : 2; // Histogram için daha az sampling yeterli

    for (int y = 1; y < height - 1; y += samplingStep) {
      for (int x = 1; x < width - 1; x += samplingStep) {
        double gx = 0;
        double gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final gray = ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000).round();
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

    // Normalize et (0.0-1.0 arası)
    // Keskin görüntülerde highGradientRatio genelde 0.15-0.30 arası
    // Blurlu görüntülerde 0.05'ten az
    final score = (highGradientRatio * 5.0).clamp(0.0, 1.0);
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
            final gray = ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000).round();
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

    final totalPixels = ((width - 2) / samplingStep) * ((height - 2) / samplingStep);
    if (totalPixels == 0) return 0.0;

    // Edge density (edge sayısı / toplam pixel sayısı)
    final edgeDensity = edgeCount / totalPixels;

    // Normalize et
    // Keskin görüntülerde edge density genelde 0.15-0.35 arası
    // Blurlu görüntülerde 0.05'ten az
    final score = (edgeDensity * 3.0).clamp(0.0, 1.0);
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
            final gray = ((299 * pixel.r + 587 * pixel.g + 114 * pixel.b) ~/ 1000).round();
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

    // Normalize et
    // Yüksek local variance = keskin görüntü (detaylar var)
    // Düşük local variance = blurlu görüntü (detaylar yok)
    const maxVariance = 2000.0; // 32x32 bloklar için
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
      final resized = img.copyResize(image, width: halfWidth, height: halfHeight);
      final halfScore = _calculateSingleScaleBlur(resized, halfWidth, halfHeight);
      
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
    final variance = _calculateLaplacianVariance(image, laplacianKernel, width, height);
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
  double _normalizeVarianceAdvanced(double variance, String operatorType) {
    // Operator tipine göre threshold'lar (400x400 thumbnail için optimize edildi)
    double minVariance, maxVariance;
    switch (operatorType) {
      case 'laplacian':
        minVariance = 0.0;
        maxVariance = 600.0; // 400x400 için artırıldı
        break;
      case 'sobel':
        minVariance = 0.0;
        maxVariance = 800.0; // Sobel genelde daha yüksek değerler verir
        break;
      case 'scharr':
        minVariance = 0.0;
        maxVariance = 1000.0; // Scharr daha hassas, daha yüksek değerler
        break;
      case 'prewitt':
        minVariance = 0.0;
        maxVariance = 700.0;
        break;
      default:
        minVariance = 0.0;
        maxVariance = 500.0;
    }

    // Clamp variance
    final clampedVariance = variance.clamp(minVariance, maxVariance);
    
    // Sigmoid mapping (daha doğru sonuçlar için)
    // Sigmoid: 1 / (1 + e^(-k*(x - midpoint)))
    // k = steepness, midpoint = maxVariance / 2
    final midpoint = maxVariance / 2.0;
    final k = 8.0 / maxVariance; // Steepness factor
    final normalized = (clampedVariance - midpoint) * k;
    final sigmoidScore = 1.0 / (1.0 + math.exp(-normalized));
    
    return sigmoidScore.clamp(0.0, 1.0);
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
    const pageSize = 1000; // 1000 medya/sayfa (memory-safe, daha hızlı I/O)
    const batchSize = 40; // Paralel işlenecek asset sayısı (blur detection için) - 20'den 40'a artırıldı
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
              
              // Debug: Tespit edilen problemli fotoğrafları logla
              if (isBlurry || isPixelated) {
                debugPrint(
                  '   ✅ [BlurDetection] Problemli fotoğraf tespit edildi: Asset ${asset.id}, BlurScore=${blurScore.toStringAsFixed(3)} (threshold: $blurThreshold), PixelationScore=${pixelationScore.toStringAsFixed(3)}, isBlurry=$isBlurry, isPixelated=$isPixelated',
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


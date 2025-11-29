import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Isolate içinde çalışacak blur analizi için data class
class BlurAnalysisTask {
  BlurAnalysisTask(this.imageBytes);
  final List<int> imageBytes;
}

/// Isolate içinde çalışacak blur analizi sonucu
class BlurAnalysisResult {
  BlurAnalysisResult({required this.blurScore, required this.pixelationScore});
  final double blurScore;
  final double pixelationScore;
}

/// Isolate içinde blur score hesapla (Task 2 & 3: Basit Laplacian variance)
/// Task 3: Basit ama hızlı metrik kullan
Future<BlurAnalysisResult> analyzeBlurInIsolate(List<int> imageBytes) {
  return Isolate.run(() {
    try {
      // Image decode et
      final image = img.decodeImage(Uint8List.fromList(imageBytes));
      if (image == null) {
        return BlurAnalysisResult(blurScore: 0.5, pixelationScore: 0.0);
      }

      // 128x128'e resize et (zaten küçük ama emin olmak için)
      final small = _downscaleForAnalysis(image);

      // Gri tonlamaya çevir
      final gray = img.grayscale(small);

      // Basit Laplacian variance hesapla (Task 3)
      final blurScore = _computeBlurScore(gray);

      // Pixelation score hesapla
      final pixelationScore = _computePixelationScore(small);

      return BlurAnalysisResult(
        blurScore: blurScore,
        pixelationScore: pixelationScore,
      );
    } catch (e) {
      // Hata durumunda orta değer döndür
      return BlurAnalysisResult(blurScore: 0.5, pixelationScore: 0.0);
    }
  });
}

/// 128x128'e resize et (Task 1)
img.Image _downscaleForAnalysis(img.Image original) {
  const target = 128;
  if (original.width <= target && original.height <= target) {
    return original;
  }
  return img.copyResize(
    original,
    width: target,
    height: target,
    interpolation: img.Interpolation.average,
  );
}

/// Basit Laplacian variance ile blur score hesapla (Task 3)
/// Gözle görülen blur için "mükemmel ML modeli" değil, basit ama hızlı bir metrik yeterli
double _computeBlurScore(img.Image gray) {
  // Basit Laplacian kernel
  final kernel = [
    [0, 1, 0],
    [1, -4, 1],
    [0, 1, 0],
  ];

  double sum = 0;
  double sumSq = 0;
  int count = 0;

  final width = gray.width;
  final height = gray.height;

  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      int conv = 0;
      for (var ky = -1; ky <= 1; ky++) {
        for (var kx = -1; kx <= 1; kx++) {
          final p = gray.getPixel(x + kx, y + ky);
          final v = img.getLuminance(p);
          conv += (v * kernel[ky + 1][kx + 1]).round();
        }
      }
      sum += conv;
      sumSq += conv * conv;
      count++;
    }
  }

  if (count == 0) return 0.5;

  // Variance = E[X²] - E[X]²
  final mean = sum / count;
  final variance = (sumSq / count) - (mean * mean);

  // Normalize et (0.0-1.0 arası)
  // Yüksek variance = keskin görüntü
  // Düşük variance = blurlu görüntü
  const maxVariance = 350.0; // Deneyerek ayarlanabilir
  final score = (variance / maxVariance).clamp(0.0, 1.0);
  return score;
}

/// Pixelation score hesapla (basitleştirilmiş)
double _computePixelationScore(img.Image image) {
  try {
    final blockSize = 6;
    final width = image.width;
    final height = image.height;

    int blockCount = 0;
    double totalVariance = 0.0;

    for (int by = 0; by < height - blockSize; by += blockSize) {
      for (int bx = 0; bx < width - blockSize; bx += blockSize) {
        blockCount++;

        final colors = <int>[];
        for (int y = by; y < by + blockSize && y < height; y++) {
          for (int x = bx; x < bx + blockSize && x < width; x++) {
            final pixel = image.getPixel(x, y);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();
            final color = (r << 16) | (g << 8) | b;
            colors.add(color);
          }
        }

        if (colors.isNotEmpty) {
          final mean = colors.reduce((a, b) => a + b) / colors.length;
          final variance =
              colors
                  .map((c) => (c - mean) * (c - mean))
                  .reduce((a, b) => a + b) /
              colors.length;
          totalVariance += variance;
        }
      }
    }

    if (blockCount == 0) return 0.0;

    final avgVariance = totalVariance / blockCount;
    const minVariance = 0.0;
    const maxVariance = 50000.0;

    final normalizedVariance =
        (avgVariance - minVariance) / (maxVariance - minVariance);
    final pixelationScore = (1.0 - normalizedVariance.clamp(0.0, 1.0));

    return pixelationScore;
  } catch (e) {
    return 0.0;
  }
}

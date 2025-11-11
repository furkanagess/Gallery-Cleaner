import 'package:photo_manager/photo_manager.dart' as pm;

/// Blurlu veya pixelleşmiş fotoğraf modeli
class BlurPhoto {
  final pm.AssetEntity asset;
  final double blurScore; // 0.0 - 1.0 (0.0 = çok blurlu, 1.0 = keskin)
  final double pixelationScore; // 0.0 - 1.0 (0.0 = pixelleşmiş değil, 1.0 = çok pixelleşmiş)
  final String albumName;
  final double estimatedSizeMB;

  const BlurPhoto({
    required this.asset,
    required this.blurScore,
    this.pixelationScore = 0.0,
    required this.albumName,
    required this.estimatedSizeMB,
  });

  /// Blurlu mu? (blurScore < threshold)
  bool isBlurry({double threshold = 0.3}) {
    return blurScore < threshold;
  }

  /// Pixelleşmiş mi? (pixelationScore > threshold)
  bool isPixelated({double threshold = 0.5}) {
    return pixelationScore > threshold;
  }

  /// Problem var mı? (blurlu veya pixelleşmiş)
  bool hasProblem({double blurThreshold = 0.3, double pixelationThreshold = 0.5}) {
    return isBlurry(threshold: blurThreshold) || isPixelated(threshold: pixelationThreshold);
  }

  /// Problem tipi
  String get problemType {
    if (isPixelated()) {
      if (isBlurry()) {
        return 'Blurlu ve Pixelleşmiş';
      }
      return 'Pixelleşmiş';
    }
    if (isBlurry()) {
      return 'Blurlu';
    }
    return 'Keskin';
  }

  /// Blur seviyesi metni
  String get blurLevel {
    if (blurScore < 0.2) return 'Çok Blurlu';
    if (blurScore < 0.3) return 'Blurlu';
    if (blurScore < 0.5) return 'Biraz Blurlu';
    if (blurScore < 0.7) return 'Orta';
    return 'Keskin';
  }

  /// Pixelation seviyesi metni
  String get pixelationLevel {
    if (pixelationScore < 0.3) return 'Keskin';
    if (pixelationScore < 0.5) return 'Biraz Pixelleşmiş';
    if (pixelationScore < 0.7) return 'Pixelleşmiş';
    return 'Çok Pixelleşmiş';
  }
}



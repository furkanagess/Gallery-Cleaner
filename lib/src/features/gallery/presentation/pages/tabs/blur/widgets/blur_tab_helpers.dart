import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../../../../../../../../l10n/app_localizations.dart';

/// Tahmini scan süresini hesapla (saniye cinsinden) - Static versiyon
/// Estimated scan duration ve limit kontrolü
/// Returns: ({estimatedSeconds: int, totalPhotoCount: int, hasLimitWarning: bool})
Future<({int estimatedSeconds, int totalPhotoCount, bool hasLimitWarning})>
    estimateBlurScanDuration(
  List<pm.AssetPathEntity> albums,
) async {
  try {
    int totalPhotoCount = 0;

    for (final album in albums) {
      try {
        final count = await album.assetCountAsync;
        totalPhotoCount += count;
      } catch (e) {
        // Hata durumunda tahmin et
        debugPrint(
          '⚠️ [BlurTab] Albüm sayısı alınamadı: ${album.name}, $e',
        );
        // Ortalama albüm boyutu tahmini
        totalPhotoCount += 500;
      }
    }

    // 1000 fotoğraf limit kontrolü
    const maxPhotos = 1000;
    final hasLimitWarning = totalPhotoCount > maxPhotos;

    // Limit varsa 1000 fotoğraf için hesapla
    final effectivePhotoCount = hasLimitWarning ? maxPhotos : totalPhotoCount;

    // Fotoğraf başına ortalama işleme süresi (saniye)
    // Blur detection: ~0.15 saniye/fotoğraf (400x400 thumbnail + çoklu analiz)
    const secondsPerPhoto = 0.15;

    // Toplam tahmini süre (saniye) - limit varsa 1000 fotoğraf için
    final estimatedSeconds = (effectivePhotoCount * secondsPerPhoto).round();

    // Minimum 5 saniye, maksimum 600 saniye (10 dakika)
    return (
      estimatedSeconds: estimatedSeconds.clamp(5, 600),
      totalPhotoCount: totalPhotoCount,
      hasLimitWarning: hasLimitWarning,
    );
  } catch (e) {
    debugPrint('⚠️ [BlurTab] Tahmini süre hesaplanamadı: $e');
    return (estimatedSeconds: 30, totalPhotoCount: 0, hasLimitWarning: false);
  }
}

/// Süreyi formatla (örn: "~30 saniye", "~2 dakika") - Static versiyon
String formatEstimatedTime(int seconds, AppLocalizations l10n) {
  if (seconds < 60) {
    return l10n.estimatedTimeSeconds(seconds);
  } else {
    final minutes = (seconds / 60).round();
    return l10n.estimatedTimeMinutes(minutes);
  }
}


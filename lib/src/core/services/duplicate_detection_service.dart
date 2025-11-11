import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../models/duplicate_photo.dart';

/// Performanslı duplicate detection servisi
class DuplicateDetectionService {
  /// Thumbnail hash'i hesapla (hızlı ve memory-efficient)
  Future<String> _calculateThumbnailHash(
    pm.AssetEntity asset, {
    int thumbnailSize = 128,
  }) async {
    try {
      // Küçük thumbnail al (128x128 yeterli)
      final thumbnail = await asset.thumbnailDataWithSize(
        pm.ThumbnailSize(thumbnailSize, thumbnailSize),
        quality: 75,
      );

      if (thumbnail == null || thumbnail.isEmpty) {
        debugPrint('   ⚠️ [DuplicateDetection] Thumbnail alınamadı (ID: ${asset.id}), fallback kullanılıyor');
        // Thumbnail alınamazsa, dosya boyutu ve boyutları kullan
        return _fallbackHash(asset);
      }

      // MD5 hash hesapla (hızlı)
      final digest = md5.convert(thumbnail);
      final hash = digest.toString();
      return hash;
    } catch (e) {
      debugPrint('   ⚠️ [DuplicateDetection] Hash hesaplama hatası (ID: ${asset.id}): $e');
      return _fallbackHash(asset);
    }
  }

  /// Fallback hash (thumbnail alınamazsa)
  String _fallbackHash(pm.AssetEntity asset) {
    try {
    // Dosya boyutu, genişlik, yükseklik ve oluşturma tarihini kullan
    final size = asset.size;
      final width = asset.width;
      final height = asset.height;
      final createDateTime = asset.createDateTime.millisecondsSinceEpoch;
      final data = '${width}_${height}_${size.width}_${size.height}_$createDateTime';
    return md5.convert(data.codeUnits).toString();
    } catch (e) {
      debugPrint('   ⚠️ [DuplicateDetection] Fallback hash hatası: $e');
      // Son çare: sadece ID kullan
      return md5.convert(asset.id.codeUnits).toString();
    }
  }

  /// Albüm içinde duplicate fotoğrafları tespit et
  /// 
  /// [album] - Taranacak albüm
  /// [progressCallback] - İlerleme callback'i (0.0 - 1.0, processedCount, totalCount)
  /// [shouldCancel] - İptal kontrolü callback'i
  /// [isPremium] - Premium kullanıcı mı?
  /// Returns: ({duplicateGroups: List<DuplicatePhotoGroup>, scannedPhotoCount: int})
  Future<({List<DuplicatePhotoGroup> duplicateGroups, int scannedPhotoCount})> findDuplicatesInAlbum(
    pm.AssetPathEntity album, {
    void Function(double progress, int processedCount, int totalCount)? progressCallback,
    bool Function()? shouldCancel,
    bool isPremium = false,
    int maxScanLimit = 999999999,
  }) async {
    debugPrint('🔍 [DuplicateDetection] findDuplicatesInAlbum başladı: ${album.name} (ID: ${album.id})');

    final hashMap = <String, List<pm.AssetEntity>>{};
    // Optimize sayfa boyutu: daha büyük sayfa = daha az I/O = daha hızlı
    const pageSize = 500; // 500 medya/sayfa (memory-safe, hızlı)
    const batchSize = 50; // Paralel işlenecek asset sayısı
    int page = 0;
    int totalProcessed = 0;
    int totalAssets = 0;
    int imageCount = 0;

    try {
      // Gerçek toplam asset sayısını al
      debugPrint('📊 [DuplicateDetection] Toplam asset sayısı alınıyor...');
      try {
        totalAssets = await album.assetCountAsync;
        debugPrint('📊 [DuplicateDetection] Gerçek toplam asset: $totalAssets');
      } catch (e) {
        // Eğer assetCountAsync çalışmazsa, tahmin et
        debugPrint('⚠️ [DuplicateDetection] assetCountAsync çalışmadı, tahmin ediliyor: $e');
        final firstPage = await album.getAssetListPaged(page: 0, size: pageSize);
        totalAssets = firstPage.length >= pageSize ? firstPage.length * 10 : firstPage.length;
        totalAssets = totalAssets > 0 ? totalAssets : 1000;
        debugPrint('📊 [DuplicateDetection] Tahmini toplam asset: $totalAssets');
      }

      debugPrint('💎 [DuplicateDetection] Premium durumu: $isPremium');
      debugPrint('📊 [DuplicateDetection] Max scan limit: $maxScanLimit');

      // Kalan scan hakkı kadar fotoğraf scan et
      final int maxImagesToProcess = isPremium ? 999999999 : maxScanLimit;
      
      // Toplam sayıyı maxImagesToProcess ile sınırla (premium değilse)
      if (!isPremium && totalAssets > maxImagesToProcess) {
        totalAssets = maxImagesToProcess;
        debugPrint('📊 [DuplicateDetection] Toplam sayı limit ile sınırlandı: $totalAssets');
      }

      debugPrint('🔄 [DuplicateDetection] Assetler hashleniyor (hızlı mod)...');
      // Tüm asset'leri hash'le
      while (true) {
        // İptal kontrolü
        if (shouldCancel != null && shouldCancel()) {
          debugPrint('   🛑 [DuplicateDetection] Tarama iptal edildi');
          // Mevcut sonuçları döndürmek için duplicate grupları oluştur
          final cancelDuplicateGroups = <DuplicatePhotoGroup>[];
          for (final entry in hashMap.entries) {
            if (entry.value.length > 1) {
              double totalSizeMB = 0;
              for (final asset in entry.value) {
                try {
                  final size = asset.size;
                  final estimatedBytes = size.width * size.height * 3;
                  totalSizeMB += estimatedBytes / (1024 * 1024);
                } catch (_) {}
              }
              cancelDuplicateGroups.add(DuplicatePhotoGroup(
                hash: entry.key,
                assets: entry.value,
                totalSizeMB: totalSizeMB,
                albumName: album.name,
              ));
            }
          }
          cancelDuplicateGroups.sort((a, b) => b.totalSizeMB.compareTo(a.totalSizeMB));
          return (duplicateGroups: cancelDuplicateGroups, scannedPhotoCount: imageCount);
        }

        // Premium olmayan kullanıcılar için limit kontrolü
        if (!isPremium && imageCount >= maxImagesToProcess) {
          debugPrint(
            '   ⚠️ [DuplicateDetection] Premium olmayan kullanıcı için limit aşıldı: $imageCount/$maxImagesToProcess fotoğraf işlendi',
          );
          break;
        }

        final assets = await album.getAssetListPaged(page: page, size: pageSize);
        
        if (assets.isEmpty) {
          debugPrint('   ✅ [DuplicateDetection] Tüm sayfalar işlendi (boş sayfa)');
          break;
        }

        // Sadece image asset'leri filtrele
        final imageAssets = assets.where((a) => a.type == pm.AssetType.image).toList();
        
        // Paralel batch processing: asset'leri batch'ler halinde işle
        for (var i = 0; i < imageAssets.length; i += batchSize) {
          // İptal kontrolü (her batch'te)
          if (shouldCancel != null && shouldCancel()) {
            debugPrint('   🛑 [DuplicateDetection] Tarama iptal edildi');
            break;
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

                final hash = await _calculateThumbnailHash(asset);
                return (hash: hash, asset: asset);
              } catch (e) {
                debugPrint('   ⚠️ [DuplicateDetection] Hash hesaplama hatası: $e');
                return null;
              }
            }),
          );

          // Batch sonuçlarını hashMap'e ekle
          for (final result in batchResults) {
            if (result != null) {
              hashMap.putIfAbsent(result.hash, () => []).add(result.asset);
            }
          }

          imageCount += batch.length;
          totalProcessed += batch.length;

          // İlerleme callback (her batch'te)
          if (progressCallback != null && totalAssets > 0) {
            final progress = (totalProcessed / totalAssets).clamp(0.0, 1.0);
            progressCallback(progress, totalProcessed, totalAssets);
          }

          // Debug log (her 100 fotoğrafta bir)
          if (imageCount % 100 == 0) {
            debugPrint('   🖼️ [DuplicateDetection] $imageCount fotoğraf işlendi, ${hashMap.length} benzersiz hash...');
          }
        }

        // Premium olmayan kullanıcılar için limit kontrolü (loop dışında)
        if (!isPremium && imageCount >= maxImagesToProcess) {
          break;
        }

        if (assets.length < pageSize) {
          debugPrint('   ✅ [DuplicateDetection] Son sayfa işlendi');
          break;
        }
        page++;
      }

      debugPrint('📊 [DuplicateDetection] Hash işleme tamamlandı:');
      debugPrint('   - Toplam işlenen: $totalProcessed');
      debugPrint('   - Toplam fotoğraf: $imageCount');
      debugPrint('   - Benzersiz hash: ${hashMap.length}');
      debugPrint(
        '📊 [DuplicateDetection] Toplam scan edilen fotoğraf: $imageCount',
      );

      // Duplicate grupları oluştur (2 veya daha fazla aynı hash)
      debugPrint('🔍 [DuplicateDetection] Duplicate grupları oluşturuluyor...');
      final duplicateGroups = <DuplicatePhotoGroup>[];
      int duplicateHashCount = 0;
      
      for (final entry in hashMap.entries) {
        if (entry.value.length > 1) {
          duplicateHashCount++;
          // Toplam boyutu hesapla
          double totalSizeMB = 0;
          for (final asset in entry.value) {
            try {
              final size = asset.size;
              final estimatedBytes = size.width * size.height * 3;
              totalSizeMB += estimatedBytes / (1024 * 1024);
            } catch (_) {
              // Hata olsa bile devam et
            }
          }

          duplicateGroups.add(DuplicatePhotoGroup(
            hash: entry.key,
            assets: entry.value,
            totalSizeMB: totalSizeMB,
            albumName: album.name,
          ));
        }
      }

      debugPrint('📊 [DuplicateDetection] Duplicate analizi:');
      debugPrint('   - Duplicate hash sayısı: $duplicateHashCount');
      debugPrint('   - Duplicate grup sayısı: ${duplicateGroups.length}');

      // Boyuta göre sırala (büyükten küçüğe)
      duplicateGroups.sort((a, b) => b.totalSizeMB.compareTo(a.totalSizeMB));

      debugPrint(
        '✅ [DuplicateDetection] ${duplicateGroups.length} duplicate grup bulundu (${album.name})',
      );
      debugPrint(
        '📊 [DuplicateDetection] Toplam scan edilen fotoğraf: $imageCount',
      );

      return (duplicateGroups: duplicateGroups, scannedPhotoCount: imageCount);
    } catch (e, stackTrace) {
      debugPrint('❌ [DuplicateDetection] Hata: $e');
      debugPrint('❌ [DuplicateDetection] Stack trace: $stackTrace');
      return (duplicateGroups: <DuplicatePhotoGroup>[], scannedPhotoCount: 0);
    }
  }

  /// Birden fazla albümde duplicate fotoğrafları tespit et
  /// Returns: ({results: Map<String, List<DuplicatePhotoGroup>>, scannedPhotoCount: int})
  Future<({Map<String, List<DuplicatePhotoGroup>> results, int scannedPhotoCount})> findDuplicatesInAlbums(
    List<pm.AssetPathEntity> albums, {
    void Function(String albumName, double progress, int processedCount, int totalCount)? progressCallback,
    bool Function()? shouldCancel,
    bool isPremium = false,
    int maxScanLimit = 999999999,
  }) async {
    debugPrint('🔍 [DuplicateDetection] findDuplicatesInAlbums başladı - ${albums.length} albüm');
    final results = <String, List<DuplicatePhotoGroup>>{};
    int totalScannedPhotos = 0;

    for (int i = 0; i < albums.length; i++) {
      // İptal kontrolü
      if (shouldCancel != null && shouldCancel()) {
        debugPrint('   🛑 [DuplicateDetection] Tarama iptal edildi');
        return (results: results, scannedPhotoCount: totalScannedPhotos);
      }

      // Kalan scan limit kontrolü (premium değilse)
      if (!isPremium && totalScannedPhotos >= maxScanLimit) {
        debugPrint(
          '   ⚠️ [DuplicateDetection] Scan limit aşıldı: $totalScannedPhotos/$maxScanLimit fotoğraf scan edildi',
        );
        break;
      }

      final album = albums[i];
      debugPrint('📁 [DuplicateDetection] Albüm ${i + 1}/${albums.length}: ${album.name} (ID: ${album.id})');

      // Kalan scan limit'i hesapla
      final remainingScanLimit = isPremium 
          ? 999999999 
          : (maxScanLimit - totalScannedPhotos).clamp(0, maxScanLimit);

      debugPrint('🔍 [DuplicateDetection] findDuplicatesInAlbum çağrılıyor...');
      final albumResult = await findDuplicatesInAlbum(
        album,
        progressCallback: (albumProgress, albumProcessedCount, albumTotalCount) {
          // Genel ilerleme hesapla (tüm albümler için)
          final overallProcessedCount = totalScannedPhotos + albumProcessedCount;
          final overallTotalCount = totalScannedPhotos + albumTotalCount;
          final overallProgress = albums.length > 1 
              ? (i + albumProgress) / albums.length 
              : albumProgress;
          
          debugPrint('📊 [DuplicateDetection] Albüm ilerlemesi: $albumProgress ($albumProcessedCount/$albumTotalCount) -> Genel: $overallProgress ($overallProcessedCount/$overallTotalCount)');
          if (progressCallback != null) {
            progressCallback(album.name, overallProgress, overallProcessedCount, overallTotalCount);
          }
        },
        shouldCancel: shouldCancel,
        isPremium: isPremium,
        maxScanLimit: remainingScanLimit,
      );

      final duplicates = albumResult.duplicateGroups;
      final albumScannedCount = albumResult.scannedPhotoCount;

      // İptal edildiyse sonuçları döndür
      if (shouldCancel != null && shouldCancel()) {
        debugPrint('   🛑 [DuplicateDetection] Tarama iptal edildi');
        return (results: results, scannedPhotoCount: totalScannedPhotos);
      }

      totalScannedPhotos += albumScannedCount;

      debugPrint('✅ [DuplicateDetection] Albüm taraması tamamlandı: ${album.name} - ${duplicates.length} duplicate grup bulundu');

      if (duplicates.isNotEmpty) {
        results[album.name] = duplicates;
        debugPrint('   💾 [DuplicateDetection] Sonuçlar kaydedildi');
      } else {
        debugPrint('   ⚠️ [DuplicateDetection] Duplicate bulunamadı, sonuçlar kaydedilmedi');
      }

      // Scan limit aşıldıysa dur
      if (!isPremium && totalScannedPhotos >= maxScanLimit) {
        debugPrint(
          '   ⚠️ [DuplicateDetection] Scan limit aşıldı: $totalScannedPhotos/$maxScanLimit fotoğraf scan edildi',
        );
        break;
      }
    }

    debugPrint('🎉 [DuplicateDetection] Tüm albümler taranı! Toplam sonuç: ${results.length} albüm, Toplam scan edilen: $totalScannedPhotos fotoğraf');
    return (results: results, scannedPhotoCount: totalScannedPhotos);
  }
}


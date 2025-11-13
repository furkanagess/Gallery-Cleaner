import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart' as pm;
import '../models/duplicate_photo.dart';

/// Performanslı duplicate detection servisi
/// Gelişmiş algoritma: Perceptual hash (dHash) + MD5 + Histogram comparison
class DuplicateDetectionService {
  /// Gelişmiş hash hesapla: Perceptual hash (dHash) + MD5 kombinasyonu
  /// dHash: Benzer görüntüleri tespit eder (küçük farklılıkları tolere eder)
  /// MD5: Tam eşleşmeleri tespit eder
  Future<String> _calculateThumbnailHash(
    pm.AssetEntity asset, {
    int thumbnailSize = 256,
  }) async {
    try {
      // Daha büyük thumbnail al (daha doğru tespit için)
      final thumbnail = await asset.thumbnailDataWithSize(
        pm.ThumbnailSize(thumbnailSize, thumbnailSize),
        quality: 85,
      );

      if (thumbnail == null || thumbnail.isEmpty) {
        debugPrint('   ⚠️ [DuplicateDetection] Thumbnail alınamadı (ID: ${asset.id}), fallback kullanılıyor');
        return _fallbackHash(asset);
      }

      // Image decode et
      final image = img.decodeImage(thumbnail);
      if (image == null) {
        return _fallbackHash(asset);
      }

      // 1. Perceptual hash (dHash) hesapla - benzer görüntüleri tespit eder
      final dHash = _calculateDHash(image);
      
      // 2. MD5 hash hesapla - tam eşleşmeler için
      final md5Hash = md5.convert(thumbnail).toString();
      
      // 3. Color histogram hash - renk dağılımı için
      final histogramHash = _calculateHistogramHash(image);
      
      // Kombine hash: dHash + MD5 + Histogram
      // Bu kombinasyon hem benzer hem de tam eşleşmeleri tespit eder
      final combinedData = '$dHash|$md5Hash|$histogramHash';
      final combinedHash = md5.convert(combinedData.codeUnits).toString();
      
      return combinedHash;
    } catch (e) {
      debugPrint('   ⚠️ [DuplicateDetection] Hash hesaplama hatası (ID: ${asset.id}): $e');
      return _fallbackHash(asset);
    }
  }

  /// Difference Hash (dHash) hesapla - perceptual hash algoritması
  /// Benzer görüntüleri tespit eder (küçük farklılıkları tolere eder)
  String _calculateDHash(img.Image image) {
    // 9x8 boyutuna resize et (dHash için standart)
    final resized = img.copyResize(image, width: 9, height: 8);
    
    // Gri tonlamaya çevir
    final gray = img.grayscale(resized);
    
    // dHash hesapla: Her satırda komşu pikselleri karşılaştır
    final hashBits = <bool>[];
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final pixel1 = gray.getPixel(x, y);
        final pixel2 = gray.getPixel(x + 1, y);
        final gray1 = (0.299 * pixel1.r + 0.587 * pixel1.g + 0.114 * pixel1.b).toInt();
        final gray2 = (0.299 * pixel2.r + 0.587 * pixel2.g + 0.114 * pixel2.b).toInt();
        hashBits.add(gray1 > gray2);
      }
    }
    
    // Bit string'e çevir
    final hashString = hashBits.map((b) => b ? '1' : '0').join();
    
    // Hex string'e çevir (64 bit = 16 hex karakter)
    final hashInt = int.parse(hashString, radix: 2);
    return hashInt.toRadixString(16).padLeft(16, '0');
  }

  /// Color histogram hash hesapla
  /// Renk dağılımını analiz eder
  String _calculateHistogramHash(img.Image image) {
    // RGB histogram hesapla (her kanal için 16 bin)
    final rHist = List<int>.filled(16, 0);
    final gHist = List<int>.filled(16, 0);
    final bHist = List<int>.filled(16, 0);
    
    final width = image.width;
    final height = image.height;
    final totalPixels = width * height;
    
    // Histogram oluştur
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        rHist[pixel.r ~/ 16]++;
        gHist[pixel.g ~/ 16]++;
        bHist[pixel.b ~/ 16]++;
      }
    }
    
    // Normalize et ve hash'e çevir
    final normalized = <double>[];
    for (int i = 0; i < 16; i++) {
      normalized.add(rHist[i] / totalPixels);
      normalized.add(gHist[i] / totalPixels);
      normalized.add(bHist[i] / totalPixels);
    }
    
    // Hash string oluştur
    final histString = normalized.map((v) => v.toStringAsFixed(3)).join('|');
    return md5.convert(histString.codeUnits).toString().substring(0, 8);
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


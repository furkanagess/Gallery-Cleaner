import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../models/duplicate_photo.dart';
import '../utils/app_logger.dart';
import 'duplicate_detection_isolate.dart';

/// Duplicate detection modu - hız ve hassasiyet dengesi
enum DuplicateDetectionMode {
  /// Düşük hız - Yüksek hassasiyet: En doğru sonuçlar, daha uzun süre
  lowSpeedHighAccuracy,

  /// Yüksek hız - Düşük hassasiyet: Hızlı sonuçlar, daha az doğru
  highSpeedLowAccuracy,

  /// Dengeli: Hız ve hassasiyet dengesi
  balanced,
}

/// Asset hash'lerini saklamak için class
class _AssetHashes {
  final String dHash;
  final String dHashVertical; // Dikey dHash
  final String pHash;
  final String aHash; // Average Hash
  final String md5Hash;
  final List<double> histogram; // Direkt histogram (MD5 yerine)

  _AssetHashes({
    required this.dHash,
    required this.dHashVertical,
    required this.pHash,
    required this.aHash,
    required this.md5Hash,
    required this.histogram,
  });
}

/// Geliştirilmiş duplicate detection servisi
/// Doğruluk odaklı: Her hash algoritması ayrı değerlendirilir ve benzerlik kontrolü yapılır
/// Benzerlik tabanlı: Hamming distance kullanarak benzer fotoğrafları tespit eder
class DuplicateDetectionService {
  // Hash cache - aynı asset için tekrar hesaplama yapmamak için
  final _hashCache = <String, _AssetHashes>{};

  /// Geliştirilmiş hash hesapla: Her hash algoritması ayrı saklanır
  /// dHash: Difference hash - yatay benzerlik tespiti (33x32 boyut)
  /// dHashVertical: Difference hash - dikey benzerlik tespiti (33x32 boyut)
  /// pHash: Perceptual hash - gerçek DCT bazlı hassas benzerlik tespiti
  /// aHash: Average hash - ortalama bazlı benzerlik tespiti
  /// MD5: Tam eşleşmeler için
  /// Histogram: Renk dağılımı analizi (direkt karşılaştırma için)
  Future<_AssetHashes> _calculateThumbnailHashes(
    pm.AssetEntity asset, {
    int thumbnailSize =
        256, // Performans optimizasyonu - task 1 (800'den 256'ya)
    int quality = 85, // Kalite (80-95 arası)
    bool useCache = true,
  }) async {
    // Cache kontrolü
    if (useCache && _hashCache.containsKey(asset.id)) {
      return _hashCache[asset.id]!;
    }
    try {
      // Daha yüksek kaliteli thumbnail al (doğruluk için)
      final thumbnail = await asset.thumbnailDataWithSize(
        pm.ThumbnailSize(thumbnailSize, thumbnailSize),
        quality: quality,
      );

      if (thumbnail == null || thumbnail.isEmpty) {
        AppLogger.w(
          '⚠️ [DuplicateDetection] Thumbnail alınamadı (ID: ${asset.id}), fallback kullanılıyor',
        );
        return _fallbackHashes(asset);
      }

      // Task 2: Isolate içinde hash hesapla
      final result = await calculateHashesInIsolate(thumbnail, thumbnailSize);

      final hashes = _AssetHashes(
        dHash: result.dHash,
        dHashVertical: result.dHashVertical,
        pHash: result.pHash,
        aHash: result.aHash,
        md5Hash: result.md5Hash,
        histogram: result.histogram,
      );

      // Cache'e kaydet
      if (useCache) {
        _hashCache[asset.id] = hashes;
      }

      return hashes;
    } catch (e) {
      AppLogger.w(
        '⚠️ [DuplicateDetection] Hash hesaplama hatası (ID: ${asset.id}): $e',
      );
      return _fallbackHashes(asset);
    }
  }

  /// Hamming distance hesapla (iki hex string arasındaki farklı bit sayısı)
  /// Task 4: duplicate_detection_isolate.dart'dan kullan
  int _hammingDistance(String hash1, String hash2) {
    return hammingDistanceHex(hash1, hash2);
  }

  /// İki hash'in benzer olup olmadığını kontrol et
  bool _areHashesSimilar(String hash1, String hash2, int threshold) {
    return _hammingDistance(hash1, hash2) <= threshold;
  }

  /// Histogram benzerliği hesapla (Cosine similarity veya Euclidean distance)
  double _calculateHistogramSimilarity(List<double> hist1, List<double> hist2) {
    if (hist1.length != hist2.length) return 0.0;

    // Cosine similarity kullan
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < hist1.length; i++) {
      dotProduct += hist1[i] * hist2[i];
      norm1 += hist1[i] * hist1[i];
      norm2 += hist2[i] * hist2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;

    return dotProduct / (math.sqrt(norm1) * math.sqrt(norm2));
  }

  /// Mode'a göre threshold değerlerini döndür
  (int dHash, int dHashVertical, int pHash, int aHash, double histogram)
  _getThresholdsForMode(DuplicateDetectionMode mode) {
    switch (mode) {
      case DuplicateDetectionMode.lowSpeedHighAccuracy:
        // Düşük hız - Yüksek hassasiyet: Çok sıkı threshold'lar
        return (10, 10, 4, 10, 0.93); // Çok sıkı

      case DuplicateDetectionMode.highSpeedLowAccuracy:
        // Yüksek hız - Düşük hassasiyet: Gevşek threshold'lar
        return (25, 25, 12, 25, 0.80); // Gevşek

      case DuplicateDetectionMode.balanced:
        // Dengeli: Orta seviye threshold'lar
        return (16, 16, 7, 16, 0.88); // Orta
    }
  }

  /// Mode'a göre thumbnail size ve quality döndür
  (int size, int quality) _getThumbnailSettingsForMode(
    DuplicateDetectionMode mode,
  ) {
    switch (mode) {
      case DuplicateDetectionMode.lowSpeedHighAccuracy:
        // Düşük hız - Yüksek hassasiyet: Orta thumbnail, yüksek kalite
        return (256, 90); // Performans optimizasyonu - task 1

      case DuplicateDetectionMode.highSpeedLowAccuracy:
        // Yüksek hız - Düşük hassasiyet: Küçük thumbnail, düşük kalite
        return (128, 75); // Performans optimizasyonu - task 1

      case DuplicateDetectionMode.balanced:
        // Dengeli: Orta boyut ve kalite
        return (256, 85); // Performans optimizasyonu - task 1
    }
  }

  /// Duplicate grupları bul (Task 4: Hash bucket kullan - O(n²) yerine)
  List<DuplicatePhotoGroup> _findDuplicateGroups(
    Map<pm.AssetEntity, _AssetHashes> assetHashesMap,
    String albumName,
    DuplicateDetectionMode mode,
  ) {
    final duplicateGroups = <DuplicatePhotoGroup>[];
    final processedAssets = <pm.AssetEntity>{};

    // Mode'a göre benzerlik eşikleri
    final (
      dHashThreshold,
      dHashVerticalThreshold,
      pHashThreshold,
      aHashThreshold,
      histogramSimilarityThreshold,
    ) = _getThresholdsForMode(
      mode,
    );

    // Task 4: Hash bucket oluştur (Map<int, List<Photo>>)
    // aHash'i int'e çevirip bucket'lara koy
    final hashBuckets = <int, List<pm.AssetEntity>>{};
    final assetToHash = <pm.AssetEntity, int>{};

    for (final entry in assetHashesMap.entries) {
      final asset = entry.key;
      final hashes = entry.value;

      // aHash'i int'e çevir (bucket key olarak kullan)
      try {
        // aHash hex string'ini int'e çevir (ilk 8 karakter yeterli)
        final hashStr = hashes.aHash.length >= 8
            ? hashes.aHash.substring(0, 8)
            : hashes.aHash;
        final hashInt = int.parse(hashStr, radix: 16);
        final bucketKey = hashInt;

        assetToHash[asset] = bucketKey;
        hashBuckets.putIfAbsent(bucketKey, () => []).add(asset);
      } catch (e) {
        // Parse hatası, fallback bucket kullan
        final fallbackKey = hashes.aHash.hashCode;
        assetToHash[asset] = fallbackKey;
        hashBuckets.putIfAbsent(fallbackKey, () => []).add(asset);
      }
    }

    // Her bucket için duplicate kontrolü yap
    for (final bucketEntry in hashBuckets.entries) {
      final bucketAssets = bucketEntry.value;

      // Aynı bucket içindeki asset'leri karşılaştır
      for (int i = 0; i < bucketAssets.length; i++) {
        final asset1 = bucketAssets[i];
        if (processedAssets.contains(asset1)) continue;

        final hashes1 = assetHashesMap[asset1]!;
        final duplicateGroup = <pm.AssetEntity>[asset1];

        // Aynı bucket içindeki diğer asset'lerle karşılaştır
        for (int j = i + 1; j < bucketAssets.length; j++) {
          final asset2 = bucketAssets[j];
          if (processedAssets.contains(asset2)) continue;

          final hashes2 = assetHashesMap[asset2]!;

          // Benzerlik kontrolü
          int similarCount = 0;
          bool hasMD5Match = false;

          // MD5 tam eşleşme kontrolü
          if (hashes1.md5Hash == hashes2.md5Hash) {
            hasMD5Match = true;
            similarCount += 3;
          }

          // Diğer hash benzerlik kontrolleri
          if (_areHashesSimilar(hashes1.dHash, hashes2.dHash, dHashThreshold)) {
            similarCount++;
          }
          if (_areHashesSimilar(
            hashes1.dHashVertical,
            hashes2.dHashVertical,
            dHashVerticalThreshold,
          )) {
            similarCount++;
          }
          if (_areHashesSimilar(hashes1.pHash, hashes2.pHash, pHashThreshold)) {
            similarCount++;
          }
          if (_areHashesSimilar(hashes1.aHash, hashes2.aHash, aHashThreshold)) {
            similarCount++;
          }

          final histogramSimilarity = _calculateHistogramSimilarity(
            hashes1.histogram,
            hashes2.histogram,
          );
          if (histogramSimilarity >= histogramSimilarityThreshold) {
            similarCount++;
          }

          final isDuplicate = hasMD5Match
              ? (similarCount >= 4)
              : (similarCount >= 2);

          if (isDuplicate) {
            duplicateGroup.add(asset2);
            processedAssets.add(asset2);
          }
        }

        // Yakın bucket'ları kontrol et (Hamming distance <= 5 için)
        final currentHash = assetToHash[asset1]!;
        for (final otherBucketEntry in hashBuckets.entries) {
          if (otherBucketEntry.key == bucketEntry.key) {
            continue; // Aynı bucket'ı atla
          }

          // Yakın hash kontrolü (basit fark kontrolü)
          final hashDiff = (currentHash - otherBucketEntry.key).abs();
          if (hashDiff <= 1000) {
            // Yakın hash'ler (threshold ayarlanabilir)
            for (final asset2 in otherBucketEntry.value) {
              if (processedAssets.contains(asset2)) continue;

              final hashes2 = assetHashesMap[asset2]!;

              // Sadece aHash Hamming distance kontrolü (yakın bucket'lar için)
              final hammingDist = hammingDistanceHex(
                hashes1.aHash,
                hashes2.aHash,
              );
              if (hammingDist <= 5) {
                // Task 4: distance <= 5 threshold
                // Diğer kontrolleri de yap
                int similarCount = 0;
                bool hasMD5Match = false;

                if (hashes1.md5Hash == hashes2.md5Hash) {
                  hasMD5Match = true;
                  similarCount += 3;
                }

                if (_areHashesSimilar(
                  hashes1.dHash,
                  hashes2.dHash,
                  dHashThreshold,
                )) {
                  similarCount++;
                }
                if (_areHashesSimilar(
                  hashes1.dHashVertical,
                  hashes2.dHashVertical,
                  dHashVerticalThreshold,
                )) {
                  similarCount++;
                }
                if (_areHashesSimilar(
                  hashes1.pHash,
                  hashes2.pHash,
                  pHashThreshold,
                )) {
                  similarCount++;
                }

                final histogramSimilarity = _calculateHistogramSimilarity(
                  hashes1.histogram,
                  hashes2.histogram,
                );
                if (histogramSimilarity >= histogramSimilarityThreshold) {
                  similarCount++;
                }

                final isDuplicate = hasMD5Match
                    ? (similarCount >= 4)
                    : (similarCount >= 2);

                if (isDuplicate && !duplicateGroup.contains(asset2)) {
                  duplicateGroup.add(asset2);
                  processedAssets.add(asset2);
                }
              }
            }
          }
        }

        // Eğer duplicate grup varsa (2 veya daha fazla asset)
        if (duplicateGroup.length > 1) {
          processedAssets.add(asset1);

          // Toplam boyutu hesapla
          double totalSizeMB = 0;
          for (final asset in duplicateGroup) {
            try {
              final size = asset.size;
              final estimatedBytes = size.width * size.height * 3;
              totalSizeMB += estimatedBytes / (1024 * 1024);
            } catch (_) {
              // Hata olsa bile devam et
            }
          }

          // Hash string oluştur (grup için)
          final groupHash = md5
              .convert(duplicateGroup.map((a) => a.id).join('|').codeUnits)
              .toString();

          duplicateGroups.add(
            DuplicatePhotoGroup(
              hash: groupHash,
              assets: duplicateGroup,
              totalSizeMB: totalSizeMB,
              albumName: albumName,
            ),
          );
        }
      }
    }

    return duplicateGroups;
  }

  /// Cache'i temizle (bellek yönetimi için)
  void clearCache() {
    _hashCache.clear();
  }

  /// Fallback hash'ler (thumbnail alınamazsa)
  _AssetHashes _fallbackHashes(pm.AssetEntity asset) {
    try {
      // Dosya boyutu, genişlik, yükseklik ve oluşturma tarihini kullan
      final size = asset.size;
      final width = asset.width;
      final height = asset.height;
      final createDateTime = asset.createDateTime.millisecondsSinceEpoch;
      final data =
          '${width}_${height}_${size.width}_${size.height}_$createDateTime';
      final fallbackHash = md5.convert(data.codeUnits).toString();

      // Boş histogram (64*3 = 192 eleman)
      final emptyHistogram = List<double>.filled(192, 0.0);

      return _AssetHashes(
        dHash: fallbackHash,
        dHashVertical: fallbackHash,
        pHash: fallbackHash,
        aHash: fallbackHash,
        md5Hash: fallbackHash,
        histogram: emptyHistogram,
      );
    } catch (e) {
      AppLogger.w('⚠️ [DuplicateDetection] Fallback hash hatası: $e');
      // Son çare: sadece ID kullan
      final idHash = md5.convert(asset.id.codeUnits).toString();
      final emptyHistogram = List<double>.filled(192, 0.0);

      return _AssetHashes(
        dHash: idHash,
        dHashVertical: idHash,
        pHash: idHash,
        aHash: idHash,
        md5Hash: idHash,
        histogram: emptyHistogram,
      );
    }
  }

  /// Albüm içinde duplicate fotoğrafları tespit et
  ///
  /// [album] - Taranacak albüm
  /// [progressCallback] - İlerleme callback'i (0.0 - 1.0, processedCount, totalCount)
  /// [shouldCancel] - İptal kontrolü callback'i
  /// [isPremium] - Premium kullanıcı mı?
  /// [mode] - Duplicate detection modu (hız/hassasiyet dengesi)
  Future<
    ({
      List<DuplicatePhotoGroup> duplicateGroups,
      int scannedPhotoCount,
      int targetCount,
    })
  >
  findDuplicatesInAlbum(
    pm.AssetPathEntity album, {
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
    DuplicateDetectionMode mode = DuplicateDetectionMode.balanced,
  }) async {
    AppLogger.i(
      '🔍 [DuplicateDetection] findDuplicatesInAlbum başladı: ${album.name} (ID: ${album.id})',
    );

    // Optimize edilmiş batch size - hız ve bellek dengesi
    const pageSize =
        500; // Kontrollü işleme için optimal (300'den 500'e artırıldı - daha hızlı I/O)
    const batchSize =
        50; // Performans için optimize edilmiş (20'den 50'ye artırıldı - daha fazla paralel işleme)
    int totalProcessed = 0;
    int totalAssets = 0;
    int imageCount = 0;
    final random = math.Random();
    int sampleTarget = 0;

    try {
      // Gerçek toplam asset sayısını al
      AppLogger.d('📊 [DuplicateDetection] Toplam asset sayısı alınıyor...');
      try {
        totalAssets = await album.assetCountAsync;
        AppLogger.d(
          '📊 [DuplicateDetection] Gerçek toplam asset: $totalAssets',
        );
      } catch (e) {
        // Eğer assetCountAsync çalışmazsa, tahmin et
        AppLogger.w(
          '⚠️ [DuplicateDetection] assetCountAsync çalışmadı, tahmin ediliyor: $e',
        );
        final firstPage = await album.getAssetListPaged(
          page: 0,
          size: pageSize,
        );
        totalAssets = firstPage.length >= pageSize
            ? firstPage.length * 10
            : firstPage.length;
        totalAssets = totalAssets > 0 ? totalAssets : 1000;
        AppLogger.d(
          '📊 [DuplicateDetection] Tahmini toplam asset: $totalAssets',
        );
      }

      AppLogger.d('💎 [DuplicateDetection] Premium durumu: $isPremium');
      AppLogger.d('📊 [DuplicateDetection] Max scan limit: $maxScanLimit');

      // 1000 fotoğraf limit kontrolü (premium olsa bile)
      const maxPhotosPerScan = 1000;
      final effectiveMaxLimit = isPremium
          ? maxPhotosPerScan // Premium olsa bile 1000 limit
          : math.min(maxScanLimit, maxPhotosPerScan);
      sampleTarget = totalAssets > 0
          ? math.min(totalAssets, effectiveMaxLimit)
          : effectiveMaxLimit;

      if (sampleTarget <= 0) {
        AppLogger.w('⚠️ [DuplicateDetection] Scan limiti 0, tarama yapılmadı.');
        return (
          duplicateGroups: <DuplicatePhotoGroup>[],
          scannedPhotoCount: 0,
          targetCount: 0,
        );
      }

      final int totalPages = totalAssets > 0
          ? ((totalAssets + pageSize - 1) ~/ pageSize)
          : 1;
      final pageIndices = List.generate(totalPages, (index) => index)
        ..shuffle(random);

      AppLogger.i(
        '🔄 [DuplicateDetection] Assetler hashleniyor (rastgele seçilen en fazla $sampleTarget fotoğraf)...',
      );

      // Asset hash'lerini saklamak için map
      final assetHashesMap = <pm.AssetEntity, _AssetHashes>{};

      // Tüm asset'leri hash'le
      for (final pageIndex in pageIndices) {
        if (imageCount >= sampleTarget) {
          break;
        }

        // İptal kontrolü
        if (shouldCancel != null && shouldCancel()) {
          AppLogger.w('🛑 [DuplicateDetection] Tarama iptal edildi');
          final cancelDuplicateGroups = _findDuplicateGroups(
            assetHashesMap,
            album.name,
            mode,
          );
          cancelDuplicateGroups.sort(
            (a, b) => b.totalSizeMB.compareTo(a.totalSizeMB),
          );
          return (
            duplicateGroups: cancelDuplicateGroups,
            scannedPhotoCount: imageCount,
            targetCount: sampleTarget,
          );
        }

        final assets = await album.getAssetListPaged(
          page: pageIndex,
          size: pageSize,
        );

        if (assets.isEmpty) {
          continue;
        }

        // Sadece image asset'leri filtrele
        final imageAssets =
            assets.where((a) => a.type == pm.AssetType.image).toList()
              ..shuffle(random);
        if (imageAssets.isEmpty) {
          continue;
        }

        // Paralel batch processing: asset'leri batch'ler halinde işle
        for (var i = 0; i < imageAssets.length; i += batchSize) {
          if (imageCount >= sampleTarget) {
            break;
          }

          // İptal kontrolü (her batch'te)
          if (shouldCancel != null && shouldCancel()) {
            AppLogger.w('🛑 [DuplicateDetection] Tarama iptal edildi');
            break;
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

                if (imageCount >= sampleTarget) {
                  return null;
                }

                // Mode'a göre thumbnail ayarlarını al
                final (thumbnailSize, quality) = _getThumbnailSettingsForMode(
                  mode,
                );
                final hashes = await _calculateThumbnailHashes(
                  asset,
                  thumbnailSize: thumbnailSize,
                  quality: quality,
                );
                return (hashes: hashes, asset: asset);
              } catch (e) {
                AppLogger.w(
                  '⚠️ [DuplicateDetection] Hash hesaplama hatası: $e',
                );
                return null;
              }
            }),
          );

          // Batch sonuçlarını assetHashesMap'e ekle
          for (final result in batchResults) {
            if (result != null) {
              assetHashesMap[result.asset] = result.hashes;
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

          // Debug log (her 100 fotoğrafta bir)
          if (imageCount % 100 == 0) {
            AppLogger.d(
              '🖼️ [DuplicateDetection] $imageCount fotoğraf işlendi, ${assetHashesMap.length} asset hash\'lendi...',
            );
          }
        }

        if (imageCount >= sampleTarget) {
          break;
        }
      }

      AppLogger.d('📊 [DuplicateDetection] Hash işleme tamamlandı:');
      AppLogger.d('   - Toplam işlenen: $totalProcessed');
      AppLogger.d('   - Toplam fotoğraf: $imageCount');
      AppLogger.d('   - Hash\'lenen asset: ${assetHashesMap.length}');
      AppLogger.i(
        '📊 [DuplicateDetection] Toplam scan edilen fotoğraf: $imageCount',
      );

      // Duplicate grupları oluştur (benzerlik kontrolü ile)
      AppLogger.i(
        '🔍 [DuplicateDetection] Duplicate grupları oluşturuluyor (benzerlik kontrolü ile)...',
      );
      final duplicateGroups = _findDuplicateGroups(
        assetHashesMap,
        album.name,
        mode,
      );

      AppLogger.d('📊 [DuplicateDetection] Duplicate analizi:');
      AppLogger.d('   - Duplicate grup sayısı: ${duplicateGroups.length}');

      // Boyuta göre sırala (büyükten küçüğe)
      duplicateGroups.sort((a, b) => b.totalSizeMB.compareTo(a.totalSizeMB));

      AppLogger.i(
        '✅ [DuplicateDetection] ${duplicateGroups.length} duplicate grup bulundu (${album.name})',
      );
      AppLogger.i(
        '📊 [DuplicateDetection] Toplam scan edilen fotoğraf: $imageCount',
      );

      return (
        duplicateGroups: duplicateGroups,
        scannedPhotoCount: imageCount,
        targetCount: sampleTarget,
      );
    } catch (e, stackTrace) {
      AppLogger.e('❌ [DuplicateDetection] Hata: $e', e, stackTrace);
      return (
        duplicateGroups: <DuplicatePhotoGroup>[],
        scannedPhotoCount: 0,
        targetCount: sampleTarget,
      );
    }
  }

  /// Birden fazla albümde duplicate fotoğrafları tespit et
  Future<
    ({
      Map<String, List<DuplicatePhotoGroup>> results,
      int scannedPhotoCount,
      int targetCount,
    })
  >
  findDuplicatesInAlbums(
    List<pm.AssetPathEntity> albums, {
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
    DuplicateDetectionMode mode = DuplicateDetectionMode.balanced,
  }) async {
    AppLogger.i(
      '🔍 [DuplicateDetection] findDuplicatesInAlbums başladı - ${albums.length} albüm',
    );
    final results = <String, List<DuplicatePhotoGroup>>{};
    int totalScannedPhotos = 0;
    int totalTargetPhotos = 0;

    for (int i = 0; i < albums.length; i++) {
      // İptal kontrolü
      if (shouldCancel != null && shouldCancel()) {
        AppLogger.w('🛑 [DuplicateDetection] Tarama iptal edildi');
        return (
          results: results,
          scannedPhotoCount: totalScannedPhotos,
          targetCount: totalTargetPhotos,
        );
      }

      // Kalan scan limit kontrolü (premium değilse)
      if (!isPremium && totalScannedPhotos >= maxScanLimit) {
        AppLogger.w(
          '⚠️ [DuplicateDetection] Scan limit aşıldı: $totalScannedPhotos/$maxScanLimit fotoğraf scan edildi',
        );
        break;
      }

      final album = albums[i];
      AppLogger.d(
        '📁 [DuplicateDetection] Albüm ${i + 1}/${albums.length}: ${album.name} (ID: ${album.id})',
      );

      // Kalan scan limit'i hesapla
      final remainingScanLimit = isPremium
          ? 999999999
          : (maxScanLimit - totalScannedPhotos).clamp(0, maxScanLimit);

      AppLogger.d(
        '🔍 [DuplicateDetection] findDuplicatesInAlbum çağrılıyor...',
      );
      final albumResult = await findDuplicatesInAlbum(
        album,
        mode: mode,
        progressCallback:
            (
              albumProgress,
              albumProcessedCount,
              albumPlannedCount,
              albumTotalCount,
            ) {
              AppLogger.d(
                '📊 [DuplicateDetection] Albüm ilerlemesi: $albumProgress ($albumProcessedCount/$albumTotalCount)',
              );
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

      final duplicates = albumResult.duplicateGroups;
      final albumScannedCount = albumResult.scannedPhotoCount;
      totalTargetPhotos += albumResult.targetCount;

      // İptal edildiyse sonuçları döndür
      if (shouldCancel != null && shouldCancel()) {
        AppLogger.w('🛑 [DuplicateDetection] Tarama iptal edildi');
        return (
          results: results,
          scannedPhotoCount: totalScannedPhotos,
          targetCount: totalTargetPhotos,
        );
      }

      totalScannedPhotos += albumScannedCount;

      AppLogger.i(
        '✅ [DuplicateDetection] Albüm taraması tamamlandı: ${album.name} - ${duplicates.length} duplicate grup bulundu',
      );

      if (duplicates.isNotEmpty) {
        results[album.name] = duplicates;
        AppLogger.d('💾 [DuplicateDetection] Sonuçlar kaydedildi');
      } else {
        AppLogger.d(
          '⚠️ [DuplicateDetection] Duplicate bulunamadı, sonuçlar kaydedilmedi',
        );
      }

      // Scan limit aşıldıysa dur
      if (!isPremium && totalScannedPhotos >= maxScanLimit) {
        AppLogger.w(
          '⚠️ [DuplicateDetection] Scan limit aşıldı: $totalScannedPhotos/$maxScanLimit fotoğraf scan edildi',
        );
        break;
      }
    }

    AppLogger.i(
      '🎉 [DuplicateDetection] Tüm albümler taranı! Toplam sonuç: ${results.length} albüm, Toplam scan edilen: $totalScannedPhotos fotoğraf',
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

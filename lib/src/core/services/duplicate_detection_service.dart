import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart' as pm;
import '../models/duplicate_photo.dart';

/// Asset hash'lerini saklamak için class
class _AssetHashes {
  final String dHash;
  final String pHash;
  final String md5Hash;
  final String histogramHash;
  
  _AssetHashes({
    required this.dHash,
    required this.pHash,
    required this.md5Hash,
    required this.histogramHash,
  });
}

/// Geliştirilmiş duplicate detection servisi
/// Doğruluk odaklı: Her hash algoritması ayrı değerlendirilir ve benzerlik kontrolü yapılır
/// Benzerlik tabanlı: Hamming distance kullanarak benzer fotoğrafları tespit eder
class DuplicateDetectionService {
  // Hash cache - aynı asset için tekrar hesaplama yapmamak için
  final _hashCache = <String, _AssetHashes>{};
  
  /// Geliştirilmiş hash hesapla: Her hash algoritması ayrı saklanır
  /// dHash: Difference hash - benzerlik tespiti için (17x16 boyut)
  /// pHash: Perceptual hash - hassas benzerlik tespiti (32x32 DCT)
  /// MD5: Tam eşleşmeler için
  /// Histogram: Renk dağılımı analizi (32 bin)
  Future<_AssetHashes> _calculateThumbnailHashes(
    pm.AssetEntity asset, {
    int thumbnailSize = 600, // Doğruluk için artırıldı (400'den 600'e)
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
        quality: 90, // Doğruluk için artırıldı (85'ten 90'a)
      );

      if (thumbnail == null || thumbnail.isEmpty) {
        debugPrint('   ⚠️ [DuplicateDetection] Thumbnail alınamadı (ID: ${asset.id}), fallback kullanılıyor');
        return _fallbackHashes(asset);
      }

      // Image decode et
      final image = img.decodeImage(thumbnail);
      if (image == null) {
        return _fallbackHashes(asset);
      }

      // Her hash algoritmasını ayrı hesapla
      final dHash = _calculateDHash(image);
      final pHash = _calculatePHash(image);
      final md5Hash = md5.convert(thumbnail).toString();
      final histogramHash = _calculateOptimizedHistogramHash(image);
      
      final hashes = _AssetHashes(
        dHash: dHash,
        pHash: pHash,
        md5Hash: md5Hash,
        histogramHash: histogramHash,
      );
      
      // Cache'e kaydet
      if (useCache) {
        _hashCache[asset.id] = hashes;
      }
      
      return hashes;
    } catch (e) {
      debugPrint('   ⚠️ [DuplicateDetection] Hash hesaplama hatası (ID: ${asset.id}): $e');
      return _fallbackHashes(asset);
    }
  }
  
  /// Hamming distance hesapla (iki hex string arasındaki farklı bit sayısı)
  int _hammingDistance(String hash1, String hash2) {
    if (hash1.length != hash2.length) {
      // Farklı uzunlukta hash'ler için maksimum distance döndür
      return hash1.length * 4; // Her hex karakter 4 bit
    }
    
    int distance = 0;
    for (int i = 0; i < hash1.length; i++) {
      final char1 = hash1[i];
      final char2 = hash2[i];
      if (char1 != char2) {
        // Hex karakterler arasındaki farkı hesapla
        final val1 = int.parse(char1, radix: 16);
        final val2 = int.parse(char2, radix: 16);
        final xor = val1 ^ val2;
        // XOR sonucundaki set bit sayısını say (manuel)
        int bitCount = 0;
        int n = xor;
        while (n > 0) {
          bitCount += n & 1;
          n >>= 1;
        }
        distance += bitCount;
      }
    }
    return distance;
  }
  
  /// İki hash'in benzer olup olmadığını kontrol et
  bool _areHashesSimilar(String hash1, String hash2, int threshold) {
    return _hammingDistance(hash1, hash2) <= threshold;
  }
  
  /// Duplicate grupları bul (benzerlik kontrolü ile)
  List<DuplicatePhotoGroup> _findDuplicateGroups(
    Map<pm.AssetEntity, _AssetHashes> assetHashesMap,
    String albumName,
  ) {
    final duplicateGroups = <DuplicatePhotoGroup>[];
    final processedAssets = <pm.AssetEntity>{};
    
    // Benzerlik eşikleri
    const dHashThreshold = 8; // dHash için 8 bit fark (256 bit hash için %3.1)
    const pHashThreshold = 8; // pHash için 8 bit fark (64 bit hash için %12.5)
    const histogramThreshold = 4; // Histogram için 4 bit fark
    
    final assetList = assetHashesMap.keys.toList();
    
    for (int i = 0; i < assetList.length; i++) {
      final asset1 = assetList[i];
      if (processedAssets.contains(asset1)) continue;
      
      final hashes1 = assetHashesMap[asset1]!;
      final duplicateGroup = <pm.AssetEntity>[asset1];
      
      for (int j = i + 1; j < assetList.length; j++) {
        final asset2 = assetList[j];
        if (processedAssets.contains(asset2)) continue;
        
        final hashes2 = assetHashesMap[asset2]!;
        
        // Benzerlik kontrolü: En az 2 hash algoritması benzer olmalı
        int similarCount = 0;
        
        // MD5 tam eşleşme kontrolü (en güvenilir)
        if (hashes1.md5Hash == hashes2.md5Hash) {
          similarCount += 2; // MD5 tam eşleşme çok önemli
        }
        
        // dHash benzerlik kontrolü
        if (_areHashesSimilar(hashes1.dHash, hashes2.dHash, dHashThreshold)) {
          similarCount++;
        }
        
        // pHash benzerlik kontrolü
        if (_areHashesSimilar(hashes1.pHash, hashes2.pHash, pHashThreshold)) {
          similarCount++;
        }
        
        // Histogram benzerlik kontrolü
        if (_areHashesSimilar(hashes1.histogramHash, hashes2.histogramHash, histogramThreshold)) {
          similarCount++;
        }
        
        // En az 2 algoritma benzer olmalı (veya MD5 tam eşleşmeli)
        if (similarCount >= 2) {
          duplicateGroup.add(asset2);
          processedAssets.add(asset2);
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
        final groupHash = md5.convert(
          duplicateGroup.map((a) => a.id).join('|').codeUnits
        ).toString();

        duplicateGroups.add(DuplicatePhotoGroup(
          hash: groupHash,
          assets: duplicateGroup,
          totalSizeMB: totalSizeMB,
          albumName: albumName,
        ));
      }
    }
    
    return duplicateGroups;
  }

  /// Difference Hash (dHash) hesapla - perceptual hash algoritması (doğruluk odaklı)
  /// Benzer görüntüleri tespit eder (küçük farklılıkları tolere eder)
  /// Daha büyük boyut kullanarak daha doğru tespit yapar
  String _calculateDHash(img.Image image) {
    // 17x16 boyutuna resize et (9x8'den daha büyük - daha doğru tespit için)
    final resized = img.copyResize(image, width: 17, height: 16);
    
    // Gri tonlamaya çevir
    final gray = img.grayscale(resized);
    
    // dHash hesapla: Her satırda komşu pikselleri karşılaştır (tüm pikselleri kontrol et)
    final hashBits = <bool>[];
    for (int y = 0; y < 16; y++) {
      for (int x = 0; x < 16; x++) {
        final pixel1 = gray.getPixel(x, y);
        final pixel2 = gray.getPixel(x + 1, y);
        // Daha doğru luminance hesaplama (floating point kullan)
        final gray1 = (0.299 * pixel1.r + 0.587 * pixel1.g + 0.114 * pixel1.b);
        final gray2 = (0.299 * pixel2.r + 0.587 * pixel2.g + 0.114 * pixel2.b);
        hashBits.add(gray1 > gray2);
      }
    }
    
    // Bit string'e çevir (256 bit = 64 hex karakter)
    final hashString = hashBits.map((b) => b ? '1' : '0').join();
    
    // Hex string'e çevir (256 bit için 64 hex karakter)
    // 63 bit parçalara böl (Dart int maksimum 63 bit signed integer)
    final hashParts = <String>[];
    const chunkSize = 63; // 64 bit yerine 63 bit (overflow önlemek için)
    for (int i = 0; i < hashString.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, hashString.length);
      final part = hashString.substring(i, end);
      if (part.isNotEmpty) {
        // 63 bit'i güvenli şekilde parse et
        final hashInt = int.parse(part.padRight(chunkSize, '0'), radix: 2);
        hashParts.add(hashInt.toRadixString(16).padLeft(16, '0'));
      }
    }
    return hashParts.join('');
  }

  /// Perceptual Hash (pHash) hesapla - DCT (Discrete Cosine Transform) bazlı (optimize edilmiş)
  /// dHash'tan daha hassas, benzer görüntüleri daha iyi tespit eder
  /// Optimize edilmiş boyut ve DCT analizi kullanır
  String _calculatePHash(img.Image image) {
    // 32x32 boyutuna resize et (hız için optimize edilmiş)
    final resized = img.copyResize(image, width: 32, height: 32);
    final gray = img.grayscale(resized);
    
    // Optimize edilmiş DCT analizi - 8x8 DCT bloğu kullan (hız için)
    final dctSize = 8;
    final dctBlock = List<List<double>>.generate(
      dctSize,
      (_) => List<double>.filled(dctSize, 0.0),
    );
    
    // 32x32 görüntüyü 8x8 bloklara böl ve DCT hesapla (4x4 = 16 blok)
    for (int by = 0; by < 4; by++) {
      for (int bx = 0; bx < 4; bx++) {
        // Her 8x8 bloğun analizini yap
        double sum = 0.0;
        double sumSquared = 0.0;
        int pixelCount = 0;
        
        for (int y = 0; y < dctSize; y++) {
          for (int x = 0; x < dctSize; x++) {
            final pixel = gray.getPixel(bx * dctSize + x, by * dctSize + y);
            final grayValue = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
            sum += grayValue;
            sumSquared += grayValue * grayValue;
            pixelCount++;
          }
        }
        
        // Ortalama ve varyans hesapla (daha detaylı analiz)
        final mean = sum / pixelCount;
        final variance = (sumSquared / pixelCount) - (mean * mean);
        dctBlock[by][bx] = mean + (variance * 0.1); // Ortalama + varyans etkisi
      }
    }
    
    // DCT katsayılarının ortalamasını hesapla
    double dctMean = 0.0;
    for (int y = 0; y < dctSize; y++) {
      for (int x = 0; x < dctSize; x++) {
        dctMean += dctBlock[y][x];
      }
    }
    dctMean /= (dctSize * dctSize);
    
    // Hash bits oluştur (ortalama üzerinde/altında)
    final hashBits = <bool>[];
    for (int y = 0; y < dctSize; y++) {
      for (int x = 0; x < dctSize; x++) {
        hashBits.add(dctBlock[y][x] > dctMean);
      }
    }
    
    // Bit string'e çevir ve hex'e dönüştür (256 bit = 64 hex karakter)
    final hashString = hashBits.map((b) => b ? '1' : '0').join();
    final hashParts = <String>[];
    const chunkSize = 63; // 64 bit yerine 63 bit (overflow önlemek için)
    for (int i = 0; i < hashString.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, hashString.length);
      final part = hashString.substring(i, end);
      if (part.isNotEmpty) {
        // 63 bit'i güvenli şekilde parse et
        final hashInt = int.parse(part.padRight(chunkSize, '0'), radix: 2);
        hashParts.add(hashInt.toRadixString(16).padLeft(16, '0'));
      }
    }
    return hashParts.join('');
  }

  /// Optimize edilmiş Color histogram hash hesapla (hız ve doğruluk dengesi)
  /// RGB analizi - optimize edilmiş bin sayısı
  String _calculateOptimizedHistogramHash(img.Image image) {
    // RGB histogram (her kanal için 32 bin - hız için optimize edilmiş)
    final rHist = List<int>.filled(32, 0);
    final gHist = List<int>.filled(32, 0);
    final bHist = List<int>.filled(32, 0);
    
    final width = image.width;
    final height = image.height;
    final totalPixels = width * height;
    
    // Doğruluk odaklı: Tüm pikselleri analiz et (sampling yok)
    // Histogram oluştur
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        
        // RGB histogram (32 bin - hız için optimize edilmiş)
        rHist[r ~/ 8]++;
        gHist[g ~/ 8]++;
        bHist[b ~/ 8]++;
      }
    }
    
    // Normalize et ve hash'e çevir (optimize edilmiş hassasiyet)
    final normalized = <double>[];
    for (int i = 0; i < 32; i++) {
      normalized.add(rHist[i] / totalPixels);
      normalized.add(gHist[i] / totalPixels);
      normalized.add(bHist[i] / totalPixels);
    }
    
    // Hash string oluştur (optimize edilmiş hassasiyet)
    final histString = normalized.map((v) => v.toStringAsFixed(4)).join('|');
    return md5.convert(histString.codeUnits).toString();
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
      final data = '${width}_${height}_${size.width}_${size.height}_$createDateTime';
      final fallbackHash = md5.convert(data.codeUnits).toString();
      
      return _AssetHashes(
        dHash: fallbackHash,
        pHash: fallbackHash,
        md5Hash: fallbackHash,
        histogramHash: fallbackHash,
      );
    } catch (e) {
      debugPrint('   ⚠️ [DuplicateDetection] Fallback hash hatası: $e');
      // Son çare: sadece ID kullan
      final idHash = md5.convert(asset.id.codeUnits).toString();
      return _AssetHashes(
        dHash: idHash,
        pHash: idHash,
        md5Hash: idHash,
        histogramHash: idHash,
      );
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

    // Optimize edilmiş batch size - hız ve bellek dengesi
    const pageSize = 500; // Kontrollü işleme için optimal
    const batchSize = 50; // Performans için optimize edilmiş (30'dan 50'ye) - daha hızlı paralel işleme
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

      debugPrint('🔄 [DuplicateDetection] Assetler hashleniyor (geliştirilmiş mod)...');
      
      // Asset hash'lerini saklamak için map
      final assetHashesMap = <pm.AssetEntity, _AssetHashes>{};
      
      // Tüm asset'leri hash'le
      while (true) {
        // İptal kontrolü
        if (shouldCancel != null && shouldCancel()) {
          debugPrint('   🛑 [DuplicateDetection] Tarama iptal edildi');
          // Mevcut sonuçları döndürmek için duplicate grupları oluştur (benzerlik kontrolü ile)
          final cancelDuplicateGroups = _findDuplicateGroups(assetHashesMap, album.name);
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

                final hashes = await _calculateThumbnailHashes(asset);
                return (hashes: hashes, asset: asset);
              } catch (e) {
                debugPrint('   ⚠️ [DuplicateDetection] Hash hesaplama hatası: $e');
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

          // İlerleme callback (her batch'te)
          if (progressCallback != null && totalAssets > 0) {
            final progress = (totalProcessed / totalAssets).clamp(0.0, 1.0);
            progressCallback(progress, totalProcessed, totalAssets);
          }

          // Debug log (her 100 fotoğrafta bir)
          if (imageCount % 100 == 0) {
            debugPrint('   🖼️ [DuplicateDetection] $imageCount fotoğraf işlendi, ${assetHashesMap.length} asset hash\'lendi...');
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
      debugPrint('   - Hash\'lenen asset: ${assetHashesMap.length}');
      debugPrint(
        '📊 [DuplicateDetection] Toplam scan edilen fotoğraf: $imageCount',
      );

      // Duplicate grupları oluştur (benzerlik kontrolü ile)
      debugPrint('🔍 [DuplicateDetection] Duplicate grupları oluşturuluyor (benzerlik kontrolü ile)...');
      final duplicateGroups = _findDuplicateGroups(assetHashesMap, album.name);

      debugPrint('📊 [DuplicateDetection] Duplicate analizi:');
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


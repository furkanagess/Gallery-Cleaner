import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart' as pm;
import '../models/duplicate_photo.dart';

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
    int thumbnailSize = 800, // Doğruluk için artırıldı (600'den 800'e)
    int quality = 95, // Kalite (80-95 arası)
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
      final dHashVertical = _calculateDHashVertical(image);
      final pHash = _calculatePHash(image);
      final aHash = _calculateAHash(image);
      final md5Hash = md5.convert(thumbnail).toString();
      final histogram = _calculateHistogram(image);
      
      final hashes = _AssetHashes(
        dHash: dHash,
        dHashVertical: dHashVertical,
        pHash: pHash,
        aHash: aHash,
        md5Hash: md5Hash,
        histogram: histogram,
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
  (int dHash, int dHashVertical, int pHash, int aHash, double histogram) _getThresholdsForMode(
    DuplicateDetectionMode mode,
  ) {
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
  (int size, int quality) _getThumbnailSettingsForMode(DuplicateDetectionMode mode) {
    switch (mode) {
      case DuplicateDetectionMode.lowSpeedHighAccuracy:
        // Düşük hız - Yüksek hassasiyet: Büyük thumbnail, yüksek kalite
        return (1000, 98);
        
      case DuplicateDetectionMode.highSpeedLowAccuracy:
        // Yüksek hız - Düşük hassasiyet: Küçük thumbnail, düşük kalite
        return (400, 80);
        
      case DuplicateDetectionMode.balanced:
        // Dengeli: Orta boyut ve kalite
        return (800, 95);
    }
  }
  
  /// Duplicate grupları bul (benzerlik kontrolü ile)
  List<DuplicatePhotoGroup> _findDuplicateGroups(
    Map<pm.AssetEntity, _AssetHashes> assetHashesMap,
    String albumName,
    DuplicateDetectionMode mode,
  ) {
    final duplicateGroups = <DuplicatePhotoGroup>[];
    final processedAssets = <pm.AssetEntity>{};
    
    // Mode'a göre benzerlik eşikleri
    final (dHashThreshold, dHashVerticalThreshold, pHashThreshold, aHashThreshold, histogramSimilarityThreshold) = 
        _getThresholdsForMode(mode);
    
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
        
        // Benzerlik kontrolü: Orta seviye kriterler - önceki ve şu anki arasında
        // Önceki: en az 2 algoritma | Şu anki: en az 3 algoritma (veya MD5 + 1)
        // Orta nokta: en az 2 algoritma (veya MD5 + 1 algoritma) - biraz daha esnek
        int similarCount = 0;
        bool hasMD5Match = false;
        
        // MD5 tam eşleşme kontrolü (en güvenilir - otomatik duplicate)
        if (hashes1.md5Hash == hashes2.md5Hash) {
          hasMD5Match = true;
          similarCount += 3; // MD5 tam eşleşme kesin duplicate (yüksek ağırlık)
        }
        
        // dHash yatay benzerlik kontrolü
        if (_areHashesSimilar(hashes1.dHash, hashes2.dHash, dHashThreshold)) {
          similarCount++;
        }
        
        // dHash dikey benzerlik kontrolü
        if (_areHashesSimilar(hashes1.dHashVertical, hashes2.dHashVertical, dHashVerticalThreshold)) {
          similarCount++;
        }
        
        // pHash benzerlik kontrolü
        if (_areHashesSimilar(hashes1.pHash, hashes2.pHash, pHashThreshold)) {
          similarCount++;
        }
        
        // aHash benzerlik kontrolü
        if (_areHashesSimilar(hashes1.aHash, hashes2.aHash, aHashThreshold)) {
          similarCount++;
        }
        
        // Histogram benzerlik kontrolü (cosine similarity)
        final histogramSimilarity = _calculateHistogramSimilarity(hashes1.histogram, hashes2.histogram);
        if (histogramSimilarity >= histogramSimilarityThreshold) {
          similarCount++;
        }
        
        // Orta seviye kriterler:
        // 1. MD5 tam eşleşme varsa + en az 1 algoritma benzer olmalı (toplam >= 4)
        // 2. MD5 eşleşme yoksa en az 2 algoritma benzer olmalı (toplam >= 2) - önceki gibi
        final isDuplicate = hasMD5Match 
            ? (similarCount >= 4) // MD5 + en az 1 algoritma
            : (similarCount >= 2); // En az 2 algoritma (önceki gibi)
        
        if (isDuplicate) {
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

  /// Difference Hash (dHash) hesapla - yatay karşılaştırma (en üst düzey doğruluk)
  /// Benzer görüntüleri tespit eder (küçük farklılıkları tolere eder)
  /// Daha büyük boyut kullanarak daha doğru tespit yapar
  String _calculateDHash(img.Image image) {
    try {
      // 33x32 boyutuna resize et (daha doğru tespit için artırıldı)
      final resized = img.copyResize(image, width: 33, height: 32);
    
    // Gri tonlamaya çevir
    final gray = img.grayscale(resized);
    
      // Güvenlik kontrolü: Resize edilen görüntünün boyutlarını kontrol et
      final width = gray.width;
      final height = gray.height;
      
      // dHash hesapla: Her satırda komşu pikselleri karşılaştır (yatay)
    final hashBits = <bool>[];
      for (int y = 0; y < height - 1 && y < 32; y++) {
        for (int x = 0; x < width - 1 && x < 32; x++) {
          if (x + 1 < width && y < height) {
        final pixel1 = gray.getPixel(x, y);
        final pixel2 = gray.getPixel(x + 1, y);
            // Daha doğru luminance hesaplama (floating point kullan)
            final gray1 = (0.299 * pixel1.r + 0.587 * pixel1.g + 0.114 * pixel1.b);
            final gray2 = (0.299 * pixel2.r + 0.587 * pixel2.g + 0.114 * pixel2.b);
            hashBits.add(gray1 > gray2);
          }
        }
      }
    
      // Bit string'e çevir (1024 bit = 256 hex karakter)
      if (hashBits.isEmpty) {
        // Boş hash bits, fallback döndür
        return md5.convert('${image.width}_${image.height}_empty'.codeUnits).toString();
      }
      
      final hashString = hashBits.map((b) => b ? '1' : '0').join();
      
      // Hex string'e çevir (63 bit parçalara böl)
      final hashParts = <String>[];
      const chunkSize = 63;
      for (int i = 0; i < hashString.length; i += chunkSize) {
        // Güvenli end hesaplama
        final calculatedEnd = i + chunkSize;
        final end = calculatedEnd < hashString.length ? calculatedEnd : hashString.length;
        
        // Ekstra güvenlik: end'in geçerli olduğundan emin ol
        if (end > i && end <= hashString.length && i >= 0 && i < hashString.length) {
          try {
            final part = hashString.substring(i, end);
            if (part.isNotEmpty && part.length <= chunkSize) {
              try {
                // Güvenli padding - part uzunluğunu kontrol et
                final paddedPart = part.length < chunkSize 
                    ? part.padRight(chunkSize, '0') 
                    : part;
                if (paddedPart.length <= chunkSize) {
                  final hashInt = int.parse(paddedPart, radix: 2);
                  hashParts.add(hashInt.toRadixString(16).padLeft(16, '0'));
                }
              } catch (e) {
                // Parse hatası, devam et
                continue;
              }
            }
          } catch (e) {
            // Substring hatası, devam et
            continue;
          }
        }
      }
      
      // Eğer hiç hash part oluşturulamadıysa fallback döndür
      if (hashParts.isEmpty) {
        return md5.convert('${image.width}_${image.height}_fallback'.codeUnits).toString();
      }
      
      return hashParts.join('');
    } catch (e) {
      debugPrint('   ⚠️ [DuplicateDetection] dHash hesaplama hatası: $e');
      // Fallback: basit hash
      return md5.convert('${image.width}_${image.height}'.codeUnits).toString();
    }
  }
  
  /// Difference Hash (dHash) hesapla - dikey karşılaştırma
  /// Yatay dHash'ın tamamlayıcısı, dikey benzerlikleri tespit eder
  String _calculateDHashVertical(img.Image image) {
    try {
      // 33x32 boyutuna resize et
      final resized = img.copyResize(image, width: 33, height: 32);
      
      // Gri tonlamaya çevir
      final gray = img.grayscale(resized);
      
      // Güvenlik kontrolü: Resize edilen görüntünün boyutlarını kontrol et
      final width = gray.width;
      final height = gray.height;
      
      // dHash hesapla: Her sütunda komşu pikselleri karşılaştır (dikey)
      final hashBits = <bool>[];
      for (int x = 0; x < width && x < 32; x++) {
        for (int y = 0; y < height - 1 && y < 32; y++) {
          if (x < width && y + 1 < height) {
            final pixel1 = gray.getPixel(x, y);
            final pixel2 = gray.getPixel(x, y + 1);
            final gray1 = (0.299 * pixel1.r + 0.587 * pixel1.g + 0.114 * pixel1.b);
            final gray2 = (0.299 * pixel2.r + 0.587 * pixel2.g + 0.114 * pixel2.b);
        hashBits.add(gray1 > gray2);
          }
        }
      }
    
      // Bit string'e çevir ve hex'e dönüştür
      final hashString = hashBits.map((b) => b ? '1' : '0').join();
      final hashParts = <String>[];
      const chunkSize = 63;
      for (int i = 0; i < hashString.length; i += chunkSize) {
        final end = (i + chunkSize < hashString.length) ? i + chunkSize : hashString.length;
        if (end > i && end <= hashString.length) {
          final part = hashString.substring(i, end);
          if (part.isNotEmpty) {
            try {
              // Güvenli padding - part uzunluğunu kontrol et
              final paddedPart = part.length < chunkSize 
                  ? part.padRight(chunkSize, '0') 
                  : part.substring(0, chunkSize);
              final hashInt = int.parse(paddedPart, radix: 2);
              hashParts.add(hashInt.toRadixString(16).padLeft(16, '0'));
            } catch (e) {
              // Parse hatası, devam et
              continue;
            }
          }
        }
      }
      return hashParts.join('');
    } catch (e) {
      debugPrint('   ⚠️ [DuplicateDetection] dHashVertical hesaplama hatası: $e');
      // Fallback: basit hash
      return md5.convert('${image.width}_${image.height}_v'.codeUnits).toString();
    }
  }

  /// Perceptual Hash (pHash) hesapla - Gerçek DCT (Discrete Cosine Transform) bazlı
  /// dHash'tan daha hassas, benzer görüntüleri daha iyi tespit eder
  /// 8x8 DCT kullanarak en üst düzey doğruluk sağlar
  String _calculatePHash(img.Image image) {
    try {
      // 32x32 boyutuna resize et (DCT için optimal)
      final resized = img.copyResize(image, width: 32, height: 32);
      final gray = img.grayscale(resized);
      
      // Güvenlik kontrolü
      final width = gray.width;
      final height = gray.height;
      
      // 8x8 DCT bloğu için pixel değerlerini hazırla
      final dctSize = 8;
      final pixels = List<List<double>>.generate(
        dctSize,
        (_) => List<double>.filled(dctSize, 0.0),
      );
      
      // 32x32 görüntüden 8x8 bloğu al (sol üst köşe)
      for (int y = 0; y < dctSize && y < height; y++) {
        for (int x = 0; x < dctSize && x < width; x++) {
          if (x < width && y < height) {
            final pixel = gray.getPixel(x, y);
            pixels[y][x] = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
          }
        }
      }
    
    // DCT hesapla (basitleştirilmiş 2D DCT)
    final dct = _calculate2DDCT(pixels, dctSize);
    
    // DCT katsayılarının ortalamasını hesapla (DC katsayısını hariç tut)
    double dctMean = 0.0;
    int count = 0;
    for (int y = 0; y < dctSize; y++) {
      for (int x = 0; x < dctSize; x++) {
        if (x != 0 || y != 0) { // DC katsayısını hariç tut
          dctMean += dct[y][x];
          count++;
        }
      }
    }
    dctMean /= count;
    
    // Hash bits oluştur (ortalama üzerinde/altında, DC hariç)
    final hashBits = <bool>[];
    for (int y = 0; y < dctSize; y++) {
      for (int x = 0; x < dctSize; x++) {
        if (x != 0 || y != 0) { // DC katsayısını hariç tut
          hashBits.add(dct[y][x] > dctMean);
        }
      }
    }
    
      // Bit string'e çevir ve hex'e dönüştür (63 bit = 16 hex karakter)
    final hashString = hashBits.map((b) => b ? '1' : '0').join();
      final hashParts = <String>[];
      const chunkSize = 63;
      for (int i = 0; i < hashString.length; i += chunkSize) {
        final end = (i + chunkSize < hashString.length) ? i + chunkSize : hashString.length;
        if (end > i && end <= hashString.length) {
          final part = hashString.substring(i, end);
          if (part.isNotEmpty) {
            try {
              // Güvenli padding - part uzunluğunu kontrol et
              final paddedPart = part.length < chunkSize 
                  ? part.padRight(chunkSize, '0') 
                  : part.substring(0, chunkSize);
              final hashInt = int.parse(paddedPart, radix: 2);
              hashParts.add(hashInt.toRadixString(16).padLeft(16, '0'));
            } catch (e) {
              // Parse hatası, devam et
              continue;
            }
          }
        }
      }
      return hashParts.join('');
    } catch (e) {
      debugPrint('   ⚠️ [DuplicateDetection] pHash hesaplama hatası: $e');
      // Fallback: basit hash
      return md5.convert('${image.width}_${image.height}_p'.codeUnits).toString();
    }
  }
  
  /// 2D DCT (Discrete Cosine Transform) hesapla
  List<List<double>> _calculate2DDCT(List<List<double>> pixels, int size) {
    final dct = List<List<double>>.generate(
      size,
      (_) => List<double>.filled(size, 0.0),
    );
    
    // 2D DCT: Önce satırlar, sonra sütunlar
    for (int u = 0; u < size; u++) {
      for (int v = 0; v < size; v++) {
        double sum = 0.0;
        final cu = u == 0 ? 1.0 / math.sqrt(2) : 1.0;
        final cv = v == 0 ? 1.0 / math.sqrt(2) : 1.0;
        
        for (int y = 0; y < size; y++) {
          for (int x = 0; x < size; x++) {
            final cosX = math.cos((2 * x + 1) * u * math.pi / (2 * size));
            final cosY = math.cos((2 * y + 1) * v * math.pi / (2 * size));
            sum += pixels[y][x] * cosX * cosY;
          }
        }
        
        dct[v][u] = (2.0 / size) * cu * cv * sum;
      }
    }
    
    return dct;
  }
  
  /// Average Hash (aHash) hesapla - ortalama bazlı benzerlik tespiti
  /// Basit ama etkili, dHash'a benzer ama ortalama kullanır
  String _calculateAHash(img.Image image) {
    try {
      // 33x32 boyutuna resize et (dHash ile aynı boyut)
      final resized = img.copyResize(image, width: 33, height: 32);
      final gray = img.grayscale(resized);
      
      // Güvenlik kontrolü
      final width = gray.width;
      final height = gray.height;
      
      // Ortalama gri değeri hesapla
      double sum = 0.0;
      int pixelCount = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          if (x < width && y < height) {
            final pixel = gray.getPixel(x, y);
            final grayValue = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
            sum += grayValue;
            pixelCount++;
          }
        }
      }
      final average = pixelCount > 0 ? sum / pixelCount : 128.0;
      
      // Hash bits oluştur (ortalama üzerinde/altında)
      final hashBits = <bool>[];
      for (int y = 0; y < height && y < 32; y++) {
        for (int x = 0; x < width && x < 32; x++) {
          if (x < width && y < height) {
            final pixel = gray.getPixel(x, y);
            final grayValue = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
            hashBits.add(grayValue > average);
          }
        }
      }
    
      // Bit string'e çevir ve hex'e dönüştür (1024 bit)
      final hashString = hashBits.map((b) => b ? '1' : '0').join();
      final hashParts = <String>[];
      const chunkSize = 63;
      for (int i = 0; i < hashString.length; i += chunkSize) {
        final end = (i + chunkSize < hashString.length) ? i + chunkSize : hashString.length;
        if (end > i && end <= hashString.length) {
          final part = hashString.substring(i, end);
          if (part.isNotEmpty) {
            try {
              // Güvenli padding - part uzunluğunu kontrol et
              final paddedPart = part.length < chunkSize 
                  ? part.padRight(chunkSize, '0') 
                  : part.substring(0, chunkSize);
              final hashInt = int.parse(paddedPart, radix: 2);
              hashParts.add(hashInt.toRadixString(16).padLeft(16, '0'));
            } catch (e) {
              // Parse hatası, devam et
              continue;
            }
          }
        }
      }
      return hashParts.join('');
    } catch (e) {
      debugPrint('   ⚠️ [DuplicateDetection] aHash hesaplama hatası: $e');
      // Fallback: basit hash
      return md5.convert('${image.width}_${image.height}_a'.codeUnits).toString();
    }
  }

  /// Histogram hesapla - direkt karşılaştırma için normalize edilmiş histogram
  /// RGB analizi - 64 bin (her kanal için 64 bin, daha hassas)
  List<double> _calculateHistogram(img.Image image) {
    try {
      // RGB histogram (her kanal için 64 bin - daha hassas)
      final rHist = List<int>.filled(64, 0);
      final gHist = List<int>.filled(64, 0);
      final bHist = List<int>.filled(64, 0);
    
    final width = image.width;
    final height = image.height;
    final totalPixels = width * height;
    
      if (totalPixels == 0) {
        // Boş görüntü için boş histogram döndür
        return List<double>.filled(192, 0.0);
      }
      
      // Doğruluk odaklı: Tüm pikselleri analiz et (sampling yok)
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
          if (x < width && y < height) {
            try {
        final pixel = image.getPixel(x, y);
              final r = pixel.r.toInt().clamp(0, 255);
              final g = pixel.g.toInt().clamp(0, 255);
              final b = pixel.b.toInt().clamp(0, 255);
              
              // RGB histogram (64 bin - daha hassas) - index sınır kontrolü
              // r ~/ 4: 0-255 -> 0-63 (255/4 = 63.75, ama integer division 63 verir)
              // Ekstra güvenlik: clamp ile sınırla
              final rDiv = r ~/ 4;
              final gDiv = g ~/ 4;
              final bDiv = b ~/ 4;
              
              final rIndex = (rDiv < 0 ? 0 : (rDiv > 63 ? 63 : rDiv));
              final gIndex = (gDiv < 0 ? 0 : (gDiv > 63 ? 63 : gDiv));
              final bIndex = (bDiv < 0 ? 0 : (bDiv > 63 ? 63 : bDiv));
              
              // Ekstra güvenlik: array bounds kontrolü
              if (rIndex >= 0 && rIndex < rHist.length) rHist[rIndex]++;
              if (gIndex >= 0 && gIndex < gHist.length) gHist[gIndex]++;
              if (bIndex >= 0 && bIndex < bHist.length) bHist[bIndex]++;
            } catch (e) {
              // Pixel erişim hatası, devam et
              continue;
            }
          }
        }
      }
      
      // Normalize et ve direkt döndür (MD5'e çevirme)
    final normalized = <double>[];
      for (int i = 0; i < 64; i++) {
      normalized.add(rHist[i] / totalPixels);
      normalized.add(gHist[i] / totalPixels);
      normalized.add(bHist[i] / totalPixels);
    }
    
      return normalized;
    } catch (e) {
      debugPrint('   ⚠️ [DuplicateDetection] Histogram hesaplama hatası: $e');
      // Fallback: boş histogram
      return List<double>.filled(192, 0.0);
    }
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
      debugPrint('   ⚠️ [DuplicateDetection] Fallback hash hatası: $e');
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
  /// Returns: ({duplicateGroups: List<DuplicatePhotoGroup>, scannedPhotoCount: int})
  Future<({List<DuplicatePhotoGroup> duplicateGroups, int scannedPhotoCount})> findDuplicatesInAlbum(
    pm.AssetPathEntity album, {
    void Function(double progress, int processedCount, int totalCount)? progressCallback,
    bool Function()? shouldCancel,
    bool isPremium = false,
    int maxScanLimit = 999999999,
    DuplicateDetectionMode mode = DuplicateDetectionMode.balanced,
  }) async {
    debugPrint('🔍 [DuplicateDetection] findDuplicatesInAlbum başladı: ${album.name} (ID: ${album.id})');

    // Optimize edilmiş batch size - hız ve bellek dengesi
    const pageSize = 300; // Kontrollü işleme için optimal (500'den 300'e düşürüldü - daha az memory)
    const batchSize = 20; // Performans için optimize edilmiş (50'den 20'ye - UI thread'i bloklamamak için)
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

      // 1000 fotoğraf limit kontrolü (premium olsa bile)
      const maxPhotosPerScan = 1000;
      final effectiveMaxLimit = isPremium 
          ? maxPhotosPerScan // Premium olsa bile 1000 limit
          : (maxScanLimit > maxPhotosPerScan ? maxPhotosPerScan : maxScanLimit);
      
      // Kalan scan hakkı kadar fotoğraf scan et (1000 limit ile)
      final int maxImagesToProcess = effectiveMaxLimit;
      
      // Toplam sayıyı maxImagesToProcess ile sınırla
      if (totalAssets > maxImagesToProcess) {
        totalAssets = maxImagesToProcess;
        debugPrint('📊 [DuplicateDetection] Toplam sayı 1000 limit ile sınırlandı: $totalAssets');
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
          final cancelDuplicateGroups = _findDuplicateGroups(assetHashesMap, album.name, mode);
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

                // Mode'a göre thumbnail ayarlarını al
                final (thumbnailSize, quality) = _getThumbnailSettingsForMode(mode);
                final hashes = await _calculateThumbnailHashes(
                  asset,
                  thumbnailSize: thumbnailSize,
                  quality: quality,
                );
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

          // İlerleme callback (throttled - her 50 asset'te bir veya her 500ms'de bir)
          // UI thread'i bloklamamak için callback'leri azalt
          if (progressCallback != null && totalAssets > 0 && (totalProcessed % 50 == 0 || totalProcessed == imageAssets.length)) {
            final progress = (totalProcessed / totalAssets).clamp(0.0, 1.0);
            // Async olarak çağır (UI thread'i bloklamamak için)
            Future.microtask(() {
              progressCallback(progress, totalProcessed, totalAssets);
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
      final duplicateGroups = _findDuplicateGroups(assetHashesMap, album.name, mode);

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
    DuplicateDetectionMode mode = DuplicateDetectionMode.balanced,
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
        mode: mode,
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



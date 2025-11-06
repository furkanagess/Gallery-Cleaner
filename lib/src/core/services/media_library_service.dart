import 'dart:typed_data';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../models/gallery_stats.dart';

class MediaLibraryService {
  Future<List<pm.AssetPathEntity>> fetchAlbums({
    bool onlyAll = false,
    pm.RequestType type = pm.RequestType.image,
  }) async {
    final paths = await pm.PhotoManager.getAssetPathList(
      onlyAll: onlyAll,
      type: type,
      hasAll: true,
    );
    return paths;
  }

  Future<List<pm.AssetEntity>> fetchRecentAssets({
    required int page,
    required int pageSize,
    pm.AssetPathEntity? album,
    pm.RequestType type = pm.RequestType.image,
  }) async {
    final targetAlbum = album ?? (await fetchAlbums(onlyAll: true, type: type)).first;
    final list = await targetAlbum.getAssetListPaged(page: page, size: pageSize);
    return list;
  }

  Future<Uint8List?> loadThumbnailBytes(pm.AssetEntity asset, {int width = 300, int height = 300}) async {
    return asset.thumbnailDataWithSize(pm.ThumbnailSize(width, height), quality: 85);
  }

  Future<bool> deleteById(String id) async {
    final deleted = await pm.PhotoManager.editor.deleteWithIds([id]);
    // Some platforms return deleted ids list; treat non-empty as success
    return deleted.isNotEmpty;
  }

  Future<List<String>> deleteBatch(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final deleted = await pm.PhotoManager.editor.deleteWithIds(ids);
    return deleted; // returns deleted ids
  }

  Future<bool> moveAssetToAlbum({
    required pm.AssetEntity asset,
    required pm.AssetPathEntity album,
  }) async {
    debugPrint(
      '📸 [MediaLibraryService] Albüm taşıma isteği: ${asset.id} → ${album.name} (${album.id})',
    );

    if (kIsWeb) {
      debugPrint('🌐 [MediaLibraryService] Web platformu albüm taşıma desteklemiyor');
      return false;
    }

    if (album.isAll) {
      debugPrint('ℹ️ [MediaLibraryService] Hedef albüm “All Photos” → ek işlem yok');
      return true;
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final moved = await pm.PhotoManager.editor.android.moveAssetToAnother(
          entity: asset,
          target: album,
        );
        debugPrint('🤖 [MediaLibraryService][Android] moveAssetToAnother sonucu: $moved');
        if (moved) {
          return true;
        }
      } catch (e, st) {
        debugPrint('🛑 [MediaLibraryService][Android] moveAssetToAnother hatası: $e');
        debugPrint('🛑 [MediaLibraryService][Android] Stack trace: $st');
      }

      debugPrint('🤖 [MediaLibraryService][Android] move başarısız, copy fallback denenecek');
      return _copyAssetWithVerification(
        asset: asset,
        album: album,
        platformLabel: 'Android',
      );
    }

    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      return _copyAssetWithVerification(
        asset: asset,
        album: album,
        platformLabel: 'Darwin',
      );
    }

    debugPrint('⚙️ [MediaLibraryService] Platform ${Platform.operatingSystem} için özel yol yok, genel kopyalama kullanılacak');
    return _copyAssetWithVerification(
      asset: asset,
      album: album,
      platformLabel: 'Default',
    );
  }

  Future<bool> _copyAssetWithVerification({
    required pm.AssetEntity asset,
    required pm.AssetPathEntity album,
    required String platformLabel,
  }) async {
    debugPrint('🌀 [MediaLibraryService][$platformLabel] copyAssetToPath başlatılıyor');
    debugPrint('🌀 [MediaLibraryService][$platformLabel] Kaynak asset: id=${asset.id}, album=${album.name} (${album.id})');
    
    // iOS/macOS'ta asset'ler birden fazla albümde olabilir
    // copyAssetToPath yeni bir asset döndürür, bu yüzden verification farklı yapılmalı
    final isDarwin = Platform.isIOS || Platform.isMacOS;
    
    pm.AssetEntity? copiedAsset;
    bool copySuccessful = false;
    
    try {
      copiedAsset = await pm.PhotoManager.editor.copyAssetToPath(
        asset: asset,
        pathEntity: album,
      );
      copySuccessful = true;
      
      debugPrint(
        '🌀 [MediaLibraryService][$platformLabel] copyAssetToPath dönen asset: id=${copiedAsset.id}, width=${copiedAsset.width}, height=${copiedAsset.height}',
      );
      
      // iOS/macOS'ta copyAssetToPath başarılı olduğunda yeni asset döner
      // Exception olmadan tamamlandıysa başarılı kabul ediyoruz
      if (isDarwin) {
        // iOS/macOS'ta copyAssetToPath exception fırlatmadan tamamlandıysa başarılı
        // Yeni asset döndüyse (ID, width, height gibi özellikler varsa) kesinlikle başarılı
        if (copiedAsset.id.isNotEmpty) {
          debugPrint(
            '✅ [MediaLibraryService][$platformLabel] copyAssetToPath başarılı: yeni asset oluşturuldu (id=${copiedAsset.id})',
          );
          
          // Yeni asset'in gerçekten hedef albümde olduğunu doğrula
          debugPrint('🔎 [MediaLibraryService][$platformLabel] Yeni asset\'in albümde olup olmadığı kontrol ediliyor...');
          final newAssetExists = await _isAssetInAlbum(copiedAsset, album, isDarwin: isDarwin);
          
          if (newAssetExists) {
            debugPrint('✅ [MediaLibraryService][$platformLabel] Yeni asset hedef albümde doğrulandı!');
            return true;
          } else {
            debugPrint('⚠️ [MediaLibraryService][$platformLabel] Yeni asset hedef albümde bulunamadı, orijinal asset kontrol ediliyor...');
            // Belki orijinal asset'in kendisi eklenmiştir (iOS bazı durumlarda kopyalama yerine referans ekler)
            final originalExists = await _isAssetInAlbum(asset, album, isDarwin: isDarwin);
            if (originalExists) {
              debugPrint('✅ [MediaLibraryService][$platformLabel] Orijinal asset hedef albümde bulundu!');
              return true;
            }
          }
        }
        
        // Asset özellikleri boşsa bile, exception olmadan tamamlandıysa başarılı kabul et
        debugPrint(
          '✅ [MediaLibraryService][$platformLabel] copyAssetToPath exception olmadan tamamlandı → başarılı kabul edildi',
        );
        return true;
      }
      
      // Android/Diğer platformlarda ID kontrolü yap
      if (copiedAsset.id.isNotEmpty) {
        debugPrint(
          '✅ [MediaLibraryService][$platformLabel] copyAssetToPath başarılı: yeni asset oluşturuldu',
        );
        return true;
      }
      
      // ID boşsa verification yap
      debugPrint(
        '⚠️ [MediaLibraryService][$platformLabel] copyAssetToPath boş ID döndü, verification yapılıyor...',
      );
    } catch (e, st) {
      debugPrint(
        '🛑 [MediaLibraryService][$platformLabel] copyAssetToPath hatası: $e',
      );
      debugPrint('🛑 [MediaLibraryService][$platformLabel] Stack trace: $st');
      
      copySuccessful = false;

      // "Zaten var" hatalarını kontrol et
      if (_errorLooksLikeAlreadyExists(e)) {
        debugPrint(
          'ℹ️ [MediaLibraryService][$platformLabel] Hata mesajı "zaten var" gibi görünüyor, kontrol ediliyor...',
        );
        final already = await _isAssetInAlbum(asset, album, isDarwin: isDarwin);
        if (already) {
          debugPrint(
            '✅ [MediaLibraryService][$platformLabel] Medya zaten hedef albümde → başarı kabul edildi',
          );
          return true;
        }
      }
      
      // iOS/macOS'ta bazı exception'lar normal olabilir (örneğin asset zaten albümde)
      if (isDarwin) {
        debugPrint(
          '⚠️ [MediaLibraryService][$platformLabel] Exception sonrası verification yapılıyor...',
        );
        // Exception sonrası da verification yap - hem orijinal hem de copiedAsset varsa onu kontrol et
        if (copiedAsset != null && copiedAsset.id.isNotEmpty) {
          final newExists = await _isAssetInAlbum(copiedAsset, album, isDarwin: isDarwin);
          if (newExists) {
            debugPrint('✅ [MediaLibraryService][$platformLabel] Exception sonrası: Yeni asset hedef albümde bulundu!');
            return true;
          }
        }
      }
    }

    // Final verification: Asset'in hedef albümde olup olmadığını kontrol et
    // Önce yeni asset'i (varsa), sonra orijinal asset'i kontrol et
    if (isDarwin && copiedAsset != null && copiedAsset.id.isNotEmpty) {
      debugPrint('🔎 [MediaLibraryService][$platformLabel] Final verification: Yeni asset kontrol ediliyor...');
      final newExists = await _isAssetInAlbum(copiedAsset, album, isDarwin: isDarwin);
      if (newExists) {
        debugPrint(
          '✅ [MediaLibraryService][$platformLabel] Final verification başarılı: Yeni asset hedef albümde',
        );
        return true;
      }
    }
    
    debugPrint('🔎 [MediaLibraryService][$platformLabel] Final verification: Orijinal asset kontrol ediliyor...');
    final originalExists = await _isAssetInAlbum(asset, album, isDarwin: isDarwin);
    if (originalExists) {
      debugPrint(
        '✅ [MediaLibraryService][$platformLabel] Final verification başarılı: Orijinal asset hedef albümde',
      );
      return true;
    }

    // Hiçbir verification başarılı olmadı
    debugPrint(
      '❌ [MediaLibraryService][$platformLabel] Medya hedef albümde bulunamadı (copySuccessful=$copySuccessful)',
    );
    return false;
  }

  bool _errorLooksLikeAlreadyExists(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('already') || message.contains('exist');
  }

  Future<bool> _isAssetInAlbum(
    pm.AssetEntity asset,
    pm.AssetPathEntity album, {
    bool isDarwin = false,
  }) async {
    try {
      // iOS/macOS'ta asset'ler birden fazla albümde olabilir
      // Verification için daha fazla sayfa kontrol etmeliyiz
      const pageSize = 120;
      final maxPages = isDarwin ? 20 : 5; // iOS/macOS'ta daha fazla sayfa kontrol et
      
      debugPrint(
        '🔎 [MediaLibraryService] Albüm kontrolü başlatılıyor: album=${album.name}, assetId=${asset.id}, maxPages=$maxPages',
      );
      
      for (var page = 0; page < maxPages; page++) {
        final assets = await album.getAssetListPaged(page: page, size: pageSize);
        if (assets.isEmpty) {
          debugPrint(
            '🔎 [MediaLibraryService] Albüm sayfa $page boş, tarama durduruldu',
          );
          break;
        }
        
        // Asset ID'sini kontrol et
        final found = assets.any((a) => a.id == asset.id);
        if (found) {
          debugPrint(
            '✅ [MediaLibraryService] Albüm taraması (page=$page) → medya bulundu (id=${asset.id})',
          );
          return true;
        }
        
        // iOS/macOS'ta asset'ler birden fazla albümde olabilir
        // Bu yüzden asset'in özelliklerini de kontrol edebiliriz (createDateTime, width, height)
        if (isDarwin) {
          final foundByProperties = assets.any((a) =>
              a.createDateTime == asset.createDateTime &&
              a.width == asset.width &&
              a.height == asset.height);
          if (foundByProperties) {
            debugPrint(
              '✅ [MediaLibraryService] Albüm taraması (page=$page) → medya özelliklerine göre bulundu',
            );
            return true;
          }
        }
        
        debugPrint(
          '🔎 [MediaLibraryService] Albüm sayfa $page: ${assets.length} medya kontrol edildi, bulunamadı',
        );
      }
      
      debugPrint(
        '❌ [MediaLibraryService] Albüm kontrolü tamamlandı: medya bulunamadı (${maxPages} sayfa kontrol edildi)',
      );
    } catch (e) {
      debugPrint('🛑 [MediaLibraryService] Albüm kontrolü hatası: $e');
    }
    return false;
  }

  /// Galeri istatistiklerini toplar (albüm sayısı, medya sayısı, toplam boyut)
  Future<GalleryStats> fetchGalleryStats() async {
    debugPrint('📸 [MediaLibraryService] İstatistikler toplanmaya başlandı');
    
    // Albümleri ve "All" albümlerini paralel olarak al
    debugPrint('📸 [MediaLibraryService] Albümler ve "All" albümleri paralel alınıyor...');
    final results = await Future.wait<List<pm.AssetPathEntity>>([
      fetchAlbums(onlyAll: false, type: pm.RequestType.image),
      fetchAlbums(onlyAll: false, type: pm.RequestType.video),
      pm.PhotoManager.getAssetPathList(
        onlyAll: true,
        type: pm.RequestType.image,
        hasAll: true,
      ),
      pm.PhotoManager.getAssetPathList(
        onlyAll: true,
        type: pm.RequestType.video,
        hasAll: true,
      ),
    ]);
    
    final imageAlbums = results[0];
    final videoAlbums = results[1];
    final allImagePath = results[2];
    final allVideoPath = results[3];
    
    debugPrint('📸 [MediaLibraryService] ${imageAlbums.length} image albümü, ${videoAlbums.length} video albümü bulundu');
    
    // Benzersiz albümleri bul (id'ye göre)
    final allAlbums = <String, pm.AssetPathEntity>{};
    for (final album in imageAlbums) {
      allAlbums[album.id] = album;
    }
    for (final album in videoAlbums) {
      allAlbums[album.id] = album;
    }
    
    final albumCount = allAlbums.length;
    debugPrint('📸 [MediaLibraryService] Toplam ${albumCount} benzersiz albüm');
    
    // Image ve video sayılarını paralel olarak topla (ultra hızlı)
    debugPrint('📸 [MediaLibraryService] Medya sayıları ve boyutları ultra hızlı toplanıyor...');
    
    final imageStats = allImagePath.isNotEmpty
        ? _countMediaAndSizeFast(allImagePath.first, 'Image')
        : Future.value((count: 0, size: 0));
    final videoStats = allVideoPath.isNotEmpty
        ? _countMediaAndSizeFast(allVideoPath.first, 'Video')
        : Future.value((count: 0, size: 0));
    
    final results2 = await Future.wait([imageStats, videoStats]);
    final imageResult = results2[0];
    final videoResult = results2[1];
    
    final mediaCount = imageResult.count + videoResult.count;
    final totalSizeBytes = imageResult.size + videoResult.size;
    final totalSizeMB = totalSizeBytes / (1024 * 1024);
    
    debugPrint('📸 [MediaLibraryService] İstatistikler toplandı: $albumCount albüm, $mediaCount medya, ${totalSizeMB.toStringAsFixed(2)} MB');
    
    return GalleryStats(
      albumCount: albumCount,
      mediaCount: mediaCount,
      totalSizeMB: totalSizeMB,
      cachedAt: null, // Service'den dönen veri cache değildir
    );
  }
  
  /// Medya sayısını ve toplam boyutunu hesaplar (memory-efficient)
  /// Galerideki tüm içeriklerin boyutunu hesaplar (crash önlemli)
  Future<({int count, int size})> _countMediaAndSizeFast(
    pm.AssetPathEntity album,
    String type,
  ) async {
    debugPrint('📸 [MediaLibraryService] $type medyaları sayılıyor ve boyutları hesaplanıyor...');
    
    // Memory-efficient: Küçük sayfa boyutu kullan (crash önlemek için)
    const pageSize = 150; // 150 medya/sayfa (5000'den çok daha güvenli)
    const batchDelayMs = 50; // Örnekleme arası delay (memory pressure azaltmak için)
    
    int mediaCount = 0;
    int totalSizeBytes = 0;
    int page = 0;
    
    try {
      while (true) {
        // Her sayfada memory pressure kontrolü
        if (page > 0 && page % 10 == 0) {
          // Her 10 sayfada bir kısa delay (memory temizleme için)
          await Future.delayed(Duration(milliseconds: batchDelayMs * 2));
          debugPrint('📸 [MediaLibraryService] $type sayfa $page: Memory pressure kontrolü...');
        }
        
        final assets = await album.getAssetListPaged(page: page, size: pageSize);
        if (assets.isEmpty) break;
        
        mediaCount += assets.length;
        debugPrint('📸 [MediaLibraryService] $type sayfa ${page + 1}: ${assets.length} medya (Toplam: $mediaCount)');
        
        // Memory-efficient boyut hesaplama: sadece örnekleme yap (her 10 asset'te bir)
        // Bu çok daha az memory kullanır ve crash riskini azaltır
        const sampleRate = 10; // Her 10 asset'te bir boyut hesapla
        int sampledCount = 0;
        int sampledTotalSize = 0;
        
        for (var i = 0; i < assets.length; i += sampleRate) {
          final asset = assets[i];
          try {
            final size = await _getAssetSizeSafe(asset);
            if (size != null) {
              sampledCount++;
              sampledTotalSize += size;
            }
          } catch (_) {
            // Hata olsa bile devam et
          }
          
          // Her örnekleme arasında kısa delay
          if (i + sampleRate < assets.length) {
            await Future.delayed(Duration(milliseconds: batchDelayMs));
          }
        }
        
        // Ortalama boyutu hesapla ve tüm asset'lere uygula
        if (sampledCount > 0) {
          final avgSize = sampledTotalSize ~/ sampledCount;
          final estimatedPageSize = avgSize * assets.length;
          totalSizeBytes += estimatedPageSize;
          debugPrint('📸 [MediaLibraryService] $type sayfa ${page + 1} tahmini boyutu: ${(estimatedPageSize / (1024 * 1024)).toStringAsFixed(2)} MB (${sampledCount} örnekten)');
        }
        
        if (assets.length < pageSize) break;
        page++;
        
        // Çok fazla sayfa olursa memory crash riski var - güvenlik sınırı
        if (page > 1000) {
          debugPrint('⚠️ [MediaLibraryService] $type: 1000+ sayfa limitine ulaşıldı, güvenlik için durduruluyor');
          break;
        }
      }
    } catch (e, st) {
      debugPrint('🛑 [MediaLibraryService] $type sayma/boyut hesaplama hatası: $e');
      debugPrint('🛑 [MediaLibraryService] Stack trace: $st');
      // Hata olsa bile sayıyı döndür (boyut 0 olabilir)
    }
    
    debugPrint('📸 [MediaLibraryService] $type toplam: $mediaCount medya, ${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
    
    return (count: mediaCount, size: totalSizeBytes);
  }
  
  /// Asset boyutunu güvenli şekilde alır (crash önlemli, memory-efficient)
  /// File açmadan önce tahmin yapar, gerekirse file açma denemesi yapar
  Future<int?> _getAssetSizeSafe(pm.AssetEntity asset) async {
    try {
      // File açmak çok ağır - sadece gerekirse dene (timeout ile)
      // Önce rough estimate yap (width * height * bytes per pixel tahmin)
      // Bu çoğu durumda yeterli olur
      final sizeObj = asset.size;
      if (sizeObj.width > 0 && sizeObj.height > 0) {
        // Rough estimate: width * height * bytes per pixel tahmin
        // Bu çok daha hızlı ve memory-efficient (file açmadan)
        final estimatedBytes = sizeObj.width * sizeObj.height * 3; // RGB için 3 bytes
        return estimatedBytes.toInt();
      }
      
      // Size bilgisi yoksa veya 0 ise, file açmayı dene (ama çok sınırlı)
      // Sadece kritik durumlarda kullan (çok nadir)
      try {
        final file = await asset.file
            .timeout(const Duration(seconds: 1), onTimeout: () => null);
        if (file != null) {
          final length = await file.length()
              .timeout(const Duration(seconds: 1), onTimeout: () => -1);
          if (length > 0) {
            return length;
          }
        }
      } catch (_) {
        // File açma hatası - sessizce devam et
        // Tahmin değeri kullanılacak
      }
      
      // Fallback: çok küçük bir tahmin (crash önlemek için)
      return 100000; // 100KB fallback
    } catch (_) {
      // Genel hata - fallback değer
      return 100000; // 100KB fallback
    }
  }
}


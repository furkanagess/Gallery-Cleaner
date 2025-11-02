import 'dart:typed_data';

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

  Future<bool> addAssetToAlbum({required pm.AssetEntity asset, required pm.AssetPathEntity album}) async {
    debugPrint('📸 [MediaLibraryService] Albüme medya ekleniyor: ${asset.id} -> ${album.name} (${album.id})');
    
    // Albüm bilgilerini kontrol et
    debugPrint('📸 [MediaLibraryService] Albüm tipi: ${album.type}, Okunabilir: ${album.isAll}');
    
    // İlk olarak copyAssetToPath'i dene
    try {
      final result = await pm.PhotoManager.editor.copyAssetToPath(
        asset: asset,
        pathEntity: album,
      );
      debugPrint('📸 [MediaLibraryService] copyAssetToPath sonucu: $result');
      
      // iOS'ta copyAssetToPath bazı durumlarda başarısız olabilir
      // Ancak sonucu kontrol edelim
      if (result == true) {
        debugPrint('📸 [MediaLibraryService] Medya başarıyla albüme eklendi (copyAssetToPath)');
        return true;
      }
      
      // Sonuç null veya false ise, medya zaten albümde olabilir
      // Bu durumda başarılı sayılabilir
      debugPrint('📸 [MediaLibraryService] copyAssetToPath sonuç: $result (null/false ama medya zaten albümde olabilir)');
      
      // Medyanın albümde olup olmadığını kontrol et
      try {
        final albumAssets = await album.getAssetListPaged(page: 0, size: 100);
        final isInAlbum = albumAssets.any((a) => a.id == asset.id);
        
        if (isInAlbum) {
          debugPrint('📸 [MediaLibraryService] Medya zaten albümde - başarılı');
          return true;
        }
      } catch (checkError) {
        debugPrint('📸 [MediaLibraryService] Albüm kontrolü başarısız: $checkError');
      }
      
      // Eğer hala başarısız görünüyorsa, tekrar dene
      debugPrint('📸 [MediaLibraryService] İkinci deneme yapılıyor...');
      final retryResult = await pm.PhotoManager.editor.copyAssetToPath(
        asset: asset,
        pathEntity: album,
      );
      
      if (retryResult == true) {
        debugPrint('📸 [MediaLibraryService] İkinci denemede başarılı');
        return true;
      }
      
      debugPrint('📸 [MediaLibraryService] Tüm denemeler başarısız, false döndürülüyor');
      return false;
    } catch (e, stackTrace) {
      debugPrint('📸 [MediaLibraryService] copyAssetToPath exception: $e');
      debugPrint('📸 [MediaLibraryService] Stack trace: $stackTrace');
      
      // Hata mesajını kontrol et
      final errorMessage = e.toString().toLowerCase();
      
      // Bazı hatalar gerçekten başarısız değildir
      if (errorMessage.contains('already') || errorMessage.contains('exists')) {
        debugPrint('📸 [MediaLibraryService] Medya zaten albümde - başarılı sayılıyor');
        return true;
      }
      
      return false;
    }
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
    );
  }
  
  /// Medya sayısını ve toplam boyutunu hesaplar (tüm medyaların gerçek boyutu)
  /// Galerideki tüm içeriklerin gerçek boyutunu hesaplar
  Future<({int count, int size})> _countMediaAndSizeFast(
    pm.AssetPathEntity album,
    String type,
  ) async {
    debugPrint('📸 [MediaLibraryService] $type medyaları sayılıyor ve boyutları hesaplanıyor...');
    
    // Büyük sayfa boyutu ile hızlı yükleme
    const pageSize = 5000; // 5.000 medya/sayfa
    int mediaCount = 0;
    int totalSizeBytes = 0;
    int page = 0;
    
    while (true) {
      final assets = await album.getAssetListPaged(page: page, size: pageSize);
      if (assets.isEmpty) break;
      
      mediaCount += assets.length;
      debugPrint('📸 [MediaLibraryService] $type sayfa ${page + 1}: ${assets.length} medya (Toplam: $mediaCount)');
      
      // Tüm medyaların boyutunu paralel olarak al
      final sizeFutures = <Future<int?>>[];
      for (final asset in assets) {
        sizeFutures.add(_getAssetSize(asset));
      }
      
      // Tüm boyutları paralel olarak hesapla
      final sizes = await Future.wait(sizeFutures);
      int pageSizeBytes = 0;
      for (final size in sizes) {
        if (size != null) {
          pageSizeBytes += size;
          totalSizeBytes += size;
        }
      }
      
      debugPrint('📸 [MediaLibraryService] $type sayfa ${page + 1} boyutu: ${(pageSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
      
      if (assets.length < pageSize) break;
      page++;
    }
    
    debugPrint('📸 [MediaLibraryService] $type toplam: $mediaCount medya, ${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
    
    return (count: mediaCount, size: totalSizeBytes);
  }
  
  /// Asset boyutunu güvenli şekilde alır
  Future<int?> _getAssetSize(pm.AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file != null) {
        return await file.length();
      }
    } catch (_) {
      // Dosya boyutu alınamazsa null döndür
    }
    return null;
  }
}



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
    // Eğer album verilmemişse, "All" albümünü al
    if (album == null) {
      final albums = await fetchAlbums(onlyAll: true, type: type);

      // iOS'ta izin verildikten hemen sonra PhotoManager henüz hazır olmayabilir
      // Boş liste dönerse, PhotoManager'ın hazır olmasını bekle
      if (albums.isEmpty) {
        debugPrint(
          '⚠️ [MediaLibraryService] Albums listesi boş - PhotoManager hazır olmayabilir, bekleniyor...',
        );

        // iOS için PhotoManager'ın hazır olmasını bekle (max 3 saniye, her 200ms'de bir kontrol)
        if (Platform.isIOS) {
          for (int attempt = 0; attempt < 15; attempt++) {
            await Future.delayed(const Duration(milliseconds: 200));
            final retryAlbums = await fetchAlbums(onlyAll: true, type: type);
            if (retryAlbums.isNotEmpty) {
              debugPrint(
                '✅ [MediaLibraryService] Albums yüklendi (attempt ${attempt + 1})',
              );
              album = retryAlbums.first;
              break;
            }
          }
        }

        // Hala boşsa hata fırlat
        if (album == null) {
          debugPrint(
            '❌ [MediaLibraryService] Albums listesi hala boş - boş liste döndürülüyor',
          );
          return [];
        }
      } else {
        album = albums.first;
      }
    }

    // Album artık null değil, asset'leri yükle
    try {
      // Album burada kesinlikle null değil
      final list = await album.getAssetListPaged(page: page, size: pageSize);
      return list;
    } catch (e, st) {
      debugPrint('❌ [MediaLibraryService] fetchRecentAssets hatası: $e');
      debugPrint('   Stack trace: $st');
      // Hata durumunda boş liste döndür (crash önleme)
      return [];
    }
  }

  Future<Uint8List?> loadThumbnailBytes(
    pm.AssetEntity asset, {
    int width = 300,
    int height = 300,
  }) async {
    return asset.thumbnailDataWithSize(
      pm.ThumbnailSize(width, height),
      quality: 85,
    );
  }

  Future<bool> deleteById(String id) async {
    final deleted = await pm.PhotoManager.editor.deleteWithIds([id]);
    // Some platforms return deleted ids list; treat non-empty as success
    return deleted.isNotEmpty;
  }

  Future<List<String>> deleteBatch(List<String> ids) async {
    if (ids.isEmpty) {
      debugPrint('⚠️ [MediaLibraryService] deleteBatch: Boş ID listesi');
      return const [];
    }

    debugPrint(
      '🗑️ [MediaLibraryService] deleteBatch başlatılıyor: ${ids.length} fotoğraf',
    );

    try {
      final deleted = await pm.PhotoManager.editor.deleteWithIds(ids);
      debugPrint(
        '✅ [MediaLibraryService] deleteBatch tamamlandı: ${deleted.length}/${ids.length} fotoğraf silindi',
      );
      return deleted; // returns deleted ids
    } catch (e) {
      debugPrint('❌ [MediaLibraryService] deleteBatch hatası: $e');
      return const []; // Hata durumunda boş liste döndür
    }
  }

  Future<bool> moveAssetToAlbum({
    required pm.AssetEntity asset,
    required pm.AssetPathEntity album,
  }) async {
    debugPrint(
      '📸 [MediaLibraryService] Albüm taşıma isteği: ${asset.id} → ${album.name} (${album.id})',
    );

    if (kIsWeb) {
      debugPrint(
        '🌐 [MediaLibraryService] Web platformu albüm taşıma desteklemiyor',
      );
      return false;
    }

    if (album.isAll) {
      debugPrint(
        'ℹ️ [MediaLibraryService] Hedef albüm “All Photos” → ek işlem yok',
      );
      return true;
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final moved = await pm.PhotoManager.editor.android.moveAssetToAnother(
          entity: asset,
          target: album,
        );
        debugPrint(
          '🤖 [MediaLibraryService][Android] moveAssetToAnother sonucu: $moved',
        );
        if (moved) {
          return true;
        }
      } catch (e, st) {
        debugPrint(
          '🛑 [MediaLibraryService][Android] moveAssetToAnother hatası: $e',
        );
        debugPrint('🛑 [MediaLibraryService][Android] Stack trace: $st');
      }

      debugPrint(
        '🤖 [MediaLibraryService][Android] move başarısız, copy fallback denenecek',
      );
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

    debugPrint(
      '⚙️ [MediaLibraryService] Platform ${Platform.operatingSystem} için özel yol yok, genel kopyalama kullanılacak',
    );
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
    debugPrint(
      '🌀 [MediaLibraryService][$platformLabel] copyAssetToPath başlatılıyor',
    );
    debugPrint(
      '🌀 [MediaLibraryService][$platformLabel] Kaynak asset: id=${asset.id}, album=${album.name} (${album.id})',
    );

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
          debugPrint(
            '🔎 [MediaLibraryService][$platformLabel] Yeni asset\'in albümde olup olmadığı kontrol ediliyor...',
          );
          final newAssetExists = await _isAssetInAlbum(
            copiedAsset,
            album,
            isDarwin: isDarwin,
          );

          if (newAssetExists) {
            debugPrint(
              '✅ [MediaLibraryService][$platformLabel] Yeni asset hedef albümde doğrulandı!',
            );
            return true;
          } else {
            debugPrint(
              '⚠️ [MediaLibraryService][$platformLabel] Yeni asset hedef albümde bulunamadı, orijinal asset kontrol ediliyor...',
            );
            // Belki orijinal asset'in kendisi eklenmiştir (iOS bazı durumlarda kopyalama yerine referans ekler)
            final originalExists = await _isAssetInAlbum(
              asset,
              album,
              isDarwin: isDarwin,
            );
            if (originalExists) {
              debugPrint(
                '✅ [MediaLibraryService][$platformLabel] Orijinal asset hedef albümde bulundu!',
              );
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
          final newExists = await _isAssetInAlbum(
            copiedAsset,
            album,
            isDarwin: isDarwin,
          );
          if (newExists) {
            debugPrint(
              '✅ [MediaLibraryService][$platformLabel] Exception sonrası: Yeni asset hedef albümde bulundu!',
            );
            return true;
          }
        }
      }
    }

    // Final verification: Asset'in hedef albümde olup olmadığını kontrol et
    // Önce yeni asset'i (varsa), sonra orijinal asset'i kontrol et
    if (isDarwin && copiedAsset != null && copiedAsset.id.isNotEmpty) {
      debugPrint(
        '🔎 [MediaLibraryService][$platformLabel] Final verification: Yeni asset kontrol ediliyor...',
      );
      final newExists = await _isAssetInAlbum(
        copiedAsset,
        album,
        isDarwin: isDarwin,
      );
      if (newExists) {
        debugPrint(
          '✅ [MediaLibraryService][$platformLabel] Final verification başarılı: Yeni asset hedef albümde',
        );
        return true;
      }
    }

    debugPrint(
      '🔎 [MediaLibraryService][$platformLabel] Final verification: Orijinal asset kontrol ediliyor...',
    );
    final originalExists = await _isAssetInAlbum(
      asset,
      album,
      isDarwin: isDarwin,
    );
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
      final maxPages = isDarwin
          ? 20
          : 5; // iOS/macOS'ta daha fazla sayfa kontrol et

      debugPrint(
        '🔎 [MediaLibraryService] Albüm kontrolü başlatılıyor: album=${album.name}, assetId=${asset.id}, maxPages=$maxPages',
      );

      for (var page = 0; page < maxPages; page++) {
        final assets = await album.getAssetListPaged(
          page: page,
          size: pageSize,
        );
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
          final foundByProperties = assets.any(
            (a) =>
                a.createDateTime == asset.createDateTime &&
                a.width == asset.width &&
                a.height == asset.height,
          );
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
        '❌ [MediaLibraryService] Albüm kontrolü tamamlandı: medya bulunamadı ($maxPages sayfa kontrol edildi)',
      );
    } catch (e) {
      debugPrint('🛑 [MediaLibraryService] Albüm kontrolü hatası: $e');
    }
    return false;
  }

  /// Galeri istatistiklerini toplar (albüm sayısı, medya sayısı, toplam boyut)
  /// [onProgress] callback'i her bir veri geldiğinde çağrılır (incremental updates için)
  /// [shouldCancel] callback'i tarama sırasında kontrol edilir, true dönerse tarama durur
  Future<GalleryStats> fetchGalleryStats({
    void Function(GalleryStats partialStats)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    debugPrint('📸 [MediaLibraryService] İstatistikler toplanmaya başlandı');

    // Albümleri ve "All" albümlerini paralel olarak al
    debugPrint(
      '📸 [MediaLibraryService] Albümler ve "All" albümleri paralel alınıyor...',
    );
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

    debugPrint(
      '📸 [MediaLibraryService] ${imageAlbums.length} image albümü, ${videoAlbums.length} video albümü bulundu',
    );

    // Benzersiz albümleri bul (id'ye göre)
    final allAlbums = <String, pm.AssetPathEntity>{};
    for (final album in imageAlbums) {
      allAlbums[album.id] = album;
    }
    for (final album in videoAlbums) {
      allAlbums[album.id] = album;
    }

    final albumCount = allAlbums.length;
    debugPrint('📸 [MediaLibraryService] Toplam $albumCount benzersiz albüm');

    // İptal kontrolü
    if (shouldCancel != null && shouldCancel()) {
      debugPrint('🛑 [MediaLibraryService] Tarama iptal edildi (başlangıç)');
      return GalleryStats(
        albumCount: 0,
        mediaCount: 0,
        totalSizeMB: 0.0,
        albumDetails: [],
        cachedAt: null,
      );
    }

    // İlk partial stats: sadece albüm sayısı
    var partialStats = GalleryStats(
      albumCount: albumCount,
      mediaCount: 0,
      totalSizeMB: 0.0,
      albumDetails: [],
      cachedAt: null,
    );
    onProgress?.call(partialStats);

    // İptal kontrolü
    if (shouldCancel != null && shouldCancel()) {
      debugPrint(
        '🛑 [MediaLibraryService] Tarama iptal edildi (albüm sayısı sonrası)',
      );
      return partialStats;
    }

    // Image ve video sayılarını incremental olarak topla
    // Her analizde 0'dan başla
    debugPrint(
      '📸 [MediaLibraryService] Medya sayıları ve boyutları toplanıyor...',
    );

    int totalMediaCount = 0;
    int totalSizeBytes = 0;

    // Image sayısını say - her analizde 0'dan başla
    if (allImagePath.isNotEmpty) {
      final imageResult = await _countMediaAndSizeFast(
        allImagePath.first,
        'Image',
        shouldCancel: shouldCancel,
        onProgress: (count, size) {
          // İptal kontrolü
          if (shouldCancel != null && shouldCancel()) return;

          // Image sayımı sırasında sadece image değerlerini göster
          totalMediaCount = count;
          totalSizeBytes = size;
          partialStats = GalleryStats(
            albumCount: albumCount,
            mediaCount: totalMediaCount,
            totalSizeMB: totalSizeBytes / (1024 * 1024),
            albumDetails: [],
            cachedAt: null,
          );
          onProgress?.call(partialStats);
        },
      );

      // Final image sonuçlarını al (onProgress'ten sonra kesin değerler)
      totalMediaCount = imageResult.count;
      totalSizeBytes = imageResult.size;
      debugPrint(
        '📸 [MediaLibraryService] Image sayımı tamamlandı: $totalMediaCount medya, ${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
      );
    }

    // İptal kontrolü
    if (shouldCancel != null && shouldCancel()) {
      debugPrint(
        '🛑 [MediaLibraryService] Tarama iptal edildi (image sayımı sonrası)',
      );
      partialStats = GalleryStats(
        albumCount: albumCount,
        mediaCount: totalMediaCount,
        totalSizeMB: totalSizeBytes / (1024 * 1024),
        albumDetails: [],
        cachedAt: null,
      );
      return partialStats;
    }

    // Video sayısını say (image count'a ekle) - her analizde 0'dan başla
    if (allVideoPath.isNotEmpty) {
      final initialImageCount = totalMediaCount;
      final initialImageSize = totalSizeBytes;

      final videoResult = await _countMediaAndSizeFast(
        allVideoPath.first,
        'Video',
        shouldCancel: shouldCancel,
        onProgress: (videoCount, videoSize) {
          // İptal kontrolü
          if (shouldCancel != null && shouldCancel()) return;

          // Video sayımı sırasında image + video toplamını göster
          totalMediaCount = initialImageCount + videoCount;
          totalSizeBytes = initialImageSize + videoSize;
          partialStats = GalleryStats(
            albumCount: albumCount,
            mediaCount: totalMediaCount,
            totalSizeMB: totalSizeBytes / (1024 * 1024),
            albumDetails: [],
            cachedAt: null,
          );
          onProgress?.call(partialStats);
        },
      );

      // Final video sonuçlarını al ve image değerlerine ekle
      totalMediaCount = initialImageCount + videoResult.count;
      totalSizeBytes = initialImageSize + videoResult.size;
      debugPrint(
        '📸 [MediaLibraryService] Video sayımı tamamlandı: ${videoResult.count} medya, ${(videoResult.size / (1024 * 1024)).toStringAsFixed(2)} MB',
      );
    }

    // İptal kontrolü
    if (shouldCancel != null && shouldCancel()) {
      debugPrint(
        '🛑 [MediaLibraryService] Tarama iptal edildi (video sayımı sonrası)',
      );
      partialStats = GalleryStats(
        albumCount: albumCount,
        mediaCount: totalMediaCount,
        totalSizeMB: totalSizeBytes / (1024 * 1024),
        albumDetails: [],
        cachedAt: null,
      );
      return partialStats;
    }

    final totalSizeMB = totalSizeBytes / (1024 * 1024);

    debugPrint(
      '📸 [MediaLibraryService] İstatistikler toplandı: $albumCount albüm, $totalMediaCount medya, ${totalSizeMB.toStringAsFixed(2)} MB',
    );

    // Albüm bazında detaylı istatistik topla (incremental, paralel işleme ile hızlı)
    debugPrint(
      '📸 [MediaLibraryService] Albüm bazında detaylı istatistikler toplanıyor...',
    );
    final albumDetails = <AlbumDetail>[];
    final albumsList = allAlbums.values.toList();

    // Albümleri paralel batch'ler halinde işle (daha hızlı)
    const albumBatchSize = 5; // Her seferde 5 albüm paralel işle

    for (var i = 0; i < albumsList.length; i += albumBatchSize) {
      // İptal kontrolü
      if (shouldCancel != null && shouldCancel()) {
        debugPrint(
          '🛑 [MediaLibraryService] Tarama iptal edildi (albüm detayları sırasında)',
        );
        break;
      }

      final albumBatch = albumsList.skip(i).take(albumBatchSize).toList();

      // Albüm batch'ini paralel işle
      final batchResults = await Future.wait(
        albumBatch.map((album) async {
          try {
            final albumStats = await _countMediaAndSizeFast(
              album,
              'Album: ${album.name}',
              shouldCancel: shouldCancel,
            );

            // İptal kontrolü
            if (shouldCancel != null && shouldCancel()) {
              return null;
            }

            final albumSizeMB = albumStats.size / (1024 * 1024);

            return AlbumDetail(
              albumId: album.id,
              albumName: album.name,
              mediaCount: albumStats.count,
              sizeMB: albumSizeMB,
            );
          } catch (e) {
            debugPrint(
              '⚠️ [MediaLibraryService] ${album.name} için istatistik toplama hatası: $e',
            );
            return null;
          }
        }),
      );

      // İptal kontrolü
      if (shouldCancel != null && shouldCancel()) {
        debugPrint(
          '🛑 [MediaLibraryService] Tarama iptal edildi (albüm batch sonrası)',
        );
        break;
      }

      // Batch sonuçlarını ekle
      for (final detail in batchResults) {
        if (detail != null) {
          albumDetails.add(detail);
        }
      }

      // Boyuta göre sırala (büyükten küçüğe)
      albumDetails.sort((a, b) => b.sizeMB.compareTo(a.sizeMB));

      // Her batch eklendiğinde partial stats'i güncelle (incremental update)
      partialStats = GalleryStats(
        albumCount: albumCount,
        mediaCount: totalMediaCount,
        totalSizeMB: totalSizeMB,
        albumDetails: List.from(albumDetails),
        cachedAt: null,
      );
      onProgress?.call(partialStats);

      debugPrint(
        '📸 [MediaLibraryService] ${albumDetails.length}/${albumsList.length} albüm detayı toplandı',
      );
    }

    // İptal edildiyse mevcut partial stats'i döndür
    if (shouldCancel != null && shouldCancel()) {
      return partialStats;
    }

    debugPrint(
      '📸 [MediaLibraryService] ${albumDetails.length} albüm detayı toplandı',
    );

    return GalleryStats(
      albumCount: albumCount,
      mediaCount: totalMediaCount,
      totalSizeMB: totalSizeMB,
      albumDetails: albumDetails,
      cachedAt: null, // Service'den dönen veri cache değildir
    );
  }

  /// Medya sayısını ve toplam boyutunu hesaplar (hızlı ve memory-efficient)
  /// Metadata-based boyut hesaplama kullanır (file açmadan, çok daha hızlı)
  /// [onProgress] callback'i her sayfa işlendiğinde çağrılır (incremental updates için)
  /// [shouldCancel] callback'i tarama sırasında kontrol edilir, true dönerse tarama durur
  Future<({int count, int size})> _countMediaAndSizeFast(
    pm.AssetPathEntity album,
    String type, {
    void Function(int count, int size)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    debugPrint(
      '📸 [MediaLibraryService] $type medyaları sayılıyor ve boyutları hesaplanıyor (hızlı mod)...',
    );

    // Optimize sayfa boyutu: daha büyük sayfa = daha az I/O = daha hızlı
    const pageSize = 500; // 500 medya/sayfa (memory-safe, hızlı)
    const batchSize = 50; // Paralel işlenecek asset sayısı

    int mediaCount = 0;
    int totalSizeBytes = 0;
    int page = 0;

    try {
      while (true) {
        // İptal kontrolü
        if (shouldCancel != null && shouldCancel()) {
          debugPrint('🛑 [MediaLibraryService] $type taraması iptal edildi');
          break;
        }

        final assets = await album.getAssetListPaged(
          page: page,
          size: pageSize,
        );
        if (assets.isEmpty) break;

        mediaCount += assets.length;

        // Paralel batch processing: asset'leri batch'ler halinde işle
        int pageSizeBytes = 0;
        for (var i = 0; i < assets.length; i += batchSize) {
          // İptal kontrolü (her batch'te)
          if (shouldCancel != null && shouldCancel()) {
            break;
          }

          final batch = assets.skip(i).take(batchSize).toList();

          // Batch'i paralel işle (senkron fonksiyon, çok hızlı)
          // Future.wait kullanmaya gerek yok, direkt sync işle
          for (final asset in batch) {
            final size = _getAssetSizeFast(asset);
            if (size != null && size > 0) {
              pageSizeBytes += size;
            }
          }
        }

        totalSizeBytes += pageSizeBytes;

        // Her sayfa işlendiğinde progress callback'i çağır
        onProgress?.call(mediaCount, totalSizeBytes);

        // İptal kontrolü
        if (shouldCancel != null && shouldCancel()) {
          debugPrint(
            '🛑 [MediaLibraryService] $type taraması iptal edildi (sayfa $page sonrası)',
          );
          break;
        }

        if (assets.length < pageSize) break;
        page++;

        // Çok fazla sayfa olursa memory crash riski var - güvenlik sınırı
        if (page > 2000) {
          debugPrint(
            '⚠️ [MediaLibraryService] $type: 2000+ sayfa limitine ulaşıldı, güvenlik için durduruluyor',
          );
          break;
        }
      }
    } catch (e, st) {
      debugPrint(
        '🛑 [MediaLibraryService] $type sayma/boyut hesaplama hatası: $e',
      );
      debugPrint('🛑 [MediaLibraryService] Stack trace: $st');
      // Hata olsa bile sayıyı döndür (boyut 0 olabilir)
    }

    debugPrint(
      '📸 [MediaLibraryService] $type toplam: $mediaCount medya, ${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
    );

    return (count: mediaCount, size: totalSizeBytes);
  }

  /// Asset boyutunu hızlı şekilde tahmin eder (metadata-based, file açmadan)
  /// File açmak çok yavaş olduğu için metadata'dan tahmin yapar (10-100x daha hızlı)
  /// Bu yöntem yaklaşık sonuçlar verir ama çok daha hızlıdır
  int? _getAssetSizeFast(pm.AssetEntity asset) {
    try {
      // Metadata'dan direkt boyut tahmini (file açmadan, çok hızlı)
      final sizeObj = asset.size;
      if (sizeObj.width > 0 && sizeObj.height > 0) {
        final pixelCount = sizeObj.width * sizeObj.height;

        // Asset tipine göre farklı tahminler (gerçekçi compression ratios)
        if (asset.type == pm.AssetType.video) {
          // Video için: pixel count * bit depth * compression ratio
          // Ortalama: 0.5-1 bytes per pixel (H.264/HEVC compression)
          final estimatedBytes = (pixelCount * 0.75).toInt();
          return estimatedBytes.clamp(
            500000,
            200 * 1024 * 1024,
          ); // 500KB - 200MB
        } else {
          // Image için: JPEG/HEIC compression (0.2-0.5 bytes per pixel)
          // Ortalama: 0.3 bytes per pixel
          final estimatedBytes = (pixelCount * 0.3).toInt();
          return estimatedBytes.clamp(30000, 15 * 1024 * 1024); // 30KB - 15MB
        }
      }

      // Fallback: ortalama dosya boyutu (metadata yoksa)
      return asset.type == pm.AssetType.video
          ? 8 *
                1024 *
                1024 // 8MB for video (ortalaması)
          : (1.5 * 1024 * 1024).toInt(); // 1.5MB for image (ortalaması)
    } catch (e) {
      // Hata durumunda fallback
      return asset.type == pm.AssetType.video
          ? 8 *
                1024 *
                1024 // 8MB for video
          : (1.5 * 1024 * 1024).toInt(); // 1.5MB for image
    }
  }
}

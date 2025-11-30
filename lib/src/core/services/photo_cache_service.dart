import 'package:hive_flutter/hive_flutter.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../utils/app_logger.dart';

/// Photo cache model (Task 5: Cache/Index sistemi)
class PhotoCacheModel {
  final String assetId;
  final String? dHash;
  final String? dHashVertical;
  final String? pHash;
  final String? aHash;
  final String? md5Hash;
  final double? blurScore;
  final double? pixelationScore;
  final int lastModified; // millisecondsSinceEpoch
  final String? path;

  PhotoCacheModel({
    required this.assetId,
    this.dHash,
    this.dHashVertical,
    this.pHash,
    this.aHash,
    this.md5Hash,
    this.blurScore,
    this.pixelationScore,
    required this.lastModified,
    this.path,
  });

  Map<String, dynamic> toMap() {
    return {
      'assetId': assetId,
      'dHash': dHash,
      'dHashVertical': dHashVertical,
      'pHash': pHash,
      'aHash': aHash,
      'md5Hash': md5Hash,
      'blurScore': blurScore,
      'pixelationScore': pixelationScore,
      'lastModified': lastModified,
      'path': path,
    };
  }

  factory PhotoCacheModel.fromMap(Map<String, dynamic> map) {
    return PhotoCacheModel(
      assetId: map['assetId'] as String,
      dHash: map['dHash'] as String?,
      dHashVertical: map['dHashVertical'] as String?,
      pHash: map['pHash'] as String?,
      aHash: map['aHash'] as String?,
      md5Hash: map['md5Hash'] as String?,
      blurScore: (map['blurScore'] as num?)?.toDouble(),
      pixelationScore: (map['pixelationScore'] as num?)?.toDouble(),
      lastModified: map['lastModified'] as int,
      path: map['path'] as String?,
    );
  }
}

/// Photo cache service (Task 5: Her açılışta sıfırdan tarama yapma → indeksle & cache'le)
class PhotoCacheService {
  static const String _boxName = 'photo_cache';
  Box? _box;
  bool _isInitialized = false;

  /// Hive'ı initialize et
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
      _isInitialized = true;
      AppLogger.i('✅ [PhotoCache] Hive initialized');
    } catch (e) {
      AppLogger.e('❌ [PhotoCache] Hive initialization error: $e');
      _isInitialized = false;
    }
  }

  /// Cache'den photo bilgilerini al
  Future<PhotoCacheModel?> getPhotoCache(String assetId) async {
    if (!_isInitialized || _box == null) {
      await initialize();
      if (!_isInitialized || _box == null) return null;
    }

    try {
      final data = _box!.get(assetId);
      if (data == null) return null;

      if (data is Map) {
        return PhotoCacheModel.fromMap(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      AppLogger.w('⚠️ [PhotoCache] Get cache error: $e');
      return null;
    }
  }

  /// Cache'e photo bilgilerini kaydet
  Future<void> savePhotoCache(PhotoCacheModel cache) async {
    if (!_isInitialized || _box == null) {
      await initialize();
      if (!_isInitialized || _box == null) return;
    }

    try {
      await _box!.put(cache.assetId, cache.toMap());
    } catch (e) {
      AppLogger.w('⚠️ [PhotoCache] Save cache error: $e');
    }
  }

  /// Asset'in lastModified tarihini kontrol et ve cache'deki ile karşılaştır
  /// Eğer değişmişse true döndür (yeniden analiz gerekiyor)
  Future<bool> needsReanalysis(pm.AssetEntity asset) async {
    final cache = await getPhotoCache(asset.id);
    if (cache == null) return true; // Cache'de yok, analiz gerekiyor

    // lastModified tarihini kontrol et
    final assetModified = asset.modifiedDateTime.millisecondsSinceEpoch;
    if (assetModified != cache.lastModified) {
      return true; // Değişmiş, yeniden analiz gerekiyor
    }

    return false; // Değişmemiş, cache'den kullanılabilir
  }

  /// Sadece değişen veya yeni eklenen asset'leri filtrele
  /// Task 5: Sonraki açılışlarda sadece "lastModified tarihi değişmiş veya yeni eklenen" fotoğrafları yeniden analiz et
  Future<List<pm.AssetEntity>> filterNewOrModifiedAssets(
    List<pm.AssetEntity> assets,
  ) async {
    final filtered = <pm.AssetEntity>[];

    for (final asset in assets) {
      final needsReanalysis = await this.needsReanalysis(asset);
      if (needsReanalysis) {
        filtered.add(asset);
      }
    }

    return filtered;
  }

  /// Cache'i temizle
  Future<void> clearCache() async {
    if (!_isInitialized || _box == null) {
      await initialize();
      if (!_isInitialized || _box == null) return;
    }

    try {
      await _box!.clear();
      AppLogger.i('✅ [PhotoCache] Cache cleared');
    } catch (e) {
      AppLogger.w('⚠️ [PhotoCache] Clear cache error: $e');
    }
  }

  /// Cache'den asset'i sil
  Future<void> deletePhotoCache(String assetId) async {
    if (!_isInitialized || _box == null) {
      await initialize();
      if (!_isInitialized || _box == null) return;
    }

    try {
      await _box!.delete(assetId);
    } catch (e) {
      AppLogger.w('⚠️ [PhotoCache] Delete cache error: $e');
    }
  }

  /// Cache istatistikleri
  Future<Map<String, dynamic>> getCacheStats() async {
    if (!_isInitialized || _box == null) {
      await initialize();
      if (!_isInitialized || _box == null) {
        return {'count': 0, 'size': 0};
      }
    }

    try {
      final count = _box!.length;
      // Approximate size (bytes)
      int size = 0;
      for (final key in _box!.keys) {
        final value = _box!.get(key);
        if (value is Map) {
          size += value.toString().length;
        }
      }
      return {'count': count, 'size': size};
    } catch (e) {
      AppLogger.w('⚠️ [PhotoCache] Get stats error: $e');
      return {'count': 0, 'size': 0};
    }
  }
}

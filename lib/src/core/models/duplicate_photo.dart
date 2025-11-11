import 'package:photo_manager/photo_manager.dart' as pm;

/// Duplicate fotoğraf grubu modeli
class DuplicatePhotoGroup {
  final String hash;
  final List<pm.AssetEntity> assets;
  final double totalSizeMB;
  final String? albumName;

  const DuplicatePhotoGroup({
    required this.hash,
    required this.assets,
    required this.totalSizeMB,
    this.albumName,
  });

  /// Korunacak fotoğraf (en eski)
  pm.AssetEntity get keepAsset {
    final sorted = List<pm.AssetEntity>.from(assets)
      ..sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
    return sorted.first;
  }

  /// Silinecek fotoğraflar
  List<pm.AssetEntity> get duplicatesToDelete {
    if (assets.length <= 1) return [];
    final sorted = List<pm.AssetEntity>.from(assets)
      ..sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
    return sorted.skip(1).toList();
  }

  /// Silinecek fotoğraf sayısı
  int get duplicateCount => duplicatesToDelete.length;

  /// Toplam kazanılacak alan (MB)
  double get spaceToSaveMB {
    if (duplicatesToDelete.isEmpty) return 0.0;
    // En eski fotoğraf hariç diğerlerinin toplam boyutu
    double totalSize = 0.0;
    for (final asset in duplicatesToDelete) {
      try {
        final size = asset.size;
        final estimatedBytes = size.width * size.height * 3;
        totalSize += estimatedBytes / (1024 * 1024);
      } catch (_) {
        // Hata durumunda devam et
      }
    }
    return totalSize;
  }
}


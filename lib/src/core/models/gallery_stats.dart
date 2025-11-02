class GalleryStats {
  final int albumCount;
  final int mediaCount; // fotoğraf + video
  final double totalSizeMB; // toplam boyut MB cinsinden

  const GalleryStats({
    required this.albumCount,
    required this.mediaCount,
    required this.totalSizeMB,
  });
}


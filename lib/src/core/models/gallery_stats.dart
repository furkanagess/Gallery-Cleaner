class GalleryStats {
  final int albumCount;
  final int mediaCount; // fotoğraf + video
  final double totalSizeMB; // toplam boyut MB cinsinden
  final DateTime? cachedAt; // Cache zamanı (opsiyonel)

  const GalleryStats({
    required this.albumCount,
    required this.mediaCount,
    required this.totalSizeMB,
    this.cachedAt,
  });

  // JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'albumCount': albumCount,
      'mediaCount': mediaCount,
      'totalSizeMB': totalSizeMB,
      'cachedAt': cachedAt?.toIso8601String(),
    };
  }

  // JSON'dan oluştur
  factory GalleryStats.fromJson(Map<String, dynamic> json) {
    return GalleryStats(
      albumCount: json['albumCount'] as int,
      mediaCount: json['mediaCount'] as int,
      totalSizeMB: (json['totalSizeMB'] as num).toDouble(),
      cachedAt: json['cachedAt'] != null
          ? DateTime.parse(json['cachedAt'] as String)
          : null,
    );
  }

  // Cache'den kopyala
  GalleryStats copyWith({
    int? albumCount,
    int? mediaCount,
    double? totalSizeMB,
    DateTime? cachedAt,
  }) {
    return GalleryStats(
      albumCount: albumCount ?? this.albumCount,
      mediaCount: mediaCount ?? this.mediaCount,
      totalSizeMB: totalSizeMB ?? this.totalSizeMB,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}


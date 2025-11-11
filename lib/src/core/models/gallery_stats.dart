class AlbumDetail {
  final String albumId;
  final String albumName;
  final int mediaCount;
  final double sizeMB;

  const AlbumDetail({
    required this.albumId,
    required this.albumName,
    required this.mediaCount,
    required this.sizeMB,
  });

  Map<String, dynamic> toJson() => {
        'albumId': albumId,
        'albumName': albumName,
        'mediaCount': mediaCount,
        'sizeMB': sizeMB,
      };

  factory AlbumDetail.fromJson(Map<String, dynamic> json) => AlbumDetail(
        albumId: json['albumId'] as String,
        albumName: json['albumName'] as String,
        mediaCount: json['mediaCount'] as int,
        sizeMB: (json['sizeMB'] as num).toDouble(),
      );
}

class GalleryStats {
  final int albumCount;
  final int mediaCount; // fotoğraf + video
  final double totalSizeMB; // toplam boyut MB cinsinden
  final List<AlbumDetail> albumDetails; // Albüm bazında detaylar
  final DateTime? cachedAt; // Cache zamanı (opsiyonel)

  const GalleryStats({
    required this.albumCount,
    required this.mediaCount,
    required this.totalSizeMB,
    this.albumDetails = const [],
    this.cachedAt,
  });

  // JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'albumCount': albumCount,
      'mediaCount': mediaCount,
      'totalSizeMB': totalSizeMB,
      'albumDetails': albumDetails.map((e) => e.toJson()).toList(),
      'cachedAt': cachedAt?.toIso8601String(),
    };
  }

  // JSON'dan oluştur
  factory GalleryStats.fromJson(Map<String, dynamic> json) {
    final detailsJson = json['albumDetails'] as List<dynamic>?;
    return GalleryStats(
      albumCount: json['albumCount'] as int,
      mediaCount: json['mediaCount'] as int,
      totalSizeMB: (json['totalSizeMB'] as num).toDouble(),
      albumDetails: detailsJson != null
          ? detailsJson.map((e) => AlbumDetail.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
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
    List<AlbumDetail>? albumDetails,
    DateTime? cachedAt,
  }) {
    return GalleryStats(
      albumCount: albumCount ?? this.albumCount,
      mediaCount: mediaCount ?? this.mediaCount,
      totalSizeMB: totalSizeMB ?? this.totalSizeMB,
      albumDetails: albumDetails ?? this.albumDetails,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}


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
  final int photoCount; // sadece fotoğraf sayısı
  final int videoCount; // sadece video sayısı
  final double totalSizeMB; // toplam boyut MB cinsinden
  final double photoSizeMB; // sadece fotoğrafların boyutu MB cinsinden
  final double videoSizeMB; // sadece videoların boyutu MB cinsinden
  final List<AlbumDetail> albumDetails; // Albüm bazında detaylar
  final DateTime? cachedAt; // Cache zamanı (opsiyonel)

  const GalleryStats({
    required this.albumCount,
    required this.mediaCount,
    this.photoCount = 0,
    this.videoCount = 0,
    required this.totalSizeMB,
    this.photoSizeMB = 0.0,
    this.videoSizeMB = 0.0,
    this.albumDetails = const [],
    this.cachedAt,
  });

  // JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'albumCount': albumCount,
      'mediaCount': mediaCount,
      'photoCount': photoCount,
      'videoCount': videoCount,
      'totalSizeMB': totalSizeMB,
      'photoSizeMB': photoSizeMB,
      'videoSizeMB': videoSizeMB,
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
      photoCount: (json['photoCount'] as int?) ?? 0,
      videoCount: (json['videoCount'] as int?) ?? 0,
      totalSizeMB: (json['totalSizeMB'] as num).toDouble(),
      photoSizeMB: (json['photoSizeMB'] as num?)?.toDouble() ?? 0.0,
      videoSizeMB: (json['videoSizeMB'] as num?)?.toDouble() ?? 0.0,
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
    int? photoCount,
    int? videoCount,
    double? totalSizeMB,
    double? photoSizeMB,
    double? videoSizeMB,
    List<AlbumDetail>? albumDetails,
    DateTime? cachedAt,
  }) {
    return GalleryStats(
      albumCount: albumCount ?? this.albumCount,
      mediaCount: mediaCount ?? this.mediaCount,
      photoCount: photoCount ?? this.photoCount,
      videoCount: videoCount ?? this.videoCount,
      totalSizeMB: totalSizeMB ?? this.totalSizeMB,
      photoSizeMB: photoSizeMB ?? this.photoSizeMB,
      videoSizeMB: videoSizeMB ?? this.videoSizeMB,
      albumDetails: albumDetails ?? this.albumDetails,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}


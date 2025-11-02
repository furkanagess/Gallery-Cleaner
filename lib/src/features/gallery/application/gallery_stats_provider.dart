import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/gallery_stats.dart';
import '../application/gallery_providers.dart';
import '../../onboarding/application/permissions_controller.dart';

/// Galeri istatistiklerini toplar ve sağlar
final galleryStatsProvider = FutureProvider<GalleryStats?>((ref) async {
  debugPrint('📊 [GalleryStats] Provider başlatıldı');
  
  // İzin durumunu watch et - değiştiğinde otomatik yeniden yüklenecek
  final permission = ref.watch(permissionsControllerProvider);
  debugPrint('📊 [GalleryStats] Permission durumu: $permission');
  
  // İzin verilmemişse null döndür
  if (permission != GalleryPermissionStatus.authorized) {
    debugPrint('📊 [GalleryStats] İzin verilmedi, null döndürülüyor');
    return null;
  }
  
  // İzin verilmişse istatistikleri yükle
  try {
    debugPrint('📊 [GalleryStats] İzin verildi, istatistikler yükleniyor...');
    final service = ref.watch(mediaLibraryServiceProvider);
    final stats = await service.fetchGalleryStats();
    debugPrint('📊 [GalleryStats] İstatistikler başarıyla yüklendi: ${stats.albumCount} albüm, ${stats.mediaCount} medya, ${stats.totalSizeMB.toStringAsFixed(2)} MB');
    return stats;
  } catch (e, stackTrace) {
    debugPrint('❌ [GalleryStats] Hata oluştu: $e');
    debugPrint('❌ [GalleryStats] Stack trace: $stackTrace');
    // Hata durumunda exception fırlat (FutureProvider error state'e geçer)
    // Bu sayede UI hata durumunu görebilir
    throw Exception('Galeri istatistikleri yüklenirken hata oluştu: $e');
  }
});


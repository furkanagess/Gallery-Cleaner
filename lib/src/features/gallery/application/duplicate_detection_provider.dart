import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import '../../../core/services/duplicate_detection_service.dart';
import '../../../core/models/duplicate_photo.dart';
import '../../../core/services/preferences_service.dart';

export '../../../core/services/duplicate_detection_service.dart' show DuplicateDetectionMode;
import '../../onboarding/application/permissions_controller.dart';
import '../../onboarding/application/onboarding_controller.dart';
import 'gallery_providers.dart';

final duplicateDetectionServiceProvider =
    Provider<DuplicateDetectionService>((ref) {
  return DuplicateDetectionService();
});

/// Duplicate detection state
class DuplicateDetectionState {
  final Map<String, List<DuplicatePhotoGroup>> duplicatesByAlbum;
  final bool isScanning;
  final double progress;
  final String? currentAlbum;
  final Object? error;
  final bool hasCompletedScan; // Tarama tamamlandı mı?
  final int processedCount; // İşlenen fotoğraf sayısı
  final int totalCount; // Toplam fotoğraf sayısı

  const DuplicateDetectionState({
    this.duplicatesByAlbum = const {},
    this.isScanning = false,
    this.progress = 0.0,
    this.currentAlbum,
    this.error,
    this.hasCompletedScan = false,
    this.processedCount = 0,
    this.totalCount = 0,
  });

  DuplicateDetectionState copyWith({
    Map<String, List<DuplicatePhotoGroup>>? duplicatesByAlbum,
    bool? isScanning,
    double? progress,
    String? currentAlbum,
    Object? error,
    bool clearError = false,
    bool? hasCompletedScan,
    int? processedCount,
    int? totalCount,
  }) {
    return DuplicateDetectionState(
      duplicatesByAlbum: duplicatesByAlbum ?? this.duplicatesByAlbum,
      isScanning: isScanning ?? this.isScanning,
      progress: progress ?? this.progress,
      currentAlbum: currentAlbum ?? this.currentAlbum,
      error: clearError ? null : (error ?? this.error),
      hasCompletedScan: hasCompletedScan ?? this.hasCompletedScan,
      processedCount: processedCount ?? this.processedCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  /// Toplam duplicate grup sayısı
  int get totalGroups {
    return duplicatesByAlbum.values.fold<int>(
      0,
      (sum, groups) => sum + groups.length,
    );
  }

  /// Toplam duplicate fotoğraf sayısı
  int get totalDuplicatePhotos {
    return duplicatesByAlbum.values.fold<int>(
      0,
      (sum, groups) => sum + groups.fold<int>(
            0,
            (groupSum, group) => groupSum + group.duplicateCount,
          ),
    );
  }

  /// Toplam kazanılacak alan (MB)
  double get totalSpaceToSaveMB {
    return duplicatesByAlbum.values.fold<double>(
      0.0,
      (sum, groups) => sum + groups.fold<double>(
            0.0,
            (groupSum, group) => groupSum + group.spaceToSaveMB,
          ),
    );
  }
}

class DuplicateDetectionNotifier extends StateNotifier<DuplicateDetectionState> {
  DuplicateDetectionNotifier(this.ref) : super(const DuplicateDetectionState());

  final Ref ref;
  bool _isCancelled = false;
  
  // Progress callback throttling - %1 artışlarla güncelleme
  DateTime? _lastProgressUpdate;
  int _lastProgressPercent = -1; // Son gösterilen yüzde değeri
  static const _progressThrottleMs = 50; // Her 50ms'de bir kontrol et

  /// Belirli albümlerde duplicate taraması yap
  Future<void> scanAlbums(
    List<pm.AssetPathEntity> albums, {
    DuplicateDetectionMode mode = DuplicateDetectionMode.balanced,
  }) async {
    debugPrint('🚀 [DuplicateDetection] scanAlbums çağrıldı - Albüm sayısı: ${albums.length}');
    
    final permission = ref.read(permissionsControllerProvider);
    debugPrint('🔐 [DuplicateDetection] İzin durumu: $permission');
    
    if (permission != GalleryPermissionStatus.authorized) {
      debugPrint('❌ [DuplicateDetection] İzin yok! Tarama durduruldu.');
      state = state.copyWith(
        error: 'Permission not granted',
        isScanning: false,
      );
      return;
    }

    debugPrint('✅ [DuplicateDetection] İzin var, tarama başlatılıyor...');
    
    _isCancelled = false;
    _lastProgressPercent = -1; // Progress takibini sıfırla
    _lastProgressUpdate = null; // Zaman takibini sıfırla
    state = state.copyWith(
      isScanning: true,
      progress: 0.0,
      clearError: true,
      duplicatesByAlbum: {},
      hasCompletedScan: false, // Yeni tarama başladığında false yap
      processedCount: 0,
      totalCount: 0,
      currentAlbum: null, // Başlangıçta albüm bilgisi yok
    );

    try {
      debugPrint('📦 [DuplicateDetection] Service alınıyor...');
      final service = ref.read(duplicateDetectionServiceProvider);
      debugPrint('📦 [DuplicateDetection] Service alındı: ${service.runtimeType}');
      
      // Premium kontrolü
      final prefsService = ref.read(preferencesServiceProvider);
      final isPremium = await prefsService.isPremium();
      debugPrint('💎 [DuplicateDetection] Premium durumu: $isPremium');
      
      // Kalan duplicate scan hakkını al (premium değilse)
      int remainingScanLimit = 999999999; // Premium için sınırsız
      if (!isPremium) {
        remainingScanLimit = await prefsService.getDuplicateScanLimit();
        debugPrint('📊 [DuplicateDetection] Kalan duplicate scan hakkı: $remainingScanLimit');
      }

      debugPrint('🔍 [DuplicateDetection] findDuplicatesInAlbums çağrılıyor... (maxScanLimit: $remainingScanLimit, mode: $mode)');
      final scanResult = await service.findDuplicatesInAlbums(
        albums,
        mode: mode,
        progressCallback: (albumName, progress, processedCount, totalCount) {
          if (_isCancelled) return;
          
          // Progress'i %1 artışlarla güncelle (0%, 1%, 2%, 3% şeklinde)
          final currentProgressPercent = (progress * 100).floor(); // Yüzdeyi tam sayıya yuvarla
          final now = DateTime.now();
          final timeDelta = _lastProgressUpdate != null 
              ? now.difference(_lastProgressUpdate!).inMilliseconds 
              : _progressThrottleMs + 1;
          
          // %1 artış olduğunda veya zaman aşımında güncelle
          if (currentProgressPercent > _lastProgressPercent || timeDelta >= _progressThrottleMs) {
            _lastProgressUpdate = now;
            _lastProgressPercent = currentProgressPercent;
            
            // State güncellemesini frame callback ile yap (UI thread'i bloklamamak için)
            SchedulerBinding.instance.scheduleFrameCallback((_) {
              if (!_isCancelled) {
                state = state.copyWith(
                  progress: progress,
                  currentAlbum: albumName,
                  processedCount: processedCount,
                  totalCount: totalCount,
                );
              }
            });
          }
        },
        shouldCancel: () => _isCancelled,
        isPremium: isPremium,
        maxScanLimit: remainingScanLimit,
      );
      
      final results = scanResult.results;
      final scannedPhotoCount = scanResult.scannedPhotoCount;
      
      if (_isCancelled) {
        debugPrint('⚠️ [DuplicateDetection] Tarama iptal edildi');
        state = state.copyWith(
          isScanning: false,
          progress: 0.0,
          currentAlbum: null,
          processedCount: 0,
          totalCount: 0,
        );
        return;
      }

      debugPrint('✅ [DuplicateDetection] Tarama tamamlandı! Bulunan albüm sayısı: ${results.length}, Scan edilen fotoğraf: $scannedPhotoCount');
      
      // Boş olmayan sonuçları filtrele
      final filteredResults = <String, List<DuplicatePhotoGroup>>{};
      int totalGroups = 0;
      int totalPhotos = 0;
      
      for (final entry in results.entries) {
        // Boş olmayan grupları filtrele
        final nonEmptyGroups = entry.value.where((group) => 
          group.assets.isNotEmpty && group.assets.length > 1
        ).toList();
        
        if (nonEmptyGroups.isNotEmpty) {
          filteredResults[entry.key] = nonEmptyGroups;
          totalGroups += nonEmptyGroups.length;
          
          debugPrint('   📁 ${entry.key}: ${nonEmptyGroups.length} duplicate grup');
          for (final group in nonEmptyGroups) {
            totalPhotos += group.assets.length;
            debugPrint('      - Grup: ${group.assets.length} fotoğraf, ${group.duplicateCount} silinecek, Hash: ${group.hash.substring(0, 8)}...');
          }
        } else {
          debugPrint('   ⚠️ ${entry.key}: Tüm gruplar boş veya geçersiz, atlanıyor');
        }
      }

      debugPrint('📊 [DuplicateDetection] Toplam istatistikler:');
      debugPrint('   - Orijinal albüm sayısı: ${results.length}');
      debugPrint('   - Filtrelenmiş albüm sayısı: ${filteredResults.length}');
      debugPrint('   - Duplicate grup sayısı: $totalGroups');
      debugPrint('   - Toplam fotoğraf sayısı: $totalPhotos');

      // Duplicate scan limit'i düşür - SADECE sonuç bulunduysa
      final hasResults = filteredResults.isNotEmpty && totalGroups > 0;
      if (!isPremium && scannedPhotoCount > 0 && hasResults) {
        try {
          final prefsService = PreferencesService();
          await prefsService.decreaseDuplicateScanLimit(scannedPhotoCount);
          ref.invalidate(duplicateScanLimitProvider);
          debugPrint('💾 [DuplicateDetection] Duplicate scan limit düşürüldü: $scannedPhotoCount fotoğraf (sonuç bulundu)');
        } catch (e) {
          debugPrint('⚠️ [DuplicateDetection] Duplicate scan limit düşürülemedi: $e');
        }
      } else if (!hasResults) {
        debugPrint('✅ [DuplicateDetection] Sonuç bulunamadı, duplicate scan limit azaltılmadı');
      }

      // State'i güncelle - YENİ bir Map ve State objesi oluştur
      // Bu, Riverpod'ın state değişikliğini algılaması için önemli
      final newResultsMap = Map<String, List<DuplicatePhotoGroup>>.from(filteredResults);
      
      final newState = DuplicateDetectionState(
        duplicatesByAlbum: newResultsMap,
        isScanning: false,
        progress: 1.0,
        currentAlbum: null,
        error: null,
        hasCompletedScan: true, // Tarama tamamlandı
        processedCount: scannedPhotoCount,
        totalCount: scannedPhotoCount, // Tamamlandığında eşit olur
      );
      
      debugPrint('✅ [DuplicateDetection] Yeni state oluşturuldu:');
      debugPrint('   - duplicatesByAlbum size: ${newState.duplicatesByAlbum.length}');
      debugPrint('   - totalGroups: ${newState.totalGroups}');
      debugPrint('   - totalDuplicatePhotos: ${newState.totalDuplicatePhotos}');
      debugPrint('   - totalSpaceToSaveMB: ${newState.totalSpaceToSaveMB.toStringAsFixed(2)}');
      
      // State'i güncelle - bu Riverpod'ı notify edecek
      state = newState;
      debugPrint('✅ [DuplicateDetection] State başarıyla güncellendi!');
      
      // State güncellemesinden sonra bir kez daha kontrol et
      Future.microtask(() {
        debugPrint('🔍 [DuplicateDetection] Microtask - State kontrolü:');
        debugPrint('   - duplicatesByAlbum.length: ${state.duplicatesByAlbum.length}');
        debugPrint('   - totalGroups: ${state.totalGroups}');
      });
    } catch (e, stackTrace) {
      debugPrint('❌ [DuplicateDetection] Hata: $e');
      debugPrint('❌ [DuplicateDetection] Stack trace: $stackTrace');
      state = state.copyWith(
        error: e,
        isScanning: false,
        currentAlbum: null,
        processedCount: 0,
        totalCount: 0,
      );
    }
  }

  /// Belirli bir albümde duplicate taraması yap
  Future<void> scanAlbum(pm.AssetPathEntity album) async {
    await scanAlbums([album]);
  }

  /// Seçili albümlerde duplicate taraması yap
  Future<void> scanSelectedAlbums() async {
    final albumsAsync = ref.read(albumsProvider);
    final albums = albumsAsync.asData?.value ?? [];
    if (albums.isEmpty) {
      state = state.copyWith(
        error: 'No albums available',
        isScanning: false,
      );
      return;
    }
    await scanAlbums(albums);
  }

  /// Duplicate fotoğrafları topluca sil
  Future<int> deleteDuplicates(
    List<DuplicatePhotoGroup> groups, {
    int? maxDeleteCount,
  }) async {
    if (groups.isEmpty) return 0;
    
    final service = ref.read(mediaLibraryServiceProvider);

    // Tüm silinecek fotoğraf ID'lerini topla
    final allIdsToDelete = <String>[];
    for (final group in groups) {
      final toDelete = group.duplicatesToDelete;
      if (toDelete.isNotEmpty) {
        allIdsToDelete.addAll(toDelete.map((asset) => asset.id));
      }
    }
    
    if (allIdsToDelete.isEmpty) {
      debugPrint('⚠️ [DuplicateDetection] Silinecek fotoğraf bulunamadı');
      return 0;
    }
    
    // Eğer maxDeleteCount belirtilmişse, sadece o kadar sil
    final idsToDelete = maxDeleteCount != null && allIdsToDelete.length > maxDeleteCount
        ? allIdsToDelete.take(maxDeleteCount).toList()
        : allIdsToDelete;
    
    debugPrint('🗑️ [DuplicateDetection] Toplu silme başlatılıyor: ${idsToDelete.length} fotoğraf (${groups.length} grup)');
    
    try {
      // Toplu silme işlemi - tüm ID'leri tek seferde sil
      final deletedIds = await service.deleteBatch(idsToDelete);
      final deletedCount = deletedIds.length;
      
      debugPrint('✅ [DuplicateDetection] ${deletedCount}/${idsToDelete.length} fotoğraf başarıyla silindi');
      
      // Silinmek istenen grupların hash'lerini topla (referans eşitliği yerine)
      final groupsToDeleteHash = groups.map((g) => g.hash).toSet();

    // State'i güncelle - silinen grupları kaldır
    final updatedMap = <String, List<DuplicatePhotoGroup>>{};
      
    for (final entry in state.duplicatesByAlbum.entries) {
        final updatedGroups = entry.value.where((group) {
          // Eğer bu grup silinmek istenen gruplar içindeyse, kaldır
          if (groupsToDeleteHash.contains(group.hash)) {
            return false;
          }
          // Grup hala geçerli
          return true;
        }).toList();
        
        if (updatedGroups.isNotEmpty) {
          updatedMap[entry.key] = updatedGroups;
      }
    }

      // State'i güncelle
    state = state.copyWith(duplicatesByAlbum: updatedMap);
      
      debugPrint('💾 [DuplicateDetection] State güncellendi: ${updatedMap.length} albüm kaldı');

    return deletedCount;
    } catch (e) {
      debugPrint('❌ [DuplicateDetection] Toplu silme hatası: $e');
      return 0;
    }
  }

  /// Tüm duplicate fotoğrafları sil
  Future<int> deleteAllDuplicates({int? maxDeleteCount}) async {
    final allGroups = state.duplicatesByAlbum.values
        .expand((groups) => groups)
        .toList();
    return await deleteDuplicates(allGroups, maxDeleteCount: maxDeleteCount);
  }

  /// Taramayı iptal et
  void cancel() {
    debugPrint('🛑 [DuplicateDetection] Tarama iptal ediliyor...');
    _isCancelled = true;
    state = state.copyWith(
      isScanning: false,
      progress: 0.0,
      currentAlbum: null,
      processedCount: 0,
      totalCount: 0,
    );
  }

  /// State'i temizle
  void clear() {
    _isCancelled = false;
    state = const DuplicateDetectionState();
  }
}

final duplicateDetectionProvider = StateNotifierProvider<
    DuplicateDetectionNotifier, DuplicateDetectionState>((ref) {
  return DuplicateDetectionNotifier(ref);
});


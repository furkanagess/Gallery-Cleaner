import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'gallery_providers.dart';
import 'review_history_controller.dart';

class PendingDeleteAction {
  PendingDeleteAction({required this.asset});
  final pm.AssetEntity asset;
}

class ReviewActionsController extends StateNotifier<List<PendingDeleteAction>> {
  ReviewActionsController(this._ref) : super(const []);

  final Ref _ref;
  final List<String> _pendingDeleteIds = [];
  bool _isApplying = false;

  Future<void> onKeep(pm.AssetEntity asset) async {
    HapticFeedback.lightImpact();
    // Dosya boyutunu al
    final file = await asset.file;
    final fileSize = file != null ? await file.length() : 0;
    _ref.read(reviewHistoryControllerProvider.notifier).addKeep(
      asset.id,
      fileSizeBytes: fileSize,
    );
  }

  Future<void> onDelete(pm.AssetEntity asset) async {
    HapticFeedback.heavyImpact();
    // Only queue delete - visual is immediate via card animation
    // Real deletion happens when user taps "Apply"
    // Dosya boyutunu al
    final file = await asset.file;
    final fileSize = file != null ? await file.length() : 0;
    _ref.read(reviewHistoryControllerProvider.notifier).addDeletePending(
      asset.id,
      fileSizeBytes: fileSize,
    );
    state = [...state, PendingDeleteAction(asset: asset)];
    
    // Add to batch queue (no automatic deletion)
    _pendingDeleteIds.add(asset.id);
  }

  void undoLast() {
    if (state.isEmpty) return;
    final last = state.last;
    _pendingDeleteIds.remove(last.asset.id);
    state = [...state]..removeLast();
    HapticFeedback.selectionClick();
    _ref.read(reviewHistoryControllerProvider.notifier).undoDelete(last.asset.id);
  }

  Future<int> _applyBatchDelete({int? maxDeleteCount}) async {
    if (_pendingDeleteIds.isEmpty || _isApplying) return 0;
    
    _isApplying = true;
    
    // Delete limit kontrolü: Eğer maxDeleteCount belirtilmişse, sadece o kadar sil
    final allPendingIds = List<String>.from(_pendingDeleteIds);
    final idsToDelete = maxDeleteCount != null && allPendingIds.length > maxDeleteCount
        ? allPendingIds.take(maxDeleteCount).toList()
        : allPendingIds;
    
    // Geri kalan ID'leri (limit'ten fazla olanlar) sakla - bunlar state'te kalacak
    final remainingIds = maxDeleteCount != null && allPendingIds.length > maxDeleteCount
        ? allPendingIds.skip(maxDeleteCount).toList()
        : <String>[];
    
    // Silinecek ID'leri pending listesinden çıkar
    for (final id in idsToDelete) {
      _pendingDeleteIds.remove(id);
    }
    
    try {
      debugPrint('🗑️ [ReviewActionsController] Toplu silme başlatılıyor: ${idsToDelete.length} fotoğraf');
      debugPrint('🗑️ [ReviewActionsController] Pending IDs: ${idsToDelete.join(", ")}');
      debugPrint('🗑️ [ReviewActionsController] State length: ${state.length}');
      
      // Use batch delete - Android may still show dialogs per item due to OS restrictions
      final service = _ref.read(mediaLibraryServiceProvider);
      final deletedIds = await service.deleteBatch(idsToDelete);
      
      debugPrint('📊 [ReviewActionsController] deleteBatch sonucu: ${deletedIds.length}/${idsToDelete.length} fotoğraf silindi');
      debugPrint('📊 [ReviewActionsController] Silinen ID\'ler: ${deletedIds.join(", ")}');
      
      // Only process successfully deleted items
      final successfulIds = Set<String>.from(deletedIds);
      final rejectedIds = idsToDelete.where((id) => !successfulIds.contains(id)).toList();
      
      debugPrint('📊 [ReviewActionsController] Silme sonuçları: ${successfulIds.length} başarılı, ${rejectedIds.length} reddedildi, ${idsToDelete.length} toplam denenen');
      
      if (rejectedIds.isNotEmpty) {
        debugPrint('⚠️ [ReviewActionsController] ${rejectedIds.length} fotoğraf silinemedi (kullanıcı reddetti veya hata oluştu)');
        debugPrint('⚠️ [ReviewActionsController] Reddedilen ID\'ler: ${rejectedIds.join(", ")}');
      }
      
      // Eğer hiç fotoğraf silinmediyse, rejected ID'leri geri ekle ve 0 döndür
      if (successfulIds.isEmpty) {
        debugPrint('⚠️ [ReviewActionsController] Hiç fotoğraf silinmedi, rejected ID\'ler geri ekleniyor');
        _pendingDeleteIds.addAll(rejectedIds);
        // Rejected items'ı state'te tut (henüz silinmediler)
        return 0;
      }
      
      // State'i güncellemeden ÖNCE, silinecek asset'leri bul
      // Çünkü state'i güncelledikten sonra asset'leri bulamayabiliriz
      final assetsToDelete = <String, PendingDeleteAction>{};
      final foundIds = <String>[];
      final notFoundIds = <String>[];
      
      for (final id in successfulIds) {
        try {
          final pendingAction = state.firstWhere(
            (e) => e.asset.id == id,
            orElse: () => throw StateError('Asset not found in pending list: $id'),
          );
          assetsToDelete[id] = pendingAction;
          foundIds.add(id);
        } catch (e) {
          debugPrint('⚠️ [ReviewActionsController] Asset bulunamadı: $id, $e');
          notFoundIds.add(id);
          // Asset bulunamadıysa, successfulIds'den çıkar
          successfulIds.remove(id);
        }
      }
      
      debugPrint('📊 [ReviewActionsController] Asset bulma sonuçları: ${foundIds.length} bulundu, ${notFoundIds.length} bulunamadı');
      if (notFoundIds.isNotEmpty) {
        debugPrint('⚠️ [ReviewActionsController] Bulunamayan ID\'ler: ${notFoundIds.join(", ")}');
      }
      
      // Eğer hiç asset bulunamadıysa, rejected ID'leri geri ekle ve 0 döndür
      if (assetsToDelete.isEmpty) {
        debugPrint('⚠️ [ReviewActionsController] Silinecek asset bulunamadı, işlem iptal ediliyor');
        // Rejected items'ı geri ekle
        _pendingDeleteIds.addAll(rejectedIds);
        // Bulunamayan ID'leri de geri ekle (belki state'te yoktur)
        _pendingDeleteIds.addAll(notFoundIds);
        return 0;
      }
      
      // Eğer bazı ID'ler bulunamadıysa, bunları rejected ID'lere ekle
      if (notFoundIds.isNotEmpty) {
        rejectedIds.addAll(notFoundIds);
        debugPrint('⚠️ [ReviewActionsController] Bulunamayan ${notFoundIds.length} ID rejected listesine eklendi');
      }
      
      // State'i güncelle: Silinen fotoğrafları state'ten çıkar
      // Geri kalan fotoğraflar (limit'ten fazla olanlar) state'te kalacak
      final updatedState = state.where((action) {
        // Silinen fotoğrafları state'ten çıkar
        return !successfulIds.contains(action.asset.id);
      }).toList();
      
      debugPrint('📊 [ReviewActionsController] State güncelleniyor: ${state.length} -> ${updatedState.length} (${successfulIds.length} fotoğraf silindi)');
      
      // State'i güncelle
      state = updatedState;
      
      // Mark successfully deleted items as applied and save thumbnails
      // Thumbnail alma işlemini async olarak yap, ancak silme işlemini engellemesin
      final thumbnailFutures = <Future<void>>[];
      for (final id in successfulIds) {
        final pendingAction = assetsToDelete[id];
        if (pendingAction == null) {
          debugPrint('⚠️ [ReviewActionsController] PendingAction null: $id');
          continue;
        }
        
        // Thumbnail alma işlemini başlat (await etmeden)
        final future = _saveThumbnailAndMarkApplied(id, pendingAction);
        thumbnailFutures.add(future);
      }
      
      // Tüm thumbnail işlemlerini bekle (paralel olarak çalışır)
      await Future.wait(thumbnailFutures);
      
      debugPrint('✅ [ReviewActionsController] Tüm thumbnail işlemleri tamamlandı');
      
      // Re-add rejected items to queue (user denied in system dialog)
      if (rejectedIds.isNotEmpty) {
        _pendingDeleteIds.addAll(rejectedIds);
        // Mark rejected items as undone so they remain in queue
        for (final id in rejectedIds) {
          _ref.read(reviewHistoryControllerProvider.notifier).undoDelete(id);
        }
        
        // Rejected items zaten state'te kalmalı (henüz silinmediler)
        // State'i güncellerken sadece successfulIds'i çıkardık, rejected items state'te kaldı
      }
      
      // Geri kalan fotoğraflar (limit'ten fazla olanlar) zaten state'te kaldı
      // Çünkü state'i güncellerken sadece silinen fotoğrafları çıkardık
      if (remainingIds.isNotEmpty) {
        debugPrint('💾 [ReviewActionsController] ${assetsToDelete.length} fotoğraf silindi. ${remainingIds.length} fotoğraf limit nedeniyle state\'te kaldı (sonraki silme işleminde silinebilir).');
      } else {
        debugPrint('💾 [ReviewActionsController] ${assetsToDelete.length} fotoğraf silindi.');
      }
      
      // Silinen fotoğraf sayısını hesapla (sadece başarıyla silinen ve asset'i bulunanlar)
      final deletedCount = assetsToDelete.length;
      final totalRejected = rejectedIds.length;
      debugPrint('✅ [ReviewActionsController] Silme işlemi tamamlandı: $deletedCount fotoğraf başarıyla silindi (toplam denenen: ${idsToDelete.length}, reddedilen: $totalRejected)');
      
      // Eğer deletedCount 0 ise, bir sorun var demektir
      if (deletedCount == 0) {
        debugPrint('❌ [ReviewActionsController] deletedCount 0, bu beklenmeyen bir durum!');
        debugPrint('❌ [ReviewActionsController] Rejected IDs: ${rejectedIds.join(", ")}');
        debugPrint('❌ [ReviewActionsController] NotFound IDs: ${notFoundIds.join(", ")}');
        // Rejected items'ı geri ekle
        _pendingDeleteIds.addAll(rejectedIds);
        return 0;
      }
      
      debugPrint('✅ [ReviewActionsController] Başarıyla silinen fotoğraf sayısı: $deletedCount');
      return deletedCount;
    } catch (e) {
      // On error, re-add all IDs to queue (user can retry)
      _pendingDeleteIds.addAll(idsToDelete);
      _pendingDeleteIds.addAll(remainingIds);
      // Mark as undone so they can be retried
      for (final id in idsToDelete) {
        _ref.read(reviewHistoryControllerProvider.notifier).undoDelete(id);
      }
      debugPrint('❌ [ReviewActionsController] Silme hatası: $e');
      return 0;
    } finally {
      _isApplying = false;
    }
  }

  Future<int> applyPendingDeletes({int? maxDeleteCount}) async {
    return await _applyBatchDelete(maxDeleteCount: maxDeleteCount);
  }
  
  /// Thumbnail'i kaydet ve silme işlemini işaretle (helper method)
  Future<void> _saveThumbnailAndMarkApplied(String id, PendingDeleteAction pendingAction) async {
        Uint8List? thumbnailBytes;
        try {
          // Silinen fotoğraflar için daha küçük thumbnail kullan (200x240)
          thumbnailBytes = await pendingAction.asset.thumbnailDataWithSize(
            const pm.ThumbnailSize(200, 240),
            quality: 75,
          );
          
          // Thumbnail başarıyla alındı, kontrol et
          if (thumbnailBytes == null || thumbnailBytes.isEmpty) {
            debugPrint('⚠️ [ReviewActionsController] Thumbnail boş: $id');
            // Tekrar dene, daha küçük boyutla
            try {
              thumbnailBytes = await pendingAction.asset.thumbnailDataWithSize(
                const pm.ThumbnailSize(150, 180),
                quality: 70,
              );
            } catch (e2) {
              debugPrint('❌ [ReviewActionsController] Thumbnail alınamadı (2. deneme): $id, $e2');
            }
          }
        } catch (e) {
          debugPrint('❌ [ReviewActionsController] Thumbnail alınamadı: $id, $e');
          // Hata olsa bile devam et, thumbnail olmadan da kaydet
        }
        
        // Thumbnail olsa da olmasa da kaydet
    try {
        await _ref.read(reviewHistoryControllerProvider.notifier).markDeleteApplied(
          id,
          thumbnailBytes: thumbnailBytes,
        );
      debugPrint('✅ [ReviewActionsController] Silme işlemi kaydedildi: $id');
    } catch (e) {
      debugPrint('❌ [ReviewActionsController] Silme işlemi kaydedilemedi: $id, $e');
    }
  }
}

final reviewActionsControllerProvider =
    StateNotifierProvider<ReviewActionsController, List<PendingDeleteAction>>((ref) {
  return ReviewActionsController(ref);
});



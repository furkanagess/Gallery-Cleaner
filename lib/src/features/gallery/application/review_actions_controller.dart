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

  Future<int> _applyBatchDelete() async {
    if (_pendingDeleteIds.isEmpty || _isApplying) return 0;
    
    _isApplying = true;
    final ids = List<String>.from(_pendingDeleteIds);
    _pendingDeleteIds.clear();
    
    try {
      // Use batch delete - Android may still show dialogs per item due to OS restrictions
      final service = _ref.read(mediaLibraryServiceProvider);
      final deletedIds = await service.deleteBatch(ids);
      
      // Only process successfully deleted items
      final successfulIds = Set<String>.from(deletedIds);
      final rejectedIds = ids.where((id) => !successfulIds.contains(id)).toList();
      
      // Mark successfully deleted items as applied and save thumbnails
      for (final id in successfulIds) {
        // Find the asset to get thumbnail before deletion
        final pendingAction = state.firstWhere(
          (e) => e.asset.id == id,
          orElse: () => throw StateError('Asset not found in pending list'),
        );
        
        // Get thumbnail before marking as applied - küçük boyut kullan (daha hızlı ve daha az yer kaplar)
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
          } else {
            debugPrint('✅ [ReviewActionsController] Thumbnail başarıyla alındı: $id, boyut: ${thumbnailBytes.length} bytes');
          }
        } catch (e) {
          debugPrint('❌ [ReviewActionsController] Thumbnail alınamadı: $id, $e');
          // Hata olsa bile devam et, thumbnail olmadan da kaydet
        }
        
        // Thumbnail olsa da olmasa da kaydet
        await _ref.read(reviewHistoryControllerProvider.notifier).markDeleteApplied(
          id,
          thumbnailBytes: thumbnailBytes,
        );
        // Remove from pending state
        final copy = [...state];
        copy.removeWhere((e) => e.asset.id == id);
        state = copy;
      }
      
      // Re-add rejected items to queue (user denied in system dialog)
      if (rejectedIds.isNotEmpty) {
        _pendingDeleteIds.addAll(rejectedIds);
        // Mark rejected items as undone so they remain in queue
        for (final id in rejectedIds) {
          _ref.read(reviewHistoryControllerProvider.notifier).undoDelete(id);
        }
      }
      
      return successfulIds.length;
    } catch (e) {
      // On error, re-add all IDs to queue (user can retry)
      _pendingDeleteIds.addAll(ids);
      // Mark as undone so they can be retried
      for (final id in ids) {
        _ref.read(reviewHistoryControllerProvider.notifier).undoDelete(id);
      }
      return 0;
    } finally {
      _isApplying = false;
    }
  }

  Future<int> applyPendingDeletes() async {
    return await _applyBatchDelete();
  }
}

final reviewActionsControllerProvider =
    StateNotifierProvider<ReviewActionsController, List<PendingDeleteAction>>((ref) {
  return ReviewActionsController(ref);
});



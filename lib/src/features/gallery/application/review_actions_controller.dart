import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import '../../../core/services/media_library_service.dart';
import '../../../core/services/preferences_service.dart';
import 'review_history_controller.dart';
import 'asset_size_helper.dart';

class PendingDeleteAction {
  PendingDeleteAction({required this.asset, required this.fileSizeBytes});

  final pm.AssetEntity asset;
  final int fileSizeBytes;
}

class DeleteResult {
  DeleteResult({required this.deletedCount, required this.deletedSizeMB});

  final int deletedCount;
  final double deletedSizeMB;
}

class ReviewActionsCubit extends Cubit<List<PendingDeleteAction>> {
  ReviewActionsCubit({
    required MediaLibraryService mediaLibraryService,
    required ReviewHistoryCubit reviewHistoryCubit,
    PreferencesService? preferencesService,
  }) : _mediaLibraryService = mediaLibraryService,
       _historyCubit = reviewHistoryCubit,
       _preferencesService = preferencesService,
       super(const []);

  final MediaLibraryService _mediaLibraryService;
  final ReviewHistoryCubit _historyCubit;
  final PreferencesService? _preferencesService;
  final List<String> _pendingDeleteIds = [];
  bool _isApplying = false;

  Future<void> onKeep(pm.AssetEntity asset) async {
    HapticFeedback.lightImpact();
    final fileSize = await estimateAssetSize(asset);
    _historyCubit.addKeep(asset.id, fileSizeBytes: fileSize);
  }

  Future<void> onDelete(pm.AssetEntity asset) async {
    HapticFeedback.heavyImpact();
    // Only queue delete - visual is immediate via card animation
    // Real deletion happens when user taps "Apply"
    final fileSize = await estimateAssetSize(asset);
    _historyCubit.addDeletePending(asset.id, fileSizeBytes: fileSize);
    emit([
      ...state,
      PendingDeleteAction(asset: asset, fileSizeBytes: fileSize),
    ]);

    // Add to batch queue (no automatic deletion)
    _pendingDeleteIds.add(asset.id);
  }

  Future<void> undoDecision(
    pm.AssetEntity asset, {
    required bool wasKeep,
  }) async {
    if (wasKeep) {
      _historyCubit.undoKeep(asset.id);
      return;
    }

    final updatedState = [...state];
    final removeIndex = updatedState.lastIndexWhere(
      (action) => action.asset.id == asset.id,
    );
    if (removeIndex != -1) {
      updatedState.removeAt(removeIndex);
      emit(updatedState);
    }
    _pendingDeleteIds.remove(asset.id);
    _historyCubit.undoDelete(asset.id);
  }

  void undoLast() {
    if (state.isEmpty) return;
    final last = state.last;
    _pendingDeleteIds.remove(last.asset.id);
    emit([...state]..removeLast());
    HapticFeedback.selectionClick();
    _historyCubit.undoDelete(last.asset.id);
  }

  Future<DeleteResult> _applyBatchDelete({int? maxDeleteCount}) async {
    if (_pendingDeleteIds.isEmpty || _isApplying) {
      return DeleteResult(deletedCount: 0, deletedSizeMB: 0.0);
    }

    _isApplying = true;

    // Delete limit kontrolü: Eğer maxDeleteCount belirtilmişse, sadece o kadar sil
    final allPendingIds = List<String>.from(_pendingDeleteIds);
    final idsToDelete =
        maxDeleteCount != null && allPendingIds.length > maxDeleteCount
        ? allPendingIds.take(maxDeleteCount).toList()
        : allPendingIds;

    // Geri kalan ID'leri (limit'ten fazla olanlar) sakla - bunlar state'te kalacak
    final remainingIds =
        maxDeleteCount != null && allPendingIds.length > maxDeleteCount
        ? allPendingIds.skip(maxDeleteCount).toList()
        : <String>[];

    // Silinecek ID'leri pending listesinden çıkar
    for (final id in idsToDelete) {
      _pendingDeleteIds.remove(id);
    }

    try {
      debugPrint(
        '🗑️ [ReviewActionsController] Toplu silme başlatılıyor: ${idsToDelete.length} fotoğraf',
      );
      debugPrint(
        '🗑️ [ReviewActionsController] Pending IDs: ${idsToDelete.join(", ")}',
      );
      debugPrint('🗑️ [ReviewActionsController] State length: ${state.length}');

      // Silme işleminden önce asset'lerin hala mevcut olup olmadığını kontrol et
      // Zaten silinmiş asset'leri filtrele (tekrar silme hatasını önlemek için)
      final validIdsToDelete = <String>[];
      final alreadyDeletedIds = <String>[];

      for (final id in idsToDelete) {
        try {
          // State'ten asset'i bul
          final pendingAction = state.firstWhere(
            (action) => action.asset.id == id,
            orElse: () => throw StateError('Asset not found in state'),
          );

          // Asset'in hala mevcut olup olmadığını kontrol et
          try {
            final file = await pendingAction.asset.file;
            if (file != null) {
              final exists = await file.exists();
              if (exists) {
                validIdsToDelete.add(id);
              } else {
                // Asset zaten silinmiş
                alreadyDeletedIds.add(id);
                debugPrint(
                  'ℹ️ [ReviewActionsController] Asset zaten silinmiş, atlanıyor: $id',
                );
              }
            } else {
              // File null, muhtemelen silinmiş
              alreadyDeletedIds.add(id);
              debugPrint(
                'ℹ️ [ReviewActionsController] Asset file null, muhtemelen silinmiş: $id',
              );
            }
          } catch (e) {
            // Asset'e erişilemiyor, muhtemelen silinmiş
            alreadyDeletedIds.add(id);
            debugPrint(
              'ℹ️ [ReviewActionsController] Asset\'e erişilemiyor, muhtemelen silinmiş: $id, $e',
            );
          }
        } catch (e) {
          // State'te bulunamadı, muhtemelen zaten işlenmiş
          alreadyDeletedIds.add(id);
          debugPrint(
            'ℹ️ [ReviewActionsController] Asset state\'te bulunamadı: $id, $e',
          );
        }
      }

      if (alreadyDeletedIds.isNotEmpty) {
        debugPrint(
          'ℹ️ [ReviewActionsController] ${alreadyDeletedIds.length} asset zaten silinmiş, atlanıyor',
        );
      }

      if (validIdsToDelete.isEmpty) {
        debugPrint(
          'ℹ️ [ReviewActionsController] Silinecek geçerli asset yok (hepsi zaten silinmiş)',
        );
        return DeleteResult(
          deletedCount: alreadyDeletedIds.length,
          deletedSizeMB: 0.0,
        );
      }

      // Use batch delete - Android may still show dialogs per item due to OS restrictions
      final deletedIds = await _mediaLibraryService.deleteBatch(
        validIdsToDelete,
      );

      // Zaten silinmiş asset'leri de başarılı olarak say
      final allDeletedIds = [...deletedIds, ...alreadyDeletedIds];

      debugPrint(
        '📊 [ReviewActionsController] deleteBatch sonucu: ${deletedIds.length}/${validIdsToDelete.length} fotoğraf silindi (${alreadyDeletedIds.length} zaten silinmişti)',
      );
      debugPrint(
        '📊 [ReviewActionsController] Silinen ID\'ler: ${allDeletedIds.join(", ")}',
      );

      // Only process successfully deleted items
      final successfulIds = Set<String>.from(allDeletedIds);
      final rejectedIds = validIdsToDelete
          .where((id) => !successfulIds.contains(id))
          .toList();

      debugPrint(
        '📊 [ReviewActionsController] Silme sonuçları: ${successfulIds.length} başarılı (${deletedIds.length} yeni silindi, ${alreadyDeletedIds.length} zaten silinmişti), ${rejectedIds.length} reddedildi, ${idsToDelete.length} toplam denenen',
      );

      if (rejectedIds.isNotEmpty) {
        debugPrint(
          '⚠️ [ReviewActionsController] ${rejectedIds.length} fotoğraf silinemedi (kullanıcı reddetti veya hata oluştu)',
        );
        debugPrint(
          '⚠️ [ReviewActionsController] Reddedilen ID\'ler: ${rejectedIds.join(", ")}',
        );
      }

      // Eğer hiç fotoğraf silinmediyse, rejected ID'leri geri ekle ve 0 döndür
      if (successfulIds.isEmpty) {
        debugPrint(
          '⚠️ [ReviewActionsController] Hiç fotoğraf silinmedi, rejected ID\'ler geri ekleniyor',
        );
        _pendingDeleteIds.addAll(rejectedIds);
        // Rejected items'ı state'te tut (henüz silinmediler)
        return DeleteResult(deletedCount: 0, deletedSizeMB: 0.0);
      }

      // State'i güncellemeden ÖNCE, silinecek asset'leri bul
      // Çünkü state'i güncelledikten sonra asset'leri bulamayabiliriz
      final assetsToDelete = <String, PendingDeleteAction>{};
      final foundIds = <String>[];
      final notFoundIds = <String>[];

      // Sadece yeni silinen asset'ler için (zaten silinmiş olanlar için asset bulmaya gerek yok)
      final newlyDeletedIds = successfulIds
          .where((id) => !alreadyDeletedIds.contains(id))
          .toList();

      for (final id in newlyDeletedIds) {
        try {
          final pendingAction = state.firstWhere(
            (e) => e.asset.id == id,
            orElse: () =>
                throw StateError('Asset not found in pending list: $id'),
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

      debugPrint(
        '📊 [ReviewActionsController] Asset bulma sonuçları: ${foundIds.length} bulundu, ${notFoundIds.length} bulunamadı',
      );
      if (notFoundIds.isNotEmpty) {
        debugPrint(
          '⚠️ [ReviewActionsController] Bulunamayan ID\'ler: ${notFoundIds.join(", ")}',
        );
      }

      // Eğer hiç asset bulunamadıysa ve yeni silinen asset yoksa kontrol et
      if (assetsToDelete.isEmpty && newlyDeletedIds.isEmpty) {
        // Eğer zaten silinmiş asset'ler varsa, bunları başarılı say
        if (alreadyDeletedIds.isNotEmpty) {
          debugPrint(
            'ℹ️ [ReviewActionsController] Tüm asset\'ler zaten silinmiş, başarılı olarak işaretleniyor',
          );
          // State'ten zaten silinmiş asset'leri temizle
          final updatedState = state.where((action) {
            return !alreadyDeletedIds.contains(action.asset.id);
          }).toList();
          emit(updatedState);
          return DeleteResult(
            deletedCount: alreadyDeletedIds.length,
            deletedSizeMB: 0.0,
          );
        }

        debugPrint(
          '⚠️ [ReviewActionsController] Silinecek asset bulunamadı, işlem iptal ediliyor',
        );
        // Rejected items'ı geri ekle
        _pendingDeleteIds.addAll(rejectedIds);
        // Bulunamayan ID'leri de geri ekle (belki state'te yoktur)
        _pendingDeleteIds.addAll(notFoundIds);
        return DeleteResult(deletedCount: 0, deletedSizeMB: 0.0);
      }

      // Eğer bazı ID'ler bulunamadıysa, bunları rejected ID'lere ekle
      if (notFoundIds.isNotEmpty) {
        rejectedIds.addAll(notFoundIds);
        debugPrint(
          '⚠️ [ReviewActionsController] Bulunamayan ${notFoundIds.length} ID rejected listesine eklendi',
        );
      }

      // State'i güncelle: Silinen fotoğrafları state'ten çıkar
      // Geri kalan fotoğraflar (limit'ten fazla olanlar) state'te kalacak
      final updatedState = state.where((action) {
        // Silinen fotoğrafları state'ten çıkar
        return !successfulIds.contains(action.asset.id);
      }).toList();

      debugPrint(
        '📊 [ReviewActionsController] State güncelleniyor: ${state.length} -> ${updatedState.length} (${successfulIds.length} fotoğraf silindi)',
      );

      // State'i güncelle
      emit(updatedState);

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

      debugPrint(
        '✅ [ReviewActionsController] Tüm thumbnail işlemleri tamamlandı',
      );

      // Re-add rejected items to queue (user denied in system dialog)
      if (rejectedIds.isNotEmpty) {
        _pendingDeleteIds.addAll(rejectedIds);
        // Mark rejected items as undone so they remain in queue
        for (final id in rejectedIds) {
          _historyCubit.undoDelete(id);
        }

        // Rejected items zaten state'te kalmalı (henüz silinmediler)
        // State'i güncellerken sadece successfulIds'i çıkardık, rejected items state'te kaldı
      }

      // Geri kalan fotoğraflar (limit'ten fazla olanlar) zaten state'te kaldı
      // Çünkü state'i güncellerken sadece silinen fotoğrafları çıkardık
      if (remainingIds.isNotEmpty) {
        debugPrint(
          '💾 [ReviewActionsController] ${assetsToDelete.length} fotoğraf silindi. ${remainingIds.length} fotoğraf limit nedeniyle state\'te kaldı (sonraki silme işleminde silinebilir).',
        );
      } else {
        debugPrint(
          '💾 [ReviewActionsController] ${assetsToDelete.length} fotoğraf silindi.',
        );
      }

      // Silinen fotoğraf sayısını hesapla (sadece başarıyla silinen ve asset'i bulunanlar)
      final deletedCount = assetsToDelete.length;
      final totalRejected = rejectedIds.length;

      // Silme işleminden ÖNCE asset boyutlarını hesapla ve sakla
      // Çünkü silme işleminden sonra asset'ler artık mevcut olmayacak
      final assetSizes = <String, int>{};
      for (final id in successfulIds) {
        final pendingAction = assetsToDelete[id];
        if (pendingAction != null) {
          try {
            // Önce review history'den fileSizeBytes'i kontrol et
            final historyItem = _historyCubit.state.firstWhere(
              (item) =>
                  item.assetId == id && item.type == ReviewActionType.delete,
              orElse: () => ReviewActionItem(
                assetId: id,
                type: ReviewActionType.delete,
                timestampMs: 0,
                fileSizeBytes: 0,
              ),
            );

            if (historyItem.fileSizeBytes > 0) {
              assetSizes[id] = historyItem.fileSizeBytes;
            } else {
              // History'de yoksa, asset'ten direkt hesapla
              final sizeBytes = await estimateAssetSize(pendingAction.asset);
              if (sizeBytes > 0) {
                assetSizes[id] = sizeBytes;
              }
            }
          } catch (e) {
            debugPrint(
              '⚠️ [ReviewActionsController] Asset boyutu hesaplanamadı (silme öncesi): $id, $e',
            );
          }
        }
      }

      // Toplam silinen MB'ı hesapla - saklanan boyutları kullan
      double totalSizeMB = 0.0;
      for (final id in successfulIds) {
        final sizeBytes = assetSizes[id];
        if (sizeBytes != null && sizeBytes > 0) {
          totalSizeMB += sizeBytes / (1024 * 1024);
        }
      }

      debugPrint(
        '✅ [ReviewActionsController] Silme işlemi tamamlandı: $deletedCount fotoğraf başarıyla silindi, ${totalSizeMB.toStringAsFixed(2)} MB boşaltıldı (toplam denenen: ${idsToDelete.length}, reddedilen: $totalRejected)',
      );

      // Eğer deletedCount 0 ise, bir sorun var demektir
      if (deletedCount == 0) {
        debugPrint(
          '❌ [ReviewActionsController] deletedCount 0, bu beklenmeyen bir durum!',
        );
        debugPrint(
          '❌ [ReviewActionsController] Rejected IDs: ${rejectedIds.join(", ")}',
        );
        debugPrint(
          '❌ [ReviewActionsController] NotFound IDs: ${notFoundIds.join(", ")}',
        );
        // Rejected items'ı geri ekle
        _pendingDeleteIds.addAll(rejectedIds);
        return DeleteResult(deletedCount: 0, deletedSizeMB: 0.0);
      }

      debugPrint(
        '✅ [ReviewActionsController] Başarıyla silinen fotoğraf sayısı: $deletedCount, toplam boyut: ${totalSizeMB.toStringAsFixed(2)} MB',
      );

      // Silinen fotoğraf ID'lerini kaydet (deck'te tekrar gösterilmemesi için)
      if (_preferencesService != null && successfulIds.isNotEmpty) {
        await _preferencesService.addDeletedPhotoIds(successfulIds.toList());
      }

      return DeleteResult(
        deletedCount: deletedCount,
        deletedSizeMB: totalSizeMB,
      );
    } catch (e) {
      // On error, re-add all IDs to queue (user can retry)
      _pendingDeleteIds.addAll(idsToDelete);
      _pendingDeleteIds.addAll(remainingIds);
      // Mark as undone so they can be retried
      for (final id in idsToDelete) {
        _historyCubit.undoDelete(id);
      }
      debugPrint('❌ [ReviewActionsController] Silme hatası: $e');
      return DeleteResult(deletedCount: 0, deletedSizeMB: 0.0);
    } finally {
      _isApplying = false;
    }
  }

  Future<DeleteResult> applyPendingDeletes({int? maxDeleteCount}) async {
    return await _applyBatchDelete(maxDeleteCount: maxDeleteCount);
  }

  /// Thumbnail'i kaydet ve silme işlemini işaretle (helper method)
  Future<void> _saveThumbnailAndMarkApplied(
    String id,
    PendingDeleteAction pendingAction,
  ) async {
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
          debugPrint(
            '❌ [ReviewActionsController] Thumbnail alınamadı (2. deneme): $id, $e2',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [ReviewActionsController] Thumbnail alınamadı: $id, $e');
      // Hata olsa bile devam et, thumbnail olmadan da kaydet
    }

    // Thumbnail olsa da olmasa da kaydet
    try {
      await _historyCubit.markDeleteApplied(id, thumbnailBytes: thumbnailBytes);
      debugPrint('✅ [ReviewActionsController] Silme işlemi kaydedildi: $id');
    } catch (e) {
      debugPrint(
        '❌ [ReviewActionsController] Silme işlemi kaydedilemedi: $id, $e',
      );
    }
  }
}

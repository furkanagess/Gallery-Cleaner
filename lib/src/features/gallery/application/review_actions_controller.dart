import 'dart:async';

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
    _ref.read(reviewHistoryControllerProvider.notifier).addKeep(asset.id);
  }

  Future<void> onDelete(pm.AssetEntity asset) async {
    HapticFeedback.heavyImpact();
    // Only queue delete - visual is immediate via card animation
    // Real deletion happens when user taps "Apply"
    _ref.read(reviewHistoryControllerProvider.notifier).addDeletePending(asset.id);
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
      
      // Mark successfully deleted items as applied
      for (final id in successfulIds) {
        _ref.read(reviewHistoryControllerProvider.notifier).markDeleteApplied(id);
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



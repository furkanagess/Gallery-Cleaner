import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReviewActionType { keep, delete, move }
enum ReviewActionStatus { pending, applied, undone }

class ReviewActionItem {
  ReviewActionItem({
    required this.assetId,
    required this.type,
    required this.timestampMs,
    this.targetAlbumId,
    this.status = ReviewActionStatus.pending,
  });

  final String assetId;
  final ReviewActionType type;
  final int timestampMs;
  final String? targetAlbumId;
  final ReviewActionStatus status;

  ReviewActionItem copyWith({ReviewActionStatus? status}) {
    return ReviewActionItem(
      assetId: assetId,
      type: type,
      timestampMs: timestampMs,
      targetAlbumId: targetAlbumId,
      status: status ?? this.status,
    );
  }
}

class ReviewHistoryController extends StateNotifier<List<ReviewActionItem>> {
  ReviewHistoryController() : super(const []);

  static const int maxItems = 200;

  void addKeep(String assetId) {
    _push(ReviewActionItem(assetId: assetId, type: ReviewActionType.keep, timestampMs: DateTime.now().millisecondsSinceEpoch));
  }

  void addDeletePending(String assetId) {
    _push(ReviewActionItem(assetId: assetId, type: ReviewActionType.delete, timestampMs: DateTime.now().millisecondsSinceEpoch, status: ReviewActionStatus.pending));
  }

  void markDeleteApplied(String assetId) {
    _updateFirst(assetId, (it) => it.type == ReviewActionType.delete, (it) => it.copyWith(status: ReviewActionStatus.applied));
  }

  void undoDelete(String assetId) {
    _updateFirst(assetId, (it) => it.type == ReviewActionType.delete, (it) => it.copyWith(status: ReviewActionStatus.undone));
  }

  void addMove(String assetId, String albumId) {
    _push(ReviewActionItem(assetId: assetId, type: ReviewActionType.move, timestampMs: DateTime.now().millisecondsSinceEpoch, targetAlbumId: albumId, status: ReviewActionStatus.applied));
  }

  void clear() {
    state = const [];
  }

  void _push(ReviewActionItem item) {
    final next = [item, ...state];
    if (next.length > maxItems) {
      next.removeRange(maxItems, next.length);
    }
    state = next;
  }

  void _updateFirst(String assetId, bool Function(ReviewActionItem it) match, ReviewActionItem Function(ReviewActionItem it) update) {
    final idx = state.indexWhere((e) => e.assetId == assetId && match(e));
    if (idx == -1) return;
    final copy = [...state];
    copy[idx] = update(copy[idx]);
    state = copy;
  }
}

final reviewHistoryControllerProvider = StateNotifierProvider<ReviewHistoryController, List<ReviewActionItem>>((ref) {
  return ReviewHistoryController();
});



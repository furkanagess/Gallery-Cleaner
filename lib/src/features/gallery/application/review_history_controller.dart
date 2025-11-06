import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReviewActionType { keep, delete, move }
enum ReviewActionStatus { pending, applied, undone }

class ReviewActionItem {
  ReviewActionItem({
    required this.assetId,
    required this.type,
    required this.timestampMs,
    this.targetAlbumId,
    this.status = ReviewActionStatus.pending,
    this.fileSizeBytes = 0,
    this.thumbnailBytes,
  });

  final String assetId;
  final ReviewActionType type;
  final int timestampMs;
  final String? targetAlbumId;
  final ReviewActionStatus status;
  final int fileSizeBytes; // Dosya boyutu byte cinsinden
  final Uint8List? thumbnailBytes; // Silinen görsellerin thumbnail'ı (base64 olarak kaydedilecek)

  ReviewActionItem copyWith({
    ReviewActionStatus? status,
    int? fileSizeBytes,
    Uint8List? thumbnailBytes,
  }) {
    return ReviewActionItem(
      assetId: assetId,
      type: type,
      timestampMs: timestampMs,
      targetAlbumId: targetAlbumId,
      status: status ?? this.status,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
    );
  }

  Map<String, dynamic> toJson() => {
        'assetId': assetId,
        'type': type.name,
        'timestampMs': timestampMs,
        'targetAlbumId': targetAlbumId,
        'status': status.name,
        'fileSizeBytes': fileSizeBytes,
        'thumbnailBytes': thumbnailBytes != null ? base64Encode(thumbnailBytes!) : null,
      };

  static ReviewActionItem fromJson(Map<String, dynamic> json) {
    Uint8List? thumbnailBytes;
    if (json['thumbnailBytes'] != null) {
      try {
        thumbnailBytes = base64Decode(json['thumbnailBytes'] as String);
      } catch (_) {
        // ignore decode errors
      }
    }
    return ReviewActionItem(
      assetId: json['assetId'] as String,
      type: ReviewActionType.values
          .firstWhere((e) => e.name == (json['type'] as String)),
      timestampMs: json['timestampMs'] as int,
      targetAlbumId: json['targetAlbumId'] as String?,
      status: ReviewActionStatus.values
          .firstWhere((e) => e.name == (json['status'] as String)),
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      thumbnailBytes: thumbnailBytes,
    );
  }
}

class ReviewHistoryController extends StateNotifier<List<ReviewActionItem>> {
  ReviewHistoryController() : super(const []) {
    _load();
  }

  static const int maxItems = 200;
  static const String _prefsKey = 'review_history_v1';

  void addKeep(String assetId, {int fileSizeBytes = 0}) {
    _push(ReviewActionItem(
      assetId: assetId,
      type: ReviewActionType.keep,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      fileSizeBytes: fileSizeBytes,
    ));
  }

  void addDeletePending(String assetId, {int fileSizeBytes = 0}) {
    _push(ReviewActionItem(
      assetId: assetId,
      type: ReviewActionType.delete,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      status: ReviewActionStatus.pending,
      fileSizeBytes: fileSizeBytes,
    ));
  }

  Future<void> markDeleteApplied(String assetId, {Uint8List? thumbnailBytes}) async {
    if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
      debugPrint('💾 [ReviewHistoryController] Thumbnail kaydediliyor: $assetId, boyut: ${thumbnailBytes.length} bytes');
    } else {
      debugPrint('⚠️ [ReviewHistoryController] Thumbnail yok: $assetId');
    }
    _updateFirst(assetId, (it) => it.type == ReviewActionType.delete, (it) => it.copyWith(status: ReviewActionStatus.applied, thumbnailBytes: thumbnailBytes));
  }

  void undoDelete(String assetId) {
    _updateFirst(assetId, (it) => it.type == ReviewActionType.delete, (it) => it.copyWith(status: ReviewActionStatus.undone));
  }

  void addMove(String assetId, String albumId, {int fileSizeBytes = 0}) {
    _push(ReviewActionItem(
      assetId: assetId,
      type: ReviewActionType.move,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      targetAlbumId: albumId,
      status: ReviewActionStatus.applied,
      fileSizeBytes: fileSizeBytes,
    ));
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
    _persist();
  }

  void _updateFirst(String assetId, bool Function(ReviewActionItem it) match, ReviewActionItem Function(ReviewActionItem it) update) {
    final idx = state.indexWhere((e) => e.assetId == assetId && match(e));
    if (idx == -1) return;
    final copy = [...state];
    copy[idx] = update(copy[idx]);
    state = copy;
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = state.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(list);
      
      // JSON string'in boyutunu kontrol et (SharedPreferences limiti ~1MB)
      if (jsonString.length > 900000) {
        debugPrint('⚠️ [ReviewHistoryController] JSON çok büyük: ${jsonString.length} bytes, thumbnail\'ları temizliyoruz...');
        // Eski kayıtların thumbnail'larını temizle (en eski 50 tanesini)
        final cleanedList = state.map((e) {
          // En eski 50 kayıt için thumbnail'ı temizle
          final sortedByTime = [...state]..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
          final oldest50 = sortedByTime.take(50).map((item) => item.assetId).toSet();
          if (oldest50.contains(e.assetId)) {
            return e.copyWith(thumbnailBytes: null);
          }
          return e;
        }).toList();
        
        final cleanedJsonString = jsonEncode(cleanedList.map((e) => e.toJson()).toList());
        await prefs.setString(_prefsKey, cleanedJsonString);
        debugPrint('✅ [ReviewHistoryController] Thumbnail\'lar temizlendi, yeni boyut: ${cleanedJsonString.length} bytes');
      } else {
        await prefs.setString(_prefsKey, jsonString);
        debugPrint('✅ [ReviewHistoryController] History kaydedildi: ${list.length} item, ${jsonString.length} bytes');
      }
    } catch (e) {
      debugPrint('❌ [ReviewHistoryController] History kaydedilemedi: $e');
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr == null) return;
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      final items = decoded
          .cast<Map<String, dynamic>>()
          .map(ReviewActionItem.fromJson)
          .toList();
      state = items;
    } catch (_) {
      // ignore
    }
  }
}

final reviewHistoryControllerProvider = StateNotifierProvider<ReviewHistoryController, List<ReviewActionItem>>((ref) {
  return ReviewHistoryController();
});



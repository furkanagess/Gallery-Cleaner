import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import '../../../core/services/media_library_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../onboarding/application/permissions_controller.dart';

final mediaLibraryServiceProvider = Provider<MediaLibraryService>((ref) {
  return MediaLibraryService();
});

final selectedAlbumProvider = StateProvider<pm.AssetPathEntity?>((ref) => null);

final albumsProvider = FutureProvider<List<pm.AssetPathEntity>>((ref) async {
  final permission = ref.watch(permissionsControllerProvider);
  if (permission != GalleryPermissionStatus.authorized) {
    // Debug: Permission not granted, return empty list
    // Using debugPrint here to avoid spamming in release builds
    debugPrint('📁 [albumsProvider] Permission not authorized → returning empty album list');
    return [];
  }
  final service = ref.watch(mediaLibraryServiceProvider);
  debugPrint('📁 [albumsProvider] Fetching albums (images only)...');
  final albums = await service.fetchAlbums(onlyAll: false, type: pm.RequestType.image);
  debugPrint('📁 [albumsProvider] Albums fetched: count=${albums.length}');
  for (final a in albums) {
    debugPrint('   • ${a.name} (${a.id}) isAll=${a.isAll}');
  }
  return albums;
});

class GalleryPagingController extends StateNotifier<AsyncValue<List<pm.AssetEntity>>> {
  GalleryPagingController(this._ref)
      : _page = 0,
        _canLoadMore = true,
        super(const AsyncValue.data([]));

  final Ref _ref;
  int _page;
  bool _canLoadMore;
  static const int _pageSize = 60;

  Future<void> reload() async {
    _page = 0;
    _canLoadMore = true;
    state = const AsyncLoading();
    try {
      final service = _ref.read(mediaLibraryServiceProvider);
      final album = _ref.read(selectedAlbumProvider);
      debugPrint('📸 [GalleryPagingController.reload] page=$_page size=$_pageSize album=${album?.name ?? 'All'}');
      final items = await service.fetchRecentAssets(page: _page, pageSize: _pageSize, album: album);
      debugPrint('📸 [GalleryPagingController.reload] fetched ${items.length} items');
      state = AsyncValue.data(items);
      _canLoadMore = items.length == _pageSize;
    } catch (e, st) {
      debugPrint('🛑 [GalleryPagingController.reload] error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_canLoadMore || state.isLoading) return;
    final current = state.value ?? [];
    state = AsyncValue.data(current);
    try {
      _page += 1;
      final service = _ref.read(mediaLibraryServiceProvider);
      final album = _ref.read(selectedAlbumProvider);
      debugPrint('📸 [GalleryPagingController.loadMore] page=$_page size=$_pageSize album=${album?.name ?? 'All'}');
      final next = await service.fetchRecentAssets(page: _page, pageSize: _pageSize, album: album);
      final combined = [...current, ...next];
      debugPrint('📸 [GalleryPagingController.loadMore] fetched ${next.length} (combined ${combined.length})');
      state = AsyncValue.data(combined);
      _canLoadMore = next.length == _pageSize;
    } catch (e, st) {
      debugPrint('🛑 [GalleryPagingController.loadMore] error: $e');
      state = AsyncValue.error(e, st);
    }
  }
}

final galleryPagingControllerProvider =
    StateNotifierProvider<GalleryPagingController, AsyncValue<List<pm.AssetEntity>>>((ref) {
  final permission = ref.watch(permissionsControllerProvider);
  final controller = GalleryPagingController(ref);

  // Auto-reload when permission granted or album changes
  ref.listen<GalleryPermissionStatus>(permissionsControllerProvider, (prev, next) {
    if (next == GalleryPermissionStatus.authorized && prev != next) {
      debugPrint('🔄 [GalleryPagingController] Permission granted → reload');
      controller.reload();
    }
  });
  ref.listen<pm.AssetPathEntity?>(selectedAlbumProvider, (prev, next) {
    if (prev != next) {
      debugPrint('🔄 [GalleryPagingController] Selected album changed: prev=${prev?.name} next=${next?.name}');
      controller.reload();
    }
  });

  if (permission == GalleryPermissionStatus.authorized) {
    debugPrint('🔄 [GalleryPagingController] Initial authorized state → initial reload');
    controller.reload();
  }

  return controller;
});

class DeleteLimitController extends StateNotifier<AsyncValue<int>> {
  DeleteLimitController()
      : _prefs = PreferencesService(),
        super(const AsyncValue.loading()) {
    refresh();
  }

  final PreferencesService _prefs;

  Future<int> refresh() async {
    try {
      final limit = await _prefs.getDeleteLimit();
      state = AsyncValue.data(limit);
      return limit;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<int> currentLimit() async {
    final value = state.valueOrNull;
    if (value != null) return value;
    return await refresh();
  }

  Future<int> decrease(int amount) async {
    final newLimit = await _prefs.decreaseDeleteLimit(amount);
    state = AsyncValue.data(newLimit);
    return newLimit;
  }

  Future<int> increase(int amount) async {
    final newLimit = await _prefs.increaseDeleteLimit(amount);
    state = AsyncValue.data(newLimit);
    return newLimit;
  }

  Future<void> set(int value) async {
    await _prefs.setDeleteLimit(value);
    state = AsyncValue.data(value);
  }
}

/// Silme hakkı provider'ı (StateNotifier tabanlı)
final deleteLimitProvider =
    StateNotifierProvider<DeleteLimitController, AsyncValue<int>>(
  (ref) => DeleteLimitController(),
);

/// Premium durumu provider'ı
final isPremiumProvider = FutureProvider<bool>((ref) async {
  // Prefer RevenueCat entitlement; fallback to local pref if RC not active
  final rc = RevenueCatService.instance;
  await rc.initialize();
  final rcPremium = await rc.isPremium();
  if (rcPremium) return true;
  // backward compatibility
  final prefsService = PreferencesService();
  return await prefsService.isPremium();
});

/// Tarama limiti provider'ı (Premium olmayan kullanıcılar için 1000)
/// Backward compatibility için korunuyor
final scanLimitProvider = FutureProvider<int>((ref) async {
  final prefsService = PreferencesService();
  return await prefsService.getScanLimit();
});

/// Duplicate tarama limiti provider'ı (azalır)
final duplicateScanLimitProvider = FutureProvider<int>((ref) async {
  final prefsService = PreferencesService();
  return await prefsService.getDuplicateScanLimit();
});

/// Blur tarama limiti provider'ı (sabit - azalmaz)
final blurScanLimitProvider = FutureProvider<int>((ref) async {
  final prefsService = PreferencesService();
  return await prefsService.getBlurScanLimit();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import '../../../core/services/media_library_service.dart';
import '../../onboarding/application/permissions_controller.dart';

final mediaLibraryServiceProvider = Provider<MediaLibraryService>((ref) {
  return MediaLibraryService();
});

final selectedAlbumProvider = StateProvider<pm.AssetPathEntity?>((ref) => null);

final albumsProvider = FutureProvider<List<pm.AssetPathEntity>>((ref) async {
  final permission = ref.watch(permissionsControllerProvider);
  if (permission != GalleryPermissionStatus.authorized) {
    return [];
  }
  final service = ref.watch(mediaLibraryServiceProvider);
  final albums = await service.fetchAlbums(onlyAll: false, type: pm.RequestType.image);
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
      final items = await service.fetchRecentAssets(page: _page, pageSize: _pageSize, album: album);
      state = AsyncValue.data(items);
      _canLoadMore = items.length == _pageSize;
    } catch (e, st) {
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
      final next = await service.fetchRecentAssets(page: _page, pageSize: _pageSize, album: album);
      final combined = [...current, ...next];
      state = AsyncValue.data(combined);
      _canLoadMore = next.length == _pageSize;
    } catch (e, st) {
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
    if (next == GalleryPermissionStatus.authorized) {
      controller.reload();
    }
  });
  ref.listen<pm.AssetPathEntity?>(selectedAlbumProvider, (prev, next) {
    controller.reload();
  });

  if (permission == GalleryPermissionStatus.authorized) {
    controller.reload();
  }

  return controller;
});



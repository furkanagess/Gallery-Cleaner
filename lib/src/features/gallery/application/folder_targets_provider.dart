import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'gallery_providers.dart';

class FolderTargetsController extends StateNotifier<List<String>> {
  FolderTargetsController(this.ref) : super(const []);
  final Ref ref;

  void initializeIfEmpty(List<pm.AssetPathEntity> albums) {
    if (state.isEmpty && albums.isNotEmpty) {
      // Pick first few albums as defaults
      final defaults = albums.take(4).map((e) => e.id).toList();
      state = defaults;
    }
  }

  void toggle(String albumId) {
    final copy = [...state];
    final idx = copy.indexOf(albumId);
    if (idx == -1) {
      copy.add(albumId);
    } else {
      copy.removeAt(idx);
    }
    state = copy;
  }
}

final folderTargetsProvider =
    StateNotifierProvider<FolderTargetsController, List<String>>((ref) {
      return FolderTargetsController(ref);
    });

final targetAlbumsProvider = Provider<List<pm.AssetPathEntity>>((ref) {
  final ids = ref.watch(folderTargetsProvider);
  final albums = ref
      .watch(albumsProvider)
      .maybeWhen(data: (a) => a, orElse: () => <pm.AssetPathEntity>[]);
  final byId = {for (final a in albums) a.id: a};
  return [
    for (final id in ids)
      if (byId.containsKey(id)) byId[id]!,
  ];
});

// Initialize default targets when albums are first loaded (outside widget build)
final folderTargetsInitEffectProvider = Provider<void>((ref) {
  ref.listen(albumsProvider, (previous, next) {
    final albums = next.maybeWhen(
      data: (a) => a,
      orElse: () => <pm.AssetPathEntity>[],
    );
    if (albums.isNotEmpty && ref.read(folderTargetsProvider).isEmpty) {
      ref.read(folderTargetsProvider.notifier).initializeIfEmpty(albums);
    }
  });
});

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import '../../../core/utils/async_value.dart';
import 'gallery_providers.dart';

class FolderTargetsCubit extends Cubit<List<String>> {
  FolderTargetsCubit({required AlbumsCubit albumsCubit})
      : _albumsCubit = albumsCubit,
        super(const []) {
    _albumsSubscription = _albumsCubit.stream.listen(_handleAlbums);
    _handleAlbums(_albumsCubit.state);
  }

  final AlbumsCubit _albumsCubit;
  StreamSubscription<AsyncValue<List<pm.AssetPathEntity>>>? _albumsSubscription;

  void toggle(String albumId) {
    final copy = List<String>.from(state);
    final idx = copy.indexOf(albumId);
    if (idx == -1) {
      copy.add(albumId);
    } else {
      copy.removeAt(idx);
    }
    emit(copy);
  }

  List<pm.AssetPathEntity> getTargetAlbums() {
    final ids = state;
    final albums = _albumsCubit.state.valueOrNull ?? [];
    final byId = {for (final a in albums) a.id: a};
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  void _handleAlbums(AsyncValue<List<pm.AssetPathEntity>> asyncAlbums) {
    final albums = asyncAlbums.valueOrNull ?? [];
    if (albums.isNotEmpty && state.isEmpty) {
      final defaults = albums.take(4).map((e) => e.id).toList();
      emit(defaults);
    }
  }

  @override
  Future<void> close() {
    _albumsSubscription?.cancel();
    return super.close();
  }
}

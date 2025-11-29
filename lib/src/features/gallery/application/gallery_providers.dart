import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import '../../../core/services/media_library_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../../core/utils/async_value.dart';
import '../../onboarding/application/permissions_controller.dart';

class SelectedAlbumCubit extends Cubit<pm.AssetPathEntity?> {
  SelectedAlbumCubit() : super(null);

  void select(pm.AssetPathEntity? album) => emit(album);
}

class AlbumsCubit extends Cubit<AsyncValue<List<pm.AssetPathEntity>>> {
  AlbumsCubit({
    required MediaLibraryService mediaLibraryService,
    required PermissionsCubit permissionsCubit,
  })  : _mediaLibraryService = mediaLibraryService,
        _permissionsCubit = permissionsCubit,
        super(const AsyncValue.loading()) {
    _permissionSubscription =
        _permissionsCubit.stream.listen(_handlePermissionChange);
    _handlePermissionChange(_permissionsCubit.state);
  }

  final MediaLibraryService _mediaLibraryService;
  final PermissionsCubit _permissionsCubit;
  StreamSubscription<GalleryPermissionStatus>? _permissionSubscription;
  bool _isFetching = false;

  Future<void> refresh() async {
    if (_permissionsCubit.state != GalleryPermissionStatus.authorized) {
      emit(const AsyncValue.data([]));
      return;
    }
    await _fetchAlbums();
  }

  Future<void> _fetchAlbums() async {
    if (_isFetching) return;
    _isFetching = true;
    emit(const AsyncValue.loading());
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final albums = await _mediaLibraryService.fetchAlbums(
        onlyAll: false,
        type: pm.RequestType.image,
      );
      emit(AsyncValue.data(albums));
    } catch (e, st) {
      emit(AsyncValue.error(e, st));
    } finally {
      _isFetching = false;
    }
  }

  void _handlePermissionChange(GalleryPermissionStatus status) {
    if (status == GalleryPermissionStatus.authorized) {
      _fetchAlbums();
    } else {
      emit(const AsyncValue.data([]));
    }
  }

  @override
  Future<void> close() {
    _permissionSubscription?.cancel();
    return super.close();
  }
}

class GalleryPagingCubit extends Cubit<AsyncValue<List<pm.AssetEntity>>> {
  GalleryPagingCubit({
    required MediaLibraryService mediaLibraryService,
    required SelectedAlbumCubit selectedAlbumCubit,
    required PermissionsCubit permissionsCubit,
    required AlbumFilterCubit albumFilterCubit,
    required AlbumSortOrderCubit albumSortOrderCubit,
  })  : _mediaLibraryService = mediaLibraryService,
        _selectedAlbumCubit = selectedAlbumCubit,
        _permissionsCubit = permissionsCubit,
        _albumFilterCubit = albumFilterCubit,
        _albumSortOrderCubit = albumSortOrderCubit,
        super(const AsyncLoading()) {
    _albumSubscription = _selectedAlbumCubit.stream.listen((_) {
      _scheduleReload(const Duration(milliseconds: 100));
    });
    _filterSubscription = _albumFilterCubit.stream.listen((_) {
      _scheduleReload(const Duration(milliseconds: 100));
    });
    _sortSubscription = _albumSortOrderCubit.stream.listen((_) {
      _scheduleReload(const Duration(milliseconds: 100));
    });
    _permissionSubscription =
        _permissionsCubit.stream.listen((status) {
      final previous = _lastPermission;
      _lastPermission = status;
      if (status == GalleryPermissionStatus.authorized &&
          previous != GalleryPermissionStatus.authorized) {
        final delay = Platform.isIOS
            ? const Duration(milliseconds: 800)
            : const Duration(milliseconds: 300);
        _scheduleReload(delay);
      } else if (status != GalleryPermissionStatus.authorized) {
        emit(const AsyncValue.data([]));
      }
    });

    if (_permissionsCubit.state == GalleryPermissionStatus.authorized) {
      final delay = Platform.isIOS
          ? const Duration(milliseconds: 800)
          : const Duration(milliseconds: 300);
      _scheduleReload(delay);
    }
  }

  final MediaLibraryService _mediaLibraryService;
  final SelectedAlbumCubit _selectedAlbumCubit;
  final PermissionsCubit _permissionsCubit;
  final AlbumFilterCubit _albumFilterCubit;
  final AlbumSortOrderCubit _albumSortOrderCubit;
  StreamSubscription<pm.AssetPathEntity?>? _albumSubscription;
  StreamSubscription<DateRangeFilter>? _filterSubscription;
  StreamSubscription<SortOrder>? _sortSubscription;
  StreamSubscription<GalleryPermissionStatus>? _permissionSubscription;
  Timer? _reloadTimer;
  GalleryPermissionStatus? _lastPermission;
  bool _canLoadMore = true;
  static const int _pageSize = 60;

  List<pm.AssetEntity> _applyFilters(List<pm.AssetEntity> assets) {
    final dateFilter = _albumFilterCubit.state;
    final sortOrder = _albumSortOrderCubit.state;

    // Apply date filter
    if (dateFilter.hasFilter) {
      assets = assets.where((asset) {
        final createDate = asset.createDateTime;
        if (dateFilter.startDate != null &&
            createDate.isBefore(dateFilter.startDate!)) {
          return false;
        }
        if (dateFilter.endDate != null &&
            createDate.isAfter(dateFilter.endDate!.add(const Duration(days: 1)))) {
          return false;
        }
        return true;
      }).toList();
    }

    // Apply sort order
    assets.sort((a, b) {
      final comparison = a.createDateTime.compareTo(b.createDateTime);
      return sortOrder == SortOrder.newest ? -comparison : comparison;
    });

    return assets;
  }

  void _scheduleReload(Duration delay) {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(delay, () {
      if (_permissionsCubit.state == GalleryPermissionStatus.authorized) {
        reload();
      }
    });
  }

  Future<void> reload() async {
    _canLoadMore = true;
    _allFilteredAssets.clear();
    _loadedPages.clear();
    emit(const AsyncLoading());
    
    try {
      final dateFilter = _albumFilterCubit.state;
      
      // Optimize: Load only first few pages initially for faster response
      // If no date filter, we can load incrementally
      // If date filter exists, we need to load more to find matching items
      final initialPageCount = dateFilter.hasFilter ? 10 : 3;
      
      final allItems = <pm.AssetEntity>[];
      int page = 0;
      
      // Load initial pages
      while (page < initialPageCount) {
        final items = await _mediaLibraryService.fetchRecentAssets(
          page: page,
          pageSize: _pageSize,
          album: _selectedAlbumCubit.state,
        );
        if (items.isEmpty) break;
        allItems.addAll(items);
        _loadedPages.add(page);
        if (items.length < _pageSize) break;
        page++;
      }

      // Apply filters and sorting
      var filtered = _applyFilters(allItems);

      // If we have date filter and not enough items, load more pages
      if (dateFilter.hasFilter && filtered.length < _pageSize && page < 50) {
        // Load more pages until we have enough filtered items or reach limit
        while (filtered.length < _pageSize * 2 && page < 50) {
          final items = await _mediaLibraryService.fetchRecentAssets(
            page: page,
            pageSize: _pageSize,
            album: _selectedAlbumCubit.state,
          );
          if (items.isEmpty) break;
          allItems.addAll(items);
          _loadedPages.add(page);
          filtered = _applyFilters(allItems);
          if (items.length < _pageSize) break;
          page++;
        }
      }

      // Take first page
      final firstPage = filtered.take(_pageSize).toList();
      _canLoadMore = filtered.length > _pageSize || page < 50;
      _allFilteredAssets = filtered;
      _lastLoadedPage = page - 1;
      emit(AsyncValue.data(firstPage));
    } catch (e, st) {
      emit(AsyncValue.error(e, st));
    }
  }

  List<pm.AssetEntity> _allFilteredAssets = [];
  Set<int> _loadedPages = {};
  int _lastLoadedPage = -1;

  Future<void> loadMore() async {
    if (!_canLoadMore || state.isLoading) return;
    final current = state.value ?? [];
    emit(AsyncValue.data(current));
    
    try {
      // If we have cached filtered assets, use them
      if (_allFilteredAssets.length > current.length) {
        final startIndex = current.length;
        final endIndex = startIndex + _pageSize;
        final next = _allFilteredAssets.skip(startIndex).take(_pageSize).toList();
        final combined = [...current, ...next];
        _canLoadMore = endIndex < _allFilteredAssets.length;
        emit(AsyncValue.data(combined));
        return;
      }
      
      // Otherwise, load more pages and filter
      final allItems = <pm.AssetEntity>[];
      int page = _lastLoadedPage + 1;
      int loadedCount = 0;
      
      // Load a few more pages
      while (loadedCount < 3 && page < 100) {
        if (_loadedPages.contains(page)) {
          page++;
          continue;
        }
        
        final items = await _mediaLibraryService.fetchRecentAssets(
          page: page,
          pageSize: _pageSize,
          album: _selectedAlbumCubit.state,
        );
        if (items.isEmpty) break;
        allItems.addAll(items);
        _loadedPages.add(page);
        _lastLoadedPage = page;
        loadedCount++;
        if (items.length < _pageSize) break;
        page++;
      }
      
      if (allItems.isNotEmpty) {
        // Add new items to existing filtered list
        final newFiltered = _applyFilters(allItems);
        _allFilteredAssets.addAll(newFiltered);
        
        // Re-sort entire list
        _allFilteredAssets.sort((a, b) {
          final comparison = a.createDateTime.compareTo(b.createDateTime);
          final sortOrder = _albumSortOrderCubit.state;
          return sortOrder == SortOrder.newest ? -comparison : comparison;
        });
        
        // Remove duplicates
        final seen = <String>{};
        _allFilteredAssets = _allFilteredAssets.where((asset) {
          if (seen.contains(asset.id)) return false;
          seen.add(asset.id);
          return true;
        }).toList();
      }
      
      // Get next page from filtered assets
      final startIndex = current.length;
      final endIndex = startIndex + _pageSize;
      final next = _allFilteredAssets.skip(startIndex).take(_pageSize).toList();
      final combined = [...current, ...next];
      _canLoadMore = endIndex < _allFilteredAssets.length || page < 100;
      emit(AsyncValue.data(combined));
    } catch (e, st) {
      emit(AsyncValue.error(e, st));
    }
  }

  @override
  Future<void> close() {
    _albumSubscription?.cancel();
    _filterSubscription?.cancel();
    _sortSubscription?.cancel();
    _permissionSubscription?.cancel();
    _reloadTimer?.cancel();
    return super.close();
  }
}

class DeleteLimitCubit extends Cubit<AsyncValue<int>> {
  DeleteLimitCubit(this._prefs) : super(const AsyncValue.loading()) {
    refresh();
  }

  final PreferencesService _prefs;

  Future<int> refresh() async {
    emit(const AsyncValue.loading());
    try {
      final limit = await _prefs.getDeleteLimit();
      emit(AsyncValue.data(limit));
      return limit;
    } catch (e, st) {
      emit(AsyncValue.error(e, st));
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
    emit(AsyncValue.data(newLimit));
    return newLimit;
  }

  Future<int> increase(int amount) async {
    final newLimit = await _prefs.increaseDeleteLimit(amount);
    emit(AsyncValue.data(newLimit));
    return newLimit;
  }

  Future<void> set(int value) async {
    await _prefs.setDeleteLimit(value);
    emit(AsyncValue.data(value));
  }
}

class PremiumCubit extends Cubit<AsyncValue<bool>> {
  PremiumCubit(this._prefs) : super(const AsyncValue.loading()) {
    refresh();
  }

  final PreferencesService _prefs;

  Future<void> refresh() async {
    emit(const AsyncValue.loading());
    try {
      final rc = RevenueCatService.instance;
      await rc.initialize();
      final rcPremium = await rc.isPremium();
      if (rcPremium) {
        emit(const AsyncValue.data(true));
        return;
      }
      final prefPremium = await _prefs.isPremium();
      emit(AsyncValue.data(prefPremium));
    } catch (e, st) {
      emit(AsyncValue.error(e, st));
    }
  }
}

abstract class BaseScanLimitCubit extends Cubit<AsyncValue<int>> {
  BaseScanLimitCubit() : super(const AsyncValue.loading());

  Future<int> loadLimit();

  Future<void> refresh() async {
    emit(const AsyncValue.loading());
    try {
      final value = await loadLimit();
      emit(AsyncValue.data(value));
    } catch (e, st) {
      emit(AsyncValue.error(e, st));
    }
  }
}

class GeneralScanLimitCubit extends BaseScanLimitCubit {
  GeneralScanLimitCubit(this._prefs) {
    refresh();
  }

  final PreferencesService _prefs;

  @override
  Future<int> loadLimit() => _prefs.getScanLimit();
}

class DuplicateScanLimitCubit extends BaseScanLimitCubit {
  DuplicateScanLimitCubit(this._prefs) {
    refresh();
  }

  final PreferencesService _prefs;

  @override
  Future<int> loadLimit() => _prefs.getDuplicateScanLimit();
}

class BlurScanLimitCubit extends BaseScanLimitCubit {
  BlurScanLimitCubit(this._prefs) {
    refresh();
  }

  final PreferencesService _prefs;

  @override
  Future<int> loadLimit() => _prefs.getBlurScanLimit();
}

class TabSelectionCubit extends Cubit<int> {
  TabSelectionCubit() : super(0);

  void selectTab(int index) {
    if (index != state) {
      emit(index);
    }
  }
}

enum SortOrder { newest, oldest }

class DateRangeFilter {
  final DateTime? startDate;
  final DateTime? endDate;

  const DateRangeFilter({
    this.startDate,
    this.endDate,
  });

  bool get hasFilter => startDate != null || endDate != null;

  DateRangeFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return DateRangeFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

class AlbumFilterCubit extends Cubit<DateRangeFilter> {
  AlbumFilterCubit() : super(const DateRangeFilter());

  void setDateRange(DateTime? startDate, DateTime? endDate) {
    emit(DateRangeFilter(startDate: startDate, endDate: endDate));
  }

  void clearDateRange() {
    emit(const DateRangeFilter());
  }
}

class AlbumSortOrderCubit extends Cubit<SortOrder> {
  AlbumSortOrderCubit() : super(SortOrder.newest);

  void setSortOrder(SortOrder order) {
    emit(order);
  }
}

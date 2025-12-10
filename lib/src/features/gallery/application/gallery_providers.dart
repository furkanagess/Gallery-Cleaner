import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import '../../../core/services/media_library_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../../core/utils/async_value.dart';
import '../../onboarding/application/permissions_controller.dart';

class SelectedAlbumCubit extends Cubit<pm.AssetPathEntity?> {
  SelectedAlbumCubit({PreferencesService? preferencesService})
      : _preferencesService = preferencesService,
        super(null);

  final PreferencesService? _preferencesService;

  void select(pm.AssetPathEntity? album) {
    emit(album);
    // Albüm seçildiğinde PreferencesService'e kaydet
    if (_preferencesService != null) {
      _preferencesService.saveLastSelectedAlbumId(album?.id);
    }
  }
}

class AlbumsCubit extends Cubit<AsyncValue<List<pm.AssetPathEntity>>> {
  AlbumsCubit({
    required MediaLibraryService mediaLibraryService,
    required PermissionsCubit permissionsCubit,
    SelectedAlbumCubit? selectedAlbumCubit,
    PreferencesService? preferencesService,
  })  : _mediaLibraryService = mediaLibraryService,
        _permissionsCubit = permissionsCubit,
        _selectedAlbumCubit = selectedAlbumCubit,
        _preferencesService = preferencesService,
        super(const AsyncValue.loading()) {
    _permissionSubscription =
        _permissionsCubit.stream.listen(_handlePermissionChange);
    _handlePermissionChange(_permissionsCubit.state);
  }

  final MediaLibraryService _mediaLibraryService;
  final PermissionsCubit _permissionsCubit;
  final SelectedAlbumCubit? _selectedAlbumCubit;
  final PreferencesService? _preferencesService;
  StreamSubscription<GalleryPermissionStatus>? _permissionSubscription;
  bool _isFetching = false;
  bool _hasSelectedDefaultAlbum = false;

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
      
      // Albümleri en çok fotoğrafa sahip olanlara göre sırala (gösterim ve default seçim için)
      final sortedAlbumsByCount = await _sortAlbumsByPhotoCount(albums);
      
      // İlk yüklemede, eğer hiç albüm seçilmemişse, önce son seçilen albümü kontrol et
      if (!_hasSelectedDefaultAlbum && 
          _selectedAlbumCubit != null && 
          _selectedAlbumCubit.state == null) {
        _hasSelectedDefaultAlbum = true;
        
        // Son seçilen albümü PreferencesService'den al
        String? lastSelectedAlbumId;
        if (_preferencesService != null) {
          lastSelectedAlbumId = await _preferencesService.getLastSelectedAlbumId();
        }
        
        // Eğer son seçilen albüm ID'si varsa ve bu albüm hala mevcutsa, onu seç
        if (lastSelectedAlbumId != null) {
          final lastSelectedAlbum = albums.firstWhere(
            (album) => album.id == lastSelectedAlbumId,
            orElse: () => albums.first, // Bulunamazsa ilk albümü kullan
          );
          
          if (lastSelectedAlbum.id == lastSelectedAlbumId) {
            debugPrint('🎯 [AlbumsCubit] Son seçilen albüm yüklendi: ${lastSelectedAlbum.name}');
            _selectedAlbumCubit.select(lastSelectedAlbum);
          } else {
            // Son seçilen albüm bulunamadı, default seçime geç
            debugPrint('⚠️ [AlbumsCubit] Son seçilen albüm bulunamadı, default seçime geçiliyor');
            _selectDefaultAlbum(sortedAlbumsByCount);
          }
        } else {
          // Son seçilen albüm yok, default seçime geç
          _selectDefaultAlbum(sortedAlbumsByCount);
        }
      }
      
      // Gösterim için fotoğraf sayısına göre sıralanmış listeyi kullan
      emit(AsyncValue.data(sortedAlbumsByCount));
    } catch (e, st) {
      emit(AsyncValue.error(e, st));
    } finally {
      _isFetching = false;
    }
  }

  /// Default albüm seçim mantığı:
  /// - En çok fotoğrafa sahip 3. albüm (index 2)
  /// - Eğer 2 albüm varsa: 2. albüm
  /// - Eğer 1 albüm varsa: 1. albüm
  void _selectDefaultAlbum(List<pm.AssetPathEntity> sortedAlbumsByCount) {
    if (_selectedAlbumCubit == null) return;
    
    if (sortedAlbumsByCount.length >= 3) {
      // En çok fotoğrafa sahip 3. albüm
      final thirdByCountAlbum = sortedAlbumsByCount[2]; // Index 2 = 3. albüm
      debugPrint('🎯 [AlbumsCubit] İlk yüklemede en çok fotoğrafa sahip 3. albüm seçiliyor: ${thirdByCountAlbum.name}');
      _selectedAlbumCubit.select(thirdByCountAlbum);
    } else if (sortedAlbumsByCount.length == 2) {
      // Eğer sadece 2 albüm varsa, en çok fotoğrafa sahip 2. albümü seç
      final secondByCountAlbum = sortedAlbumsByCount[1];
      debugPrint('🎯 [AlbumsCubit] İlk yüklemede en çok fotoğrafa sahip 2. albüm seçiliyor: ${secondByCountAlbum.name}');
      _selectedAlbumCubit.select(secondByCountAlbum);
    } else if (sortedAlbumsByCount.length == 1) {
      // Eğer sadece 1 albüm varsa, onu seç
      final firstAlbum = sortedAlbumsByCount[0];
      debugPrint('🎯 [AlbumsCubit] İlk yüklemede tek albüm seçiliyor: ${firstAlbum.name}');
      _selectedAlbumCubit.select(firstAlbum);
    }
  }

  /// Albümleri en çok fotoğrafa sahip olanlara göre sıralar (en çok fotoğraf önce)
  Future<List<pm.AssetPathEntity>> _sortAlbumsByPhotoCount(
    List<pm.AssetPathEntity> albums,
  ) async {
    if (albums.isEmpty) return albums;
    
    // Her albüm için fotoğraf sayısını al (paralel işleme için batch'ler halinde)
    final albumCounts = <pm.AssetPathEntity, int>{};
    const batchSize = 10; // Her seferde 10 albüm paralel işle
    
    for (var i = 0; i < albums.length; i += batchSize) {
      final batch = albums.skip(i).take(batchSize).toList();
      
      // Batch'i paralel işle
      await Future.wait(
        batch.map((album) async {
          try {
            // Albümün toplam asset sayısını al
            final assetCount = await album.assetCountAsync;
            albumCounts[album] = assetCount;
          } catch (e) {
            debugPrint('⚠️ [AlbumsCubit] Albüm ${album.name} için fotoğraf sayısı alınamadı: $e');
            albumCounts[album] = 0;
          }
        }),
      );
    }
    
    // Albümleri fotoğraf sayısına göre sırala (en çok fotoğraf önce)
    final sortedAlbums = List<pm.AssetPathEntity>.from(albums);
    sortedAlbums.sort((a, b) {
      final countA = albumCounts[a] ?? 0;
      final countB = albumCounts[b] ?? 0;
      return countB.compareTo(countA); // Büyükten küçüğe
    });
    
    return sortedAlbums;
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
    PreferencesService? preferencesService,
  })  : _mediaLibraryService = mediaLibraryService,
        _selectedAlbumCubit = selectedAlbumCubit,
        _permissionsCubit = permissionsCubit,
        _albumFilterCubit = albumFilterCubit,
        _albumSortOrderCubit = albumSortOrderCubit,
        _preferencesService = preferencesService,
        super(const AsyncLoading()) {
    _albumSubscription = _selectedAlbumCubit.stream.listen((album) {
      // Sadece albüm gerçekten değiştiyse reload yap
      final albumId = album?.id;
      if (albumId != _currentLoadedAlbumId) {
        _scheduleReload(const Duration(milliseconds: 100));
      }
    });
    _filterSubscription = _albumFilterCubit.stream.listen((filter) {
      // Filtre gerçekten değiştiyse reload yap
      if (!_filtersEqual(filter, _currentLoadedFilter)) {
        _scheduleReload(const Duration(milliseconds: 100));
      }
    });
    _sortSubscription = _albumSortOrderCubit.stream.listen((sortOrder) {
      // Sıralama gerçekten değiştiyse reload yap
      if (sortOrder != _currentLoadedSortOrder) {
        _scheduleReload(const Duration(milliseconds: 100));
      }
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
  final PreferencesService? _preferencesService;
  StreamSubscription<pm.AssetPathEntity?>? _albumSubscription;
  StreamSubscription<DateRangeFilter>? _filterSubscription;
  StreamSubscription<SortOrder>? _sortSubscription;
  StreamSubscription<GalleryPermissionStatus>? _permissionSubscription;
  Timer? _reloadTimer;
  GalleryPermissionStatus? _lastPermission;
  bool _canLoadMore = true;
  static const int _pageSize = 1000;
  
  // State management için
  String? _currentLoadedAlbumId; // Şu an yüklenmiş albüm ID'si
  SortOrder? _currentLoadedSortOrder; // Şu an yüklenmiş sıralama
  DateRangeFilter? _currentLoadedFilter; // Şu an yüklenmiş filtre
  bool _isLoading = false; // Yükleme devam ediyor mu
  
  // Progress tracking için
  int _currentLoadingProgress = 0; // Şu an yüklenen item sayısı
  int? _currentLoadingTotal; // Toplam item sayısı
  
  // Progress getter'ları
  int get currentLoadingProgress => _currentLoadingProgress;
  int? get currentLoadingTotal => _currentLoadingTotal;

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
    // Eğer zaten yükleme devam ediyorsa, reload yapma
    if (_isLoading) {
      debugPrint('⚠️ [GalleryPagingCubit] Reload already in progress, skipping...');
      return;
    }
    
    _reloadTimer?.cancel();
    _reloadTimer = Timer(delay, () {
      if (_permissionsCubit.state == GalleryPermissionStatus.authorized && !_isLoading) {
        reload();
      }
    });
  }
  
  // Filtrelerin eşit olup olmadığını kontrol et
  bool _filtersEqual(DateRangeFilter? a, DateRangeFilter? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.startDate == b.startDate && a.endDate == b.endDate;
  }

  Future<void> reload() async {
    // Yükleme zaten devam ediyorsa, yeni reload'ı atla
    if (_isLoading) {
      debugPrint('⚠️ [GalleryPagingCubit] Reload already in progress, skipping duplicate reload');
      return;
    }
    
    final dateFilter = _albumFilterCubit.state;
    final sortOrder = _albumSortOrderCubit.state;
    final album = _selectedAlbumCubit.state;
    final albumId = album?.id;
    
    // Cache key oluştur
    final cacheKey = _getCacheKey(albumId, sortOrder, dateFilter);
    
    // Cache'de var mı kontrol et
    if (_albumCache.containsKey(cacheKey)) {
      debugPrint('✅ [GalleryPagingCubit] Cache hit for album: $albumId, sort: $sortOrder');
      var cachedPhotos = _albumCache[cacheKey]!;
      
      // Oldest sort için cache'den yüklenen fotoğrafları da sırala (garantile)
      if (sortOrder == SortOrder.oldest && cachedPhotos.isNotEmpty) {
        cachedPhotos = List.from(cachedPhotos);
        cachedPhotos.sort((a, b) {
          return a.createDateTime.compareTo(b.createDateTime);
        });
      }
      
      // Silinen fotoğrafları filtrele
      if (_preferencesService != null) {
        final deletedIds = await _preferencesService.getDeletedPhotoIds();
        if (deletedIds.isNotEmpty) {
          final beforeCount = cachedPhotos.length;
          cachedPhotos = cachedPhotos
              .where((asset) => !deletedIds.contains(asset.id))
              .toList();
          final afterCount = cachedPhotos.length;
          if (beforeCount != afterCount) {
            debugPrint('🚫 [GalleryPagingCubit] Cache\'den ${beforeCount - afterCount} silinen fotoğraf filtrelendi (${beforeCount} -> ${afterCount})');
          }
        }
      }
      
      // State'i güncelle
      _currentLoadedAlbumId = albumId;
      _currentLoadedSortOrder = sortOrder;
      _currentLoadedFilter = dateFilter;
      _allFilteredAssets = cachedPhotos;
      _isLoading = false;
      
      // Cache'den direkt emit et
      emit(AsyncValue.data(cachedPhotos));
      return;
    }
    
    // Eğer aynı albüm, aynı filtre ve aynı sıralama zaten yüklenmişse, reload yapma
    if (albumId == _currentLoadedAlbumId &&
        sortOrder == _currentLoadedSortOrder &&
        _filtersEqual(dateFilter, _currentLoadedFilter) &&
        !state.isLoading) {
      debugPrint('ℹ️ [GalleryPagingCubit] Album, filter and sort order unchanged, skipping reload');
      return;
    }
    
    // Yükleme başlatılıyor
    _isLoading = true;
    _canLoadMore = true;
    _allFilteredAssets.clear();
    _loadedPages.clear();
    _currentLoadingProgress = 0;
    _currentLoadingTotal = null;
    emit(const AsyncLoading());
    
    try {
      
      // If oldest sort order is selected, we need to start from the oldest photos
      // Get total asset count to calculate starting page
      int? totalAssets;
      int? lastPage;
      if (sortOrder == SortOrder.oldest && album != null) {
        try {
          totalAssets = await album.assetCountAsync;
          if (totalAssets > 0) {
            lastPage = ((totalAssets - 1) ~/ _pageSize);
            _currentLoadingTotal = totalAssets;
            debugPrint('📊 [GalleryPagingCubit] Total assets: $totalAssets, Last page: $lastPage');
          } else {
            debugPrint('⚠️ [GalleryPagingCubit] Total assets is 0 or negative');
          }
        } catch (e) {
          // If assetCountAsync fails, try to estimate by loading pages
          debugPrint('⚠️ [GalleryPagingCubit] assetCountAsync failed: $e, trying to estimate...');
          try {
            // Try to find the last page by loading pages until we get an empty page
            int testPage = 0;
            int maxTestPages = 100; // Safety limit
            while (testPage < maxTestPages) {
              final testItems = await _mediaLibraryService.fetchRecentAssets(
                page: testPage,
                pageSize: _pageSize,
                album: album,
              );
              if (testItems.isEmpty || testItems.length < _pageSize) {
                lastPage = testPage > 0 ? testPage - 1 : 0;
                debugPrint('📊 [GalleryPagingCubit] Estimated last page: $lastPage (by testing pages)');
                break;
              }
              testPage++;
            }
            if (lastPage == null) {
              lastPage = maxTestPages - 1;
              debugPrint('⚠️ [GalleryPagingCubit] Could not find last page, using max: $lastPage');
            }
          } catch (e2) {
            debugPrint('❌ [GalleryPagingCubit] Failed to estimate last page: $e2');
          }
        }
      }
      
      final allItems = <pm.AssetEntity>[];
      int page = 0;
      
      // Load ALL photos from the album - no limits
      if (sortOrder == SortOrder.oldest && album != null) {
        // Oldest sort için: tüm fotoğrafları index bazlı range ile yükle
        try {
          totalAssets ??= await album.assetCountAsync;
        } catch (_) {}
        
        if (totalAssets == null || totalAssets == 0) {
          debugPrint('⚠️ [GalleryPagingCubit] Total assets is null or 0 for oldest sort');
        } else {
          debugPrint('🔄 [GalleryPagingCubit] Loading ALL oldest photos via getAssetListRange (total: $totalAssets)');
          final loadedAssetIds = <String>{};
          const int chunkSize = 1000;
          
          for (int start = 0; start < totalAssets; start += chunkSize) {
            final end = (start + chunkSize) > totalAssets ? totalAssets : (start + chunkSize);
            final items = await album.getAssetListRange(start: start, end: end);
            
            if (items.isEmpty) {
              debugPrint('⚠️ [GalleryPagingCubit] Empty range [$start, $end) returned, breaking');
              break;
            }
            
            for (final item in items) {
              if (!loadedAssetIds.contains(item.id)) {
                allItems.add(item);
                loadedAssetIds.add(item.id);
              }
            }
            
            _currentLoadingProgress = loadedAssetIds.length;
            debugPrint('📄 [GalleryPagingCubit] Loaded range [$start, $end): ${items.length} items (unique total: ${loadedAssetIds.length})');
          }
          
          debugPrint('✅ [GalleryPagingCubit] Loaded ALL ${loadedAssetIds.length} unique photos from album via range');
        }
      } else {
        // For newest sort: start from page 0 and load ALL pages forward
        debugPrint('🔄 [GalleryPagingCubit] Loading ALL newest photos: starting from page 0');
        
        // Load ALL pages from the beginning (no limit)
        while (true) {
          // Skip if already loaded
          if (_loadedPages.contains(page)) {
            page++;
            continue;
          }
          
          final items = await _mediaLibraryService.fetchRecentAssets(
            page: page,
            pageSize: _pageSize,
            album: album,
          );
          if (items.isEmpty) break; // No more pages
          allItems.addAll(items);
          _loadedPages.add(page);
          _currentLoadingProgress = allItems.length; // Progress güncelle
          debugPrint('📄 [GalleryPagingCubit] Loaded page $page: ${items.length} items (total: ${allItems.length})');
          if (items.length < _pageSize) break; // Last page
          page++;
        }
        
        debugPrint('✅ [GalleryPagingCubit] Loaded ALL ${allItems.length} items from pages starting at 0');
      }

      // Apply filters and sorting
      // For oldest sort, this will sort by date ascending (oldest first)
      var filtered = _applyFilters(allItems);
      
      // Oldest sort için mutlaka tarihe göre ascending sıralama yap (en eski önce)
      if (sortOrder == SortOrder.oldest && filtered.isNotEmpty) {
        // Tarihe göre ascending sıralama (en eski önce) - _applyFilters'da yapılan sıralamayı garantile
        filtered.sort((a, b) {
          return a.createDateTime.compareTo(b.createDateTime);
        });
        
        debugPrint('📊 [GalleryPagingCubit] Filtered items: ${filtered.length}');
        debugPrint('📅 [GalleryPagingCubit] Oldest photo date: ${filtered.first.createDateTime}');
        debugPrint('📅 [GalleryPagingCubit] Newest photo date in filtered: ${filtered.last.createDateTime}');
      }

      // If we have date filter, continue loading ALL pages to find matching items
      // No limits - load all pages
      if (dateFilter.hasFilter) {
        int currentPage = page;
        
        // Continue loading ALL remaining pages (no limit)
        if (sortOrder == SortOrder.oldest && lastPage != null) {
          // For oldest sort with date filter: load all pages from 0 to lastPage
          currentPage = 0;
          while (currentPage <= lastPage) {
            if (_loadedPages.contains(currentPage)) {
              currentPage++;
              continue;
            }
            final items = await _mediaLibraryService.fetchRecentAssets(
              page: currentPage,
              pageSize: _pageSize,
              album: album,
            );
            if (items.isEmpty) {
              currentPage++;
              continue;
            }
            
            // Add only new items (avoid duplicates)
            for (final item in items) {
              if (!allItems.any((existing) => existing.id == item.id)) {
                allItems.add(item);
              }
            }
            _loadedPages.add(currentPage);
            _currentLoadingProgress = allItems.length; // Progress güncelle
            filtered = _applyFilters(allItems);
            if (items.length < _pageSize) {
              currentPage++;
              continue;
            }
            currentPage++;
          }
        } else {
          // For newest sort: continue loading forwards
          while (true) {
            if (_loadedPages.contains(currentPage)) {
              currentPage++;
              continue;
            }
            final items = await _mediaLibraryService.fetchRecentAssets(
              page: currentPage,
              pageSize: _pageSize,
              album: album,
            );
            if (items.isEmpty) break; // No more pages
            allItems.addAll(items);
            _loadedPages.add(currentPage);
            _currentLoadingProgress = allItems.length; // Progress güncelle
            filtered = _applyFilters(allItems);
            if (items.length < _pageSize) break; // Last page
            currentPage++;
          }
        }
        page = currentPage;
        
        // Date filter uygulandıktan sonra oldest sort için tekrar sırala
        if (sortOrder == SortOrder.oldest && filtered.isNotEmpty) {
          filtered.sort((a, b) {
            return a.createDateTime.compareTo(b.createDateTime);
          });
        }
      }

      // Return all filtered photos (no 60 photo limit)
      // For oldest sort, filtered list is sorted ascending (oldest first),
      // so all photos will be shown starting from the oldest
      var allFilteredPhotos = filtered.toList();
      
      // Silinen fotoğrafları filtrele
      if (_preferencesService != null) {
        final deletedIds = await _preferencesService.getDeletedPhotoIds();
        if (deletedIds.isNotEmpty) {
          final beforeCount = allFilteredPhotos.length;
          allFilteredPhotos = allFilteredPhotos
              .where((asset) => !deletedIds.contains(asset.id))
              .toList();
          final afterCount = allFilteredPhotos.length;
          if (beforeCount != afterCount) {
            debugPrint('🚫 [GalleryPagingCubit] ${beforeCount - afterCount} silinen fotoğraf filtrelendi (${beforeCount} -> ${afterCount})');
          }
        }
      }
      
      if (sortOrder == SortOrder.oldest && allFilteredPhotos.isNotEmpty) {
        debugPrint('📸 [GalleryPagingCubit] All filtered photos (oldest): ${allFilteredPhotos.length} photos');
        debugPrint('📅 [GalleryPagingCubit] First photo date: ${allFilteredPhotos.first.createDateTime}');
        debugPrint('📅 [GalleryPagingCubit] Last photo date: ${allFilteredPhotos.last.createDateTime}');
      }
      
      // Since we're loading ALL photos, canLoadMore is false (all photos are already loaded)
      _canLoadMore = false;
      _allFilteredAssets = allFilteredPhotos;
      _lastLoadedPage = page;
      
      // Cache'e kaydet
      _albumCache[cacheKey] = allFilteredPhotos;
      debugPrint('💾 [GalleryPagingCubit] Cached ${allFilteredPhotos.length} photos for key: $cacheKey');
      
      // State'i güncelle - yüklenen albüm, filtre ve sıralama bilgilerini sakla
      _currentLoadedAlbumId = album?.id;
      _currentLoadedSortOrder = sortOrder;
      _currentLoadedFilter = dateFilter;
      _isLoading = false;
      _currentLoadingProgress = 0; // Progress sıfırla
      _currentLoadingTotal = null;
      
      emit(AsyncValue.data(allFilteredPhotos));
    } catch (e, st) {
      // Hata durumunda state'i sıfırla
      _isLoading = false;
      _currentLoadingProgress = 0;
      _currentLoadingTotal = null;
      emit(AsyncValue.error(e, st));
    }
  }

  List<pm.AssetEntity> _allFilteredAssets = [];
  Set<int> _loadedPages = {};
  int _lastLoadedPage = -1;
  
  // Cache mekanizması - albüm ID + sort order + filter kombinasyonu için
  final Map<String, List<pm.AssetEntity>> _albumCache = {};
  
  // Cache key oluştur
  String _getCacheKey(String? albumId, SortOrder sortOrder, DateRangeFilter filter) {
    final filterHash = filter.hasFilter 
        ? '${filter.startDate?.millisecondsSinceEpoch ?? 0}_${filter.endDate?.millisecondsSinceEpoch ?? 0}'
        : 'no_filter';
    return '${albumId ?? 'all_photos'}_${sortOrder.name}_$filterHash';
  }

  /// Undo edilen fotoğrafları assets listesine geri ekle (reload etmeden)
  void restoreUndoneAssets(List<pm.AssetEntity> assets) {
    if (assets.isEmpty) return;
    
    final current = state.value ?? [];
    final currentIds = current.map((a) => a.id).toSet();
    
    // Sadece yeni fotoğrafları ekle (duplicate kontrolü)
    final newAssets = assets.where((asset) => !currentIds.contains(asset.id)).toList();
    if (newAssets.isEmpty) return;
    
    // Yeni fotoğrafları mevcut listeye ekle
    final combined = [...current, ...newAssets];
    
    // Sıralamayı uygula
    final sortOrder = _albumSortOrderCubit.state;
    combined.sort((a, b) {
      final comparison = a.createDateTime.compareTo(b.createDateTime);
      return sortOrder == SortOrder.newest ? -comparison : comparison;
    });
    
    // _allFilteredAssets'e de ekle
    _allFilteredAssets.addAll(newAssets);
    _allFilteredAssets.sort((a, b) {
      final comparison = a.createDateTime.compareTo(b.createDateTime);
      return sortOrder == SortOrder.newest ? -comparison : comparison;
    });
    
    // Duplicate'leri temizle
    final seen = <String>{};
    final uniqueCombined = combined.where((asset) {
      if (seen.contains(asset.id)) return false;
      seen.add(asset.id);
      return true;
    }).toList();
    
    emit(AsyncValue.data(uniqueCombined));
    debugPrint('✅ [GalleryPagingCubit] Restored ${newAssets.length} undone assets (total: ${uniqueCombined.length})');
  }

  Future<void> loadMore() async {
    if (!_canLoadMore || state.isLoading) return;
    final current = state.value ?? [];
    emit(AsyncValue.data(current));
    
    try {
      // If we have cached filtered assets, use them
      if (_allFilteredAssets.length > current.length) {
        // Return all remaining filtered assets (no 60 photo limit)
        final remaining = _allFilteredAssets.skip(current.length).toList();
        final combined = [...current, ...remaining];
        _canLoadMore = false; // All cached assets are now loaded
        emit(AsyncValue.data(combined));
        return;
      }
      
      // Otherwise, load more pages and filter
      final sortOrder = _albumSortOrderCubit.state;
      final album = _selectedAlbumCubit.state;
      final allItems = <pm.AssetEntity>[];
      int page;
      
      // Load ALL remaining pages - no limits
      if (sortOrder == SortOrder.oldest) {
        // Start from previous page (going backwards) and load ALL remaining pages
        page = _lastLoadedPage - 1;
        
        // Load ALL remaining pages going backwards (no limit)
        while (page >= 0) {
          if (_loadedPages.contains(page)) {
            page--;
            continue;
          }
          
          final items = await _mediaLibraryService.fetchRecentAssets(
            page: page,
            pageSize: _pageSize,
            album: album,
          );
          if (items.isEmpty) break; // No more pages
          allItems.addAll(items);
          _loadedPages.add(page);
          _lastLoadedPage = page;
          if (items.length < _pageSize) break; // Last page
          page--;
        }
      } else {
        // Start from next page (going forwards) and load ALL remaining pages
        page = _lastLoadedPage + 1;
        
        // Load ALL remaining pages going forwards (no limit)
        while (true) {
          if (_loadedPages.contains(page)) {
            page++;
            continue;
          }
          
          final items = await _mediaLibraryService.fetchRecentAssets(
            page: page,
            pageSize: _pageSize,
            album: album,
          );
          if (items.isEmpty) break; // No more pages
          allItems.addAll(items);
          _loadedPages.add(page);
          _lastLoadedPage = page;
          if (items.length < _pageSize) break; // Last page
          page++;
        }
      }
      
      if (allItems.isNotEmpty) {
        // Add new items to existing filtered list
        final newFiltered = _applyFilters(allItems);
        _allFilteredAssets.addAll(newFiltered);
        
        // Re-sort entire list
        _allFilteredAssets.sort((a, b) {
          final comparison = a.createDateTime.compareTo(b.createDateTime);
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
      
      // Get all remaining filtered assets (no limit - all photos)
      final remaining = _allFilteredAssets.skip(current.length).toList();
      final combined = [...current, ...remaining];
      // Since we're loading ALL photos, canLoadMore is false when all pages are loaded
      _canLoadMore = false; // All photos are already loaded
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

  /// Test için premium durumunu toggle et (sadece debug modunda kullanılmalı)
  Future<void> togglePremium() async {
    try {
      final currentPremium = await _prefs.isPremium();
      final newPremium = !currentPremium;
      await _prefs.setPremium(newPremium);
      emit(AsyncValue.data(newPremium));
      debugPrint('🧪 [PremiumCubit] Premium durumu toggle edildi: $currentPremium -> $newPremium');
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

class ReviewDeleteSelectionCubit extends Cubit<Set<String>> {
  ReviewDeleteSelectionCubit() : super({});

  void selectAll(List<String> photoIds) {
    emit(Set<String>.from(photoIds));
  }

  void toggleSelection(String photoId) {
    final updated = Set<String>.from(state);
    if (updated.contains(photoId)) {
      updated.remove(photoId);
    } else {
      updated.add(photoId);
    }
    emit(updated);
  }

  void selectPhoto(String photoId) {
    if (!state.contains(photoId)) {
      emit({...state, photoId});
    }
  }

  void deselectPhoto(String photoId) {
    if (state.contains(photoId)) {
      final updated = Set<String>.from(state);
      updated.remove(photoId);
      emit(updated);
    }
  }

  void clear() {
    emit({});
  }

  bool isSelected(String photoId) {
    return state.contains(photoId);
  }
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
  AlbumSortOrderCubit() : super(SortOrder.oldest);

  void setSortOrder(SortOrder order) {
    emit(order);
  }
}

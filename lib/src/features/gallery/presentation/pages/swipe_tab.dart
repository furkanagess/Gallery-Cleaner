import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../../../../core/services/preferences_service.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../application/gallery_providers.dart';
import '../../application/review_actions_controller.dart';
import '../../../../core/utils/view_refresh_cubit.dart';
import 'swipe_page.dart' show presentAlbumPicker;
import 'tabs/swipe/widgets/swipe_tab_shimmer.dart' show SwipeTabShimmer;
import 'tabs/swipe/widgets/swipe_area_content.dart' show SwipeAreaContent;

class SwipeTab extends StatefulWidget {
  const SwipeTab({super.key});

  @override
  State<SwipeTab> createState() => _SwipeTabState();
}

class _SwipeTabState extends State<SwipeTab>
    with
        AutomaticKeepAliveClientMixin,
        CubitStateMixin<SwipeTab>,
        TickerProviderStateMixin {
  int _currentSwipeIndex = 0;
  int _previousAssetsLength = 0;
  bool _showResetToStartButton = false;
  bool _isFirstLoad = true; // Uygulama ilk açılışındaki ilk yükleme için
  String? _currentAlbumId;
  String? _loadingAlbumId; // Yüklenmekte olan albüm ID'si
  VoidCallback? _resetToStartCallback;
  int? _pendingIndexAdjustment; // Reload sonrası index ayarlaması için
  StreamSubscription? _reviewActionsSubscription;
  Timer? _shimmerDelayTimer;
  bool _showShimmer = false;
  DateTime? _loadingStartTime;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSwipeIndex();

    // Stream listener'ı ekle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reviewActionsCubit = context.read<ReviewActionsCubit>();
      _reviewActionsSubscription = reviewActionsCubit.stream.listen((next) {
        if (next.isEmpty &&
            _currentSwipeIndex > 0 &&
            !_showResetToStartButton) {
          // Tüm geri al işlemleri yapıldı ve index > 0 ise buton göster
          // Sadece buton zaten gösterilmiyorsa cubitSetState yap
          if (mounted) {
            cubitSetState(() {
              _showResetToStartButton = true;
            });
          }
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Review ekranından geri dönüldüğünde index'i kontrol et
    // Eğer index 0 olarak kaydedilmişse, deck'i başa al
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final selectedAlbum = context.read<SelectedAlbumCubit>().state;
      final albumId = selectedAlbum?.id;
      final prefsService = PreferencesService();
      final savedIndex = await prefsService.getSwipeIndex(albumId);

      // Eğer kaydedilmiş index 0 ise ve şu anki index 0 değilse, başa al
      if (savedIndex == 0 && _currentSwipeIndex > 0 && !_isFirstLoad) {
        cubitSetState(() {
          _currentSwipeIndex = 0;
        });
        // Reset callback'i çağır
        if (_resetToStartCallback != null) {
          _resetToStartCallback!();
        }
      } else if (savedIndex != null && savedIndex > 0 && !_isFirstLoad) {
        // Normal durumda index'i yükle
        if (_currentSwipeIndex != savedIndex) {
          cubitSetState(() {
            _currentSwipeIndex = savedIndex;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _reviewActionsSubscription?.cancel();
    _shimmerDelayTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSwipeIndex() async {
    final selectedAlbum = context.read<SelectedAlbumCubit>().state;
    final albumId = selectedAlbum?.id;
    _currentAlbumId = albumId;

    final prefsService = PreferencesService();
    final savedIndex = await prefsService.getSwipeIndex(albumId);

    if (savedIndex != null && savedIndex > 0) {
      cubitSetState(() {
        _currentSwipeIndex = savedIndex;
      });
    }
  }

  void _onSwipeIndexChanged(int index) {
    // cubitSetState kullan - bu widget'ı rebuild edecek ve currentIndex prop'u güncellenecek
    cubitSetState(() {
      _currentSwipeIndex = index;
      // Index 0 ise butonu gizle
      if (index == 0) {
        _showResetToStartButton = false;
      }
    });

    // Index'i kaydet (her değişiklikte)
    _saveSwipeIndex(index);
  }

  Future<void> _saveSwipeIndex(int index) async {
    final selectedAlbum = context.read<SelectedAlbumCubit>().state;
    final albumId = selectedAlbum?.id;
    _currentAlbumId = albumId;

    final prefsService = PreferencesService();
    await prefsService.saveSwipeIndex(index, albumId);
  }

  void _resetToStart() {
    // Build sırasında state güncellemesi yapmamak için postFrameCallback kullan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Önce shimmer flag'lerini ve loading album ID'sini set et
      final selectedAlbum = context.read<SelectedAlbumCubit>().state;
      final selectedAlbumId = selectedAlbum?.id;

      _shimmerDelayTimer?.cancel();
      cubitSetState(() {
        _loadingStartTime = DateTime.now();
        _showShimmer = true; // Reset işlemi yapıldığında direkt shimmer göster
        _loadingAlbumId =
            selectedAlbumId; // Loading album ID'sini set et (shimmer gösterilmesi için)
      });

      // Reload'ı çağır - bu loading state'ini tetikleyecek
      context.read<GalleryPagingCubit>().reload();

      // Callback'i de postFrameCallback içinde çağır (build sırasında state güncellemesi yapmaması için)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _resetToStartCallback?.call();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          cubitSetState(() {
            _currentSwipeIndex = 0;
            _showResetToStartButton = false;
            _previousAssetsLength = 0; // Reset previous length
          });
          _saveSwipeIndex(0);
        });
      });
    });
  }

  Widget _buildSwipeArea(
    List<pm.AssetEntity> assets,
    GlobalKey changeAlbumZoneKey,
    String? albumId,
  ) {
    // Yeni fotoğraf eklendi mi kontrol et (assets uzunluğu arttıysa)
    if (_previousAssetsLength > 0 && assets.length > _previousAssetsLength) {
      // Yeni fotoğraf eklendi - butonu göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentSwipeIndex > 0) {
          cubitSetState(() {
            _showResetToStartButton = true;
          });
        }
      });
    }
    _previousAssetsLength = assets.length;

    // Eğer pending index adjustment varsa, onu kullan
    int adjustedIndex = _pendingIndexAdjustment ?? _currentSwipeIndex;

    // Review ekranından geri dönüldüğünde index'i koru
    // Eğer index 0 ise ve assets yüklenmişse, PreferencesService'den yükle
    // Bu sadece ilk yükleme değilse çalışır (review ekranından geri dönüldüğünde)
    if (adjustedIndex == 0 && assets.isNotEmpty && !_isFirstLoad) {
      final selectedAlbum = context.read<SelectedAlbumCubit>().state;
      final currentAlbumId = selectedAlbum?.id;
      // Aynı albümdeyse ve index 0 ise, kaydedilmiş index'i yükle
      if (_currentAlbumId == (currentAlbumId ?? 'all_photos')) {
        // Async yükleme için postFrameCallback kullan
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final prefsService = PreferencesService();
          final savedIndex = await prefsService.getSwipeIndex(currentAlbumId);
          if (savedIndex != null &&
              savedIndex > 0 &&
              savedIndex < assets.length) {
            // Index'i güncelle ve SwipeAreaContent'e bildir
            cubitSetState(() {
              _currentSwipeIndex = savedIndex;
              adjustedIndex = savedIndex;
            });
            _saveSwipeIndex(savedIndex);
          }
        });
      }
    }

    if (assets.isNotEmpty) {
      final maxIndex = assets.length - 1;
      adjustedIndex = adjustedIndex.clamp(0, maxIndex);
    } else {
      adjustedIndex = 0;
    }

    // Pending adjustment uygulandıysa temizle
    if (_pendingIndexAdjustment != null) {
      _pendingIndexAdjustment = null;
    }

    if (adjustedIndex != _currentSwipeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        cubitSetState(() {
          _currentSwipeIndex = adjustedIndex;
        });
        _saveSwipeIndex(adjustedIndex);
      });
    }

    final swipeAreaKey = albumId ?? 'all_photos';

    return RepaintBoundary(
      child: SwipeAreaContent(
        key: ValueKey('swipe_area_$swipeAreaKey'),
        assets: assets,
        changeAlbumZoneKey: changeAlbumZoneKey,
        initialIndex: adjustedIndex,
        currentIndex: _currentSwipeIndex,
        onIndexChanged: _onSwipeIndexChanged,
        onResetCallbackReady: (callback) {
          _resetToStartCallback = callback;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli

    final selectedAlbum = context.watch<SelectedAlbumCubit>().state;
    final selectedAlbumId = selectedAlbum?.id;
    final state = context.watch<GalleryPagingCubit>().state;

    // Albüm değiştiğinde index'i yükle
    // "All Photos" için selectedAlbumId null olabilir, bu durumu da kontrol et
    final currentAlbumId = selectedAlbumId ?? 'all_photos';
    final previousAlbumId = _currentAlbumId ?? 'none';
    final bool albumChanged = currentAlbumId != previousAlbumId;

    if (albumChanged) {
      _currentAlbumId = selectedAlbumId; // null da olabilir (All Photos)
      _shimmerDelayTimer?.cancel();
      // Albüm değiştiğinde hemen shimmer göster ve loading albüm ID'sini güncelle
      _loadingAlbumId = selectedAlbumId;
      cubitSetState(() {
        _currentSwipeIndex = 0;
        _previousAssetsLength = 0;
        _loadingStartTime = DateTime.now();
        _showShimmer = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadSwipeIndex();
        }
      });
    }

    // Loading state'inde yüklenmekte olan albüm ID'sini takip et
    state.maybeWhen(
      loading: () {
        // "All Photos" için selectedAlbumId null olabilir, bu durumu da kontrol et
        final currentLoadingId = selectedAlbumId ?? 'all_photos';
        final previousLoadingId = _loadingAlbumId ?? 'none';

        // Eğer shimmer zaten gösteriliyorsa (reset işlemi gibi), loading album ID'sini güncelleme
        if (_showShimmer && _loadingAlbumId != null) {
          // Shimmer zaten gösteriliyor, sadece loading album ID'sini kontrol et
          if (currentLoadingId != previousLoadingId) {
            _loadingAlbumId = selectedAlbumId; // null da olabilir (All Photos)
          }
        } else if (currentLoadingId != previousLoadingId) {
          // Loading başladığında, eğer albüm değiştiyse veya farklı bir albüm yükleniyorsa shimmer göster
          _loadingAlbumId = selectedAlbumId; // null da olabilir (All Photos)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              cubitSetState(() {
                _showShimmer = true;
                _loadingStartTime = DateTime.now();
              });
            }
          });
        } else if (_loadingStartTime == null) {
          // Normal loading - 3 saniye bekle
          _loadingStartTime = DateTime.now();
          _shimmerDelayTimer?.cancel();
          _shimmerDelayTimer = Timer(const Duration(seconds: 3), () {
            if (mounted && state.isLoading) {
              cubitSetState(() {
                _showShimmer = true;
              });
            }
          });
        }
      },
      data: (_) {
        // Yükleme tamamlandığında loading album ID'sini temizle
        if (_loadingAlbumId != null) {
          _loadingAlbumId = null;
          _shimmerDelayTimer?.cancel();
          cubitSetState(() {
            _loadingStartTime = null;
            _showShimmer = false;
          });
        }
      },
      error: (_, __) {
        // Hata durumunda temizle
        _loadingAlbumId = null;
        _shimmerDelayTimer?.cancel();
        cubitSetState(() {
          _loadingStartTime = null;
          _showShimmer = false;
        });
      },
      orElse: () {},
    );

    // Önceki assets listesini sakla
    final previousAssets = state.maybeWhen(
      data: (assets) => assets,
      orElse: () => <pm.AssetEntity>[],
    );

    final currentAssets = state.maybeWhen(
      data: (assets) => assets,
      orElse: () => null,
    );

    // "All Photos" için null kontrolü yap
    final isSameAlbum =
        !albumChanged &&
        ((selectedAlbumId == null && _currentAlbumId == null) ||
            (selectedAlbumId != null && selectedAlbumId == _currentAlbumId));

    final effectiveAssets =
        currentAssets ?? (isSameAlbum ? previousAssets : <pm.AssetEntity>[]);

    final result = state.when(
      loading: () {
        // Her türlü loading durumunda (özellikle albüm değişimlerinde)
        // mutlaka shimmer göster
        return const SwipeTabShimmer();
      },
      error: (e, _) {
        // Hata durumunda shimmer timer'ı iptal et ve state'i sıfırla
        _loadingAlbumId = null;
        _shimmerDelayTimer?.cancel();
        cubitSetState(() {
          _loadingStartTime = null;
          _showShimmer = false;
        });
        return Builder(
          builder: (ctx) {
            final l10n = AppLocalizations.of(ctx)!;
            return Center(
              child: Text(
                '${l10n.galleryInfoNotAvailable}: $e',
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        );
      },
      data: (_) {
        // İlk başarılı data geldiğinde first-load flag'ini kapat
        if (_isFirstLoad) {
          _isFirstLoad = false;
        }
        // Yükleme tamamlandı, shimmer timer'ı iptal et ve state'i sıfırla
        _loadingAlbumId = null;
        _shimmerDelayTimer?.cancel();
        cubitSetState(() {
          _loadingStartTime = null;
          _showShimmer = false;
        });
        return _buildContentWithAssets(effectiveAssets, selectedAlbum);
      },
    );

    return result;
  }

  Widget _buildContentWithAssets(
    List<pm.AssetEntity> assetsToUse,
    pm.AssetPathEntity? selectedAlbum,
  ) {
    if (assetsToUse.isEmpty) {
      return Builder(
        builder: (ctx) {
          final l10n = AppLocalizations.of(ctx)!;
          final theme = Theme.of(ctx);
          final albumsAsync = context.watch<AlbumsCubit>().state;
          final albumsData = albumsAsync.valueOrNull;
          final canOpenAlbumPicker =
              albumsData != null && albumsData.isNotEmpty;
          final selectedAlbum = context.watch<SelectedAlbumCubit>().state;

          Future<void> openAlbumPicker() async {
            final availableAlbums = albumsData;
            if (availableAlbums == null || availableAlbums.isEmpty) return;
            await presentAlbumPicker(
              context: ctx,
              albums: availableAlbums,
              selectedAlbum: selectedAlbum,
              onSelected: (album) {
                context.read<SelectedAlbumCubit>().select(album);
              },
            );
          }

          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 48,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Modern icon container with gradient and animation
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.secondaryContainer,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.25),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.photo_library_outlined,
                        color: theme.colorScheme.primary,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Title with better styling
                    Text(
                      l10n.noPhotosToShow,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        letterSpacing: -0.5,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Description in a container
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        l10n.selectAlbumToView,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.75),
                          height: 1.5,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Modern button with gradient
                    if (canOpenAlbumPicker)
                      Builder(
                        builder: (buttonContext) {
                          // Premium durumunu kontrol et
                          final isPremiumAsync = buttonContext
                              .watch<PremiumCubit>()
                              .state;
                          final isPremium = isPremiumAsync.maybeWhen(
                            data: (premium) => premium,
                            orElse: () => false,
                          );

                          // Bottom navigation bar'daki container rengiyle aynı
                          final containerColor = theme
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.8);

                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  containerColor,
                                  containerColor.withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: containerColor.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Material(
                              color: AppColors.transparent,
                              child: InkWell(
                                onTap: openAlbumPicker,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.folder_open_rounded,
                                        color: AppColors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        l10n.changeAlbum,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.white,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Material(
                          color: AppColors.transparent,
                          child: InkWell(
                            onTap: () {
                              context.read<GalleryPagingCubit>().reload();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: theme.colorScheme.onSurface,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.tryAgain,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: theme.colorScheme.onSurface,
                                          letterSpacing: 0.3,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    final changeAlbumZoneKey = GlobalKey();
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        // Ana içerik
        Column(
          children: [
            // Galeri Başına Dön butonu
            if (_showResetToStartButton && _currentSwipeIndex > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resetToStart,
                    icon: const Icon(Icons.restart_alt),
                    label: Text(l10n.resetToStart),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _buildSwipeArea(
                assetsToUse,
                changeAlbumZoneKey,
                selectedAlbum?.id,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

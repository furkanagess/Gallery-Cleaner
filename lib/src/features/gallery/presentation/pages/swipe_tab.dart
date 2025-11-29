import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:lottie/lottie.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../application/gallery_providers.dart';
import '../../application/review_actions_controller.dart';
import '../../../../core/utils/view_refresh_cubit.dart';
import 'swipe_page.dart' show presentAlbumPicker, showDeleteSuccessDialog, SwipePage;
import 'tabs/swipe/widgets/swipe_tab_shimmer.dart' show SwipeTabShimmer;
import 'tabs/swipe/widgets/swipe_area_content.dart' show SwipeAreaContent;
import 'tabs/swipe/widgets/animated_swipe_instructions.dart'
    show AnimatedSwipeInstructions;

class SwipeTab extends StatefulWidget {
  const SwipeTab();

  @override
  State<SwipeTab> createState() => _SwipeTabState();
}

class _SwipeTabState extends State<SwipeTab>
    with AutomaticKeepAliveClientMixin, CubitStateMixin<SwipeTab> {
  int _currentSwipeIndex = 0;
  int _previousAssetsLength = 0;
  bool _showResetToStartButton = false;
  String? _currentAlbumId;
  VoidCallback? _resetToStartCallback;
  bool _isDeleting = false;
  int? _pendingIndexAdjustment; // Reload sonrası index ayarlaması için
  StreamSubscription? _reviewActionsSubscription;

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
  void dispose() {
    _reviewActionsSubscription?.cancel();
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
    // Galeriyi yeniden yükle - silinen fotoğraflar artık listede olmayacak
    context.read<GalleryPagingCubit>().reload();

    _resetToStartCallback?.call();
    cubitSetState(() {
      _currentSwipeIndex = 0;
      _showResetToStartButton = false;
      _previousAssetsLength = 0; // Reset previous length
    });
    _saveSwipeIndex(0);
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

    // Stream listener artık initState'de ekleniyor - burada tekrar ekleme

    final selectedAlbum = context.watch<SelectedAlbumCubit>().state;

    // Album değiştiğinde index'i yükle
    if (selectedAlbum?.id != _currentAlbumId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadSwipeIndex();
        }
      });
    }

    // Assets listesini selector ile izle - sadece assets listesi gerçekten değiştiğinde rebuild
    // Loading state değişikliklerini ignore et - dialog/reklam gösterilirken rebuild'i engelle
    final state = context.watch<GalleryPagingCubit>().state;

    // Önceki assets listesini sakla - loading state'de kullanmak için
    final previousAssets = state.maybeWhen(
      data: (assets) => assets,
      orElse: () => <pm.AssetEntity>[],
    );

    // Sadece data state'inde ve assets listesi gerçekten değiştiğinde rebuild yap
    final galleryPagingState = context.watch<GalleryPagingCubit>().state;
    final currentAssets = galleryPagingState.maybeWhen(
      data: (assets) => assets,
      orElse: () => null, // Loading/error state'lerinde null döndür
    );

    // Assets listesi değişmediyse ve loading state'deyse, önceki build'i koru
    final effectiveAssets = currentAssets ?? previousAssets;

    return state.when(
      loading: () {
        // Loading state'de önceki widget'ı koru - dialog/reklam gösterilirken rebuild'i engelle
        // Eğer önceki assets varsa onu göster, yoksa loading göster
        if (effectiveAssets.isNotEmpty) {
          // Önceki assets'i kullan - rebuild'i engelle
          return _buildContentWithAssets(effectiveAssets, selectedAlbum);
        }
        // İlk yükleme ise comprehensive swipe tab shimmer'ı göster
        return const SwipeTabShimmer();
      },
      error: (e, _) => Builder(
        builder: (ctx) {
          final l10n = AppLocalizations.of(ctx)!;
          return Center(
            child: Text(
              '${l10n.galleryInfoNotAvailable}: $e',
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
      data: (_) {
        // effectiveAssets kullan - loading state'de önceki assets'i koru
        return _buildContentWithAssets(effectiveAssets, selectedAlbum);
      },
    );
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
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
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

    return Column(
      children: [
        // Galeri Başına Dön butonu
        if (_showResetToStartButton && _currentSwipeIndex > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        Builder(
          builder: (context) {
            final pending = context.watch<ReviewActionsCubit>().state;
            final pendingCount = pending.length;

            // Undo & Delete Photos alanı görünürken (pending > 0)
            // alttaki Delete / Keep yönerge rozetlerini gizle.
            if (pendingCount > 0) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const AnimatedSwipeInstructions(),
            );
          },
        ),
        Builder(
          builder: (context) {
            final pending = context.watch<ReviewActionsCubit>().state;
            final pendingCount = pending.length;

            if (pendingCount == 0 && !_showResetToStartButton) {
              return const SizedBox.shrink();
            }

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (pendingCount > 0)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () {
                          final reviewActionsCubit = context
                              .read<ReviewActionsCubit>();

                          // Tüm pending keep/delete işlemlerini iptal et
                          while (reviewActionsCubit.state.isNotEmpty) {
                            reviewActionsCubit.undoLast();
                          }

                          // Tüm işlemler iptal edildikten sonra galeriyi başa sar
                          // ve swipe index'ini 0'a al.
                          _resetToStart();
                        },
                        child: Text(
                          l10n.undo,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary, // Daha belirgin renk
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary
                                .withOpacity(0.6), // Primary renkte border
                            width: 1.5,
                          ),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.outline,
                          backgroundColor: AppColors.transparent,
                        ),
                      ),
                    ),
                  if (pendingCount > 0) const SizedBox(width: 12),
                  if (pendingCount > 0)
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        onPressed: () async {
                          final l10n = AppLocalizations.of(context)!;
                          final theme = Theme.of(context);

                          cubitSetState(() {
                            _isDeleting = true;
                          });

                          // Delete limit'i kontrol et
                          final deleteLimitController = context
                              .read<DeleteLimitCubit>();
                          final deleteLimit = await deleteLimitController
                              .currentLimit();
                          final pendingCount = context
                              .read<ReviewActionsCubit>()
                              .state
                              .length;

                          // Delete limit'e göre maksimum silinebilecek fotoğraf sayısını belirle
                          final maxDeleteCount = deleteLimit < 999999999
                              ? math.min(deleteLimit, pendingCount)
                              : pendingCount;

                          debugPrint(
                            '📊 [SwipePage] Silme işlemi başlatılıyor: $maxDeleteCount/$pendingCount fotoğraf silinecek (limit: $deleteLimit)',
                          );

                          final deletedCount = await context
                              .read<ReviewActionsCubit>()
                              .applyPendingDeletes(
                                maxDeleteCount: maxDeleteCount,
                              );

                          debugPrint(
                            '📊 [SwipePage] Silme işlemi tamamlandı: $deletedCount fotoğraf silindi',
                          );

                          if (!context.mounted) {
                            debugPrint(
                              '⚠️ [SwipePage] Context mounted değil, işlem iptal edildi',
                            );
                            if (mounted) {
                              cubitSetState(() {
                                _isDeleting = false;
                              });
                            }
                            return;
                          }

                          // Silme işlemi başarılı olup olmadığını kontrol et
                          if (deletedCount > 0) {
                            debugPrint(
                              '✅ [SwipePage] $deletedCount fotoğraf başarıyla silindi, silme hakkı azaltılıyor...',
                            );

                            try {
                              final newLimit = await deleteLimitController
                                  .decrease(deletedCount);
                              debugPrint(
                                '💾 [SwipePage] Delete limit güncellendi, kalan: $newLimit (azaltılan: $deletedCount)',
                              );

                              // Mevcut swipe index'ini kaydet - silme sonrası kaldığı yerden devam etmek için
                              final currentIndexBeforeReload =
                                  _currentSwipeIndex;
                              debugPrint(
                                '💾 [SwipePage] Mevcut swipe index kaydedildi: $currentIndexBeforeReload',
                              );

                              // Başarı dialog'unu önce göster - reload'dan önce
                              // Böylece dialog gösterilirken TabView rebuild olmaz
                              debugPrint(
                                '🎯 [SwipePage] About to show delete success dialog - deletedCount: $deletedCount, context.mounted: ${context.mounted}',
                              );
                              if (context.mounted) {
                                debugPrint(
                                  '✅ [SwipePage] Context is mounted, calling _showDeleteSuccessDialog...',
                                );
                                await showDeleteSuccessDialog(
                                  context,
                                  deletedCount,
                                );
                                debugPrint(
                                  '✅ [SwipePage] _showDeleteSuccessDialog completed',
                                );
                              } else {
                                debugPrint(
                                  '❌ [SwipePage] Context not mounted, cannot show dialog',
                                );
                              }

                              // Her 3 silme işleminden sonra paywall dialog göster (premium olmayan kullanıcılar için)
                              if (context.mounted) {
                                try {
                                  final prefsService = PreferencesService();
                                  final isPremium = await prefsService.isPremium();
                                  
                                  if (!isPremium) {
                                    final shouldShowPaywall = await prefsService.incrementDeleteCountForPaywall();
                                    if (shouldShowPaywall) {
                                      debugPrint('💰 [SwipeTab] 3 silme işlemi tamamlandı, paywall dialog gösteriliyor...');
                                      // Kısa bir gecikme sonra paywall dialog göster
                                      await Future.delayed(const Duration(milliseconds: 500));
                                      if (context.mounted) {
                                        await SwipePage.showPaywallDialogAfterDelete(context);
                                      }
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('❌ [SwipeTab] Paywall dialog kontrolünde hata: $e');
                                }
                              }

                              // Reload'u dialog kapandıktan sonra yap
                              // Böylece dialog gösterilirken TabView rebuild olmaz
                              if (mounted) {
                                context.read<GalleryPagingCubit>().reload();

                                // Reload sonrası, silinen fotoğraflar listeden çıktığı için
                                // index'i ayarla (silinen fotoğraflar kadar azalt)
                                // Ancak index 0'dan küçük olamaz
                                final adjustedIndex =
                                    (currentIndexBeforeReload - deletedCount)
                                        .clamp(0, 999999999);

                                // Index ayarlamasını işaretle - _buildSwipeArea'da uygulanacak
                                cubitSetState(() {
                                  _pendingIndexAdjustment = adjustedIndex;
                                  _currentSwipeIndex = adjustedIndex;
                                });
                                _saveSwipeIndex(adjustedIndex);
                                debugPrint(
                                  '💾 [SwipePage] Swipe index ayarlandı: $currentIndexBeforeReload -> $adjustedIndex (silinen: $deletedCount)',
                                );
                              }
                            } catch (e, stackTrace) {
                              debugPrint(
                                '❌ [SwipePage] Silme hakkı azaltılırken hata: $e',
                              );
                              debugPrint(
                                '❌ [SwipePage] Stack trace: $stackTrace',
                              );
                              await deleteLimitController.refresh();
                              // Hata olsa bile dialog'u göster
                              debugPrint(
                                '🎯 [SwipePage] Error case - About to show delete success dialog - deletedCount: $deletedCount, context.mounted: ${context.mounted}',
                              );
                              if (context.mounted) {
                                debugPrint(
                                  '✅ [SwipePage] Error case - Context is mounted, calling _showDeleteSuccessDialog...',
                                );
                                await showDeleteSuccessDialog(
                                  context,
                                  deletedCount,
                                );
                                debugPrint(
                                  '✅ [SwipePage] Error case - _showDeleteSuccessDialog completed',
                                );
                              } else {
                                debugPrint(
                                  '❌ [SwipePage] Error case - Context not mounted, cannot show dialog',
                                );
                              }
                            }
                          } else {
                            debugPrint(
                              '⚠️ [SwipePage] Silme işlemi başarısız veya hiç fotoğraf silinmedi (deletedCount: $deletedCount)',
                            );
                            // Kullanıcıya bilgi ver
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.deleteOperationFailed),
                                  backgroundColor: theme.colorScheme.error,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                          // Animasyonu 1 saniye sonra durdur
                          Future.delayed(
                            const Duration(milliseconds: 1000),
                            () {
                              if (mounted) {
                                cubitSetState(() {
                                  _isDeleting = false;
                                });
                              }
                            },
                          );
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              Theme.of(
                                context,
                              ).extension<AppSemanticColors>()?.delete ??
                              Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onError,
                          side: BorderSide(
                            color: AppColors.error.withOpacity(
                              0.9,
                            ), // Kırmızı border
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  Theme.of(context).colorScheme.onError,
                                  BlendMode.srcATop,
                                ),
                                child: Lottie.asset(
                                  'assets/lottie/trash.json',
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                  repeat: _isDeleting,
                                  options: LottieOptions(
                                    enableMergePaths: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.deletePhotos(pendingCount)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

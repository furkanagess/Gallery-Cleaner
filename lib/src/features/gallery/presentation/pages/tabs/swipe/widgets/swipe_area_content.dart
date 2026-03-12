import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../../../../../../../core/utils/view_refresh_cubit.dart';
import '../../../../../application/gallery_providers.dart';
import '../../../../../application/review_actions_controller.dart';
import '../../../../../../../../src/app/theme/app_colors.dart' show AppColors;
import '../../../../../../../../src/app/theme/app_three_d_button.dart'
    show AppThreeDButton;
import '../../../../../../../../src/app/theme/app_theme.dart'
    show AppSemanticColors;
import '../../../../../../../../l10n/app_localizations.dart'
    show AppLocalizations;
import '../../../../widgets/photo_swipe_deck.dart'
    show PhotoSwipeDeck, SwipeDecision;
import '../../../../../../../../src/core/services/sound_service.dart'
    show SoundService;
import '../../../../../../../../src/core/services/preferences_service.dart'
    show PreferencesService;
import '../../../../../../../../src/core/services/in_app_review_service.dart'
    show requestInAppReview;
import 'swipe_tab_helpers.dart'
    show
        isPositionOverWidget,
        getWidgetCenter,
        showAlbumSelectionDialog,
        maybePrefetch;

// iOS için basit sayaç widget'ı - ChangeNotifier ile çalışır
class _IOSSwipeCounterNotifier extends ChangeNotifier {
  int _index = 0;
  int _totalCount = 0;

  int get index => _index;
  int get totalCount => _totalCount;

  void update(int index, int totalCount) {
    if (_index != index || _totalCount != totalCount) {
      _index = index;
      _totalCount = totalCount;
      notifyListeners();
      debugPrint(
        '🔄 [_IOSSwipeCounterNotifier] Güncellendi: $_index / $_totalCount',
      );
    }
  }
}

// iOS için sayaç widget'ı - ChangeNotifier dinler
class _IOSSwipeCounter extends StatelessWidget {
  const _IOSSwipeCounter({required this.notifier});

  final _IOSSwipeCounterNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, child) {
        final index = notifier.index;
        final totalCount = notifier.totalCount;
        debugPrint('🎨 [_IOSSwipeCounter] Build - Index: $index / $totalCount');
        return Container(
          key: ValueKey('ios_counter_$index'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Text(
            '${index + 1} / $totalCount',
            key: ValueKey('ios_counter_text_$index'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        );
      },
    );
  }
}

class SwipeAreaContent extends StatefulWidget {
  const SwipeAreaContent({
    super.key,
    required this.assets,
    required this.changeAlbumZoneKey,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.onResetCallbackReady,
    this.currentIndex = 0,
  });

  final List<pm.AssetEntity> assets;
  final GlobalKey changeAlbumZoneKey;
  final int initialIndex;
  final void Function(int index)? onIndexChanged;
  final void Function(VoidCallback resetCallback)? onResetCallbackReady;
  final int currentIndex;

  @override
  State<SwipeAreaContent> createState() => SwipeAreaContentState();
}

class SwipeAreaContentState extends State<SwipeAreaContent>
    with CubitStateMixin<SwipeAreaContent>, TickerProviderStateMixin {
  // Index takibi
  int _currentIndex = 0;
  // iOS için ChangeNotifier - sayaç widget'ını güncellemek için
  _IOSSwipeCounterNotifier? _iosCounterNotifier;

  static const double _verticalActivationOffset = 16.0;
  static const double _verticalMaxTravel = 280.0;
  static const double _verticalMinScale = 0.58;
  static const double _zoneMaxDistance = 400.0;
  static const double _zoneMinScale = 0.45;
  static const double _zoneMinOpacity = 0.65;

  double _dragScale = 1.0;
  Offset _dragOffset = Offset.zero;
  bool _isDraggingToAlbum = false;
  Offset? _dragStartPosition;
  bool _isDialogShowing = false;
  // PhotoSwipeDeck'ten gelen drag offset
  Offset? _pendingDragOffset; // Build sırasında update'i geciktirmek için
  bool _hasPendingOffsetUpdate =
      false; // Build sırasında update'i geciktirmek için
  // Animasyonlu opacity değerleri - kaybolurken animasyon için
  double _animatedDeleteOpacity = 0.0;
  double _animatedKeepOpacity = 0.0;
  // Overlay genişlikleri - titremeyi önlemek için cache
  double _cachedDeleteOverlayWidth = 0.0;
  double _cachedKeepOverlayWidth = 0.0;
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    // iOS için ChangeNotifier başlat
    if (Platform.isIOS) {
      _iosCounterNotifier = _IOSSwipeCounterNotifier();
      _iosCounterNotifier!.update(_currentIndex, widget.assets.length);
    }
  }

  @override
  void dispose() {
    // iOS için ChangeNotifier dispose
    _iosCounterNotifier?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SwipeAreaContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    final didAssetCountChange = oldWidget.assets.length != widget.assets.length;
    final oldTopId = oldWidget.assets.isEmpty
        ? null
        : oldWidget.assets.first.id;
    final newTopId = widget.assets.isEmpty ? null : widget.assets.first.id;

    if (oldTopId != newTopId) {
      _resetVisuals();
    }

    // currentIndex prop'u değiştiyse state'i güncelle
    if (widget.currentIndex != _currentIndex) {
      _currentIndex = widget.currentIndex;
      // iOS için ChangeNotifier güncelle
      if (Platform.isIOS) {
        _iosCounterNotifier?.update(_currentIndex, widget.assets.length);
        debugPrint(
          '🍎 [SwipeAreaContent] iOS - sayaç prop ile güncellendi: $_currentIndex',
        );
      } else {
        cubitSetState(() {
          // _currentIndex zaten yukarıda güncellendi
        });
        debugPrint(
          '🤖 [SwipeAreaContent] Android - prop ile güncellendi: $_currentIndex',
        );
      }
    } else if (didAssetCountChange && Platform.isIOS) {
      // iOS sayaçta toplam foto sayısını senkron tut
      _iosCounterNotifier?.update(_currentIndex, widget.assets.length);
      debugPrint(
        '🍎 [SwipeAreaContent] iOS - toplam sayı güncellendi: ${widget.assets.length}',
      );
    }
  }

  void _handleIndexChanged(int index) {
    if (_currentIndex != index) {
      debugPrint(
        '🔄 [SwipeAreaContent] Index değişiyor: $_currentIndex -> $index',
      );

      _currentIndex = index;

      // iOS için ChangeNotifier güncelle - her zaman güncelle
      if (Platform.isIOS) {
        // Eğer notifier null ise, yeniden oluştur
        if (_iosCounterNotifier == null) {
          _iosCounterNotifier = _IOSSwipeCounterNotifier();
          debugPrint(
            '⚠️ [SwipeAreaContent] iOS - ChangeNotifier yeniden oluşturuldu',
          );
        }
        _iosCounterNotifier!.update(_currentIndex, widget.assets.length);
        debugPrint(
          '🍎 [SwipeAreaContent] iOS - ChangeNotifier ile güncellendi: $_currentIndex / ${widget.assets.length}',
        );
      } else {
        // Android için cubitSetState kullan
        cubitSetState(() {
          // _currentIndex zaten yukarıda güncellendi
        });
        debugPrint(
          '🤖 [SwipeAreaContent] Android - cubitSetState ile güncellendi: $_currentIndex',
        );
      }

      // Parent widget'a da bildir
      widget.onIndexChanged?.call(index);
      debugPrint(
        '✅ [SwipeAreaContent] Index güncellendi: $_currentIndex / ${widget.assets.length}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kalan silme hakkından fazla sola kaydırmaya izin verme; hak dolunca uyarı dialogu göster
    final deleteLimitAsync = context.watch<DeleteLimitCubit>().state;
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    final pendingDeletes = context.watch<ReviewActionsCubit>().state;
    final deleteLimit = deleteLimitAsync.valueOrNull ?? 0;
    final isPremium = isPremiumAsync.valueOrNull ?? false;
    final pendingDeleteCount = pendingDeletes.length;
    final remainingRights = isPremium
        ? 999999
        : (deleteLimit - pendingDeleteCount);
    final canDelete = remainingRights > 0;

    // iOS için buildWithCubit kullanma - normal build kullan
    // Android için buildWithCubit kullan
    Widget widgetTree = RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ana içerik - Swipe Deck (daha küçük)
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: AspectRatio(
                        aspectRatio: 5 / 7,
                        child: AnimatedScale(
                          scale: _dragScale,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          child: Transform.translate(
                            offset: _dragOffset,
                            child: Stack(
                              fit: StackFit.expand,
                              clipBehavior: Clip.none,
                              children: [
                                PhotoSwipeDeck(
                                  key: ValueKey(
                                    widget.assets.isEmpty
                                        ? 'empty'
                                        : '${widget.assets.first.id}_${widget.assets.length}',
                                  ),
                                  assets: widget.assets,
                                  initialIndex: widget.initialIndex,
                                  canDelete: canDelete,
                                  isDraggingToAlbum: () => _isDraggingToAlbum,
                                  onDragUpdate: _handleDragUpdate,
                                  onDragEnd: (asset, pos) {
                                    _handleDragEnd(asset, pos);
                                  },
                                  onDecision: (asset, decision) {
                                    _handleDecision(asset, decision);
                                  },
                                  onUndoDecision: (asset, decision) {
                                    _handleUndoDecision(asset, decision);
                                  },
                                  onNoRightsLeft: () {
                                    _showNoRightsDialog(context);
                                  },
                                  onIndexChanged: _handleIndexChanged,
                                  onResetCallbackReady:
                                      widget.onResetCallbackReady,
                                  onDragOffsetChanged: (offset) {
                                    // Build sırasında setState çağrılmasını engellemek için
                                    // postFrameCallback kullanarak setState'i geciktir
                                    if (!mounted) return;

                                    // Pending offset'i güncelle (her zaman en son değeri tut)
                                    _pendingDragOffset = offset;

                                    // Eğer zaten bir pending update yoksa, yeni bir tane ekle
                                    // Bu sayede çok fazla postFrameCallback eklenmesini engelleriz
                                    if (!_hasPendingOffsetUpdate) {
                                      _hasPendingOffsetUpdate = true;
                                      WidgetsBinding.instance.addPostFrameCallback((
                                        _,
                                      ) {
                                        if (mounted &&
                                            _pendingDragOffset != null) {
                                          final offsetToApply =
                                              _pendingDragOffset!;
                                          _pendingDragOffset = null;
                                          _hasPendingOffsetUpdate = false;

                                          // Opacity değerlerini hesapla
                                          final dragDx = offsetToApply.dx;
                                          final deleteOffsetAbsCalc = dragDx < 0
                                              ? dragDx.abs()
                                              : 0.0;
                                          final deleteProgressCalc =
                                              deleteOffsetAbsCalc >= 10.0
                                              ? ((deleteOffsetAbsCalc - 10.0) /
                                                        100.0)
                                                    .clamp(0.0, 1.0)
                                              : 0.0;
                                          final targetDeleteOpacity =
                                              deleteProgressCalc > 0.0
                                              ? (0.3 +
                                                        (deleteProgressCalc *
                                                            0.7))
                                                    .clamp(0.3, 1.0)
                                              : 0.0;

                                          final keepOffsetCalc = dragDx > 0
                                              ? dragDx
                                              : 0.0;
                                          final keepProgressCalc =
                                              keepOffsetCalc >= 10.0
                                              ? ((keepOffsetCalc - 10.0) /
                                                        100.0)
                                                    .clamp(0.0, 1.0)
                                              : 0.0;
                                          final targetKeepOpacity =
                                              keepProgressCalc > 0.0
                                              ? (0.3 + (keepProgressCalc * 0.7))
                                                    .clamp(0.3, 1.0)
                                              : 0.0;

                                          // Overlay genişliklerini hesapla (sadece gerekli olduğunda)
                                          final screenWidth = MediaQuery.of(
                                            context,
                                          ).size.width;
                                          const buttonSize = 80.0;
                                          final leftButtonCenterX =
                                              screenWidth / 2 - 70;
                                          final rightButtonCenterX =
                                              screenWidth / 2 + 70;
                                          final leftButtonRightEdge =
                                              leftButtonCenterX +
                                              (buttonSize / 2);
                                          final rightButtonLeftEdge =
                                              rightButtonCenterX -
                                              (buttonSize / 2);
                                          final leftToButton =
                                              leftButtonRightEdge;
                                          final rightToButton =
                                              screenWidth - rightButtonLeftEdge;

                                          final newDeleteOverlayWidth =
                                              deleteProgressCalc * leftToButton;
                                          final newKeepOverlayWidth =
                                              keepProgressCalc * rightToButton;

                                          // Titremeyi önlemek için minimum threshold kontrolü
                                          // Sadece 0.05'ten büyük değişikliklerde güncelle
                                          final deleteOpacityDelta =
                                              (targetDeleteOpacity -
                                                      _animatedDeleteOpacity)
                                                  .abs();
                                          final keepOpacityDelta =
                                              (targetKeepOpacity -
                                                      _animatedKeepOpacity)
                                                  .abs();

                                          // Overlay genişlik değişikliklerini kontrol et (2 pixel threshold)
                                          final deleteWidthDelta =
                                              (newDeleteOverlayWidth -
                                                      _cachedDeleteOverlayWidth)
                                                  .abs();
                                          final keepWidthDelta =
                                              (newKeepOverlayWidth -
                                                      _cachedKeepOverlayWidth)
                                                  .abs();

                                          if (deleteOpacityDelta > 0.05 ||
                                              keepOpacityDelta > 0.05 ||
                                              deleteWidthDelta > 2.0 ||
                                              keepWidthDelta > 2.0 ||
                                              (targetDeleteOpacity == 0.0 &&
                                                  _animatedDeleteOpacity >
                                                      0.0) ||
                                              (targetKeepOpacity == 0.0 &&
                                                  _animatedKeepOpacity > 0.0)) {
                                            setState(() {
                                              // Animasyonlu opacity değerlerini güncelle (AnimatedOpacity animasyonu yapacak)
                                              _animatedDeleteOpacity =
                                                  targetDeleteOpacity;
                                              _animatedKeepOpacity =
                                                  targetKeepOpacity;
                                              // Overlay genişliklerini güncelle
                                              _cachedDeleteOverlayWidth =
                                                  newDeleteOverlayWidth;
                                              _cachedKeepOverlayWidth =
                                                  newKeepOverlayWidth;
                                            });
                                          }

                                          // Titreme animasyonları kaldırıldı - titremeyi önlemek için
                                        } else if (mounted) {
                                          _hasPendingOffsetUpdate = false;
                                        }
                                      });
                                    }
                                  },
                                ),
                                // Fotoğraf sayacı - Deck içinde
                                // iOS için özel çözüm - direkt _currentIndex kullan ve her build'de yeni widget oluştur
                                if (widget.assets.isNotEmpty)
                                  Positioned(
                                    bottom: 12,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: _buildCounterWidget(context),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Delete Photos Butonu - Swipe Deck'in hemen altında
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child:
                          BlocBuilder<
                            ReviewActionsCubit,
                            List<PendingDeleteAction>
                          >(
                            builder: (context, pendingActions) {
                              final pendingCount = pendingActions.length;
                              final l10n = AppLocalizations.of(context)!;
                              final theme = Theme.of(context);

                              final hasPending = pendingCount > 0;

                              final baseColor = hasPending
                                  ? (theme
                                            .extension<AppSemanticColors>()
                                            ?.delete ??
                                        theme.colorScheme.error)
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.15,
                                    );

                              final textColor = hasPending
                                  ? AppColors.white
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    );

                              return IgnorePointer(
                                ignoring: !hasPending,
                                child: Opacity(
                                  opacity: hasPending ? 1.0 : 0.6,
                                  child: TweenAnimationBuilder<double>(
                                    key: ValueKey(
                                      'delete_button_$pendingCount',
                                    ),
                                    duration: const Duration(milliseconds: 420),
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    curve: Curves.easeOut,
                                    builder: (context, value, child) {
                                      // Shake + hafif scale animasyonu
                                      final shake =
                                          math.sin(value * math.pi * 6) *
                                          (1 - value) *
                                          4;
                                      final scale = 1 + (1 - value) * 0.02;
                                      return Transform.translate(
                                        offset: Offset(shake, 0),
                                        child: Transform.scale(
                                          scale: scale,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: AppThreeDButton(
                                      label: l10n.deletePhotos(pendingCount),
                                      icon: Icons.delete_outline_rounded,
                                      onPressed: hasPending
                                          ? () {
                                              context.push(
                                                '/review-delete-photos',
                                              );
                                            }
                                          : () {},
                                      baseColor: baseColor,
                                      textColor: textColor,
                                      fullWidth: true,
                                      height: 56,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Overlay'ler - Ekranın tam kenarından başlayacak (swipe deck üzerinde)
          if (widget.assets.isNotEmpty && canDelete)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: _buildSwipeActionButtons(context),
                ),
              ),
            ),
        ],
      ),
    );

    // iOS için direkt döndür, Android için buildWithCubit ile sarmala
    if (Platform.isIOS) {
      return widgetTree;
    } else {
      return buildWithCubit(() => widgetTree);
    }
  }

  void _handleDragUpdate(Offset globalPos) {
    _dragStartPosition ??= globalPos;

    final changeAlbumZoneCenter = getWidgetCenter(widget.changeAlbumZoneKey);
    final isOverChangeAlbumZone = isPositionOverWidget(
      widget.changeAlbumZoneKey,
      globalPos,
    );

    double zoneScale = 1.0;
    double zoneOpacity = 1.0;
    Offset zoneOffset = Offset.zero;
    double distanceToZone = double.infinity;

    if (changeAlbumZoneCenter != null) {
      distanceToZone = (globalPos - changeAlbumZoneCenter).distance;

      if (isOverChangeAlbumZone) {
        zoneScale = _zoneMinScale;
        zoneOpacity = _zoneMinOpacity;

        final directionToCenter = changeAlbumZoneCenter - globalPos;
        zoneOffset = Offset(
          directionToCenter.dx * 0.1,
          directionToCenter.dy * 0.1,
        );
      } else if (distanceToZone < _zoneMaxDistance) {
        final normalizedDistance = (distanceToZone / _zoneMaxDistance).clamp(
          0.0,
          1.0,
        );
        final easedDistance = math.pow(normalizedDistance, 0.65).toDouble();

        zoneScale = _zoneMinScale + (easedDistance * (1.0 - _zoneMinScale));
        zoneScale = zoneScale.clamp(_zoneMinScale, 1.0);

        zoneOpacity =
            _zoneMinOpacity + (easedDistance * (1.0 - _zoneMinOpacity));
        zoneOpacity = zoneOpacity.clamp(_zoneMinOpacity, 1.0);

        final directionToCenter = changeAlbumZoneCenter - globalPos;
        final offsetIntensity = (1.0 - easedDistance) * 0.12;
        zoneOffset = Offset(
          directionToCenter.dx * offsetIntensity,
          directionToCenter.dy * offsetIntensity,
        );
      }
    }

    final upwardDragRaw = _dragStartPosition == null
        ? 0.0
        : (_dragStartPosition!.dy - globalPos.dy);
    final upwardDrag = math.max(0.0, upwardDragRaw);
    final effectiveDrag = math.max(0.0, upwardDrag - _verticalActivationOffset);
    final verticalRange = math.max(
      1.0,
      _verticalMaxTravel - _verticalActivationOffset,
    );
    final verticalProgress = (effectiveDrag / verticalRange).clamp(0.0, 1.0);
    final verticalFactor = math.pow(verticalProgress, 0.65).toDouble();

    final verticalScale = 1.0 - verticalFactor * (1.0 - _verticalMinScale);

    cubitSetState(() {
      _dragScale = math.min(zoneScale, verticalScale);
      _dragOffset = zoneOffset;
      _isDraggingToAlbum = isOverChangeAlbumZone;
    });
  }

  Future<void> _handleDragEnd(pm.AssetEntity asset, Offset pos) async {
    final isOverChangeAlbumZone = isPositionOverWidget(
      widget.changeAlbumZoneKey,
      pos,
    );

    _resetVisuals();

    if (isOverChangeAlbumZone && mounted && widget.assets.isNotEmpty) {
      final soundService = SoundService();
      soundService.playKeepSound();

      await showAlbumSelectionDialog(context, asset, widget.assets);
    }
  }

  Future<void> _handleDecision(
    pm.AssetEntity asset,
    SwipeDecision decision,
  ) async {
    final actions = context.read<ReviewActionsCubit>();

    if (decision == SwipeDecision.keep) {
      await actions.onKeep(asset);
    } else {
      await actions.onDelete(asset);
    }

    // Swipe sayacını artır; 10 swipe sonrası in_app_review ile değerlendirme iste
    final prefsService = PreferencesService();
    final shouldShowRateUs = await prefsService.incrementSwipeCount();
    if (shouldShowRateUs) {
      unawaited(requestInAppReview());
    }

    if (!mounted) return;
    maybePrefetch(context, widget.assets, asset);
    _resetVisuals();
  }

  Future<void> _handleUndoDecision(
    pm.AssetEntity asset,
    SwipeDecision decision,
  ) async {
    if (!mounted) return;
    final actions = context.read<ReviewActionsCubit>();
    await actions.undoDecision(asset, wasKeep: decision == SwipeDecision.keep);
  }

  void _resetVisuals() {
    if (!mounted) return;

    if (Platform.isIOS) {
      setState(() {
        _dragScale = 1.0;
        _dragOffset = Offset.zero;
        _isDraggingToAlbum = false;
        _dragStartPosition = null;
      });
    } else {
      cubitSetState(() {
        _dragScale = 1.0;
        _dragOffset = Offset.zero;
        _isDraggingToAlbum = false;
        _dragStartPosition = null;
      });
    }
  }

  // Sayaç widget builder
  Widget _buildCounterWidget(BuildContext context) {
    if (Platform.isIOS) {
      // iOS için ChangeNotifier ile çalışan widget
      // Eğer notifier null ise, yeniden oluştur
      if (_iosCounterNotifier == null) {
        _iosCounterNotifier = _IOSSwipeCounterNotifier();
        _iosCounterNotifier!.update(_currentIndex, widget.assets.length);
        debugPrint(
          '⚠️ [SwipeAreaContent] iOS - ChangeNotifier build sırasında oluşturuldu',
        );
      }
      return _IOSSwipeCounter(notifier: _iosCounterNotifier!);
    } else {
      // Android için AnimatedSwitcher kullan
      final currentIndex = _currentIndex;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Container(
          key: ValueKey('counter_android_$currentIndex'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Text(
            '${currentIndex + 1} / ${widget.assets.length}',
            key: ValueKey('counter_text_android_$currentIndex'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
    }
  }

  List<Widget> _buildSwipeActionButtons(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Buton boyutları
    const double buttonSize = 80.0;
    const double buttonIconSize = 32.0;

    // Buton konumları - ekranın daha yukarısında
    final buttonCenterY = screenHeight / 2 - 120;
    final leftButtonCenterX = screenWidth / 2 - 70;
    final rightButtonCenterX = screenWidth / 2 + 70;

    // Animasyonlu opacity değerlerini kullan (drag offset callback'inde güncelleniyor)
    final deleteOpacity = _animatedDeleteOpacity;
    final keepOpacity = _animatedKeepOpacity;

    // Overlay genişlikleri - cache'lenmiş değerleri kullan (titremeyi önlemek için)
    final deleteOverlayWidth = _cachedDeleteOverlayWidth;
    final keepOverlayWidth = _cachedKeepOverlayWidth;

    return [
      // Sol overlay - Ekranın en solundan sol butonun sağına kadar
      if (deleteOpacity > 0.0 || _animatedDeleteOpacity > 0.0)
        Positioned(
          left: 0,
          top: buttonCenterY - (buttonSize / 2),
          height: buttonSize,
          width: deleteOverlayWidth,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Opacity(
                opacity: _animatedDeleteOpacity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.error.withValues(alpha: 0.6),
                        AppColors.error.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      // Sağ overlay - Ekranın en sağından sağ butonun soluna kadar
      if (keepOpacity > 0.0 || _animatedKeepOpacity > 0.0)
        Positioned(
          right: 0,
          top: buttonCenterY - (buttonSize / 2),
          height: buttonSize,
          width: keepOverlayWidth,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Opacity(
                opacity: _animatedKeepOpacity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        AppColors.success.withValues(alpha: 0.6),
                        AppColors.success.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      // Sol buton - Sil
      if (deleteOpacity > 0.0 || _animatedDeleteOpacity > 0.0)
        Positioned(
          left: leftButtonCenterX - (buttonSize / 2),
          top: buttonCenterY - (buttonSize / 2),
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Opacity(
                opacity: _animatedDeleteOpacity,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.delete_forever_rounded,
                      size: buttonIconSize,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      // Sağ buton - Tut
      if (keepOpacity > 0.0 || _animatedKeepOpacity > 0.0)
        Positioned(
          left: rightButtonCenterX - (buttonSize / 2),
          top: buttonCenterY - (buttonSize / 2),
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Opacity(
                opacity: _animatedKeepOpacity,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      size: buttonIconSize,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  void _showNoRightsDialog(BuildContext context) {
    // Dialog zaten açıksa, yeni dialog açma
    if (_isDialogShowing) return;

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.block_rounded,
                  size: 28,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noDeleteRightsLeft,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noDeleteRightsLeftMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _isDialogShowing = false;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        context.push('/paywall');
                      }
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.getUnlimitedDeletions,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColors.transparent,
                  foregroundColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.6,
                  ),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                ),
                child: Text(
                  l10n.maybeLater,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Dialog kapandığında flag'i sıfırla
      _isDialogShowing = false;
    });
  }
}

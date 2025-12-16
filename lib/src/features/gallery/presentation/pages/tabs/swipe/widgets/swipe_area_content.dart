import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import '../../../../widgets/new_year_event_card.dart' show NewYearEventCard;
import '../../../../../../../../src/core/services/sound_service.dart'
    show SoundService;
import '../../../../../../../../src/core/services/preferences_service.dart'
    show PreferencesService;
import 'swipe_tab_helpers.dart'
    show
        isPositionOverWidget,
        getWidgetCenter,
        showAlbumSelectionDialog,
        maybePrefetch;
import 'album_selection_sheet.dart' show AlbumSelectionSheet;

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
            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.2),
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
  Offset _photoSwipeDragOffset =
      Offset.zero; // PhotoSwipeDeck'ten gelen drag offset
  Offset? _pendingDragOffset; // Build sırasında update'i geciktirmek için
  bool _hasPendingOffsetUpdate =
      false; // Build sırasında update'i geciktirmek için
  // Animasyonlu opacity değerleri - kaybolurken animasyon için
  double _animatedDeleteOpacity = 0.0;
  double _animatedKeepOpacity = 0.0;
  // New Year Event Card görünürlüğü
  bool _showNewYearEventCard = true;
  // Titreme animasyonları için controller'lar
  late AnimationController _deleteShakeController;
  late AnimationController _keepShakeController;
  late Animation<double> _deleteShakeAnimation;
  late Animation<double> _keepShakeAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    // iOS için ChangeNotifier başlat
    if (Platform.isIOS) {
      _iosCounterNotifier = _IOSSwipeCounterNotifier();
      _iosCounterNotifier!.update(_currentIndex, widget.assets.length);
    }
    // Titreme animasyon controller'ları
    _deleteShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    _keepShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    // Titreme animasyonları - rastgele yönlerde titreme
    _deleteShakeAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _deleteShakeController, curve: Curves.easeInOut),
    );
    _keepShakeAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _keepShakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // iOS için ChangeNotifier dispose
    _iosCounterNotifier?.dispose();
    // Titreme animasyon controller'ları dispose
    _deleteShakeController.dispose();
    _keepShakeController.dispose();
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
    // Kullanıcı her zaman swipe edebilsin; gerçek silme hakkı,
    // review/delete aşamasında DeleteLimitCubit ile kontrol ediliyor.
    const canDelete = true;

    // iOS için buildWithCubit kullanma - normal build kullan
    // Android için buildWithCubit kullan
    Widget widgetTree = RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // New Year Event Card - Altta, Swipe Deck'in üstünde
              if (_showNewYearEventCard)
                NewYearEventCard(
                  onDismiss: () {
                    if (Platform.isIOS) {
                      setState(() {
                        _showNewYearEventCard = false;
                      });
                    } else {
                      cubitSetState(() {
                        _showNewYearEventCard = false;
                      });
                    }
                  },
                  onTap: () {
                    // Event card'a tıklandığında yapılacak işlem
                    // Örneğin: Event detay sayfasına git veya paywall göster
                  },
                ),
              // Ana içerik - Swipe Deck (daha küçük)
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: AspectRatio(
                        aspectRatio: 5 / 6,
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
                                // Kar birikimi efekti - Alt kısım
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: 40,
                                  child: IgnorePointer(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      ),
                                      child: _buildSnowAccumulation(
                                        width: double.infinity,
                                        height: 40,
                                        isHorizontal: true,
                                      ),
                                    ),
                                  ),
                                ),
                                // Kar birikimi efekti - Sol kenar
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 30,
                                  child: IgnorePointer(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        bottomLeft: Radius.circular(20),
                                      ),
                                      child: _buildSnowAccumulation(
                                        width: 30,
                                        height: double.infinity,
                                        isHorizontal: false,
                                      ),
                                    ),
                                  ),
                                ),
                                // Kar birikimi efekti - Sağ kenar
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 30,
                                  child: IgnorePointer(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      ),
                                      child: _buildSnowAccumulation(
                                        width: 30,
                                        height: double.infinity,
                                        isHorizontal: false,
                                      ),
                                    ),
                                  ),
                                ),
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
                                          final deleteOffsetAbs = dragDx < 0
                                              ? dragDx.abs()
                                              : 0.0;
                                          final deleteProgress =
                                              deleteOffsetAbs >= 10.0
                                              ? ((deleteOffsetAbs - 10.0) /
                                                        100.0)
                                                    .clamp(0.0, 1.0)
                                              : 0.0;
                                          final targetDeleteOpacity =
                                              deleteProgress > 0.0
                                              ? (0.3 + (deleteProgress * 0.7))
                                                    .clamp(0.3, 1.0)
                                              : 0.0;

                                          final keepOffset = dragDx > 0
                                              ? dragDx
                                              : 0.0;
                                          final keepProgress =
                                              keepOffset >= 10.0
                                              ? ((keepOffset - 10.0) / 100.0)
                                                    .clamp(0.0, 1.0)
                                              : 0.0;
                                          final targetKeepOpacity =
                                              keepProgress > 0.0
                                              ? (0.3 + (keepProgress * 0.7))
                                                    .clamp(0.3, 1.0)
                                              : 0.0;

                                          setState(() {
                                            _photoSwipeDragOffset =
                                                offsetToApply;
                                            // Animasyonlu opacity değerlerini güncelle (AnimatedOpacity animasyonu yapacak)
                                            _animatedDeleteOpacity =
                                                targetDeleteOpacity;
                                            _animatedKeepOpacity =
                                                targetKeepOpacity;
                                          });

                                          // Titreme animasyonlarını başlat/durdur
                                          if (targetDeleteOpacity > 0.0) {
                                            if (!_deleteShakeController
                                                .isAnimating) {
                                              _deleteShakeController.repeat();
                                            }
                                          } else {
                                            _deleteShakeController.stop();
                                            _deleteShakeController.reset();
                                          }

                                          if (targetKeepOpacity > 0.0) {
                                            if (!_keepShakeController
                                                .isAnimating) {
                                              _keepShakeController.repeat();
                                            }
                                          } else {
                                            _keepShakeController.stop();
                                            _keepShakeController.reset();
                                          }
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
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.15,
                                    );

                              final textColor = hasPending
                                  ? AppColors.white
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.6,
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

    // Swipe sayacını artır (rate us dialog artık gösterilmiyor)
    final prefsService = PreferencesService();
    await prefsService.incrementSwipeCount();

    maybePrefetch(context, widget.assets, asset);
    _resetVisuals();
  }

  Future<void> _handleUndoDecision(
    pm.AssetEntity asset,
    SwipeDecision decision,
  ) async {
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
        _photoSwipeDragOffset = Offset.zero;
      });
    } else {
      cubitSetState(() {
        _dragScale = 1.0;
        _dragOffset = Offset.zero;
        _isDraggingToAlbum = false;
        _dragStartPosition = null;
        _photoSwipeDragOffset = Offset.zero;
      });
    }
  }

  // Kar birikimi efekti builder
  Widget _buildSnowAccumulation({
    required double width,
    required double height,
    required bool isHorizontal,
  }) {
    const double snowSize = 20.0; // snow.png görselinin boyutu

    // Infinity veya NaN kontrolü
    final safeWidth = width.isFinite && width > 0 ? width : 0.0;
    final safeHeight = height.isFinite && height > 0 ? height : 0.0;

    final int count = isHorizontal
        ? (safeWidth / snowSize).ceil().clamp(
            0,
            1000,
          ) // Maksimum 1000 ile sınırla
        : (safeHeight / snowSize).ceil().clamp(
            0,
            1000,
          ); // Maksimum 1000 ile sınırla

    return isHorizontal
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              count,
              (index) => Image.asset(
                'assets/new_year/snow.png',
                width: snowSize,
                height: snowSize,
                fit: BoxFit.cover,
              ),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              count,
              (index) => Image.asset(
                'assets/new_year/snow.png',
                width: snowSize,
                height: snowSize,
                fit: BoxFit.cover,
              ),
            ),
          );
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
            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.2),
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

    // Drag offset değerlerini al
    final dragDx = _photoSwipeDragOffset.dx;

    // Debug: Her zaman offset değerini logla
    if (dragDx.abs() > 5.0) {
      debugPrint('🎯 [SwipeActionButtons] Drag dx: $dragDx');
    }

    // Sol swipe (delete) hesaplamaları
    final deleteOffsetAbs = dragDx < 0 ? dragDx.abs() : 0.0;
    // Çok düşük threshold - 10px'den itibaren görünür
    final deleteProgress = deleteOffsetAbs >= 10.0
        ? ((deleteOffsetAbs - 10.0) / 100.0).clamp(0.0, 1.0)
        : 0.0;

    // Sağ swipe (keep) hesaplamaları
    final keepOffset = dragDx > 0 ? dragDx : 0.0;
    // Çok düşük threshold - 10px'den itibaren görünür
    final keepProgress = keepOffset >= 10.0
        ? ((keepOffset - 10.0) / 100.0).clamp(0.0, 1.0)
        : 0.0;

    // Animasyonlu opacity değerlerini kullan (drag offset callback'inde güncelleniyor)
    final deleteOpacity = _animatedDeleteOpacity;
    final keepOpacity = _animatedKeepOpacity;

    // Overlay genişlikleri - ekranın kenarlarından butonlara kadar
    final leftButtonRightEdge = leftButtonCenterX + (buttonSize / 2);
    final rightButtonLeftEdge = rightButtonCenterX - (buttonSize / 2);
    final leftToButton = leftButtonRightEdge;
    final rightToButton = screenWidth - rightButtonLeftEdge;
    final deleteOverlayWidth = deleteProgress * leftToButton;
    final keepOverlayWidth = keepProgress * rightToButton;

    return [
      // Sol overlay - Ekranın en solundan sol butonun sağına kadar
      if (deleteOpacity > 0.0 || _animatedDeleteOpacity > 0.0)
        Positioned(
          left: 0,
          top: buttonCenterY - (buttonSize / 2),
          height: buttonSize,
          width: deleteOverlayWidth,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _animatedDeleteOpacity,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.error.withOpacity(0.6),
                      AppColors.error.withOpacity(0.0),
                    ],
                    stops: const [0.0, 1.0],
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
            child: AnimatedOpacity(
              opacity: _animatedKeepOpacity,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      AppColors.success.withOpacity(0.6),
                      AppColors.success.withOpacity(0.0),
                    ],
                    stops: const [0.0, 1.0],
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
            child: AnimatedOpacity(
              opacity: _animatedDeleteOpacity,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedBuilder(
                animation: _deleteShakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _deleteShakeAnimation.value *
                          math.sin(_deleteShakeController.value * math.pi * 4),
                      _deleteShakeAnimation.value *
                          math.cos(_deleteShakeController.value * math.pi * 4),
                    ),
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/new_year/christmas-tree.png',
                          width: buttonIconSize,
                          height: buttonIconSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
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
            child: AnimatedOpacity(
              opacity: _animatedKeepOpacity,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedBuilder(
                animation: _keepShakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _keepShakeAnimation.value *
                          math.sin(_keepShakeController.value * math.pi * 4),
                      _keepShakeAnimation.value *
                          math.cos(_keepShakeController.value * math.pi * 4),
                    ),
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/new_year/candy-cane.png',
                          width: buttonIconSize,
                          height: buttonIconSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
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
      barrierColor: AppColors.black.withOpacity(0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (value * 0.2),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.25),
                  blurRadius: 32,
                  spreadRadius: 2,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.error,
                        theme.colorScheme.error.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.error.withOpacity(0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.block,
                    size: 40,
                    color: theme.colorScheme.onError,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  l10n.noDeleteRightsLeft,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  l10n.noDeleteRightsLeftMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Purchase button with gradient
                SizedBox(
                  width: double.infinity,
                  child: Container(
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
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Material(
                      color: AppColors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          _isDialogShowing = false;
                          context.push('/paywall');
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Text(
                            l10n.getUnlimitedDeletions,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.white,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Cancel button
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    l10n.maybeLater,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      // Dialog kapandığında flag'i sıfırla
      _isDialogShowing = false;
    });
  }
}

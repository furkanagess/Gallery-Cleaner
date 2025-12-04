import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../../../../../../../core/utils/view_refresh_cubit.dart';
import '../../../../../application/gallery_providers.dart';
import '../../../../../application/review_actions_controller.dart';
import '../../../../../../../../src/app/theme/app_colors.dart' show AppColors;
import '../../../../../../../../l10n/app_localizations.dart'
    show AppLocalizations;
import '../../../../widgets/photo_swipe_deck.dart'
    show PhotoSwipeDeck, SwipeDecision;
import '../../../../../../../../src/core/services/sound_service.dart'
    show SoundService;
import '../../../../../../../../src/core/services/preferences_service.dart'
    show PreferencesService;
import 'swipe_tab_helpers.dart'
    show
        isPositionOverWidget,
        getWidgetCenter,
        showAlbumSelectionDialog,
        maybePrefetch,
        showRateUsDialog;

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
      debugPrint('🔄 [_IOSSwipeCounterNotifier] Güncellendi: $_index / $_totalCount');
    }
  }
}

// iOS için sayaç widget'ı - ChangeNotifier dinler
class _IOSSwipeCounter extends StatelessWidget {
  const _IOSSwipeCounter({
    required this.notifier,
  });

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
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
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
    with CubitStateMixin<SwipeAreaContent> {
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
        debugPrint('🍎 [SwipeAreaContent] iOS - sayaç prop ile güncellendi: $_currentIndex');
      } else {
        cubitSetState(() {
          // _currentIndex zaten yukarıda güncellendi
        });
        debugPrint('🤖 [SwipeAreaContent] Android - prop ile güncellendi: $_currentIndex');
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
      debugPrint('🔄 [SwipeAreaContent] Index değişiyor: $_currentIndex -> $index');
      
      _currentIndex = index;
      
      // iOS için ChangeNotifier güncelle - her zaman güncelle
      if (Platform.isIOS) {
        // Eğer notifier null ise, yeniden oluştur
        if (_iosCounterNotifier == null) {
          _iosCounterNotifier = _IOSSwipeCounterNotifier();
          debugPrint('⚠️ [SwipeAreaContent] iOS - ChangeNotifier yeniden oluşturuldu');
        }
        _iosCounterNotifier!.update(_currentIndex, widget.assets.length);
        debugPrint('🍎 [SwipeAreaContent] iOS - ChangeNotifier ile güncellendi: $_currentIndex / ${widget.assets.length}');
      } else {
        // Android için cubitSetState kullan
        cubitSetState(() {
          // _currentIndex zaten yukarıda güncellendi
        });
        debugPrint('🤖 [SwipeAreaContent] Android - cubitSetState ile güncellendi: $_currentIndex');
      }
      
      // Parent widget'a da bildir
      widget.onIndexChanged?.call(index);
      debugPrint('✅ [SwipeAreaContent] Index güncellendi: $_currentIndex / ${widget.assets.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Silme hakkı kontrolü - BLoC kullanarak
    final deleteLimitCubit = context.watch<DeleteLimitCubit>();
    final canDelete = deleteLimitCubit.state.maybeWhen(
      data: (limit) => limit > 0,
      orElse: () => true, // Loading veya error durumunda varsayılan olarak true
    );

    // iOS için buildWithCubit kullanma - normal build kullan
    // Android için buildWithCubit kullan
    Widget widgetTree = RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ana içerik - Swipe Deck
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 16,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
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
                                  onResetCallbackReady: widget.onResetCallbackReady,
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
                                        if (mounted && _pendingDragOffset != null) {
                                          final offsetToApply = _pendingDragOffset!;
                                          _pendingDragOffset = null;
                                          _hasPendingOffsetUpdate = false;
                                          setState(() {
                                            _photoSwipeDragOffset = offsetToApply;
                                          });
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
                  ),
                ),
                // Overlay'ler - Ekranın tam kenarından başlayacak
                if (widget.assets.isNotEmpty && canDelete)
                  ..._buildSwipeActionButtons(context),
              ],
            ),
          ),
          // Swipe yönlendirme metinleri - Deck'in dışında altında
          // Undo butonları göründüğünde (pending actions varsa) metinleri gizle
          if (widget.assets.isNotEmpty)
            Builder(
              builder: (context) {
                final pendingActions = context.watch<ReviewActionsCubit>().state;
                // Eğer pending actions varsa (undo butonları görünüyorsa) metinleri gösterme
                if (pendingActions.isNotEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Sola kaydır sil
                      Text(
                        AppLocalizations.of(context)!.swipeLeftToDelete,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 12,
                            ),
                      ),
                      const SizedBox(width: 16),
                      // Sağa kaydır tut
                      Text(
                        AppLocalizations.of(context)!.swipeRightToKeep,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                );
              },
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

    // Swipe sayacını artır ve rate us dialog kontrolü yap
    final prefsService = PreferencesService();
    final shouldShowRateUs = await prefsService.incrementSwipeCount();
    
    if (shouldShowRateUs && mounted) {
      // Kısa bir gecikme sonrası dialog göster (kullanıcı deneyimini bozmamak için)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          showRateUsDialog(context);
        }
      });
    }

    maybePrefetch(context, widget.assets, asset);
    _resetVisuals();
  }

  Future<void> _handleUndoDecision(
    pm.AssetEntity asset,
    SwipeDecision decision,
  ) async {
    final actions = context.read<ReviewActionsCubit>();
    await actions.undoDecision(
      asset,
      wasKeep: decision == SwipeDecision.keep,
    );
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

  // Sayaç widget builder
  Widget _buildCounterWidget(BuildContext context) {
    if (Platform.isIOS) {
      // iOS için ChangeNotifier ile çalışan widget
      // Eğer notifier null ise, yeniden oluştur
      if (_iosCounterNotifier == null) {
        _iosCounterNotifier = _IOSSwipeCounterNotifier();
        _iosCounterNotifier!.update(_currentIndex, widget.assets.length);
        debugPrint('⚠️ [SwipeAreaContent] iOS - ChangeNotifier build sırasında oluşturuldu');
      }
      return _IOSSwipeCounter(
        notifier: _iosCounterNotifier!,
      );
    } else {
      // Android için AnimatedSwitcher kullan
      final currentIndex = _currentIndex;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: Container(
          key: ValueKey('counter_android_$currentIndex'),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withOpacity(0.9),
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
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface,
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
    // Minimum %30 opacity ile başla, maksimum %100
    final deleteOpacity = deleteProgress > 0.0
        ? (0.3 + (deleteProgress * 0.7)).clamp(0.3, 1.0)
        : 0.0;

    // Sağ swipe (keep) hesaplamaları
    final keepOffset = dragDx > 0 ? dragDx : 0.0;
    // Çok düşük threshold - 10px'den itibaren görünür
    final keepProgress = keepOffset >= 10.0
        ? ((keepOffset - 10.0) / 100.0).clamp(0.0, 1.0)
        : 0.0;
    // Minimum %30 opacity ile başla, maksimum %100
    final keepOpacity = keepProgress > 0.0
        ? (0.3 + (keepProgress * 0.7)).clamp(0.3, 1.0)
        : 0.0;

    // Overlay genişlikleri - ekranın kenarlarından butonlara kadar
    final leftButtonRightEdge = leftButtonCenterX + (buttonSize / 2);
    final rightButtonLeftEdge = rightButtonCenterX - (buttonSize / 2);
    final leftToButton = leftButtonRightEdge;
    final rightToButton = screenWidth - rightButtonLeftEdge;
    final deleteOverlayWidth = deleteProgress * leftToButton;
    final keepOverlayWidth = keepProgress * rightToButton;

    return [
      // Sol overlay - Ekranın en solundan sol butonun sağına kadar
      if (deleteOpacity > 0.0)
        Positioned(
          left: 0,
          top: buttonCenterY - (buttonSize / 2),
          height: buttonSize,
          width: deleteOverlayWidth,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: deleteOpacity,
              duration: const Duration(milliseconds: 150),
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
      if (keepOpacity > 0.0)
        Positioned(
          right: 0,
          top: buttonCenterY - (buttonSize / 2),
          height: buttonSize,
          width: keepOverlayWidth,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: keepOpacity,
              duration: const Duration(milliseconds: 150),
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
      if (deleteOpacity > 0.0)
        Positioned(
          left: leftButtonCenterX - (buttonSize / 2),
          top: buttonCenterY - (buttonSize / 2),
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: deleteOpacity,
              duration: const Duration(milliseconds: 150),
              child: AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.white,
                      size: buttonIconSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      // Sağ buton - Tut
      if (keepOpacity > 0.0)
        Positioned(
          left: rightButtonCenterX - (buttonSize / 2),
          top: buttonCenterY - (buttonSize / 2),
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: keepOpacity,
              duration: const Duration(milliseconds: 150),
              child: AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.white,
                      size: buttonIconSize,
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

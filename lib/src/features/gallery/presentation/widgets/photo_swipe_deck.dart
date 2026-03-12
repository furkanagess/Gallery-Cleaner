// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/services/sound_service.dart';
import 'package:gallery_cleaner/src/core/utils/view_refresh_cubit.dart';

enum SwipeDecision { keep, delete }

pm.ThumbnailSize? _sharedThumbnailSize;

class _SwipeHistoryEntry {
  _SwipeHistoryEntry({
    required this.asset,
    required this.decision,
    required this.index,
  });

  final pm.AssetEntity asset;
  final SwipeDecision decision;
  final int index;
}

pm.ThumbnailSize _resolveThumbnailSize() {
  if (_sharedThumbnailSize != null) return _sharedThumbnailSize!;

  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  final view = dispatcher.views.isNotEmpty ? dispatcher.views.first : null;
  if (view != null) {
    final screenWidth = view.physicalSize.width / view.devicePixelRatio;
    final rawWidth = (screenWidth * 2).round();
    final width = rawWidth.clamp(400, 1200).toInt();
    final rawHeight = ((width / 3) * 4).round();
    final height = rawHeight.clamp(600, 1600).toInt();
    _sharedThumbnailSize = pm.ThumbnailSize(width, height);
    return _sharedThumbnailSize!;
  }

  // Fallback - should rarely happen
  _sharedThumbnailSize = const pm.ThumbnailSize(800, 1066);
  return _sharedThumbnailSize!;
}

class _ThumbnailMemoryCache {
  _ThumbnailMemoryCache._();

  static const _maxEntries = 40;
  static final _cache = <String, Uint8List>{};

  static Uint8List? get(String id) => _cache[id];

  static bool contains(String id) => _cache.containsKey(id);

  static void put(String id, Uint8List data) {
    _cache[id] = data;
    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }
}

class PhotoSwipeDeck extends StatefulWidget {
  const PhotoSwipeDeck({
    super.key,
    required this.assets,
    required this.onDecision,
    this.onDragUpdate,
    this.onDragEnd,
    this.isDraggingToAlbum,
    this.canDelete = true,
    this.onNoRightsLeft,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.onResetCallbackReady,
    this.onDragOffsetChanged,
    this.onUndoDecision,
    this.isCompleted = false,
    this.completedTitle,
    this.completedDescription,
  });

  final List<pm.AssetEntity> assets;
  final void Function(pm.AssetEntity asset, SwipeDecision decision) onDecision;
  final void Function(Offset globalPosition)? onDragUpdate;
  final void Function(pm.AssetEntity asset, Offset globalPosition)? onDragEnd;
  final bool Function()? isDraggingToAlbum;
  final bool canDelete;
  final VoidCallback? onNoRightsLeft;
  final int initialIndex;
  final void Function(int index)? onIndexChanged;
  final void Function(VoidCallback resetCallback)? onResetCallbackReady;
  final void Function(Offset dragOffset)? onDragOffsetChanged;
  final void Function(pm.AssetEntity asset, SwipeDecision decision)?
  onUndoDecision;
  final bool isCompleted;
  final String? completedTitle;
  final String? completedDescription;

  @override
  State<PhotoSwipeDeck> createState() => _PhotoSwipeDeckState();
}

class _PhotoSwipeDeckState extends State<PhotoSwipeDeck>
    with TickerProviderStateMixin, CubitStateMixin<PhotoSwipeDeck> {
  static const double _swipeThreshold = 120;
  static const double _rotationMaxDeg = 15;
  static const int _stackSize = 2;
  // Yukarı sürükleme eşiği

  late int _topIndex;
  Offset _dragOffset = Offset.zero;
  double _dragRotation = 0;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  SwipeDecision? _pendingDecision;
  bool _didHapticForKeep = false;
  bool _didHapticForDelete = false;
  final List<_SwipeHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _topIndex = widget.initialIndex.clamp(0, widget.assets.length);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          )
          ..addListener(_onSlideAnimationUpdate)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed &&
                _pendingDecision != null) {
              _finalizeSwipe(_pendingDecision!);
            }
          });

    // Reset callback'i hazır olduğunda bildir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onResetCallbackReady?.call(resetToStart);
      }
    });

    _prefetchThumbnails();
  }

  void _onSlideAnimationUpdate() {
    if (mounted) {
      cubitSetState(() {
        _dragOffset = _slideAnimation.value;
      });
      widget.onDragOffsetChanged?.call(_slideAnimation.value);
    }
  }

  @override
  void didUpdateWidget(PhotoSwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    final indexChanged = oldWidget.initialIndex != widget.initialIndex;
    final assetsChanged =
        oldWidget.assets.length != widget.assets.length ||
        (oldWidget.assets.isNotEmpty &&
            widget.assets.isNotEmpty &&
            oldWidget.assets.first.id != widget.assets.first.id);

    if (widget.initialIndex == 0 && indexChanged && !assetsChanged) {
      resetToStart();
    } else if (indexChanged || assetsChanged) {
      final safeIndex = widget.assets.isEmpty
          ? 0
          : widget.initialIndex.clamp(0, widget.assets.length - 1);
      if (_topIndex != safeIndex ||
          _dragOffset != Offset.zero ||
          _dragRotation != 0) {
        cubitSetState(() {
          _topIndex = safeIndex;
          _dragOffset = Offset.zero;
          _dragRotation = 0;
          if (assetsChanged) {
            _history.clear();
          }
        });
        widget.onDragOffsetChanged?.call(Offset.zero);
      }
    }
    // Reset callback değiştiyse güncelle
    if (oldWidget.onResetCallbackReady != widget.onResetCallbackReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onResetCallbackReady?.call(resetToStart);
        }
      });
    }

    _prefetchThumbnails();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Galeriyi başa al
  void resetToStart() {
    if (mounted) {
      cubitSetState(() {
        _topIndex = 0;
        _dragOffset = Offset.zero;
        _dragRotation = 0;
        _pendingDecision = null;
        _history.clear();
      });
      widget.onDragOffsetChanged?.call(Offset.zero);
      widget.onIndexChanged?.call(0);
    }

    _prefetchThumbnails();
  }

  void _animateBack() {
    _pendingDecision = null;
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller
      ..reset()
      ..forward();
    cubitSetState(() {
      _dragRotation = 0;
      _didHapticForKeep = false;
      _didHapticForDelete = false;
    });
  }

  void _animateOff(SwipeDecision decision) {
    _pendingDecision = decision;
    final width = MediaQuery.of(context).size.width;
    final end = decision == SwipeDecision.keep
        ? Offset(width * 1.5, 0)
        : Offset(-width * 1.5, 0);
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller
      ..reset()
      ..forward();
  }

  void _finalizeSwipe(SwipeDecision decision) {
    if (_topIndex >= widget.assets.length) return;
    final asset = widget.assets[_topIndex];
    final currentIndex = _topIndex;

    // Ses efekti çal
    final soundService = SoundService();
    if (decision == SwipeDecision.delete) {
      soundService.playDeleteSound();
    } else {
      soundService.playKeepSound();
    }

    cubitSetState(() {
      _topIndex += 1;
      _dragOffset = Offset.zero;
      _dragRotation = 0;
      _pendingDecision = null;
      _history.add(
        _SwipeHistoryEntry(
          asset: asset,
          decision: decision,
          index: currentIndex,
        ),
      );
    });

    widget.onDragOffsetChanged?.call(Offset.zero);
    // Index değişikliğini bildir
    widget.onIndexChanged?.call(_topIndex);

    widget.onDecision(asset, decision);

    _prefetchThumbnails();
  }

  void _undoLastSwipe() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    final targetIndex = last.index.clamp(0, widget.assets.length).toInt();

    cubitSetState(() {
      _topIndex = targetIndex;
      _dragOffset = Offset.zero;
      _dragRotation = 0;
      _pendingDecision = null;
    });

    widget.onDragOffsetChanged?.call(Offset.zero);
    widget.onIndexChanged?.call(_topIndex);
    widget.onUndoDecision?.call(last.asset, last.decision);
    _prefetchThumbnails();
  }

  Widget _buildUndoButton(BuildContext context) {
    final canUndo = _history.isNotEmpty;
    final l10n = AppLocalizations.of(context);
    final label = l10n?.undo ?? 'Undo';

    return Tooltip(
      message: label,
      child: Material(
        color: AppColors.black.withValues(alpha:canUndo ? 0.7 : 0.35),
        shape: const CircleBorder(),
        elevation: canUndo ? 6 : 0,
        child: IconButton(
          icon: Icon(
            Icons.undo_rounded,
            color: AppColors.white.withValues(alpha:canUndo ? 1 : 0.4),
          ),
          onPressed: canUndo ? _undoLastSwipe : null,
          splashRadius: 24,
          tooltip: label,
        ),
      ),
    );
  }

  void _prefetchThumbnails({int lookAhead = 3}) {
    if (widget.assets.isEmpty) return;

    final size = _resolveThumbnailSize();
    for (var i = 0; i < lookAhead; i++) {
      final idx = _topIndex + i;
      if (idx >= widget.assets.length) break;

      final asset = widget.assets[idx];
      if (_ThumbnailMemoryCache.contains(asset.id)) continue;

      asset
          .thumbnailDataWithSize(size, quality: 75)
          .then((data) {
            if (data != null) {
              _ThumbnailMemoryCache.put(asset.id, data);
            }
          })
          .catchError((error) {
            debugPrint(
              '⚠️ [PhotoSwipeDeck] Prefetch failed for ${asset.id}: $error',
            );
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildWithCubit(() {
      if (widget.isCompleted) {
        return _buildAllPhotosReviewedWidget(
          context,
          titleOverride: widget.completedTitle,
          descriptionOverride: widget.completedDescription,
        );
      }
      if (_topIndex >= widget.assets.length) {
        return _buildAllPhotosReviewedWidget(
          context,
          titleOverride: widget.completedTitle,
          descriptionOverride: widget.completedDescription,
        );
      }

      final cards = <Widget>[];
      final count = math.min(_stackSize, widget.assets.length - _topIndex);
      for (int i = 0; i < count; i++) {
        final idx = _topIndex + i;
        final isTop = i == 0;
        cards.add(
          _buildCard(
            context,
            widget.assets[idx],
            indexFromTop: i,
            isTop: isTop,
            absoluteIndex: idx,
          ),
        );
      }

      // Stack'e şeffaf arka plan ekle - siyah alan sorununu önlemek için
      return Container(
        color: AppColors.transparent,
        child: Stack(children: cards.reversed.toList()),
      );
    });
  }

  Widget _buildCard(
    BuildContext context,
    pm.AssetEntity asset, {
    required int indexFromTop,
    required bool isTop,
    required int absoluteIndex,
  }) {
    const baseScale = 1.0;
    const baseOffsetY = 0.0;

    final rotation = isTop ? _dragRotation : 0.0;

    // Only top card moves, background cards stay fixed
    final offset = isTop
        ? _dragOffset
        : Offset(0, baseOffsetY); // Background cards remain static

    // Animasyon kaldırıldı - kartlar sabit scale ve opacity ile görünür
    final cardScale = isTop
        ? 1.0
        : baseScale; // Background cards maintain fixed scale

    // Karartı overlay'i kaldırıldı - tüm kartlar tam görünür, animasyon yok
    // AnimatedContainer kaldırıldı - titremeyi önlemek için
    Widget card = Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotation * math.pi / 180,
        child: Transform.scale(
          scale: cardScale,
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                // Şeffaf arka plan - siyah alan sorununu önlemek için
                color: AppColors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha:
                      0.3 - (indexFromTop * 0.06),
                    ),
                    blurRadius: 24 - (indexFromTop * 4),
                    offset: Offset(0, 10 + (indexFromTop * 2.5)),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: _PhotoCard(asset: asset),
            ),
          ),
        ),
      ),
    );

    if (isTop) {
      card = GestureDetector(
        onPanStart: (details) {
          // Silme hakkı yoksa hiçbir hareket yapmasın
          if (!widget.canDelete) {
            widget.onNoRightsLeft?.call();
            return;
          }
          _controller.stop();
        },
        onPanUpdate: (details) {
          // Silme hakkı yoksa hiçbir swipe hareketine izin verme
          if (!widget.canDelete) {
            widget.onNoRightsLeft?.call();
            return;
          }

          // Yalnızca yatay hareket - dikey hareketi sıfırla
          final newOffset = Offset(_dragOffset.dx + details.delta.dx, 0.0);

          // Optimize: Sadece belirli bir threshold'dan büyük değişikliklerde güncelle
          // Bu titremeyi önler
          final deltaX = (newOffset.dx - _dragOffset.dx).abs();
          final newRotation = (newOffset.dx / 12).clamp(
            -_rotationMaxDeg,
            _rotationMaxDeg,
          );
          final rotationDelta = (newRotation - _dragRotation).abs();

          // Minimum threshold: 0.5 pixel veya 0.1 derece değişiklik
          if (deltaX > 0.5 || rotationDelta > 0.1) {
            cubitSetState(() {
              _dragOffset = newOffset;
              _dragRotation = newRotation;
            });
            widget.onDragOffsetChanged?.call(newOffset);
          }

          // Haptik feedback
          if (newOffset.dx > _swipeThreshold && !_didHapticForKeep) {
            HapticFeedback.lightImpact();
            _didHapticForKeep = true;
          } else if (newOffset.dx < -_swipeThreshold && !_didHapticForDelete) {
            HapticFeedback.lightImpact();
            _didHapticForDelete = true;
          }
        },
        onPanEnd: (details) {
          // Silme hakkı yoksa hiçbir swipe hareketine izin verme
          if (!widget.canDelete) {
            widget.onNoRightsLeft?.call();
            _animateBack();
            return;
          }

          final dx = _dragOffset.dx;

          // Yalnızca yatay swipe kontrolü - dikey hareket yok
          if (dx.abs() >= _swipeThreshold) {
            debugPrint(
              '🔄 [PhotoSwipeDeck] Yatay swipe: ${dx > 0 ? "keep" : "delete"}',
            );
            _animateOff(dx > 0 ? SwipeDecision.keep : SwipeDecision.delete);
          } else {
            debugPrint(
              '🔄 [PhotoSwipeDeck] Swipe threshold altında, geri dönüyor',
            );
            _animateBack();
          }
        },
        onPanCancel: () {
          _animateBack();
        },
        child: Stack(
          children: [
            card,
            // Underlay: gradient overlay
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.black.withValues(alpha:0.22),
                          AppColors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _buildUndoButton(context),
            ),
          ],
        ),
      );
    } else {
      card = IgnorePointer(child: card);
    }

    // Optimize: RepaintBoundary ile wrap et
    // AnimatedSwitcher kaldırıldı - siyah alan sorununu önlemek için
    // Key'i unique yapmak için asset.id ve absoluteIndex'i birleştir
    // Bu, albüm değiştiğinde veya aynı asset farklı pozisyonlarda göründüğünde duplicate key hatasını önler
    return RepaintBoundary(
      key: ValueKey('${asset.id}_$absoluteIndex'),
      child: card,
    );
  }

  Widget _buildAllPhotosReviewedWidget(
    BuildContext context, {
    String? titleOverride,
    String? descriptionOverride,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha:0.15),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success animation (wipe lottie)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.ctaGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha:0.3),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Lottie.asset(
                  'assets/lottie/wipe.json',
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                  repeat: false,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              titleOverride ?? l10n.allPhotosReviewedTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              descriptionOverride ?? l10n.allPhotosReviewedDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha:0.7),
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatefulWidget {
  const _PhotoCard({required this.asset});
  final pm.AssetEntity asset;

  @override
  State<_PhotoCard> createState() => _PhotoCardState();
}

enum _ArrowDirection { topLeft, topRight, bottomLeft, bottomRight }

class _BadgeWithArrow extends StatefulWidget {
  const _BadgeWithArrow({
    required this.color,
    required this.icon,
    required this.label,
    required this.arrowDirection,
    required this.isDelete,
    required this.isKeep,
    required this.shouldAnimate,
  });

  final Color color;
  final IconData icon;
  final String label;
  final _ArrowDirection arrowDirection;
  final bool isDelete;
  final bool isKeep;
  final bool shouldAnimate;

  @override
  State<_BadgeWithArrow> createState() => _BadgeWithArrowState();
}

class _BadgeWithArrowState extends State<_BadgeWithArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // Keep ve delete animasyonları daha yavaş
    final duration = widget.isKeep
        ? const Duration(milliseconds: 1000) // Keep için yavaş
        : const Duration(milliseconds: 1500); // Delete için daha yavaş
    _animationController = AnimationController(vsync: this, duration: duration);
    if (widget.shouldAnimate && (widget.isDelete || widget.isKeep)) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(_BadgeWithArrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldAnimate && widget.isKeep) {
      // Keep animasyonu - yavaş
      if (!oldWidget.shouldAnimate) {
        _animationController.duration = const Duration(milliseconds: 1000);
        _animationController.repeat();
      } else {
        _animationController.duration = const Duration(milliseconds: 800);
      }
    } else if (widget.shouldAnimate && widget.isDelete) {
      // Delete animasyonu - daha yavaş
      if (!oldWidget.shouldAnimate) {
        _animationController.duration = const Duration(milliseconds: 1500);
        _animationController.repeat();
      } else {
        _animationController.duration = const Duration(milliseconds: 1200);
      }
    } else if (!widget.shouldAnimate && oldWidget.shouldAnimate) {
      // Animasyon durduruluyor
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.color.withValues(alpha:1.0);
    final borderRadius = BorderRadius.circular(16);

    Widget arrow() {
      return Transform.rotate(
        angle: 0.785398, // 45 deg
        child: Container(width: 12, height: 12, color: bg),
      );
    }

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius,
        border: Border.all(
          color: widget.isDelete
              ? AppColors.error.withValues(alpha:
                  0.8,
                ) // Silme butonu için daha belirgin kırmızı border
              : AppColors.white.withValues(alpha:
                  0.6,
                ), // Diğer butonlar için beyaz border
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha:0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.black.withValues(alpha:0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.isDelete
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      AppColors.white,
                      BlendMode.srcATop,
                    ),
                    child: Lottie.asset(
                      'assets/lottie/trash.json',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                      controller: _animationController,
                      repeat: widget.shouldAnimate,
                      options: LottieOptions(enableMergePaths: true),
                    ),
                  ),
                )
              : widget.isKeep
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      AppColors.white,
                      BlendMode.srcATop,
                    ),
                    child: Lottie.asset(
                      'assets/lottie/keep_photo.json',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                      controller: _animationController,
                      repeat: widget.shouldAnimate,
                      options: LottieOptions(enableMergePaths: true),
                    ),
                  ),
                )
              : Icon(widget.icon, color: AppColors.white, size: 22),
          const SizedBox(width: 10),
          Text(
            widget.label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.2,
              shadows: [
                Shadow(
                  color: AppColors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
                Shadow(
                  color: AppColors.black38,
                  blurRadius: 10,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    switch (widget.arrowDirection) {
      case _ArrowDirection.topLeft:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [arrow(), chip],
        );
      case _ArrowDirection.topRight:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [arrow(), chip],
        );
      case _ArrowDirection.bottomLeft:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [chip, arrow()],
        );
      case _ArrowDirection.bottomRight:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [chip, arrow()],
        );
    }
  }
}

class _PhotoCardState extends State<_PhotoCard> {
  late Future<Uint8List?> _thumbFuture;
  Uint8List? _previousImageData;
  Uint8List? _currentImageData;

  @override
  void initState() {
    super.initState();
    _hydrateFromCache();
    _startThumbnailLoad();
  }

  @override
  void didUpdateWidget(covariant _PhotoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id == widget.asset.id) return;

    if (_currentImageData != null) {
      _previousImageData = _currentImageData;
    }

    _hydrateFromCache();
    _startThumbnailLoad();
  }

  void _hydrateFromCache() {
    final cached = _ThumbnailMemoryCache.get(widget.asset.id);
    if (cached != null) {
      _currentImageData = cached;
      _previousImageData ??= cached;
    }
  }

  void _startThumbnailLoad() {
    _thumbFuture = _getThumbnailFuture();
    _thumbFuture
        .then((data) {
          if (!mounted || data == null) return;
          if (_currentImageData == data) return;
          setState(() {
            _currentImageData = data;
            _previousImageData ??= data;
          });
        })
        .catchError((error) {
          debugPrint('❌ [PhotoCard] Error loading thumbnail: $error');
        });
  }

  Future<Uint8List?> _getThumbnailFuture() async {
    final cached = _ThumbnailMemoryCache.get(widget.asset.id);
    if (cached != null) return cached;

    try {
      final data = await widget.asset.thumbnailDataWithSize(
        _resolveThumbnailSize(),
        quality: 75,
      );
      if (data != null) {
        _ThumbnailMemoryCache.put(widget.asset.id, data);
      }
      return data;
    } catch (error) {
      debugPrint('❌ [PhotoCard] Error loading thumbnail: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbSize = _resolveThumbnailSize();
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.black.withValues(alpha:0.35),
            AppColors.black.withValues(alpha:0.15),
          ],
        ),
      ),
    );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: AppColors.transparent,
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              FutureBuilder<Uint8List?>(
                future: _thumbFuture,
                initialData: _currentImageData ?? _previousImageData,
                builder: (context, snapshot) {
                  final imageData =
                      _currentImageData ?? snapshot.data ?? _previousImageData;

                  if (imageData == null) {
                    return placeholder;
                  }

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: Image.memory(
                      imageData,
                      key: ObjectKey(imageData),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      cacheWidth: thumbSize.width,
                      cacheHeight: thumbSize.height,
                      errorBuilder: (context, error, stackTrace) {
                        if (_previousImageData != null) {
                          return Image.memory(
                            _previousImageData!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.medium,
                          );
                        }
                        return placeholder;
                      },
                    ),
                  );
                },
              ),
              // Date overlay - sol üstte
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha:0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha:0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha:0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    DateFormat('dd.MM.yyyy').format(widget.asset.createDateTime),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Fotoğrafın renklerine göre parlama efekti
class _ColorBasedGlowEffect extends StatefulWidget {
  const _ColorBasedGlowEffect({required this.imageData});

  final Uint8List imageData;

  @override
  State<_ColorBasedGlowEffect> createState() => _ColorBasedGlowEffectState();
}

class _ColorBasedGlowEffectState extends State<_ColorBasedGlowEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Color? _dominantColor;
  bool _isAnalyzing = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _analyzeImageColors();
  }

  @override
  void didUpdateWidget(_ColorBasedGlowEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageData != widget.imageData) {
      _isAnalyzing = true;
      _analyzeImageColors();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyzeImageColors() async {
    try {
      final image = img.decodeImage(widget.imageData);
      if (image == null) {
        setState(() {
          _isAnalyzing = false;
        });
        return;
      }

      // Fotoğrafın kenarlarından örnekleme yap (parlama efekti için)
      final sampleSize = math.min(50, math.min(image.width, image.height));
      final samples = <img.Color>[];

      // Üst kenar
      for (int x = 0; x < image.width; x += image.width ~/ sampleSize) {
        if (x < image.width) {
          samples.add(image.getPixel(x, 0));
        }
      }
      // Alt kenar
      for (int x = 0; x < image.width; x += image.width ~/ sampleSize) {
        if (x < image.width) {
          samples.add(image.getPixel(x, image.height - 1));
        }
      }
      // Sol kenar
      for (int y = 0; y < image.height; y += image.height ~/ sampleSize) {
        if (y < image.height) {
          samples.add(image.getPixel(0, y));
        }
      }
      // Sağ kenar
      for (int y = 0; y < image.height; y += image.height ~/ sampleSize) {
        if (y < image.height) {
          samples.add(image.getPixel(image.width - 1, y));
        }
      }

      if (samples.isEmpty) {
        setState(() {
          _isAnalyzing = false;
        });
        return;
      }

      // Ortalama renk hesapla
      int rSum = 0, gSum = 0, bSum = 0;
      for (final color in samples) {
        rSum += color.r.toInt();
        gSum += color.g.toInt();
        bSum += color.b.toInt();
      }
      final avgR = (rSum / samples.length).round();
      final avgG = (gSum / samples.length).round();
      final avgB = (bSum / samples.length).round();

      // Parlama için renkleri biraz parlaklaştır
      final brightR = math.min(255, (avgR * 1.3).round()).toInt();
      final brightG = math.min(255, (avgG * 1.3).round()).toInt();
      final brightB = math.min(255, (avgB * 1.3).round()).toInt();

      if (mounted) {
        setState(() {
          _dominantColor = Color.fromRGBO(brightR, brightG, brightB, 1.0);
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing || _dominantColor == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final animationValue = _controller.value;
        final opacity = 0.15 + (math.sin(animationValue * 2 * math.pi) * 0.1);

        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  _dominantColor!.withValues(alpha:opacity),
                  _dominantColor!.withValues(alpha:opacity * 0.5),
                  _dominantColor!.withValues(alpha:0),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}

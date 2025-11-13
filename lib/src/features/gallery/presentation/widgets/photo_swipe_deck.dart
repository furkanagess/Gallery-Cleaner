import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/services/sound_service.dart';

enum SwipeDecision { keep, delete }

pm.ThumbnailSize? _sharedThumbnailSize;

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
  static final _cache = LinkedHashMap<String, Uint8List>();

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

  @override
  State<PhotoSwipeDeck> createState() => _PhotoSwipeDeckState();
}

class _PhotoSwipeDeckState extends State<PhotoSwipeDeck> with TickerProviderStateMixin {
  static const double _swipeThreshold = 120;
  static const double _rotationMaxDeg = 15;
  static const int _stackSize = 2;
  static const double _verticalDragThreshold = -80; // Yukarı sürükleme eşiği

  late int _topIndex;
  Offset _dragOffset = Offset.zero;
  Offset? _lastGlobalPosition;
  double _dragRotation = 0;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  SwipeDecision? _pendingDecision;
  bool _didHapticForKeep = false;
  bool _didHapticForDelete = false;

  @override
  void initState() {
    super.initState();
    _topIndex = widget.initialIndex.clamp(0, widget.assets.length);
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(_onSlideAnimationUpdate)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _pendingDecision != null) {
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
      setState(() {
        _dragOffset = _slideAnimation.value;
      });
    }
  }

  @override
  void didUpdateWidget(PhotoSwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    final indexChanged = oldWidget.initialIndex != widget.initialIndex;
    final assetsChanged = oldWidget.assets.length != widget.assets.length ||
        (oldWidget.assets.isNotEmpty &&
            widget.assets.isNotEmpty &&
            oldWidget.assets.first.id != widget.assets.first.id);

    if (widget.initialIndex == 0 && indexChanged && !assetsChanged) {
      resetToStart();
    } else if (indexChanged || assetsChanged) {
      final safeIndex = widget.assets.isEmpty
          ? 0
          : widget.initialIndex.clamp(0, widget.assets.length - 1);
      if (_topIndex != safeIndex || _dragOffset != Offset.zero || _dragRotation != 0) {
        setState(() {
          _topIndex = safeIndex;
          _dragOffset = Offset.zero;
          _dragRotation = 0;
        });
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
      setState(() {
        _topIndex = 0;
        _dragOffset = Offset.zero;
        _dragRotation = 0;
        _pendingDecision = null;
      });
      widget.onIndexChanged?.call(0);
    }

    _prefetchThumbnails();
  }

  void _animateBack() {
    _pendingDecision = null;
    _slideAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller
      ..reset()
      ..forward();
    setState(() {
      _dragRotation = 0;
      _didHapticForKeep = false;
      _didHapticForDelete = false;
    });
  }

  void _animateOff(SwipeDecision decision) {
    _pendingDecision = decision;
    final width = MediaQuery.of(context).size.width;
    final end = decision == SwipeDecision.keep ? Offset(width * 1.5, 0) : Offset(-width * 1.5, 0);
    _slideAnimation = Tween<Offset>(begin: _dragOffset, end: end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller
      ..reset()
      ..forward();
  }

  void _finalizeSwipe(SwipeDecision decision) {
    if (_topIndex >= widget.assets.length) return;
    final asset = widget.assets[_topIndex];
    
    // Ses efekti çal
    final soundService = SoundService();
    if (decision == SwipeDecision.delete) {
      soundService.playDeleteSound();
    } else {
      soundService.playKeepSound();
    }
    
    setState(() {
      _topIndex += 1;
      _dragOffset = Offset.zero;
      _dragRotation = 0;
      _pendingDecision = null;
    });
    
    // Index değişikliğini bildir
    widget.onIndexChanged?.call(_topIndex);
    
    widget.onDecision(asset, decision);

    _prefetchThumbnails();
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
      }).catchError((error) {
        debugPrint(
          '⚠️ [PhotoSwipeDeck] Prefetch failed for ${asset.id}: $error',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_topIndex >= widget.assets.length) {
      return const Center(child: Text('Bitti. Yeni fotoğraflar yok.'));
    }

    final cards = <Widget>[];
    final count = math.min(_stackSize, widget.assets.length - _topIndex);
    for (int i = 0; i < count; i++) {
      final idx = _topIndex + i;
      final isTop = i == 0;
      cards.add(_buildCard(context, widget.assets[idx], indexFromTop: i, isTop: isTop));
    }

    // Stack'e şeffaf arka plan ekle - siyah alan sorununu önlemek için
    return Container(
      color: AppColors.transparent,
      child: Stack(children: cards.reversed.toList()),
    );
  }

  Widget _buildCard(BuildContext context, pm.AssetEntity asset, {required int indexFromTop, required bool isTop}) {
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

    // Border ve badge hesaplamaları sadece top kart için yapılacak
    final decisionStrength = isTop && widget.canDelete
        ? (_dragOffset.dx / _swipeThreshold).clamp(-1.0, 1.0)
        : 0.0;
    final keepOpacity = isTop && widget.canDelete && decisionStrength > 0 
        ? decisionStrength.abs().clamp(0.0, 1.0) 
        : 0.0;
    final deleteOpacity = isTop && widget.canDelete && decisionStrength < 0
        ? decisionStrength.abs().clamp(0.0, 1.0)
        : 0.0;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final borderColor = isTop
        ? (decisionStrength >= 0
            ? sem.keep.withOpacity(keepOpacity * 0.8)
            : sem.delete.withOpacity(deleteOpacity * 0.8))
        : AppColors.transparent;
    final borderWidth = isTop
        ? ((keepOpacity > deleteOpacity ? keepOpacity : deleteOpacity) * 3.5 + 1.5)
        : 0.0;
    final l10n = AppLocalizations.of(context)!;

    // Karartı overlay'i kaldırıldı - tüm kartlar tam görünür, animasyon yok
    // Border'ı Container'a ekleyerek fotoğrafın çevresinde net görünmesini sağlıyoruz
    // Border sadece top kartta ve swipe yapıldığında görünür
    Widget card = Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotation * math.pi / 180,
        child: Transform.scale(
          scale: cardScale,
          child: RepaintBoundary(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                // Şeffaf arka plan - siyah alan sorununu önlemek için
                color: AppColors.transparent,
                // Border sadece top kartta ve swipe yapıldığında gösterilir
                border: isTop && borderWidth > 0
                    ? Border.all(
                        color: borderColor,
                        width: borderWidth,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withOpacity(0.3 - (indexFromTop * 0.06)),
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
          _lastGlobalPosition = details.globalPosition;
        },
        onPanUpdate: (details) {
          // Silme hakkı yoksa hiçbir swipe hareketine izin verme
          if (!widget.canDelete) {
            widget.onNoRightsLeft?.call();
            return;
          }
          
          final newOffset = _dragOffset + details.delta;
          final isDraggingUpward = newOffset.dy < _verticalDragThreshold;
          
          // Optimize: Sadece değişiklik varsa setState çağır
          final newRotation = isDraggingUpward
              ? (newOffset.dx / 20).clamp(-_rotationMaxDeg * 0.5, _rotationMaxDeg * 0.5)
              : (newOffset.dx / 12).clamp(-_rotationMaxDeg, _rotationMaxDeg);
          
          if (_dragOffset != newOffset || _dragRotation != newRotation) {
            setState(() {
              _dragOffset = newOffset;
              _dragRotation = newRotation;
            });
          }
          
          // Yukarı sürüklenmiyorsa haptik feedback
          if (!isDraggingUpward) {
            if (newOffset.dx > _swipeThreshold && !_didHapticForKeep) {
              HapticFeedback.lightImpact();
              _didHapticForKeep = true;
            } else if (newOffset.dx < -_swipeThreshold && !_didHapticForDelete) {
              HapticFeedback.lightImpact();
              _didHapticForDelete = true;
            }
          }
          
          // Global pozisyonu sakla ve albüm hedeflerine ilet
          _lastGlobalPosition = details.globalPosition;
          if (widget.onDragUpdate != null) {
            widget.onDragUpdate!(details.globalPosition);
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
          final dy = _dragOffset.dy;
          
          final wasDraggingToAlbum = widget.isDraggingToAlbum?.call() ?? false;
          final isUpwardDrag = dy < _verticalDragThreshold;
          final releasePosition = _lastGlobalPosition ??
              (context.findRenderObject() as RenderBox?)
                  ?.localToGlobal(_dragOffset) ??
              Offset.zero;
          final currentAsset = widget.assets[_topIndex];
          
          // Önce albüm hedefi kontrolü
          if (widget.onDragEnd != null) {
            debugPrint(
              '🔄 [PhotoSwipeDeck] onPanEnd: dy=$dy, wasDraggingToAlbum=$wasDraggingToAlbum, isUpwardDrag=$isUpwardDrag, releasePosition=$releasePosition',
            );
            
            // Eğer yukarı sürüklenmişse veya albüme sürüklenmişse, onDragEnd'i çağır
            if (wasDraggingToAlbum || isUpwardDrag) {
              debugPrint('🔄 [PhotoSwipeDeck] Albüm taşıma modu - onDragEnd çağrılıyor');
              widget.onDragEnd!(currentAsset, releasePosition);
              // Albüme taşındıysa swipe yapma, kartı geri döndür
              _animateBack();
              _lastGlobalPosition = null;
              return;
            }
          }
          
          // Yukarı sürüklenmemişse ve albüme taşınmamışsa normal swipe kontrolü
          if (dx.abs() >= _swipeThreshold && dy >= _verticalDragThreshold) {
            debugPrint('🔄 [PhotoSwipeDeck] Normal swipe: ${dx > 0 ? "keep" : "delete"}');
            _animateOff(dx > 0 ? SwipeDecision.keep : SwipeDecision.delete);
          } else {
            debugPrint('🔄 [PhotoSwipeDeck] Swipe threshold altında, geri dönüyor');
            _animateBack();
          }
          
          _lastGlobalPosition = null;
        },
        onPanCancel: () {
          _lastGlobalPosition = null;
          _animateBack();
        },
        child: Stack(
          children: [
            card,
            // Underlay: gradient overlay (border artık kartın üzerinde)
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
                          AppColors.black.withOpacity(0.22),
                          AppColors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Overlays (TOP): Modern badges: delete (bottom-left) and keep/gallery (bottom-right)
            // Badge'ler sadece top kartta gösterilir ve sabit konumda kalır
            if (isTop)
              Positioned.fill(
                child: RepaintBoundary(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Stack(children: [
                    // Delete badge (bottom-left) - sol alt köşede sabit
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: AnimatedOpacity(
                        opacity: deleteOpacity > 0.08 ? deleteOpacity.clamp(0.5, 1.0) : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: AnimatedScale(
                          scale: deleteOpacity > 0.08 ? (0.92 + deleteOpacity * 0.08).clamp(0.92, 1.0) : 0.88,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: AnimatedRotation(
                            turns: deleteOpacity > 0.5 ? 0.0 : 0.025,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: _BadgeWithArrow(
                              color: sem.delete,
                              icon: Icons.delete,
                              label: l10n.delete,
                              arrowDirection: _ArrowDirection.topRight,
                              isDelete: true,
                              shouldAnimate: deleteOpacity > 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Keep/Library badge (bottom-right) - sağ alt köşede sabit
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: AnimatedOpacity(
                        opacity: keepOpacity > 0.08 ? keepOpacity.clamp(0.5, 1.0) : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: AnimatedScale(
                          scale: keepOpacity > 0.08 ? (0.92 + keepOpacity * 0.08).clamp(0.92, 1.0) : 0.88,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: AnimatedRotation(
                            turns: keepOpacity > 0.5 ? 0.0 : -0.025,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: _BadgeWithArrow(
                              color: sem.keep,
                              icon: Icons.photo_library_outlined,
                              label: l10n.keep,
                              arrowDirection: _ArrowDirection.topLeft,
                              isKeep: true,
                              shouldAnimate: keepOpacity > 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      card = IgnorePointer(child: card);
    }

    // Optimize: RepaintBoundary ile wrap et
    // AnimatedSwitcher kaldırıldı - siyah alan sorununu önlemek için
    return RepaintBoundary(
          key: ValueKey(asset.id),
          child: card,
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
    this.isDelete = false,
    this.isKeep = false,
    this.shouldAnimate = false,
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
    _animationController = AnimationController(
      vsync: this,
      duration: duration,
    );
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
    final bg = widget.color.withOpacity(1.0);
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
              ? AppColors.error.withOpacity(0.8) // Silme butonu için daha belirgin kırmızı border
              : AppColors.white.withOpacity(0.6), // Diğer butonlar için beyaz border
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
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
                    options: LottieOptions(
                      enableMergePaths: true,
                    ),
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
                        options: LottieOptions(
                          enableMergePaths: true,
                        ),
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
      ]),
    );

    switch (widget.arrowDirection) {
      case _ArrowDirection.topLeft:
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [arrow(), chip]);
      case _ArrowDirection.topRight:
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [arrow(), chip]);
      case _ArrowDirection.bottomLeft:
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [chip, arrow()]);
      case _ArrowDirection.bottomRight:
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [chip, arrow()]);
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
    _thumbFuture.then((data) {
      if (!mounted || data == null) return;
      if (_currentImageData == data) return;
      setState(() {
        _currentImageData = data;
        _previousImageData ??= data;
      });
    }).catchError((error) {
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
            AppColors.black.withOpacity(0.35),
            AppColors.black.withOpacity(0.15),
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
          child: FutureBuilder<Uint8List?>(
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
        ),
      ),
    );
  }
}

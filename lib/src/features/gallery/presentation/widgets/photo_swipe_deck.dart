import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../../../../app/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';

enum SwipeDecision { keep, delete }

class PhotoSwipeDeck extends StatefulWidget {
  const PhotoSwipeDeck({
    super.key,
    required this.assets,
    required this.onDecision,
    this.onDragUpdate,
    this.onDragEnd,
    this.isDraggingToAlbum,
  });

  final List<pm.AssetEntity> assets;
  final void Function(pm.AssetEntity asset, SwipeDecision decision) onDecision;
  final void Function(Offset globalPosition)? onDragUpdate;
  final void Function(Offset globalPosition)? onDragEnd;
  final bool Function()? isDraggingToAlbum;

  @override
  State<PhotoSwipeDeck> createState() => _PhotoSwipeDeckState();
}

class _PhotoSwipeDeckState extends State<PhotoSwipeDeck> with TickerProviderStateMixin {
  static const double _swipeThreshold = 120;
  static const double _rotationMaxDeg = 15;
  static const int _stackSize = 3;
  static const double _verticalDragThreshold = -80; // Yukarı sürükleme eşiği

  late int _topIndex;
  Offset _dragOffset = Offset.zero;
  double _dragRotation = 0;
  late AnimationController _controller;
  late AnimationController _cardTransitionController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _cardScaleAnimation;
  late Animation<double> _cardOpacityAnimation;
  SwipeDecision? _pendingDecision;
  bool _didHapticForKeep = false;
  bool _didHapticForDelete = false;

  @override
  void initState() {
    super.initState();
    _topIndex = 0;
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _cardTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragOffset = _slideAnimation.value;
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _pendingDecision != null) {
          _finalizeSwipe(_pendingDecision!);
        }
      });
    
    _cardScaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardTransitionController,
        curve: Curves.easeOutCubic,
      ),
    )..addListener(() => setState(() {}));
    
    _cardOpacityAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardTransitionController,
        curve: Curves.easeOut,
      ),
    )..addListener(() => setState(() {}));
    
    _cardTransitionController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _cardTransitionController.dispose();
    super.dispose();
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
    // Ensure card transition is at full scale/opacity when returning
    if (_cardTransitionController.value < 1.0) {
      _cardTransitionController.forward();
    }
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
    
    // Reset animations for next card
    _cardTransitionController.reset();
    
    setState(() {
      _topIndex += 1;
      _dragOffset = Offset.zero;
      _dragRotation = 0;
      _pendingDecision = null;
    });
    
    // Animate next card in
    _cardTransitionController.forward();
    
    widget.onDecision(asset, decision);
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

    return Stack(children: cards.reversed.toList());
  }

  Widget _buildCard(BuildContext context, pm.AssetEntity asset, {required int indexFromTop, required bool isTop}) {
    final baseScale = 1 - (indexFromTop * 0.04);
    final baseOffsetY = indexFromTop * 14.0;

    final rotation = isTop ? _dragRotation : 0.0;
    
    // Parallax effect: cards behind move slower and scale up as top card swipes
    final dragProgress = (_dragOffset.dx.abs() / _swipeThreshold).clamp(0.0, 1.0);
    final parallaxFactor = 1.0 - (indexFromTop * 0.3).clamp(0.0, 0.7); // Behind cards move slower
    final parallaxOffset = isTop 
        ? _dragOffset 
        : Offset(_dragOffset.dx * parallaxFactor * 0.3, baseOffsetY);
    
    // Smooth scale transitions - next card scales up as swipe progresses
    final nextCardScale = isTop 
        ? _cardScaleAnimation.value 
        : (indexFromTop == 1 
            ? baseScale * (0.94 + (dragProgress * 0.06)) // More dramatic scale up
            : baseScale * 0.96);
    
    // Opacity transitions with smooth fade
    final cardOpacity = isTop 
        ? _cardOpacityAnimation.value 
        : (1.0 - (indexFromTop * 0.12) - (dragProgress * 0.1 * (indexFromTop == 1 ? 1 : 0))).clamp(0.75, 1.0);
    
    final offset = parallaxOffset;
    final cardScale = nextCardScale;

    final decisionStrength = (_dragOffset.dx / _swipeThreshold).clamp(-1.0, 1.0);
    final keepOpacity = decisionStrength > 0 ? decisionStrength.abs().clamp(0.0, 1.0) : 0.0;
    final deleteOpacity = decisionStrength < 0 ? decisionStrength.abs().clamp(0.0, 1.0) : 0.0;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final borderColor = (decisionStrength >= 0
            ? sem.keep.withOpacity(keepOpacity * 0.8)
            : sem.delete.withOpacity(deleteOpacity * 0.8));

    Widget card = Opacity(
      opacity: cardOpacity,
      child: Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: rotation * math.pi / 180,
          child: AnimatedScale(
            scale: cardScale,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3 - (indexFromTop * 0.06)),
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
        onPanStart: (_) => _controller.stop(),
        onPanUpdate: (details) {
          final newOffset = _dragOffset + details.delta;
          final isDraggingUpward = newOffset.dy < _verticalDragThreshold;
          
          setState(() {
            _dragOffset = newOffset;
            // Eğer yukarı sürükleniyorsa, yatay rotasyonu azalt
            if (isDraggingUpward) {
              _dragRotation = (_dragOffset.dx / 20).clamp(-_rotationMaxDeg * 0.5, _rotationMaxDeg * 0.5);
            } else {
              _dragRotation = (_dragOffset.dx / 12).clamp(-_rotationMaxDeg, _rotationMaxDeg);
            }
          });
          
          // Yukarı sürüklenmiyorsa haptik feedback
          if (!isDraggingUpward) {
            if (_dragOffset.dx > _swipeThreshold && !_didHapticForKeep) {
              HapticFeedback.lightImpact();
              _didHapticForKeep = true;
            } else if (_dragOffset.dx < -_swipeThreshold && !_didHapticForDelete) {
              HapticFeedback.lightImpact();
              _didHapticForDelete = true;
            }
          }
          
          // Her zaman onDragUpdate callback'ini çağır (albüm hedefleri için)
          // Global pozisyonu doğru hesapla
          if (widget.onDragUpdate != null) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              // Local offset'i global pozisyona çevir
              final localTopLeft = box.localToGlobal(Offset.zero);
              final globalOffset = localTopLeft + _dragOffset;
              widget.onDragUpdate!(globalOffset);
            }
          }
        },
        onPanEnd: (details) {
          final dx = _dragOffset.dx;
          final dy = _dragOffset.dy;
          
          // Önce albüm hedefi kontrolü
          if (widget.onDragEnd != null) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              final wasDraggingToAlbum = widget.isDraggingToAlbum?.call() ?? false;
              final isUpwardDrag = dy < _verticalDragThreshold;
              
              debugPrint('🔄 [PhotoSwipeDeck] onPanEnd: dy=$dy, wasDraggingToAlbum=$wasDraggingToAlbum, isUpwardDrag=$isUpwardDrag');
              
              // Eğer yukarı sürüklenmişse veya albüme sürüklenmişse, onDragEnd'i çağır
              if (wasDraggingToAlbum || isUpwardDrag) {
                debugPrint('🔄 [PhotoSwipeDeck] Albüm taşıma modu - onDragEnd çağrılıyor');
                widget.onDragEnd!(box.localToGlobal(_dragOffset));
                // Albüme taşındıysa swipe yapma, kartı geri döndür
                _animateBack();
                return;
              }
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
        },
        child: Stack(
          children: [
            card,
            // Overlays
            // Modern badges: delete (top-left) and keep/gallery (bottom-right)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Stack(children: [
                  // Delete badge (top-left)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: AnimatedOpacity(
                      opacity: deleteOpacity,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: AnimatedScale(
                        scale: deleteOpacity > 0.2 ? (0.85 + deleteOpacity * 0.15).clamp(0.85, 1.0) : 0.8,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: AnimatedRotation(
                          turns: deleteOpacity > 0.5 ? 0.0 : 0.025,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: _BadgeWithArrow(
                            color: sem.delete,
                            icon: Icons.delete,
                            label: 'Sil',
                            arrowDirection: _ArrowDirection.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Keep/Library badge (bottom-right)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: AnimatedOpacity(
                      opacity: keepOpacity,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: AnimatedScale(
                        scale: keepOpacity > 0.2 ? (0.85 + keepOpacity * 0.15).clamp(0.85, 1.0) : 0.8,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: AnimatedRotation(
                          turns: keepOpacity > 0.5 ? 0.0 : -0.025,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: _BadgeWithArrow(
                            color: sem.keep,
                            icon: Icons.photo_library_outlined,
                            label: 'Tut',
                            arrowDirection: _ArrowDirection.topLeft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.32),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(color: borderColor, width: (keepOpacity > deleteOpacity ? keepOpacity : deleteOpacity) * 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ));
        
        // Use scale and slide only, no fade to avoid black background
        return SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      child: SizedBox.expand(key: ValueKey(asset.id), child: card),
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

class _BadgeWithArrow extends StatelessWidget {
  const _BadgeWithArrow({
    required this.color,
    required this.icon,
    required this.label,
    required this.arrowDirection,
  });

  final Color color;
  final IconData icon;
  final String label;
  final _ArrowDirection arrowDirection;

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.95);
    final borderRadius = BorderRadius.circular(14);

    Widget arrow() {
      return Transform.rotate(
        angle: 0.785398, // 45 deg
        child: Container(width: 10, height: 10, color: bg),
      );
    }

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: borderRadius, boxShadow: [
        BoxShadow(color: color.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 6)),
      ]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    );

    switch (arrowDirection) {
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

  @override
  void initState() {
    super.initState();
    _thumbFuture = widget.asset.thumbnailDataWithSize(const pm.ThumbnailSize(1000, 1000), quality: 85);
  }

  @override
  void didUpdateWidget(covariant _PhotoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _thumbFuture = widget.asset.thumbnailDataWithSize(const pm.ThumbnailSize(1000, 1000), quality: 85);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FutureBuilder<Uint8List?>(
        future: _thumbFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            // No loading indicator - just show transparent background for smooth transition
            return const SizedBox.expand();
          }
          return RepaintBoundary(
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            ),
          );
        },
      ),
    );
  }
}



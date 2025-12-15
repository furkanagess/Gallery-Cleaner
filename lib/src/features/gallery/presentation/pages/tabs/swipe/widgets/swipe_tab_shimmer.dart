import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:gallery_cleaner/l10n/app_localizations.dart';
import '../../../../../application/gallery_providers.dart';
import '../../../../../../../core/utils/async_value.dart';

// Shimmer widget for swipe tab
class _ShimmerWidget extends StatefulWidget {
  const _ShimmerWidget({
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final baseColor = brightness == Brightness.light
        ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.2);
    final highlightColor = brightness == Brightness.light
        ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.6)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final animationValue = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            color: baseColor,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius:
                      widget.borderRadius ?? BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + (animationValue * 2.0), 0.0),
                        end: Alignment(1.0 + (animationValue * 2.0), 0.0),
                        colors: [baseColor, highlightColor, baseColor],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Comprehensive shimmer for swipe tab covering all components
class SwipeTabShimmer extends StatefulWidget {
  const SwipeTabShimmer();

  @override
  State<SwipeTabShimmer> createState() => _SwipeTabShimmerState();
}

class _SwipeTabShimmerState extends State<SwipeTabShimmer> {
  Timer? _messageTimer;
  Timer? _progressTimer;
  int _currentMessageIndex = 0;
  int? _totalPhotos;
  int _loadedPhotos = 0;
  StreamSubscription? _galleryPagingSubscription;
  bool _showProgress = false; // Progress gösterilsin mi? (3 saniyeden fazla sürerse)

  // Samimi, açıklayıcı mesajlar - l10n'dan üretilecek
  List<String> _buildLoadingMessages(AppLocalizations l10n) => [
        l10n.loadingYourGallery,
        l10n.loadingYourGalleryDescription,
      ];

  @override
  void initState() {
    super.initState();
    // Her 3 saniyede bir mesajı değiştir
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
          setState(() {
            _currentMessageIndex = _currentMessageIndex + 1;
          });
      }
    });

    // 3 saniye sonra progress göster
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showProgress = true;
        });
      }
    });

    // Toplam fotoğraf sayısını al ve yükleme durumunu dinle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTotalPhotos();
      _listenToGalleryPaging();
      _startProgressTracking();
    });
  }

  Future<void> _loadTotalPhotos() async {
    try {
      final selectedAlbum = context.read<SelectedAlbumCubit>().state;
      if (selectedAlbum != null) {
        final total = await selectedAlbum.assetCountAsync;
        debugPrint('📊 [SwipeTabShimmer] Toplam fotoğraf sayısı: $total');
        if (mounted) {
          setState(() {
            _totalPhotos = total;
          });
        }
      } else {
        debugPrint('⚠️ [SwipeTabShimmer] Seçili albüm yok');
      }
    } catch (e) {
      debugPrint('⚠️ [SwipeTabShimmer] Toplam fotoğraf sayısı alınamadı: $e');
    }
  }

  void _listenToGalleryPaging() {
    final galleryPagingCubit = context.read<GalleryPagingCubit>();
    
    // İlk state'i kontrol et
    _updateLoadedPhotos(galleryPagingCubit.state);
    
    // Stream'i dinle
    _galleryPagingSubscription = galleryPagingCubit.stream.listen((state) {
      _updateLoadedPhotos(state);
    });
  }

  void _updateLoadedPhotos(AsyncValue<List<pm.AssetEntity>> state) {
    state.when(
      data: (assets) {
        final count = assets.length;
        debugPrint('📸 [SwipeTabShimmer] Yüklenen fotoğraf sayısı: $count');
        if (mounted) {
          setState(() {
            _loadedPhotos = count;
          });
        }
      },
      loading: () {
        // Yükleme sırasında GalleryPagingCubit'ten progress bilgisini al
        try {
          final galleryPagingCubit = context.read<GalleryPagingCubit>();
          final progress = galleryPagingCubit.currentLoadingProgress;
          final total = galleryPagingCubit.currentLoadingTotal;
          
          if (progress > 0) {
            debugPrint('⏳ [SwipeTabShimmer] Yükleme devam ediyor: $progress / ${total ?? "?"}');
            if (mounted) {
              setState(() {
                _loadedPhotos = progress;
                if (total != null) {
                  _totalPhotos = total;
                }
              });
            }
          } else {
            debugPrint('⏳ [SwipeTabShimmer] Yükleme devam ediyor...');
          }
        } catch (e) {
          debugPrint('⚠️ [SwipeTabShimmer] Progress bilgisi alınamadı: $e');
        }
      },
      error: (error, stackTrace) {
        debugPrint('❌ [SwipeTabShimmer] Hata: $error');
      },
    );
  }

  void _startProgressTracking() {
    // Her 500ms'de bir progress'i kontrol et
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final galleryPagingCubit = context.read<GalleryPagingCubit>();
        final state = galleryPagingCubit.state;
        
        // Loading state'inde progress bilgisini al
        if (state.isLoading) {
          final progress = galleryPagingCubit.currentLoadingProgress;
          final total = galleryPagingCubit.currentLoadingTotal;
          
          if (progress > 0) {
            setState(() {
              _loadedPhotos = progress;
              if (total != null && total > 0) {
                _totalPhotos = total;
              }
            });
          }
        } else {
          // Loading tamamlandıysa timer'ı iptal et
          timer.cancel();
        }
      } catch (e) {
        // Hata durumunda timer'ı iptal et
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _progressTimer?.cancel();
    _galleryPagingSubscription?.cancel();
    super.dispose();
  }

  String _getProgressText(AppLocalizations l10n) {
    debugPrint('📊 [SwipeTabShimmer] Progress: loaded=$_loadedPhotos, total=$_totalPhotos');
    
    if (_totalPhotos == null || _totalPhotos == 0) {
      if (_loadedPhotos > 0) {
        // Örneğin: "120 photos loaded"
        return l10n.photosLoaded(_loadedPhotos);
      }
      return l10n.loading;
    }

    if (_totalPhotos! > 0) {
      final percentage =
          (_loadedPhotos / _totalPhotos! * 100).clamp(0, 100).toInt();
      return l10n.photosLoadingProgress(
        _loadedPhotos,
        _totalPhotos!,
        percentage,
      );
    }
    
    return l10n.loading;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final loadingMessages = _buildLoadingMessages(l10n);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _ShimmerWidget(
                  width: double.infinity,
                  height: 48,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _ShimmerWidget(
                  width: double.infinity,
                  height: 48,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Stack(
                    children: [
                      // Shimmer placeholder for photo area (arka plan)
                      _ShimmerWidget(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      // Açıklama alanı (overlay - shimmer'ın üzerinde) - sadece 3 saniyeden fazla sürdüyse göster
                      if (_showProgress)
                        Positioned.fill(
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: theme.colorScheme.surface.withOpacity(0.85),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Lottie animasyonu
                                    SizedBox(
                                      width: 200,
                                      height: 200,
                                      child: Lottie.asset(
                                        'assets/lottie/gallery_loading.json',
                                        fit: BoxFit.contain,
                                        repeat: true,
                                        animate: true,
                                      ),
                                    ),
                                const SizedBox(height: 32),
                                // Samimi mesaj
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 500),
                                    child: Text(
                                      loadingMessages[
                                          _currentMessageIndex %
                                              loadingMessages.length],
                                      key: ValueKey(
                                        _currentMessageIndex %
                                            loadingMessages.length,
                                      ),
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Yüzdesel yükleme göstergesi
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Column(
                                    children: [
                                      // Progress bar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          minHeight: 8,
                                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            theme.colorScheme.primary,
                                          ),
                                          value: _totalPhotos != null && _totalPhotos! > 0
                                              ? (_loadedPhotos / _totalPhotos!).clamp(0.0, 1.0)
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Progress text
                                      Text(
                                        _getProgressText(l10n),
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                  ],
                                ),
                              ),
                              // Kar yağma efekti - arka planda
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: 0.6,
                                    child: ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcATop,
                                      ),
                                      child: Lottie.asset(
                                        'assets/new_year/Snowing.json',
                                        fit: BoxFit.cover,
                                        repeat: true,
                                        animate: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ShimmerWidget(
                width: 80,
                height: 32,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 16),
              _ShimmerWidget(
                width: 80,
                height: 32,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 16),
              _ShimmerWidget(
                width: 80,
                height: 32,
                borderRadius: BorderRadius.circular(12),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _ShimmerWidget(
                  width: double.infinity,
                  height: 48,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _ShimmerWidget(
                  width: double.infinity,
                  height: 48,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


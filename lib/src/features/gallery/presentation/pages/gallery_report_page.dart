import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../application/gallery_stats_provider.dart';
import '../../../onboarding/application/permissions_controller.dart';
import '../../../../core/models/gallery_stats.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_three_d_button.dart';

class GalleryReportPage extends StatefulWidget {
  const GalleryReportPage({super.key});

  @override
  State<GalleryReportPage> createState() => _GalleryReportPageState();
}

class _GalleryReportPageState extends State<GalleryReportPage>
    with TickerProviderStateMixin {
  late AnimationController _cleanupAnimationController;
  late Animation<double> _cleanupProgressAnimation;
  late AnimationController _confettiController;
  bool _showConfetti = false;
  Timer? _loadingDescriptionTimer;
  int _loadingDescriptionIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Cleanup animation controller - single play
    _cleanupAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _cleanupProgressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cleanupAnimationController,
      curve: Curves.easeInOut,
      ),
    );

    // Confetti animation controller
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _confettiController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _showConfetti = false;
        });
      }
    });

    // Loading description ticker (2s interval)
    _loadingDescriptionTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        if (!mounted) return;
        setState(() {
          _loadingDescriptionIndex++;
        });
      },
    );

    // Start cleanup animation and trigger confetti when done
    _cleanupAnimationController.forward().then((_) {
      if (mounted) {
        setState(() {
          _showConfetti = true;
        });
        _confettiController
          ..reset()
          ..forward();
      }
    });
    // Sayfa açıldığında eğer stats yoksa yükle
    // Permission request page'den geliyorsa zaten yüklenmiş olmalı
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final permission = context.read<PermissionsCubit>().state;
      final statsState = context.read<GalleryStatsCubit>().state;
      
      if (permission == GalleryPermissionStatus.authorized) {
        // Eğer stats yoksa veya tarama yapılmıyorsa yükle
        if (statsState.stats == null && !statsState.isScanning) {
          debugPrint('📊 [GalleryReportPage] Stats yok, yükleniyor...');
          context.read<GalleryStatsCubit>().refresh();
        } else if (statsState.stats != null) {
          debugPrint(
            '📊 [GalleryReportPage] Stats zaten yüklü: ${statsState.stats!.mediaCount} medya, ${statsState.stats!.albumCount} albüm, ${statsState.stats!.photoCount} fotoğraf, ${statsState.stats!.videoCount} video, ${statsState.stats!.totalSizeMB.toStringAsFixed(2)} MB',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _cleanupAnimationController.dispose();
    _confettiController.dispose();
    _loadingDescriptionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final permission = context.watch<PermissionsCubit>().state;
    final statsState = context.watch<GalleryStatsCubit>().state;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: permission != GalleryPermissionStatus.authorized
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.galleryPermissionRequired,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      AppThreeDButton(
                        label: l10n.grantPermission,
                        onPressed: () => context.go('/permission'),
                        baseColor: theme.colorScheme.primary.withOpacity(0.85),
                        textColor: AppColors.white,
                        fullWidth: false,
                        height: 56,
                      ),
                    ],
                  ),
                ),
              )
            : _buildContent(context, theme, l10n, statsState),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GalleryStatsState statsState,
  ) {
    final stats = statsState.stats;
    final isScanning = statsState.isScanning;
    final error = statsState.error;

    // Loading durumu
    if (isScanning || stats == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: Stack(
          children: [
            // Decorative elements
            Positioned(
              top: 40,
              right: 20,
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  'assets/new_year/hat.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: 20,
              child: Opacity(
                opacity: 0.25,
                child: Image.asset(
                  'assets/new_year/candy-cane.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              right: 40,
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  'assets/new_year/christmas-tree.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                    // Reindeer animation
              SizedBox(
                      width: 200,
                      height: 200,
                child: Lottie.asset(
                        'assets/new_year/Reindeer.json',
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.galleryInfoLoading,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _getLoadingDescriptions(l10n)[
                    _loadingDescriptionIndex %
                        _getLoadingDescriptions(l10n).length],
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
              ),
            ),
          ],
        ),
      );
    }

    // Error durumu
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.errorMessage(error.toString()),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AppThreeDButton(
                label: l10n.tryAgain,
                icon: Icons.refresh,
                onPressed: () {
                  context.read<GalleryStatsCubit>().refresh();
                },
                baseColor: theme.colorScheme.primary.withOpacity(0.85),
                textColor: AppColors.white,
                fullWidth: false,
                height: 56,
              ),
            ],
          ),
        ),
      );
    }

    // İstatistikleri göster
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
              // Storage cleanup potential animation
              _buildStorageCleanupAnimation(context, theme, l10n, stats),
          const SizedBox(height: 32),

          // Medya breakdown
          _buildMediaBreakdown(context, theme, l10n, stats),
          const SizedBox(height: 32),

          // Açıklama metni
          Text(
            l10n.galleryReportDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

              // Start Cleaning butonu - 3D button
              AppThreeDButton(
                label: l10n.startCleaningButton,
                icon: Icons.cleaning_services,
                onPressed: () => context.go('/swipe'),
                baseColor: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                textColor: AppColors.white,
                fullWidth: true,
                height: 56,
          ),
        ],
      ),
    );
  }

  Widget _buildStorageCleanupAnimation(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GalleryStats stats,
  ) {
    final totalMedia = stats.mediaCount;
    final totalSizeGB = stats.totalSizeMB / 1024;
    
    // %60 cleanup potential
    final cleanupPercentage = 0.6;
    final potentialFreedGB = totalSizeGB * cleanupPercentage;
    final potentialFreedMedia = (totalMedia * cleanupPercentage).round();

    return Stack(
            children: [
        AnimatedBuilder(
          animation: Listenable.merge([
            _cleanupProgressAnimation,
            _confettiController,
          ]),
          builder: (context, child) {
            final progress = _cleanupProgressAnimation.value;
            
            // Animate from current to after cleanup
            final currentGB = totalSizeGB - (totalSizeGB * cleanupPercentage * progress);
            final currentMedia = totalMedia - (potentialFreedMedia * progress);

    return Container(
          padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
      children: [
                  // Current storage info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                            '${currentGB.toStringAsFixed(1)} GB',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                                fontSize: 28,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                            '${_formatNumber(currentMedia.round())} ${l10n.media}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      // Christmas tree image
                      Image.asset(
                        'assets/new_year/christmas-tree.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
              const SizedBox(height: 24),
              // Progress bar showing cleanup
              LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth;
                  final usedWidth = barWidth * (1 - (cleanupPercentage * progress));
                  final availableWidth = barWidth * (cleanupPercentage * progress + (1 - cleanupPercentage));
                  
                  return Stack(
                    children: [
                      // Background
                      Container(
                        width: barWidth,
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Used storage (red)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 12,
                        width: usedWidth,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Available storage (green)
                      Positioned(
                        right: 0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 12,
                          width: availableWidth,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Potential savings info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.youCanClean(
                            potentialFreedGB.toStringAsFixed(1),
                            potentialFreedMedia,
                            l10n.media,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ],
      ),
        );
      },
    ),
    // Confetti animation - appears at bottom when cleanup animation completes
    if (_showConfetti)
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 200,
        child: IgnorePointer(
          child: Lottie.asset(
            'assets/new_year/Confetti.json',
            controller: _confettiController,
            fit: BoxFit.cover,
            repeat: false,
          ),
        ),
      ),
      ],
    );
  }

  Widget _buildMediaBreakdown(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GalleryStats stats,
  ) {
    final photoCount = stats.photoCount;
    final videoCount = stats.videoCount;
    final albumCount = stats.albumCount;
    final photoSizeMB = stats.photoSizeMB;
    final videoSizeMB = stats.videoSizeMB;
    
    // Tüm albümlerin toplam boyutunu hesapla
    final double totalAlbumSizeMB = stats.albumDetails.fold<double>(
      0.0,
      (sum, album) => sum + album.sizeMB,
    );

    return Column(
      children: [
        if (albumCount > 0)
          _buildMediaCard(
            context,
            theme,
            l10n,
            icon: Icons.photo_library,
            label: l10n.album,
            count: albumCount,
            sizeMB: totalAlbumSizeMB > 0 ? totalAlbumSizeMB : null,
            color: AppColors.accent,
            decorativeImage: 'assets/new_year/hat.png',
          ),
        if (albumCount > 0 && photoCount > 0) const SizedBox(height: 12),
        if (photoCount > 0)
          _buildMediaCard(
            context,
            theme,
            l10n,
            icon: Icons.photo,
            label: l10n.photos,
            count: photoCount,
            sizeMB: photoSizeMB,
            color: theme.colorScheme.primary,
            decorativeImage: 'assets/new_year/candy-cane.png',
          ),
        if ((albumCount > 0 || photoCount > 0) && videoCount > 0) const SizedBox(height: 12),
        if (videoCount > 0)
          _buildMediaCard(
            context,
            theme,
            l10n,
            icon: Icons.videocam,
            label: l10n.videos,
            count: videoCount,
            sizeMB: videoSizeMB,
            color: theme.colorScheme.secondary,
            decorativeImage: 'assets/new_year/christmas-tree.png',
          ),
      ],
    );
  }

  Widget _buildMediaCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n, {
    required IconData icon,
    required String label,
    required int count,
    double? sizeMB,
    required Color color,
    String? decorativeImage,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count $label',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (sizeMB != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatSizeMB(sizeMB),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ],
              ],
                ),
              ),
            ],
          ),
          // Decorative image on the right
          if (decorativeImage != null)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: 0.3,
                  child: Image.asset(
                    decorativeImage,
                    width: 50,
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getLoadingDescriptions(AppLocalizations l10n) {
    return [
      l10n.loadingDescriptionOptimizingSpace,
      l10n.loadingDescriptionScanningMemories,
      l10n.loadingDescriptionPreparingReport,
    ];
  }

  String _formatSizeMB(double sizeMB) {
    if (sizeMB >= 1024) {
      return '${(sizeMB / 1024).toStringAsFixed(1)} GB';
    }
    return '${sizeMB.toStringAsFixed(1)} MB';
  }

  /// Format number with commas
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}



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
  bool _hasStartedAnimation = false;
  String? _lastAnimatedStatsKey;
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
      duration: const Duration(milliseconds: 4000), // slower/smoother confetti
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

    if (!isScanning && stats != null) {
      _maybeRestartAnimations(stats);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startAnimationsIfNeeded();
        }
      });
    }

    // Loading durumu
    if (isScanning || stats == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: Stack(
          children: [
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
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.galleryStatsTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 16),
                // Medya breakdown (üstte)
                _buildMediaBreakdown(context, theme, l10n, stats),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    l10n.afterUsingThisApp,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Storage cleanup potential animation
                _buildStorageCleanupAnimation(context, theme, l10n, stats),
                const SizedBox(height: 24),
                // Media saved + optimal use (altta)
                _buildSavedAndOptimalSection(theme, l10n, stats),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: AppThreeDButton(
            label: l10n.startCleaningButton,
            icon: Icons.cleaning_services,
            onPressed: () => context.go('/swipe'),
            baseColor: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
            textColor: theme.colorScheme.background,
            fullWidth: true,
            height: 56,
          ),
        ),
      ],
    );
  }

  void _maybeRestartAnimations(GalleryStats stats) {
    final key =
        '${stats.mediaCount}-${stats.videoCount}-${stats.totalSizeMB.toStringAsFixed(2)}';
    if (_lastAnimatedStatsKey != key) {
      _lastAnimatedStatsKey = key;
      _hasStartedAnimation = false;
      _showConfetti = false;
      _cleanupAnimationController.reset();
      _confettiController.reset();
    }
  }

  void _startAnimationsIfNeeded() {
    if (_hasStartedAnimation) return;
    _hasStartedAnimation = true;

    _cleanupAnimationController.forward().then((_) {
      if (!mounted) return;
      setState(() {
        _showConfetti = true;
      });
      _confettiController
        ..reset()
        ..forward();
    });
  }

  Widget _buildStorageCleanupAnimation(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GalleryStats stats,
  ) {
    final totalSizeGB = stats.totalSizeMB / 1024;

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
            // Before -> 90% used (red), 10% available (green)
            // After  -> 30% used (red), 70% available (green)
            final double usedBefore = totalSizeGB * 0.9;
            final double usedAfter =
                (totalSizeGB * (0.9 - (0.6 * progress))).clamp(0, totalSizeGB);

                final topAlbums = _getTopAlbums(stats);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStorageUsageCard(
                      theme: theme,
                      title: l10n.beforeLabel,
                      used: usedBefore,
                      total: totalSizeGB,
                      usedColor: theme.colorScheme.error,
                      availableColor: AppColors.success,
                      animate: false,
                      topAlbums: topAlbums,
                    ),
                    const SizedBox(height: 12),
                    _buildStorageUsageCard(
                      theme: theme,
                      title: l10n.afterLabel,
                      used: usedAfter,
                      total: totalSizeGB,
                      usedColor: theme.colorScheme.error,
                      availableColor: AppColors.success,
                      animate: true,
                      topAlbums: topAlbums,
                    ),
                    const SizedBox(height: 16),
                  ],
                );
          },
        ),
        if (_showConfetti)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: IgnorePointer(
              child: Lottie.asset(
                'assets/lottie/Confeti.json',
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

  Widget _buildStorageUsageCard({
    required ThemeData theme,
    required String title,
    required double used,
    required double total,
    required Color usedColor,
    required Color availableColor,
    required bool animate,
    List<AlbumDetail>? topAlbums,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final usedFraction = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
        final minUsedWidth = 3.0;
        final currentUsedWidth =
            (barWidth * usedFraction).clamp(minUsedWidth, barWidth);
        final availableWidth =
            (barWidth - currentUsedWidth).clamp(0.0, barWidth);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${_formatSizeDynamic(used)} of ${_formatSizeDynamic(total)} Used',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  Container(
                    width: barWidth,
                    height: 14,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceTint.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  AnimatedContainer(
                    duration: animate
                        ? const Duration(milliseconds: 350)
                        : Duration.zero,
                    curve: Curves.easeInOut,
                    height: 14,
                    width: currentUsedWidth,
                    decoration: BoxDecoration(
                      color: usedColor,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: AnimatedContainer(
                      duration: animate
                          ? const Duration(milliseconds: 350)
                          : Duration.zero,
                      curve: Curves.easeInOut,
                      height: 14,
                      width: availableWidth,
                      decoration: BoxDecoration(
                        color: availableColor,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ],
              ),
              if (topAlbums != null && topAlbums.isNotEmpty) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: topAlbums.map((album) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 14)),
                            Text(
                              album.albumName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    theme.colorScheme.onSurface.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavedAndOptimalSection(
    ThemeData theme,
    AppLocalizations l10n,
    GalleryStats stats,
  ) {
    return AnimatedBuilder(
      animation: _cleanupProgressAnimation,
      builder: (context, child) {
        final totalMedia = stats.mediaCount;
        final totalSizeGB = stats.totalSizeMB / 1024;
        const cleanupPercentage = 0.6;
        final progress = _cleanupProgressAnimation.value;
        final optimalReveal = progress.clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Opacity(
              opacity: optimalReveal,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - optimalReveal)),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.success.withOpacity(0.14),
                        AppColors.success.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.35),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.optimalUseSubtitle,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _buildPotentialSavingsMessage(
                          l10n,
                          totalSizeGB * cleanupPercentage,
                          (totalMedia * cleanupPercentage).round(),
                          l10n.media,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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

  // GB değeri küçükse MB olarak göster
  String _formatSizeDynamic(double sizeInGB) {
    if (sizeInGB >= 1.0) {
      return '${sizeInGB.toStringAsFixed(1)} GB';
    }
    final sizeMB = sizeInGB * 1024;
    // 1 GB altı değerler için MB göster
    return '${sizeMB.toStringAsFixed(sizeMB >= 10 ? 0 : 1)} MB';
  }

  // GB metnini küçük boyutlarda kaldırarak çeviri çıktısını düzelt
  String _buildPotentialSavingsMessage(
    AppLocalizations l10n,
    double sizeGB,
    int mediaCount,
    String mediaLabel,
  ) {
    final text = l10n.potentialSavingsMessage(
      _formatSizeDynamic(sizeGB),
      mediaCount,
      mediaLabel,
    );

    if (sizeGB < 1.0) {
      // "12 MB GB" gibi çıktıları "12 MB" olarak düzelt
      return text.replaceAll(RegExp(r'\s?GB\b', caseSensitive: false), '');
    }
    return text;
  }

  List<AlbumDetail> _getTopAlbums(GalleryStats stats) {
    final albums = stats.albumDetails;
    if (albums.isEmpty) return const [];

    final topAlbums = [...albums]
      ..sort((a, b) => b.sizeMB.compareTo(a.sizeMB));
    return topAlbums.take(3).toList();
  }
}



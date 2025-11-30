import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../application/gallery_stats_provider.dart';
import '../../application/review_history_controller.dart';
import '../../../onboarding/application/permissions_controller.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/models/gallery_stats.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_colors.dart';
import 'package:gallery_cleaner/src/core/utils/view_refresh_cubit.dart';
import '../../application/gallery_providers.dart' show PremiumCubit;

class GalleryStatsPage extends StatefulWidget {
  const GalleryStatsPage({super.key});

  @override
  State<GalleryStatsPage> createState() => _GalleryStatsPageState();
}

class _GalleryStatsPageState extends State<GalleryStatsPage>
    with CubitStateMixin<GalleryStatsPage> {
  final SoundService _soundService = SoundService();
  bool _isScannerPlaying = false;
  bool _hasCheckedFirstAnalysis = false;
  final ScrollController _albumScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında ilk analiz kontrolü yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartFirstAnalysis();
    });
  }

  /// İlk analiz kontrolü yap ve gerekirse başlat
  Future<void> _checkAndStartFirstAnalysis() async {
    if (_hasCheckedFirstAnalysis) return;
    _hasCheckedFirstAnalysis = true;

    final permission = context.read<PermissionsCubit>().state;
    if (permission != GalleryPermissionStatus.authorized) {
      return;
    }

    final statsState = context.read<GalleryStatsCubit>().state;
    final prefsService = context.read<PreferencesService>();
    final isFirstAnalysisCompleted = await prefsService
        .isFirstAnalysisCompleted();
    final hasCachedStats = statsState.stats != null;

    // Cache yoksa ve ilk analiz tamamlanmamışsa otomatik analiz başlat
    if (!hasCachedStats &&
        !isFirstAnalysisCompleted &&
        !statsState.isScanning) {
      debugPrint('📊 [GalleryStatsPage] İlk analiz başlatılıyor...');
      // Kısa bir gecikme ile başlat (UI'nin yüklenmesi için)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          context.read<GalleryStatsCubit>().refresh();
        }
      });
    }
  }

  @override
  void dispose() {
    if (_isScannerPlaying) {
      _soundService.stopScannerSound();
    }
    _albumScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final permission = context.watch<PermissionsCubit>().state;
    final statsState = context.watch<GalleryStatsCubit>().state;

    return buildWithCubit(
      () => Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: Text(
            l10n.galleryStatsTitle,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: Platform.isIOS
              ? IconButton(
                  icon: const Icon(CupertinoIcons.chevron_left),
                  onPressed: () => context.pop(),
                )
              : null,
          automaticallyImplyLeading: !Platform.isIOS,
        ),
        body: permission != GalleryPermissionStatus.authorized
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
                      FilledButton(
                        onPressed: () => context.go('/permission'),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.85),
                          side: BorderSide(
                            color: theme.colorScheme.primary.withOpacity(0.9),
                            width: 1.5,
                          ),
                        ),
                        child: Text(l10n.grantPermission),
                      ),
                    ],
                  ),
                ),
              )
            : Builder(
                builder: (context) {
                  final stats = statsState.stats;
                  final isScanning = statsState.isScanning;
                  final error = statsState.error;

                  // Error durumu
                  if (error != null && stats == null) {
                    if (_isScannerPlaying) {
                      _soundService.stopScannerSound();
                      _isScannerPlaying = false;
                    }

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
                            FilledButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.tryAgain),
                              onPressed: () {
                                context.read<GalleryStatsCubit>().refresh();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary
                                    .withOpacity(0.85),
                                side: BorderSide(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.9,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Scanner sesini yönet
                  if (isScanning) {
                    if (!_isScannerPlaying) {
                      _soundService.playScannerSound();
                      _isScannerPlaying = true;
                    }
                  } else {
                    if (_isScannerPlaying) {
                      _soundService.stopScannerSound();
                      _isScannerPlaying = false;
                    }
                  }

                  // Stats null ise 0 değerleriyle göster
                  final displayStats =
                      stats ??
                      GalleryStats(
                        albumCount: 0,
                        mediaCount: 0,
                        totalSizeMB: 0.0,
                      );

                  // History'den sil/tut istatistiklerini al
                  final history = context.read<ReviewHistoryCubit>().state;
                  final semanticColors = Theme.of(
                    context,
                  ).extension<AppSemanticColors>();
                  final keepCount = history
                      .where((e) => e.type == ReviewActionType.keep)
                      .length;
                  final deleteCount = history
                      .where((e) => e.type == ReviewActionType.delete)
                      .length;
                  final appliedDeletes = history
                      .where(
                        (e) =>
                            e.type == ReviewActionType.delete &&
                            e.status == ReviewActionStatus.applied,
                      )
                      .toList();
                  final totalBytesFreed = appliedDeletes.fold<int>(
                    0,
                    (sum, item) => sum + item.fileSizeBytes,
                  );

                  // Tarama yapılırken full-screen loading göster
                  if (isScanning) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: Lottie.asset(
                                'assets/lottie/gallery_loading.json',
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
                              l10n.loadingMayTakeFewSeconds,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            // Progress bilgisi
                            if (displayStats.albumCount > 0) ...[
                              const SizedBox(height: 16),
                              Builder(
                                builder: (progressContext) {
                                  // Premium durumunu kontrol et
                                  final isPremiumAsync = progressContext
                                      .watch<PremiumCubit>()
                                      .state;
                                  final isPremium = isPremiumAsync.maybeWhen(
                                    data: (premium) => premium,
                                    orElse: () => false,
                                  );

                                  // Bottom navigation bar'daki container rengiyle aynı
                                  final containerColor = theme
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withOpacity(0.8);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: containerColor.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: containerColor.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      l10n.progressFormat(
                                        '${displayStats.albumDetails.length}/${displayStats.albumCount}',
                                        displayStats.mediaCount,
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: containerColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 24),
                            // Durdur butonu
                            FilledButton.icon(
                              onPressed: () {
                                context.read<GalleryStatsCubit>().cancel();
                              },
                              icon: const Icon(Icons.stop),
                              label: Text(l10n.stop),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                backgroundColor: AppColors.error.withOpacity(
                                  0.85,
                                ),
                                foregroundColor: theme.colorScheme.onError,
                                side: BorderSide(
                                  color: AppColors.error.withOpacity(0.9),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Keep/Delete Stats Section (en üstte)
                              _buildKeepDeleteStatsSection(
                                context,
                                theme,
                                l10n,
                                keepCount,
                                deleteCount,
                                totalBytesFreed,
                                semanticColors,
                              ),
                              const SizedBox(height: 24),
                              // General Statistics Section
                              _buildGeneralStatisticsSection(
                                context,
                                theme,
                                l10n,
                                displayStats,
                              ),
                              const SizedBox(height: 24),
                              // Albums Section
                              _buildAlbumsSection(
                                context,
                                theme,
                                l10n,
                                displayStats,
                              ),
                              // Bottom padding for fixed buttons
                              if (!isScanning) const SizedBox(height: 180),
                            ],
                          ),
                        ),
                      ),
                      // Otomatik analiz toggle ve Tekrardan Analiz Et butonu (ekranın en altında - sabit)
                      if (!isScanning)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.background,
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Otomatik analiz toggle
                                FutureBuilder<bool>(
                                  future: context
                                      .read<PreferencesService>()
                                      .isAutoAnalyzeOnLaunchEnabled(),
                                  builder: (context, snapshot) {
                                    final isEnabled = snapshot.data ?? true;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(isEnabled ? 0.5 : 0.7),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isEnabled
                                              ? theme.colorScheme.outline
                                                    .withOpacity(0.1)
                                              : theme.colorScheme.outline
                                                    .withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  l10n.autoAnalyzeOnLaunch,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  l10n.autoAnalyzeOnLaunchDescription,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.65),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          CupertinoSwitch(
                                            value: isEnabled,
                                            onChanged: (value) async {
                                              await context
                                                  .read<PreferencesService>()
                                                  .setAutoAnalyzeOnLaunch(
                                                    value,
                                                  );
                                              if (mounted) {
                                                cubitSetState(() {});
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                // Re-Analyze butonu
                                Builder(
                                  builder: (buttonContext) {
                                    // Premium durumunu kontrol et
                                    final isPremiumAsync = buttonContext
                                        .watch<PremiumCubit>()
                                        .state;
                                    final isPremium = isPremiumAsync.maybeWhen(
                                      data: (premium) => premium,
                                      orElse: () => false,
                                    );

                                    // Bottom navigation bar'daki container rengiyle aynı
                                    final containerColor = theme
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withOpacity(0.8);

                                    return FilledButton.icon(
                                      onPressed: () {
                                        context
                                            .read<GalleryStatsCubit>()
                                            .refresh();
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: Text(l10n.reAnalyze),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                        backgroundColor: containerColor,
                                        foregroundColor: AppColors.white,
                                        side: BorderSide(
                                          color: containerColor,
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  /// Byte'ı okunabilir formata çevir
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Keep/Delete Stats Section (en üstte) - Görsel olarak kuvvetli ve kullanıcı dostu
  Widget _buildKeepDeleteStatsSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    int keepCount,
    int deleteCount,
    int totalBytesFreed,
    AppSemanticColors? semanticColors,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCardEnhanced(
            context: context,
            theme: theme,
            label: l10n.keep,
            value: '$keepCount',
            iconColor: semanticColors?.keep ?? AppColors.success,
            gradientColors: [
              (semanticColors?.keep ?? AppColors.success).withOpacity(0.25),
              (semanticColors?.keep ?? AppColors.success).withOpacity(0.15),
            ],
            borderColor: (semanticColors?.keep ?? AppColors.success)
                .withOpacity(0.4),
            shadowColor: (semanticColors?.keep ?? AppColors.success)
                .withOpacity(0.15),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCardEnhanced(
            context: context,
            theme: theme,
            label: l10n.delete,
            value: '$deleteCount',
            iconColor: semanticColors?.delete ?? AppColors.error,
            gradientColors: [
              (semanticColors?.delete ?? AppColors.error).withOpacity(0.25),
              (semanticColors?.delete ?? AppColors.error).withOpacity(0.15),
            ],
            borderColor: (semanticColors?.delete ?? AppColors.error)
                .withOpacity(0.4),
            shadowColor: (semanticColors?.delete ?? AppColors.error)
                .withOpacity(0.15),
          ),
        ),
        const SizedBox(width: 12),
        Builder(
          builder: (builderContext) {
            // Premium durumunu kontrol et
            final isPremiumAsync = builderContext.watch<PremiumCubit>().state;
            final isPremium = isPremiumAsync.maybeWhen(
              data: (premium) => premium,
              orElse: () => false,
            );

            // Bottom navigation bar'daki container rengiyle aynı
            final containerColor = theme.colorScheme.onPrimaryContainer
                .withOpacity(0.8);

            return Expanded(
              child: _buildStatCardEnhanced(
                context: context,
                theme: theme,
                label: l10n.spaceSaved,
                value: _formatBytes(totalBytesFreed),
                iconColor: containerColor,
                gradientColors: [
                  containerColor.withOpacity(0.25),
                  containerColor.withOpacity(0.15),
                ],
                borderColor: containerColor.withOpacity(0.4),
                shadowColor: containerColor.withOpacity(0.15),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Enhanced Stat Card Widget - Görsel olarak kuvvetli tasarım
  Widget _buildStatCardEnhanced({
    required BuildContext context,
    required ThemeData theme,
    required String label,
    required String value,
    required Color iconColor,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color shadowColor,
  }) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Dekoratif arka plan daire
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Label
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Değer
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -1.5,
                      height: 1,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// General Statistics Section - 2 cards (Total Photos and Total Size) - Kullanıcı dostu tasarım
  Widget _buildGeneralStatisticsSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GalleryStats stats,
  ) {
    // Use mediaCount for photos (approximation - we don't have separate photo/video counts)
    final totalPhotos = stats.mediaCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.generalStatistics,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (builderContext) {
            // Premium durumunu kontrol et
            final isPremiumAsync = builderContext.watch<PremiumCubit>().state;
            final isPremium = isPremiumAsync.maybeWhen(
              data: (premium) => premium,
              orElse: () => false,
            );

            // Bottom navigation bar'daki container rengiyle aynı
            final containerColor = theme.colorScheme.onPrimaryContainer
                .withOpacity(0.8);

            return Row(
              children: [
                Expanded(
                  child: _buildStatCardEnhanced(
                    context: context,
                    theme: theme,
                    label: l10n.totalPhotos,
                    value: _formatNumber(totalPhotos),
                    iconColor: containerColor,
                    gradientColors: [
                      containerColor.withOpacity(0.25),
                      containerColor.withOpacity(0.15),
                    ],
                    borderColor: containerColor.withOpacity(0.4),
                    shadowColor: containerColor.withOpacity(0.15),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCardEnhanced(
                    context: context,
                    theme: theme,
                    label: l10n.totalSize,
                    value: _formatSizeMB(stats.totalSizeMB),
                    iconColor: containerColor,
                    gradientColors: [
                      containerColor.withOpacity(0.25),
                      containerColor.withOpacity(0.15),
                    ],
                    borderColor: containerColor.withOpacity(0.4),
                    shadowColor: containerColor.withOpacity(0.15),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Albums Section - Horizontal scrollable
  Widget _buildAlbumsSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    GalleryStats stats,
  ) {
    if (stats.albumDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.album,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            controller: _albumScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: stats.albumDetails.length,
            itemBuilder: (context, index) {
              final album = stats.albumDetails[index];
              return _buildAlbumCard(context, theme, l10n, album);
            },
          ),
        ),
      ],
    );
  }

  /// Album Card Widget
  Widget _buildAlbumCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    AlbumDetail album,
  ) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Album thumbnail - son fotoğraf
          Expanded(
            child: FutureBuilder<AssetEntity?>(
              future: _getAlbumThumbnail(album.albumId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: _buildThumbnailWidget(snapshot.data!, theme),
                  );
                }
                // Placeholder while loading or if no thumbnail
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.photo_library,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.albumName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${album.mediaCount} ${l10n.items}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get album thumbnail (last photo)
  Future<AssetEntity?> _getAlbumThumbnail(String albumId) async {
    try {
      // Get all albums (both image and video)
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.all,
        hasAll: true,
      );

      if (albums.isEmpty) return null;

      AssetPathEntity? targetAlbum;

      // Try to find album by ID first
      try {
        targetAlbum = albums.firstWhere((a) => a.id == albumId);
      } catch (e) {
        // If not found by ID, try to find by name (albumId might be name in some cases)
        try {
          targetAlbum = albums.firstWhere(
            (a) => a.name == albumId || a.id == albumId,
          );
        } catch (e2) {
          // If still not found, return null
          debugPrint('Album not found: $albumId');
          return null;
        }
      }

      final assetCount = await targetAlbum.assetCountAsync;
      if (assetCount == 0) return null;

      // Get the last asset (most recent) - prefer image if available
      final lastAssets = await targetAlbum.getAssetListRange(
        start: assetCount > 10 ? assetCount - 10 : 0,
        end: assetCount,
      );

      if (lastAssets.isEmpty) return null;

      // Find the first image asset from the end
      for (int i = lastAssets.length - 1; i >= 0; i--) {
        final asset = lastAssets[i];
        if (asset.type == AssetType.image) {
          return asset;
        }
      }

      // If no image found, return the last asset (could be video)
      return lastAssets.last;
    } catch (e) {
      debugPrint('Error getting album thumbnail for $albumId: $e');
      return null;
    }
  }

  /// Build thumbnail widget
  Widget _buildThumbnailWidget(AssetEntity asset, ThemeData theme) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(320, 320)),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading thumbnail: $error');
              return Container(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                child: Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
              );
            },
          );
        }
        if (snapshot.hasError) {
          debugPrint('Thumbnail error: ${snapshot.error}');
          return Container(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            child: Center(
              child: Icon(
                Icons.broken_image,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
          );
        }
        return Container(
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        );
      },
    );
  }

  /// Format number with commas
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// Format size in MB to GB if needed
  String _formatSizeMB(double sizeMB) {
    if (sizeMB >= 1024) {
      return '${(sizeMB / 1024).toStringAsFixed(1)} GB';
    }
    return '${sizeMB.toStringAsFixed(1)} MB';
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../application/gallery_stats_provider.dart';
import '../../application/review_history_controller.dart';
import '../../../onboarding/application/permissions_controller.dart';
import '../../../../core/models/gallery_stats.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_colors.dart';

class GalleryStatsPage extends ConsumerStatefulWidget {
  const GalleryStatsPage({super.key});

  @override
  ConsumerState<GalleryStatsPage> createState() => _GalleryStatsPageState();
}

class _GalleryStatsPageState extends ConsumerState<GalleryStatsPage> {
  final SoundService _soundService = SoundService();
  bool _isScannerPlaying = false;
  bool _hasCheckedFirstAnalysis = false;
  final ScrollController _albumScrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında ilk analiz kontrolü yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartFirstAnalysis();
      // GridView render edildikten sonra okları kontrol et
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _updateArrowVisibility();
        }
      });
    });

    // Scroll controller listener
    _albumScrollController.addListener(_updateArrowVisibility);
  }

  void _updateArrowVisibility() {
    if (!mounted) return;

    if (!_albumScrollController.hasClients) {
      if (mounted) {
        setState(() {
          _showLeftArrow = false;
          _showRightArrow = false;
        });
      }
      return;
    }

    final position = _albumScrollController.position;
    if (mounted) {
      setState(() {
        _showLeftArrow = position.pixels > 0;
        _showRightArrow = position.pixels < position.maxScrollExtent - 1;
      });
    }
  }

  void _scrollLeft() {
    if (_albumScrollController.hasClients) {
      _albumScrollController.animateTo(
        _albumScrollController.offset - 220,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollRight() {
    if (_albumScrollController.hasClients) {
      _albumScrollController.animateTo(
        _albumScrollController.offset + 220,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// İlk analiz kontrolü yap ve gerekirse başlat
  Future<void> _checkAndStartFirstAnalysis() async {
    if (_hasCheckedFirstAnalysis) return;
    _hasCheckedFirstAnalysis = true;

    final permission = ref.read(permissionsControllerProvider);
    if (permission != GalleryPermissionStatus.authorized) {
      return;
    }

    final statsState = ref.read(galleryStatsProvider);
    final prefsService = ref.read(preferencesServiceProvider);
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
          ref.read(galleryStatsProvider.notifier).refresh();
        }
      });
    }
  }

  @override
  void dispose() {
    if (_isScannerPlaying) {
      _soundService.stopScannerSound();
    }
    _albumScrollController.removeListener(_updateArrowVisibility);
    _albumScrollController.dispose();
    super.dispose();
  }

  /// Yüzdelik fark hesapla
  double? _calculatePercentageChange(int? current, int? previous) {
    if (current == null || previous == null || previous == 0) {
      return null;
    }
    return ((current - previous) / previous) * 100;
  }

  /// Tarihi formatla (locale'e göre)
  String _formatDate(BuildContext context, DateTime date) {
    try {
      final locale = Localizations.localeOf(context);
      final dateFormat = DateFormat('d MMMM yyyy, HH:mm', locale.toString());
      return dateFormat.format(date);
    } catch (e) {
      // Fallback: Sistem locale'i
      final dateFormat = DateFormat('d MMMM yyyy, HH:mm');
      return dateFormat.format(date);
    }
  }

  /// Değişiklik chip'i oluştur
  Widget _buildChangeChip(
    BuildContext context,
    String label,
    double change,
    ThemeData theme, {
    int? absoluteDiff,
    double? absoluteDiffDouble,
  }) {
    final isPositive = change > 0;
    final isNegative = change < 0;
    final color = isPositive
        ? AppColors.success
        : isNegative
        ? AppColors.error
        : theme.colorScheme.onSurface.withOpacity(0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive
                ? Icons.trending_up
                : isNegative
                ? Icons.trending_down
                : Icons.remove,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            absoluteDiff != null
                ? '$label: ${absoluteDiff > 0
                      ? '+'
                      : absoluteDiff < 0
                      ? '-'
                      : ''}${absoluteDiff.abs()} (${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}%)'
                : absoluteDiffDouble != null
                ? '$label: ${absoluteDiffDouble > 0
                      ? '+'
                      : absoluteDiffDouble < 0
                      ? '-'
                      : ''}${absoluteDiffDouble.abs().toStringAsFixed(1)} MB (${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}%)'
                : '$label: ${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final permission = ref.watch(permissionsControllerProvider);
    final statsState = ref.watch(galleryStatsProvider);

    return Scaffold(
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
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.85,
                        ),
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
                final previousStats = statsState.previousStats;
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
                              ref.read(galleryStatsProvider.notifier).refresh();
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

                // Stats değiştiğinde scroll oklarını güncelle
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && displayStats.albumDetails.isNotEmpty) {
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (mounted) {
                        _updateArrowVisibility();
                      }
                    });
                  }
                });

                // Yüzdelik farkları hesapla
                final albumChange = _calculatePercentageChange(
                  displayStats.albumCount,
                  previousStats?.albumCount,
                );
                final mediaChange = _calculatePercentageChange(
                  displayStats.mediaCount,
                  previousStats?.mediaCount,
                );
                final sizeChange =
                    previousStats != null && previousStats.totalSizeMB > 0
                    ? ((displayStats.totalSizeMB - previousStats.totalSizeMB) /
                              previousStats.totalSizeMB) *
                          100
                    : null;

                // Mutlak değer farkları hesapla
                final albumDiff = previousStats != null
                    ? displayStats.albumCount - previousStats.albumCount
                    : null;
                final mediaDiff = previousStats != null
                    ? displayStats.mediaCount - previousStats.mediaCount
                    : null;
                final sizeDiff = previousStats != null
                    ? displayStats.totalSizeMB - previousStats.totalSizeMB
                    : null;

                // History'den sil/tut istatistiklerini al
                final history = ref.watch(reviewHistoryControllerProvider);
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.2,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                l10n.progressFormat(
                                  '${displayStats.albumDetails.length}/${displayStats.albumCount}',
                                  displayStats.mediaCount,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          // Durdur butonu
                          FilledButton.icon(
                            onPressed: () {
                              ref.read(galleryStatsProvider.notifier).cancel();
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

                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: !isScanning
                            ? 180
                            : 16, // Toggle ve buton için alt padding
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Sil/Tut istatistikleri ve Kazanılan Alan (Badge stili)
                          Row(
                            children: [
                              // Tut sayısı badge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        (semanticColors?.keep ??
                                                AppColors.success)
                                            .withOpacity(0.15),
                                        (semanticColors?.keep ??
                                                AppColors.success)
                                            .withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          (semanticColors?.keep ??
                                                  AppColors.success)
                                              .withOpacity(0.3),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (semanticColors?.keep ??
                                                    AppColors.success)
                                                .withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 13,
                                            color:
                                                semanticColors?.keep ??
                                                AppColors.success,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              l10n.keep,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 10,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.8),
                                                    letterSpacing: 0.3,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$keepCount',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 20,
                                              color:
                                                  theme.colorScheme.onSurface,
                                              letterSpacing: -1.2,
                                              height: 1,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Sil sayısı badge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        (semanticColors?.delete ??
                                                AppColors.error)
                                            .withOpacity(0.15),
                                        (semanticColors?.delete ??
                                                AppColors.error)
                                            .withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          (semanticColors?.delete ??
                                                  AppColors.error)
                                              .withOpacity(0.3),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (semanticColors?.delete ??
                                                    AppColors.error)
                                                .withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            size: 13,
                                            color:
                                                semanticColors?.delete ??
                                                AppColors.error,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              l10n.delete,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 10,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.8),
                                                    letterSpacing: 0.3,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$deleteCount',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 20,
                                              color:
                                                  theme.colorScheme.onSurface,
                                              letterSpacing: -1.2,
                                              height: 1,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Kazanılan Alan badge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.blurTab.withOpacity(0.15),
                                        AppColors.blurTab.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.blurTab.withOpacity(0.3),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.blurTab.withOpacity(
                                          0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.data_saver_on_outlined,
                                            size: 13,
                                            color: AppColors.blurTab,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              l10n.spaceSaved,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 10,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.8),
                                                    letterSpacing: 0.3,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatBytes(totalBytesFreed),
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color:
                                                  theme.colorScheme.onSurface,
                                              letterSpacing: -1.0,
                                              height: 1,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Analiz tarihi ve önceki analiz bilgisi
                          if (displayStats.cachedAt != null ||
                              previousStats?.cachedAt != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withOpacity(
                                    0.1,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Mevcut analiz tarihi
                                  if (displayStats.cachedAt != null)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${l10n.lastAnalysis} ${_formatDate(context, displayStats.cachedAt!)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                  // Önceki analiz tarihi ve yüzdelik farklar özeti
                                  if (previousStats != null &&
                                      previousStats.cachedAt != null) ...[
                                    if (displayStats.cachedAt != null)
                                      const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 14,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${l10n.previousAnalysis} ${_formatDate(context, previousStats.cachedAt!)}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.7),
                                                  fontSize: 11,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Yüzdelik farklar özeti
                                    if (albumChange != null ||
                                        mediaChange != null ||
                                        sizeChange != null) ...[
                                      const SizedBox(height: 8),
                                      Builder(
                                        builder: (context) {
                                          final album = albumChange;
                                          final media = mediaChange;
                                          final size = sizeChange;
                                          return Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              if (album != null)
                                                _buildChangeChip(
                                                  context,
                                                  l10n.album,
                                                  album,
                                                  theme,
                                                  absoluteDiff: albumDiff,
                                                ),
                                              if (media != null)
                                                _buildChangeChip(
                                                  context,
                                                  l10n.mediaLabel,
                                                  media,
                                                  theme,
                                                  absoluteDiff: mediaDiff,
                                                ),
                                              if (size != null)
                                                _buildChangeChip(
                                                  context,
                                                  l10n.sizeLabel,
                                                  size,
                                                  theme,
                                                  absoluteDiffDouble: sizeDiff,
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          if (displayStats.cachedAt != null ||
                              previousStats?.cachedAt != null)
                            const SizedBox(height: 16),
                          // İstatistik badge'leri - yan yana
                          Row(
                            children: [
                              // Albüm sayısı badge
                              Expanded(
                                child: Container(
                                  height: 75,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.primaryContainer,
                                        theme.colorScheme.primaryContainer
                                            .withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.2),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.folder,
                                            size: 13,
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer
                                                .withOpacity(0.9),
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                l10n.album,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 10,
                                                      color: theme
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                          .withOpacity(0.9),
                                                      letterSpacing: 0.3,
                                                    ),
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${displayStats.albumCount}',
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 20,
                                                color: theme
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                                letterSpacing: -1.2,
                                                height: 1,
                                              ),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Fotoğraf/Video sayısı badge
                              Expanded(
                                child: Container(
                                  height: 75,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.secondaryContainer,
                                        theme.colorScheme.secondaryContainer
                                            .withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.colorScheme.secondary
                                          .withOpacity(0.2),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.secondary
                                            .withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.photo,
                                            size: 13,
                                            color: theme
                                                .colorScheme
                                                .onSecondaryContainer
                                                .withOpacity(0.9),
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                l10n.photoVideo,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 10,
                                                      color: theme
                                                          .colorScheme
                                                          .onSecondaryContainer
                                                          .withOpacity(0.9),
                                                      letterSpacing: 0.3,
                                                    ),
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${displayStats.mediaCount}',
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 20,
                                                color: theme
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                                letterSpacing: -1.2,
                                                height: 1,
                                              ),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Toplam boyut badge
                              Expanded(
                                child: Container(
                                  height: 75,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.tertiaryContainer,
                                        theme.colorScheme.tertiaryContainer
                                            .withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.colorScheme.tertiary
                                          .withOpacity(0.2),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.tertiary
                                            .withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.storage,
                                            size: 13,
                                            color: theme
                                                .colorScheme
                                                .onTertiaryContainer
                                                .withOpacity(0.9),
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                l10n.totalSize,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 10,
                                                      color: theme
                                                          .colorScheme
                                                          .onTertiaryContainer
                                                          .withOpacity(0.9),
                                                      letterSpacing: 0.3,
                                                    ),
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '${displayStats.totalSizeMB.toStringAsFixed(1)}',
                                              style: theme
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 20,
                                                    color: theme
                                                        .colorScheme
                                                        .onTertiaryContainer,
                                                    letterSpacing: -1.2,
                                                    height: 1,
                                                  ),
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'MB',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontSize: 8,
                                                  color: theme
                                                      .colorScheme
                                                      .onTertiaryContainer
                                                      .withOpacity(0.7),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Albüm detayları - varsa göster
                          if (displayStats.albumDetails.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withOpacity(
                                    0.1,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.folder_open,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.albumDetails,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Yatay scroll edilebilir grid yapısı + scroll okları
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Stack(
                                        children: [
                                          SingleChildScrollView(
                                            controller: _albumScrollController,
                                            scrollDirection: Axis.horizontal,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            padding: const EdgeInsets.only(
                                              right: 16,
                                            ),
                                            child: IntrinsicHeight(
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: List.generate(
                                                  (displayStats
                                                              .albumDetails
                                                              .length /
                                                          2)
                                                      .ceil(),
                                                  (rowIndex) {
                                                    return Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: [
                                                        for (
                                                          int colIndex = 0;
                                                          colIndex < 2;
                                                          colIndex++
                                                        )
                                                          Builder(
                                                            builder: (context) {
                                                              final itemIndex =
                                                                  rowIndex * 2 +
                                                                  colIndex;
                                                              if (itemIndex >=
                                                                  displayStats
                                                                      .albumDetails
                                                                      .length) {
                                                                return const SizedBox.shrink();
                                                              }
                                                              final detail =
                                                                  displayStats
                                                                      .albumDetails[itemIndex];
                                                              final double
                                                              sizeMb =
                                                                  detail.sizeMB;
                                                              // Toplam galeri boyutuna göre yüzde hesapla
                                                              final double
                                                              totalSizeMb =
                                                                  displayStats
                                                                          .totalSizeMB >
                                                                      0
                                                                  ? displayStats
                                                                        .totalSizeMB
                                                                  : 1;
                                                              final double
                                                              percentage =
                                                                  (sizeMb /
                                                                          totalSizeMb *
                                                                          100)
                                                                      .clamp(
                                                                        0.0,
                                                                        100.0,
                                                                      );
                                                              return Container(
                                                                width: 260,
                                                                margin: EdgeInsets.only(
                                                                  right: 12,
                                                                  bottom:
                                                                      rowIndex <
                                                                          (displayStats.albumDetails.length /
                                                                                      2)
                                                                                  .ceil() -
                                                                              1
                                                                      ? 12
                                                                      : 0,
                                                                ),
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      12,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: theme
                                                                      .colorScheme
                                                                      .surfaceContainerHighest
                                                                      .withOpacity(
                                                                        0.3,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        16,
                                                                      ),
                                                                  border: Border.all(
                                                                    color: theme
                                                                        .colorScheme
                                                                        .outline
                                                                        .withOpacity(
                                                                          0.1,
                                                                        ),
                                                                    width: 1,
                                                                  ),
                                                                ),
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    // Album Name - Header (compact)
                                                                    Row(
                                                                      children: [
                                                                        Container(
                                                                          width:
                                                                              32,
                                                                          height:
                                                                              32,
                                                                          decoration: BoxDecoration(
                                                                            color: theme.colorScheme.primaryContainer.withOpacity(
                                                                              0.3,
                                                                            ),
                                                                            borderRadius: BorderRadius.circular(
                                                                              10,
                                                                            ),
                                                                            border: Border.all(
                                                                              color: theme.colorScheme.primary.withOpacity(
                                                                                0.15,
                                                                              ),
                                                                              width: 1,
                                                                            ),
                                                                          ),
                                                                          child: Icon(
                                                                            Icons.folder_rounded,
                                                                            size:
                                                                                16,
                                                                            color:
                                                                                theme.colorScheme.primary,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              8,
                                                                        ),
                                                                        Expanded(
                                                                          child: Text(
                                                                            detail.albumName,
                                                                            style: theme.textTheme.titleSmall?.copyWith(
                                                                              fontWeight: FontWeight.w700,
                                                                              fontSize: 13,
                                                                              color: theme.colorScheme.onSurface,
                                                                              letterSpacing: -0.2,
                                                                              height: 1.2,
                                                                            ),
                                                                            maxLines:
                                                                                1,
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 4,
                                                                    ),
                                                                    // Percentage badge
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            3,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: theme
                                                                            .colorScheme
                                                                            .primary
                                                                            .withOpacity(
                                                                              0.1,
                                                                            ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                      ),
                                                                      child: Text(
                                                                        '${percentage.toStringAsFixed(1)}%',
                                                                        style: theme.textTheme.labelSmall?.copyWith(
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          fontSize:
                                                                              10,
                                                                          color: theme
                                                                              .colorScheme
                                                                              .primary,
                                                                          letterSpacing:
                                                                              0.2,
                                                                          height:
                                                                              1.0,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          12,
                                                                    ),
                                                                    // Stats Grid (compact layout)
                                                                    Row(
                                                                      children: [
                                                                        // Media Count
                                                                        Expanded(
                                                                          child: Container(
                                                                            padding: const EdgeInsets.all(
                                                                              8,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              color: theme.colorScheme.primaryContainer.withOpacity(
                                                                                0.2,
                                                                              ),
                                                                              borderRadius: BorderRadius.circular(
                                                                                10,
                                                                              ),
                                                                              border: Border.all(
                                                                                color: theme.colorScheme.primary.withOpacity(
                                                                                  0.1,
                                                                                ),
                                                                                width: 1,
                                                                              ),
                                                                            ),
                                                                            child: Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Row(
                                                                                  children: [
                                                                                    Icon(
                                                                                      Icons.photo_library_rounded,
                                                                                      size: 12,
                                                                                      color: theme.colorScheme.primary,
                                                                                    ),
                                                                                    const SizedBox(
                                                                                      width: 4,
                                                                                    ),
                                                                                    Expanded(
                                                                                      child: Text(
                                                                                        l10n.mediaUnit,
                                                                                        style: theme.textTheme.labelSmall?.copyWith(
                                                                                          fontWeight: FontWeight.w500,
                                                                                          fontSize: 8,
                                                                                          color: theme.colorScheme.onSurface.withOpacity(
                                                                                            0.7,
                                                                                          ),
                                                                                          height: 1.0,
                                                                                        ),
                                                                                        overflow: TextOverflow.ellipsis,
                                                                                        maxLines: 1,
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                                const SizedBox(
                                                                                  height: 4,
                                                                                ),
                                                                                Text(
                                                                                  '${detail.mediaCount}',
                                                                                  style: theme.textTheme.titleSmall?.copyWith(
                                                                                    fontWeight: FontWeight.w800,
                                                                                    fontSize: 14,
                                                                                    color: theme.colorScheme.onSurface,
                                                                                    letterSpacing: -0.4,
                                                                                    height: 1.0,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              8,
                                                                        ),
                                                                        // Size
                                                                        Expanded(
                                                                          child: Container(
                                                                            padding: const EdgeInsets.all(
                                                                              8,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              color: theme.colorScheme.secondaryContainer.withOpacity(
                                                                                0.2,
                                                                              ),
                                                                              borderRadius: BorderRadius.circular(
                                                                                10,
                                                                              ),
                                                                              border: Border.all(
                                                                                color: theme.colorScheme.secondary.withOpacity(
                                                                                  0.1,
                                                                                ),
                                                                                width: 1,
                                                                              ),
                                                                            ),
                                                                            child: Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Row(
                                                                                  children: [
                                                                                    Icon(
                                                                                      Icons.storage_rounded,
                                                                                      size: 12,
                                                                                      color: theme.colorScheme.secondary,
                                                                                    ),
                                                                                    const SizedBox(
                                                                                      width: 4,
                                                                                    ),
                                                                                    Expanded(
                                                                                      child: Text(
                                                                                        'MB',
                                                                                        style: theme.textTheme.labelSmall?.copyWith(
                                                                                          fontWeight: FontWeight.w500,
                                                                                          fontSize: 8,
                                                                                          color: theme.colorScheme.onSurface.withOpacity(
                                                                                            0.7,
                                                                                          ),
                                                                                          height: 1.0,
                                                                                        ),
                                                                                        overflow: TextOverflow.ellipsis,
                                                                                        maxLines: 1,
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                                const SizedBox(
                                                                                  height: 4,
                                                                                ),
                                                                                Text(
                                                                                  sizeMb.toStringAsFixed(
                                                                                    1,
                                                                                  ),
                                                                                  style: theme.textTheme.titleSmall?.copyWith(
                                                                                    fontWeight: FontWeight.w800,
                                                                                    fontSize: 14,
                                                                                    color: theme.colorScheme.onSurface,
                                                                                    letterSpacing: -0.4,
                                                                                    height: 1.0,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Sol ok (scroll left)
                                          if (_showLeftArrow)
                                            Positioned(
                                              left: 8,
                                              top: 0,
                                              bottom: 0,
                                              child: Center(
                                                child: Material(
                                                  color: AppColors.transparent,
                                                  child: InkWell(
                                                    onTap: _scrollLeft,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    child: Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          begin: Alignment
                                                              .centerLeft,
                                                          end: Alignment
                                                              .centerRight,
                                                          colors: [
                                                            theme
                                                                .colorScheme
                                                                .surfaceContainerHighest
                                                                .withOpacity(
                                                                  0.9,
                                                                ),
                                                            theme
                                                                .colorScheme
                                                                .surfaceContainerHighest
                                                                .withOpacity(
                                                                  0.7,
                                                                ),
                                                          ],
                                                        ),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: theme
                                                              .colorScheme
                                                              .outline
                                                              .withOpacity(0.2),
                                                          width: 1,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: AppColors
                                                                .black
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                            blurRadius: 8,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .chevron_left_rounded,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                        size: 24,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          // Sağ ok (scroll right)
                                          if (_showRightArrow)
                                            Positioned(
                                              right: 8,
                                              top: 0,
                                              bottom: 0,
                                              child: Center(
                                                child: Material(
                                                  color: AppColors.transparent,
                                                  child: InkWell(
                                                    onTap: _scrollRight,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    child: Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          begin: Alignment
                                                              .centerLeft,
                                                          end: Alignment
                                                              .centerRight,
                                                          colors: [
                                                            theme
                                                                .colorScheme
                                                                .surfaceContainerHighest
                                                                .withOpacity(
                                                                  0.9,
                                                                ),
                                                            theme
                                                                .colorScheme
                                                                .surfaceContainerHighest
                                                                .withOpacity(
                                                                  0.7,
                                                                ),
                                                          ],
                                                        ),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: theme
                                                              .colorScheme
                                                              .outline
                                                              .withOpacity(0.2),
                                                          width: 1,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: AppColors
                                                                .black
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                            blurRadius: 8,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .chevron_right_rounded,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                        size: 24,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Otomatik analiz toggle ve Tekrardan Analiz Et butonu (ekranın en altında - sabit)
                    if (!isScanning)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.background,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Otomatik analiz toggle
                                Consumer(
                                  builder: (context, ref, _) {
                                    final prefsService = ref.read(
                                      preferencesServiceProvider,
                                    );
                                    return FutureBuilder<bool>(
                                      future: prefsService
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
                                                .withOpacity(
                                                  isEnabled ? 0.5 : 0.7,
                                                ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                                  mainAxisSize:
                                                      MainAxisSize.min,
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
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      l10n.autoAnalyzeOnLaunchDescription,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            fontSize: 11,
                                                            color: theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withOpacity(
                                                                  0.65,
                                                                ),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Switch(
                                                value: isEnabled,
                                                onChanged: (value) async {
                                                  await prefsService
                                                      .setAutoAnalyzeOnLaunch(
                                                        value,
                                                      );
                                                  if (mounted) {
                                                    setState(() {});
                                                  }
                                                },
                                                activeColor:
                                                    theme.colorScheme.primary,
                                                inactiveTrackColor: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.3),
                                                inactiveThumbColor: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.5),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                // Re-Analyze butonu
                                FilledButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(galleryStatsProvider.notifier)
                                        .refresh();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l10n.reAnalyze),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    backgroundColor: theme.colorScheme.primary
                                        .withOpacity(0.85),
                                    side: BorderSide(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.9),
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
                        ),
                      ),
                  ],
                );
              },
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
}

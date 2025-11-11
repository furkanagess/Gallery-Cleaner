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

class GalleryStatsPage extends ConsumerStatefulWidget {
  const GalleryStatsPage({super.key});

  @override
  ConsumerState<GalleryStatsPage> createState() => _GalleryStatsPageState();
}

// Album Stat Item Widget
class _AlbumStatItem extends StatelessWidget {
  const _AlbumStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    required this.color,
    this.isCompact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;
  final Color color;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 8,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: color,
                letterSpacing: -0.1,
                height: 1.0,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
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
                icon,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: color,
              letterSpacing: -0.3,
              height: 1.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
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
        ? Colors.green.shade700
        : isNegative
        ? Colors.red.shade700
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
      appBar: AppBar(
        title: Text(l10n.galleryStatsTitle, overflow: TextOverflow.ellipsis),
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
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
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
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
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

                return Padding(
                  padding: const EdgeInsets.all(16),
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
                                    (semanticColors?.keep ?? Colors.green)
                                        .withOpacity(0.15),
                                    (semanticColors?.keep ?? Colors.green)
                                        .withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: (semanticColors?.keep ?? Colors.green)
                                      .withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (semanticColors?.keep ?? Colors.green)
                                            .withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 13,
                                        color:
                                            semanticColors?.keep ??
                                            Colors.green,
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
                                          color: theme.colorScheme.onSurface,
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
                                    (semanticColors?.delete ?? Colors.red)
                                        .withOpacity(0.15),
                                    (semanticColors?.delete ?? Colors.red)
                                        .withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: (semanticColors?.delete ?? Colors.red)
                                      .withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (semanticColors?.delete ?? Colors.red)
                                            .withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        size: 13,
                                        color:
                                            semanticColors?.delete ??
                                            Colors.red,
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
                                          color: theme.colorScheme.onSurface,
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
                                    Colors.blue.withOpacity(0.15),
                                    Colors.blue.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.data_saver_on_outlined,
                                        size: 13,
                                        color: Colors.blue.shade700,
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
                                          color: theme.colorScheme.onSurface,
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
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
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
                                            color: theme.colorScheme.onSurface,
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
                                              color: theme.colorScheme.onSurface
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
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
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.2,
                                  ),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                        child: Text(
                                          l10n.album,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 10,
                                                color: theme
                                                    .colorScheme
                                                    .onPrimaryContainer
                                                    .withOpacity(0.9),
                                                letterSpacing: 0.3,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Önceki analizle fark (mutlak değer + yüzde)
                                  if (previousStats != null &&
                                      albumChange != null &&
                                      albumDiff != null) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          albumDiff != 0
                                              ? (albumDiff > 0 ? '+' : '-')
                                              : '',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 9,
                                                color: albumChange > 0
                                                    ? Colors.green.shade700
                                                    : albumChange < 0
                                                    ? Colors.red.shade700
                                                    : theme
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                          .withOpacity(0.7),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Text(
                                          albumDiff.abs().toString(),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 9,
                                                color: albumChange > 0
                                                    ? Colors.green.shade700
                                                    : albumChange < 0
                                                    ? Colors.red.shade700
                                                    : theme
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                          .withOpacity(0.7),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Text(
                                          ' (${albumChange > 0 ? '+' : ''}${albumChange.toStringAsFixed(1)}%)',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 8,
                                                color: albumChange > 0
                                                    ? Colors.green.shade700
                                                    : albumChange < 0
                                                    ? Colors.red.shade700
                                                    : theme
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                          .withOpacity(0.7),
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Fotoğraf/Video sayısı badge
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                        child: Text(
                                          l10n.photoVideo,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 10,
                                                color: theme
                                                    .colorScheme
                                                    .onSecondaryContainer
                                                    .withOpacity(0.9),
                                                letterSpacing: 0.3,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Önceki analizle fark (mutlak değer + yüzde)
                                  if (previousStats != null &&
                                      mediaChange != null &&
                                      mediaDiff != null) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          mediaDiff != 0
                                              ? (mediaDiff > 0 ? '+' : '-')
                                              : '',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 9,
                                                color: mediaChange > 0
                                                    ? Colors.green.shade700
                                                    : mediaChange < 0
                                                    ? Colors.red.shade700
                                                    : theme
                                                          .colorScheme
                                                          .onSecondaryContainer
                                                          .withOpacity(0.7),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Text(
                                          mediaDiff.abs().toString(),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 9,
                                                color: mediaChange > 0
                                                    ? Colors.green.shade700
                                                    : mediaChange < 0
                                                    ? Colors.red.shade700
                                                    : theme
                                                          .colorScheme
                                                          .onSecondaryContainer
                                                          .withOpacity(0.7),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Text(
                                          ' (${mediaChange > 0 ? '+' : ''}${mediaChange.toStringAsFixed(1)}%)',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 8,
                                                color: mediaChange > 0
                                                    ? Colors.green.shade700
                                                    : mediaChange < 0
                                                    ? Colors.red.shade700
                                                    : theme
                                                          .colorScheme
                                                          .onSecondaryContainer
                                                          .withOpacity(0.7),
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Toplam boyut badge
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
                                    theme.colorScheme.tertiaryContainer,
                                    theme.colorScheme.tertiaryContainer
                                        .withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.tertiary.withOpacity(
                                    0.2,
                                  ),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                        child: Text(
                                          l10n.totalSize,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 10,
                                                color: theme
                                                    .colorScheme
                                                    .onTertiaryContainer
                                                    .withOpacity(0.9),
                                                letterSpacing: 0.3,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${displayStats.totalSizeMB.toStringAsFixed(1)}',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                          color: theme
                                              .colorScheme
                                              .onTertiaryContainer,
                                          letterSpacing: -1.2,
                                          height: 1,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
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
                                      // Önceki analizle fark (mutlak değer + yüzde)
                                      if (previousStats != null &&
                                          sizeChange != null &&
                                          sizeDiff != null) ...[
                                        const SizedBox(width: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              sizeDiff != 0
                                                  ? (sizeDiff > 0 ? '+' : '-')
                                                  : '',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontSize: 9,
                                                    color: sizeChange > 0
                                                        ? Colors.green.shade700
                                                        : sizeChange < 0
                                                        ? Colors.red.shade700
                                                        : theme
                                                              .colorScheme
                                                              .onTertiaryContainer
                                                              .withOpacity(0.7),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            Text(
                                              '${sizeDiff.abs().toStringAsFixed(1)} MB',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontSize: 9,
                                                    color: sizeChange > 0
                                                        ? Colors.green.shade700
                                                        : sizeChange < 0
                                                        ? Colors.red.shade700
                                                        : theme
                                                              .colorScheme
                                                              .onTertiaryContainer
                                                              .withOpacity(0.7),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            Text(
                                              ' (${sizeChange > 0 ? '+' : ''}${sizeChange.toStringAsFixed(1)}%)',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontSize: 8,
                                                    color: sizeChange > 0
                                                        ? Colors.green.shade700
                                                        : sizeChange < 0
                                                        ? Colors.red.shade700
                                                        : theme
                                                              .colorScheme
                                                              .onTertiaryContainer
                                                              .withOpacity(0.7),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
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
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
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
                              Stack(
                                children: [
                                  SizedBox(
                                    height:
                                        320, // 2 satır * kart yüksekliği + spacing
                                    child: GridView.builder(
                                      controller: _albumScrollController,
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.only(right: 16),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            2, // 2 satır (yatay scroll'da satır sayısı)
                                        mainAxisSpacing:
                                            14, // Yatay spacing (kartlar arası)
                                        crossAxisSpacing:
                                            14, // Dikey spacing (satırlar arası)
                                        mainAxisExtent:
                                            300, // Kart genişliği (yatay scroll'da) - daha geniş
                                      ),
                                      itemCount:
                                          displayStats.albumDetails.length,
                                      itemBuilder: (context, index) {
                                        final detail =
                                            displayStats.albumDetails[index];
                                        final double sizeMb = detail.sizeMB;
                                        // Toplam galeri boyutuna göre yüzde hesapla
                                        final double totalSizeMb =
                                            displayStats.totalSizeMB > 0
                                                ? displayStats.totalSizeMB
                                                : 1;
                                        final double percentage =
                                            (sizeMb / totalSizeMb * 100)
                                                .clamp(0.0, 100.0);
                                        return Container(
                                          constraints: const BoxConstraints(
                                            maxHeight: double.infinity,
                                          ),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: theme.colorScheme.outline
                                                  .withOpacity(0.08),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.04),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Album Name - Header (ultra compact)
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      color: theme
                                                          .colorScheme
                                                          .primaryContainer
                                                          .withOpacity(0.6),
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: theme
                                                            .colorScheme
                                                            .primary
                                                            .withOpacity(0.15),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.folder_rounded,
                                                      size: 16,
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          detail.albumName,
                                                          style: theme
                                                              .textTheme
                                                              .titleSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight.w700,
                                                                fontSize: 13,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                                letterSpacing: -0.2,
                                                                height: 1.1,
                                                              ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        // Percentage badge (inline)
                                                        Text(
                                                          '${percentage.toStringAsFixed(1)}%',
                                                          style: theme
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight.w600,
                                                                fontSize: 8,
                                                                color: theme
                                                                    .colorScheme
                                                                    .secondary,
                                                                letterSpacing: 0.1,
                                                                height: 1.0,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              // Stats Grid (ultra compact)
                                              Row(
                                                children: [
                                                  // Media Count
                                                  Expanded(
                                                    child: _AlbumStatItem(
                                                      icon: Icons.photo_library_rounded,
                                                      label: l10n.mediaUnit,
                                                      value: '${detail.mediaCount}',
                                                      theme: theme,
                                                      color: theme.colorScheme.primary,
                                                      isCompact: true,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  // Size
                                                  Expanded(
                                                    child: _AlbumStatItem(
                                                      icon: Icons.storage_rounded,
                                                      label: 'MB',
                                                      value:
                                                          sizeMb.toStringAsFixed(1),
                                                      theme: theme,
                                                      color: theme.colorScheme.secondary,
                                                      isCompact: true,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              // Progress Bar (ultra compact)
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          l10n.ofGallery,
                                                          style: theme
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight.w500,
                                                                fontSize: 8,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withOpacity(0.6),
                                                                height: 1.0,
                                                              ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${percentage.toStringAsFixed(1)}%',
                                                        style: theme
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                              fontSize: 9,
                                                              color: theme
                                                                  .colorScheme
                                                                  .primary,
                                                              height: 1.0,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                    child: SizedBox(
                                                      height: 5,
                                                      child: Stack(
                                                        children: [
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              color: theme
                                                                  .colorScheme
                                                                  .surfaceContainerHighest
                                                                  .withOpacity(0.4),
                                                            ),
                                                          ),
                                                          FractionallySizedBox(
                                                            widthFactor: (percentage / 100)
                                                                .clamp(0.0, 1.0),
                                                            alignment: Alignment
                                                                .centerLeft,
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                              ),
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
                                  ),
                                  // Sol ok (scroll left)
                                  if (_showLeftArrow)
                                    Positioned(
                                      left: 8,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _scrollLeft,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                  colors: [
                                                    theme.colorScheme.surface
                                                        .withOpacity(0.9),
                                                    theme.colorScheme.surface
                                                        .withOpacity(0.7),
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
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.chevron_left_rounded,
                                                color:
                                                    theme.colorScheme.primary,
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
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _scrollRight,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                  colors: [
                                                    theme.colorScheme.surface
                                                        .withOpacity(0.9),
                                                    theme.colorScheme.surface
                                                        .withOpacity(0.7),
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
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.chevron_right_rounded,
                                                color:
                                                    theme.colorScheme.primary,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Tekrardan Analiz Et butonu (sayfanın en altında)
                      const SizedBox(height: 24),
                      if (!isScanning)
                        FilledButton.icon(
                          onPressed: () {
                            ref.read(galleryStatsProvider.notifier).refresh();
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.reAnalyze),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
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

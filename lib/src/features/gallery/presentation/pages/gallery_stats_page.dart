import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
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
        cubitSetState(() {
          _showLeftArrow = false;
          _showRightArrow = false;
        });
      }
      return;
    }

    final position = _albumScrollController.position;
    if (mounted) {
      cubitSetState(() {
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

                  // Stats değiştiğinde scroll oklarını güncelle
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted &&
                        displayStats.albumDetails.isNotEmpty) {
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (context.mounted) {
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
                      ? ((displayStats.totalSizeMB -
                                    previousStats.totalSizeMB) /
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
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.2),
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
                            const SizedBox(height: 24),
                            // Recent Activity Section
                            _buildRecentActivitySection(
                              context,
                              theme,
                              l10n,
                              history,
                              appliedDeletes,
                            ),
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
                                                              .withOpacity(
                                                                0.65,
                                                              ),
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
                                  FilledButton.icon(
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

  /// Keep/Delete Stats Section (en üstte)
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
          child: SizedBox(
            height: 100, // Sabit yükseklik
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (semanticColors?.keep ?? AppColors.success).withOpacity(
                      0.15,
                    ),
                    (semanticColors?.keep ?? AppColors.success).withOpacity(
                      0.1,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (semanticColors?.keep ?? AppColors.success)
                      .withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (semanticColors?.keep ?? AppColors.success)
                        .withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: semanticColors?.keep ?? AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l10n.keep,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$keepCount',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: theme.colorScheme.onSurface,
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
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 100, // Sabit yükseklik
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (semanticColors?.delete ?? AppColors.error).withOpacity(
                      0.15,
                    ),
                    (semanticColors?.delete ?? AppColors.error).withOpacity(
                      0.1,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (semanticColors?.delete ?? AppColors.error)
                      .withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (semanticColors?.delete ?? AppColors.error)
                        .withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: semanticColors?.delete ?? AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l10n.delete,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$deleteCount',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: theme.colorScheme.onSurface,
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
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 100, // Sabit yükseklik
            child: Container(
              padding: const EdgeInsets.all(16),
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
                    color: AppColors.blurTab.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.data_saver_on_outlined,
                        size: 16,
                        color: AppColors.blurTab,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l10n.spaceSaved,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatBytes(totalBytesFreed),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -1.0,
                        height: 1,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// General Statistics Section - 2 cards (Total Photos and Total Size)
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
          'General Statistics',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                theme,
                'Total Photos',
                _formatNumber(totalPhotos),
                Icons.photo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                theme,
                l10n.totalSize,
                _formatSizeMB(stats.totalSizeMB),
                Icons.folder,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Stat Card Widget
  Widget _buildStatCard(
    BuildContext context,
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
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
          'Albums',
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
                  '${album.mediaCount} items',
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

  /// Recent Activity Section
  Widget _buildRecentActivitySection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<ReviewActionItem> history,
    List<ReviewActionItem> appliedDeletes,
  ) {
    // Get recent activities (last 3 applied deletes)
    final recentActivities = appliedDeletes.take(3).toList();

    if (recentActivities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...recentActivities.map(
          (action) => _buildActivityCard(context, theme, l10n, action),
        ),
      ],
    );
  }

  /// Activity Card Widget
  Widget _buildActivityCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    ReviewActionItem action,
  ) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(action.timestampMs);
    final timeAgo = _formatTimeAgo(context, dateTime);
    final spaceSaved = _formatBytes(action.fileSizeBytes);

    String title;
    IconData icon;
    if (action.type == ReviewActionType.delete) {
      title = 'Duplicates Cleaned';
      icon = Icons.delete;
    } else {
      title = 'Blurry Review';
      icon = Icons.grid_view;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+$spaceSaved',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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

  /// Format time ago
  String _formatTimeAgo(BuildContext context, DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday, ${DateFormat('h:mm a').format(dateTime)}';
      }
      return DateFormat('MMM d, h:mm a').format(dateTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:lottie/lottie.dart';
import '../../../../application/duplicate_detection_provider.dart';
import '../../../../application/gallery_providers.dart';
import '../../../../../../core/services/sound_service.dart';
import '../../../../../../core/services/preferences_service.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../../../../app/theme/app_decorations.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/utils/view_refresh_cubit.dart';
import '../../../../../../core/utils/async_value.dart';
import 'widgets/duplicate_tab_shimmer.dart' show ScanFormShimmer;
import '../blur/widgets/scan_progress_card.dart' show ScanProgressCard;
import '../blur/widgets/modern_scan_button.dart' show ModernScanButton;
import 'widgets/duplicate_tab_helpers.dart'
    show estimateDuplicateScanDuration, formatEstimatedTime;
import 'widgets/duplicate_mode_selector.dart' show DuplicateModeSelector;
import '../widgets/sound_toggle_button.dart' show SoundToggleButton;

// Duplicate Tab
class DuplicateTab extends StatefulWidget {
  const DuplicateTab({super.key});

  @override
  State<DuplicateTab> createState() => DuplicateTabState();
}

class DuplicateTabState extends State<DuplicateTab>
    with CubitStateMixin<DuplicateTab> {
  final SoundService _soundService = SoundService();
  final PreferencesService _prefsService = PreferencesService();
  DuplicateDetectionMode _duplicateMode =
      DuplicateDetectionMode.mediumSensitivity;
  bool _isSoundEnabled = true;
  StreamSubscription? _duplicateDetectionSubscription;

  @override
  void initState() {
    super.initState();
    _loadSoundState();

    // Stream listener'ı ekle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final duplicateDetectionCubit = context.read<DuplicateDetectionCubit>();
      _duplicateDetectionSubscription = duplicateDetectionCubit.stream.listen((
        next,
      ) {
        if (!mounted) return;
        final previous = duplicateDetectionCubit.state;
        // Scan durumu veya tamamlanma durumu değiştiğinde ses kontrolü yap
        final wasScanning = previous.isScanning;
        final isScanning = next.isScanning;
        final hasCompleted = next.hasCompletedScan && !next.isScanning;

        debugPrint(
          '🔍 [DuplicateTab] Stream event - wasScanning: $wasScanning, isScanning: $isScanning, hasCompleted: $hasCompleted',
        );

        // Scan başladıysa ses çal
        if (isScanning && !wasScanning) {
          _soundService.playScannerSound();
        }
        // Scan durduysa veya tamamlandıysa ses durdur
        else if ((!isScanning && wasScanning) || hasCompleted) {
          _soundService.stopScannerSound();
        }

        // Scan tamamlandığında tip rotation'ı durdur (bildirim ve navigation SwipePage'de yapılıyor)
        if (wasScanning && !isScanning && hasCompleted) {
          debugPrint(
            '✅ [DuplicateTab] Scan completed (notification and navigation will be handled by SwipePage)',
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _soundService.stopScannerSound();
    _duplicateDetectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSoundState() async {
    final isEnabled = await _prefsService.isScanSoundEnabled();
    if (mounted) {
      cubitSetState(() {
        _isSoundEnabled = isEnabled;
      });
    }
  }

  Future<void> _toggleSound() async {
    // State zaten güncellendi, SoundService'in optimize edilmiş metodunu kullan
    final currentState = _isSoundEnabled;
    await _soundService.setSoundEnabled(currentState);

    // Eğer ses açıldıysa ve scan devam ediyorsa sesi başlat
    if (currentState && mounted) {
      final duplicateState = context.read<DuplicateDetectionCubit>().state;
      if (duplicateState.isScanning) {
        _soundService.playScannerSound();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedAlbum = context.watch<SelectedAlbumCubit>().state;
    final albumsAsync = context.watch<AlbumsCubit>().state;
    final duplicateState = context.watch<DuplicateDetectionCubit>().state;

    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.8,
    );

    final isScanning = duplicateState.isScanning;

    return PopScope(
      canPop: !isScanning,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isScanning) {
          // Kullanıcı scan sırasında geri tuşuna bastı, bilgilendirme göster
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.doNotLeaveScreenDuringScan),
              duration: const Duration(seconds: 3),
              backgroundColor: theme.colorScheme.errorContainer,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: albumsAsync.when(
        loading: () => const ScanFormShimmer(),
        error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
        data: (albums) {
          if (albums.isEmpty) {
            return Center(child: Text(l10n.albumNotFound));
          }

          final selectedAlbums = selectedAlbum != null
              ? [selectedAlbum]
              : albums.where((a) => !a.isAll).toList();

          // Tarama yapılırken full-screen overlay göster (blur tab ile aynı yapı)
          if (isScanning) {
            return Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: theme.colorScheme.scrim.withValues(alpha: 0.32),
                    ),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 20,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.25,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: AppDecorations.glassSurface(
                                      borderRadius: 14,
                                      tint: theme.colorScheme.primaryContainer,
                                      opacity: 0.35,
                                    ),
                                    child: Icon(
                                      Icons.content_copy_rounded,
                                      size: 20,
                                      color: containerColor,
                                    ),
                                  ),
                                  const Spacer(),
                                  SoundToggleButton(
                                    isSoundEnabled: _isSoundEnabled,
                                    onToggle: () {
                                      cubitSetState(() {
                                        _isSoundEnabled = !_isSoundEnabled;
                                      });
                                      _toggleSound();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: 160,
                                height: 160,
                                child: Lottie.asset(
                                  'assets/lottie/gallery_loading.json',
                                  fit: BoxFit.contain,
                                  repeat: true,
                                  animate: true,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ScanProgressCard(
                                title:
                                    duplicateState.currentAlbum ??
                                    l10n.scanningDuplicatePhotos,
                                processed: duplicateState.processedCount,
                                total: duplicateState.totalCount,
                                fallbackLabel: l10n.scanningDuplicatePhotos,
                                icon: Icons.tune_rounded,
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonalIcon(
                                  onPressed: () {
                                    context
                                        .read<DuplicateDetectionCubit>()
                                        .cancel();
                                  },
                                  icon: const Icon(Icons.stop_rounded),
                                  label: Text(l10n.stop),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    backgroundColor:
                                        theme.colorScheme.errorContainer,
                                    foregroundColor:
                                        theme.colorScheme.onErrorContainer,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    side: BorderSide(
                                      color: theme.colorScheme.error.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Scan durduğunda ekstra UI timer yok
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(
              top: 8,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: Column(
              children: [
                _buildScanForm(context, theme, l10n),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final duplicateScanLimitAsync = context
                        .watch<DuplicateScanLimitCubit>()
                        .state;
                    final isPremiumAsync = context.watch<PremiumCubit>().state;

                    return duplicateScanLimitAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) =>
                          Center(child: Text(l10n.errorMessage(e.toString()))),
                      data: (scanLimit) {
                        return _buildStartScanButton(
                          context,
                          theme,
                          l10n,
                          selectedAlbums,
                          isPremiumAsync,
                          scanLimit,
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStartScanButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<pm.AssetPathEntity> selectedAlbums,
    AsyncValue<bool> isPremiumAsync,
    int scanLimit,
  ) {
    final duplicateState = context.watch<DuplicateDetectionCubit>().state;
    final isScanning = duplicateState.isScanning;
    final hasResults =
        duplicateState.hasCompletedScan || duplicateState.totalGroups > 0;

    return isPremiumAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
      data: (isPremium) {
        final hasNoScanRights = !isPremium && scanLimit <= 0;

        // Önce önceki sonuçlar varsa "Start New Scan" + "View Last Results"
        if (hasResults) {
          final containerColor = theme.colorScheme.onPrimaryContainer
              .withValues(alpha: 0.8);

          return Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<DuplicateDetectionCubit>().clear();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.startNewScan),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(0, 56),
                    side: BorderSide(
                      color: containerColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    context.push('/results/duplicate');
                  },
                  icon: const Icon(Icons.visibility_rounded),
                  label: Text(l10n.viewLastResults),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(0, 56),
                    backgroundColor: containerColor,
                    foregroundColor: AppColors.white,
                    side: BorderSide(
                      color: containerColor.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Scan hakkı yok ve hiç sonuç yoksa - sadece Get Premium butonu (Start Scan ile aynı stil, farklı renk)
        if (hasNoScanRights && !hasResults) {
          final premiumColor = AppColors.warningLight;
          return SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/paywall'),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: Text(l10n.getUnlimitedDeletions),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: premiumColor,
                foregroundColor: theme.colorScheme.surface,
                side: BorderSide(
                  color: premiumColor.withValues(alpha: 0.9),
                  width: 1.5,
                ),
              ),
            ),
          );
        }

        // Normal durumda ModernScanButton
        return FutureBuilder<bool>(
          future: _checkAlbumsHavePhotos(selectedAlbums),
          builder: (context, albumsSnapshot) {
            final hasPhotosInAlbums = albumsSnapshot.data ?? false;
            final isLoadingAlbums =
                albumsSnapshot.connectionState == ConnectionState.waiting;

            return FutureBuilder<
              ({
                int estimatedSeconds,
                int totalPhotoCount,
                bool hasLimitWarning,
              })
            >(
              future: estimateDuplicateScanDuration(selectedAlbums),
              builder: (context, snapshot) {
                final estimatedTimeText = snapshot.hasData
                    ? formatEstimatedTime(snapshot.data!.estimatedSeconds, l10n)
                    : null;

                final hasLimitWarning =
                    snapshot.hasData && snapshot.data!.hasLimitWarning;
                final totalPhotoCount = snapshot.hasData
                    ? snapshot.data!.totalPhotoCount
                    : 0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasPhotosInAlbums && !isLoadingAlbums) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.warning.withValues(alpha: 0.2),
                              AppColors.warning.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.noPhotosInSelectedAlbums,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ModernScanButton(
                      context: context,
                      theme: theme,
                      l10n: l10n,
                      onPressed:
                          isScanning ||
                              hasNoScanRights ||
                              !hasPhotosInAlbums ||
                              isLoadingAlbums
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) {
                                  final containerColor = theme
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withValues(alpha: 0.8);

                                  return AlertDialog(
                                    title: Text(l10n.confirmDuplicateScan),
                                    content: Container(
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: containerColor.withValues(
                                            alpha: 0.25,
                                          ),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxHeight:
                                                MediaQuery.of(
                                                  dialogContext,
                                                ).size.height *
                                                0.35,
                                          ),
                                          child: SingleChildScrollView(
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: selectedAlbums
                                                  .map(
                                                    (album) => Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .surface
                                                            .withValues(
                                                              alpha: 0.9,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                        border: Border.all(
                                                          color: containerColor
                                                              .withValues(
                                                                alpha: 0.4,
                                                              ),
                                                          width: 1.1,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .folder_rounded,
                                                            size: 16,
                                                            color:
                                                                containerColor,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            album.name,
                                                            style: theme
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: theme
                                                                      .colorScheme
                                                                      .onSurface,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: SizedBox(
                                              height: 48,
                                              child: TextButton(
                                                onPressed: () => Navigator.of(
                                                  dialogContext,
                                                ).pop(false),
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                ),
                                                child: Center(
                                                  child: Text(l10n.cancel),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 3,
                                            child: SizedBox(
                                              height: 48,
                                              child: FilledButton(
                                                onPressed: () => Navigator.of(
                                                  dialogContext,
                                                ).pop(true),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      containerColor,
                                                  side: BorderSide.none,
                                                  padding: EdgeInsets.zero,
                                                ),
                                                child: Center(
                                                  child: Text(l10n.scan),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirmed != true || !context.mounted) return;

                              // Boş albümleri filtrele
                              final albumsWithPhotos = <pm.AssetPathEntity>[];
                              for (final album in selectedAlbums) {
                                try {
                                  final assetCount =
                                      await album.assetCountAsync;
                                  if (assetCount > 0) {
                                    albumsWithPhotos.add(album);
                                  }
                                } catch (e) {
                                  debugPrint(
                                    '⚠️ [DuplicateTab] Albüm ${album.name} için asset sayısı alınamadı: $e',
                                  );
                                }
                              }

                              if (!context.mounted) return;

                              // Eğer hiç dolu albüm yoksa uyarı göster
                              if (albumsWithPhotos.isEmpty) {
                                if (!context.mounted) return;
                                await showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: Text(l10n.noPhotosFound),
                                    content: Text(
                                      l10n.noPhotosInSelectedAlbums,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        child: Text(l10n.ok),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }

                              // Sadece dolu albümleri scan et
                              await context
                                  .read<DuplicateDetectionCubit>()
                                  .scanAlbums(
                                    albumsWithPhotos,
                                    mode: _duplicateMode,
                                  );

                              if (!context.mounted) return;
                            },
                      icon: hasNoScanRights
                          ? Icons.block
                          : Icons.search_rounded,
                      label: hasNoScanRights
                          ? l10n.noScanRightsLeft
                          : l10n.scanSelectedAlbums,
                      isEnabled:
                          !isScanning &&
                          !hasNoScanRights &&
                          hasPhotosInAlbums &&
                          !isLoadingAlbums,
                      isError: hasNoScanRights,
                      onErrorPressed: () => context.push('/paywall'),
                      estimatedTimeText: estimatedTimeText,
                      hasLimitWarning: hasLimitWarning,
                      totalPhotoCount: totalPhotoCount,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Seçili albümlerde fotoğraf olup olmadığını kontrol eder
  Future<bool> _checkAlbumsHavePhotos(List<pm.AssetPathEntity> albums) async {
    if (albums.isEmpty) return false;

    for (final album in albums) {
      try {
        final assetCount = await album.assetCountAsync;
        if (assetCount > 0) {
          return true; // En az bir albümde fotoğraf varsa true döndür
        }
      } catch (e) {
        debugPrint(
          '⚠️ [DuplicateTab] Albüm ${album.name} için asset sayısı alınamadı: $e',
        );
      }
    }

    return false; // Hiçbir albümde fotoğraf yoksa false döndür
  }

  Widget _buildScanForm(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.8,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kompakt info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.15),
                theme.colorScheme.primary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: containerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.copy_rounded,
                  size: 28,
                  color: containerColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: containerColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: containerColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.aiPowered,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: containerColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.duplicatePhotoDetection,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: containerColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.duplicateDetectionDescriptionFromAppBar,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        height: 1.4,
                        color: containerColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Sensitivity selection (same concept as blur tab)
        DuplicateModeSelector(
          currentMode: _duplicateMode,
          onModeChanged: (DuplicateDetectionMode mode) {
            // Anında hassasiyet değişimi - state'i güncelle
            cubitSetState(() {
              _duplicateMode = mode;
            });
          },
        ),
      ],
    );
  }
}

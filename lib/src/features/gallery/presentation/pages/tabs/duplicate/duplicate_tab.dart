import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
import '../../swipe_page.dart' show showDeleteSuccessDialog;
import 'widgets/duplicate_tab_shimmer.dart' show ScanFormShimmer;
import '../blur/widgets/scan_progress_card.dart' show ScanProgressCard;
import '../blur/widgets/modern_scan_button.dart' show ModernScanButton;
import 'widgets/duplicate_tab_helpers.dart'
    show estimateDuplicateScanDuration, formatEstimatedTime;
import 'widgets/duplicate_mode_selector.dart' show DuplicateModeSelector;
import '../widgets/sound_toggle_button.dart' show SoundToggleButton;

// Duplicate Tab
class DuplicateTab extends StatefulWidget {
  const DuplicateTab();

  @override
  State<DuplicateTab> createState() => DuplicateTabState();
}

class DuplicateTabState extends State<DuplicateTab>
    with CubitStateMixin<DuplicateTab> {
  final SoundService _soundService = SoundService();
  final PreferencesService _prefsService = PreferencesService();
  DuplicateDetectionMode _duplicateMode = DuplicateDetectionMode.balanced;
  bool _isSoundEnabled = true;
  int _currentTipIndex = 0;
  Timer? _tipTimer;
  StreamSubscription? _duplicateDetectionSubscription;
  final List<int> _tipOrder = [];
  int _tipOrderIndex = 0;

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
          _stopTipRotation();
        }
      });
    });
  }

  @override
  void dispose() {
    _soundService.stopScannerSound();
    _tipTimer?.cancel();
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
    if (currentState) {
      final duplicateState = context.read<DuplicateDetectionCubit>().state;
      if (duplicateState.isScanning) {
        _soundService.playScannerSound();
      }
    }
  }

  void _startTipRotation() {
    _tipTimer?.cancel();
    // Random tip sırası oluştur (15 tip var)
    if (_tipOrder.isEmpty) {
      _tipOrder.addAll(List.generate(15, (index) => index));
      _tipOrder.shuffle();
      _tipOrderIndex = 0;
      // İlk tipi de random seç
      _currentTipIndex = _tipOrder[_tipOrderIndex];
    }
    _tipTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        cubitSetState(() {
          _tipOrderIndex = (_tipOrderIndex + 1) % _tipOrder.length;
          _currentTipIndex = _tipOrder[_tipOrderIndex];
        });
      }
    });
  }

  void _stopTipRotation() {
    _tipTimer?.cancel();
  }

  String _getCurrentTip(AppLocalizations l10n) {
    switch (_currentTipIndex) {
      case 0:
        return l10n.scanTip1;
      case 1:
        return l10n.scanTip2;
      case 2:
        return l10n.scanTip3;
      case 3:
        return l10n.scanTip4;
      case 4:
        return l10n.scanTip5;
      case 5:
        return l10n.scanTip6;
      case 6:
        return l10n.scanTip7;
      case 7:
        return l10n.scanTip8;
      case 8:
        return l10n.scanTip9;
      case 9:
        return l10n.scanTip10;
      case 10:
        return l10n.scanTip11;
      case 11:
        return l10n.scanTip12;
      case 12:
        return l10n.scanTip13;
      case 13:
        return l10n.scanTip14;
      case 14:
        return l10n.scanTip15;
      default:
        return l10n.scanTip1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedAlbum = context.watch<SelectedAlbumCubit>().state;
    final albumsAsync = context.watch<AlbumsCubit>().state;
    final duplicateState = context.watch<DuplicateDetectionCubit>().state;

    // Premium durumunu kontrol et
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    final isPremium = isPremiumAsync.maybeWhen(
      data: (premium) => premium,
      orElse: () => false,
    );

    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(
      0.8,
    );

    final isScanning = duplicateState.isScanning;

    return PopScope(
      canPop: !isScanning,
      onPopInvoked: (didPop) {
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

          // Tarama yapılırken full-screen overlay göster
          if (isScanning) {
            // Timer'ı başlat
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startTipRotation();
            });

            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ses açma/kapama butonu
                      Align(
                        alignment: Alignment.topRight,
                        child: SoundToggleButton(
                          isSoundEnabled: _isSoundEnabled,
                          onToggle: () {
                            // Anında state'i güncelle
                            setState(() {
                              _isSoundEnabled = !_isSoundEnabled;
                            });
                            // Sonra async işlemi yap
                            _toggleSound();
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Lottie animasyonu - daha büyük
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
                      const SizedBox(height: 16),
                      // Progress bilgisi - scan başladığı andan itibaren göster
                      ScanProgressCard(
                        title:
                            duplicateState.currentAlbum ??
                            l10n.scanningDuplicatePhotos,
                        processed: duplicateState.processedCount,
                        total: duplicateState.totalCount,
                        fallbackLabel: l10n.scanningDuplicatePhotos,
                      ),
                      const SizedBox(height: 20),
                      // Değişen textler
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: Container(
                          key: ValueKey(_currentTipIndex),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                containerColor.withOpacity(0.3),
                                containerColor.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: containerColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 20,
                                color: containerColor,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  _getCurrentTip(l10n),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Durdur butonu - tüm ekran genişliğinde
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            _stopTipRotation();
                            context.read<DuplicateDetectionCubit>().cancel();
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
                            side: BorderSide(
                              color: AppColors.error.withOpacity(0.9),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            // Scan durduğunda timer'ı durdur
            _stopTipRotation();
          }

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 8,
                  left: 16,
                  right: 16,
                  bottom: 80,
                ),
                child: _buildScanForm(context, theme, l10n),
              ),
              // Fixed bottom button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.background,
                  ),
                  child: SafeArea(
                    child: Builder(
                      builder: (context) {
                        // Check if there are actual duplicate groups to delete
                        final hasPhotosToDelete =
                            duplicateState.totalDuplicatePhotos > 0;

                        final duplicateScanLimitAsync = context
                            .watch<DuplicateScanLimitCubit>()
                            .state;
                        final isPremiumAsync = context
                            .watch<PremiumCubit>()
                            .state;

                        return duplicateScanLimitAsync.when(
                          loading: () => hasPhotosToDelete
                              ? _buildDeleteAllButton(
                                  context,
                                  theme,
                                  l10n,
                                  duplicateState,
                                )
                              : _buildStartScanButton(
                                  context,
                                  theme,
                                  l10n,
                                  selectedAlbums,
                                  isPremiumAsync,
                                  null,
                                  false,
                                  0,
                                ),
                          error: (_, __) => hasPhotosToDelete
                              ? _buildDeleteAllButton(
                                  context,
                                  theme,
                                  l10n,
                                  duplicateState,
                                )
                              : _buildStartScanButton(
                                  context,
                                  theme,
                                  l10n,
                                  selectedAlbums,
                                  isPremiumAsync,
                                  null,
                                  false,
                                  0,
                                ),
                          data: (scanLimit) {
                            return isPremiumAsync.when(
                              loading: () => hasPhotosToDelete
                                  ? _buildDeleteAllButton(
                                      context,
                                      theme,
                                      l10n,
                                      duplicateState,
                                    )
                                  : _buildStartScanButton(
                                      context,
                                      theme,
                                      l10n,
                                      selectedAlbums,
                                      isPremiumAsync,
                                      null,
                                      false,
                                      0,
                                    ),
                              error: (_, __) => hasPhotosToDelete
                                  ? _buildDeleteAllButton(
                                      context,
                                      theme,
                                      l10n,
                                      duplicateState,
                                    )
                                  : _buildStartScanButton(
                                      context,
                                      theme,
                                      l10n,
                                      selectedAlbums,
                                      isPremiumAsync,
                                      null,
                                      false,
                                      0,
                                    ),
                              data: (isPremium) {
                                return FutureBuilder<
                                  ({
                                    int estimatedSeconds,
                                    int totalPhotoCount,
                                    bool hasLimitWarning,
                                  })
                                >(
                                  future: estimateDuplicateScanDuration(
                                    selectedAlbums,
                                  ),
                                  builder: (context, snapshot) {
                                    final estimatedTimeText = snapshot.hasData
                                        ? formatEstimatedTime(
                                            snapshot.data!.estimatedSeconds,
                                            l10n,
                                          )
                                        : null;

                                    final hasLimitWarning =
                                        snapshot.hasData &&
                                        snapshot.data!.hasLimitWarning;
                                    final totalPhotoCount = snapshot.hasData
                                        ? snapshot.data!.totalPhotoCount
                                        : 0;

                                    return _buildStartScanButton(
                                      context,
                                      theme,
                                      l10n,
                                      selectedAlbums,
                                      isPremiumAsync,
                                      estimatedTimeText,
                                      hasLimitWarning,
                                      totalPhotoCount,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
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

  Widget _buildStartScanButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<pm.AssetPathEntity> selectedAlbums,
    AsyncValue<bool> isPremiumAsync,
    String? estimatedTimeText,
    bool hasLimitWarning,
    int totalPhotoCount,
  ) {
    final duplicateState = context.watch<DuplicateDetectionCubit>().state;
    final isScanning = duplicateState.isScanning;
    final hasResults =
        duplicateState.hasCompletedScan || duplicateState.totalGroups > 0;

    return isPremiumAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (isPremium) {
        final duplicateScanLimitAsync = context
            .watch<DuplicateScanLimitCubit>()
            .state;
        return duplicateScanLimitAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (scanLimit) {
            final hasNoScanRights = !isPremium && scanLimit <= 0;

            // hasResults durumunda "View Last Results" ve "Start New Scan" butonları göster
            if (hasResults) {
              // Bottom navigation bar'daki container rengiyle aynı
              final containerColor = theme.colorScheme.onPrimaryContainer
                  .withOpacity(0.8);

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Scan state'ini temizle
                        context.read<DuplicateDetectionCubit>().clear();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.startNewScan),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(0, 56),
                        side: BorderSide(
                          color: containerColor.withOpacity(0.5),
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
                          color: containerColor.withOpacity(0.9),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ModernScanButton(
              context: context,
              theme: theme,
              l10n: l10n,
              onPressed: isScanning || hasNoScanRights
                  ? null
                  : () async {
                      // Seçili albüm isimlerini hazırla
                      final albumNames = selectedAlbums
                          .map((a) => a.name)
                          .join(', ');

                      // Onay dialogu göster
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) {
                          // Premium durumunu kontrol et
                          final isPremiumAsync = dialogContext
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

                          return AlertDialog(
                            title: Text(l10n.confirmDuplicateScan),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.confirmDuplicateScanMessage),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: containerColor.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: containerColor.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.folder_rounded,
                                        size: 20,
                                        color: containerColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          albumNames,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: containerColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: Text(l10n.cancel),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: containerColor,
                                ),
                                child: Text(l10n.scan),
                              ),
                            ],
                          );
                        },
                      );

                      // Kullanıcı onaylamadıysa veya dialog kapatıldıysa çık
                      if (confirmed != true || !mounted) return;

                      // Scan başlat
                      await context.read<DuplicateDetectionCubit>().scanAlbums(
                        selectedAlbums,
                        mode: _duplicateMode,
                      );

                      if (!mounted) return;
                    },
              icon: hasNoScanRights ? Icons.block : Icons.search_rounded,
              label: hasNoScanRights
                  ? l10n.noScanRightsLeft
                  : l10n.scanSelectedAlbums,
              isEnabled: !isScanning && !hasNoScanRights,
              isError: hasNoScanRights,
              onErrorPressed: () => context.push('/paywall'),
              estimatedTimeText: estimatedTimeText,
              hasLimitWarning: hasLimitWarning,
              totalPhotoCount: totalPhotoCount,
            );
          },
        );
      },
    );
  }

  Widget _buildDeleteAllButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    DuplicateDetectionState duplicateState,
  ) {
    return FilledButton.icon(
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.deleteAllDuplicates),
            content: Text(
              l10n.deleteAllDuplicatesMessage(
                duplicateState.totalDuplicatePhotos,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: AppColors.error.withOpacity(0.9),
                    width: 1.5,
                  ),
                ),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );

        if (confirmed != true || !mounted) return;

        // Delete limit kontrolü
        final deleteLimitController = context.read<DeleteLimitCubit>();
        final deleteLimit = await deleteLimitController.currentLimit();
        final isPremium = await PreferencesService().isPremium();

        // Toplam silinecek fotoğraf sayısını kontrol et
        final totalPhotosToDelete = duplicateState.totalDuplicatePhotos;

        // Delete limit'e göre maksimum silinebilecek fotoğraf sayısını belirle
        final maxDeleteCount = isPremium || deleteLimit >= 999999999
            ? totalPhotosToDelete
            : math.min(deleteLimit, totalPhotosToDelete);

        debugPrint(
          '📊 [DuplicateTab] Toplu silme: $maxDeleteCount/$totalPhotosToDelete fotoğraf silinecek (limit: $deleteLimit)',
        );

        // Eğer limit varsa, sadece limit kadar fotoğrafı sil
        int deletedCount = 0;
        if (maxDeleteCount > 0) {
          deletedCount = await context
              .read<DuplicateDetectionCubit>()
              .deleteAllDuplicates(maxDeleteCount: maxDeleteCount);
        }

        if (!mounted) return;

        if (deletedCount > 0) {
          // Silme hakkını azalt
          await deleteLimitController.decrease(deletedCount);

          debugPrint('✅ [DuplicateTab] $deletedCount fotoğraf silindi');

          // Success dialog göster
          if (mounted) {
            await showDeleteSuccessDialog(context, deletedCount);
          }

          // Reload'u dialog kapandıktan sonra yap
          if (mounted) {
            context.read<GalleryPagingCubit>().reload();
          }
        } else {
          debugPrint('⚠️ [DuplicateTab] Silme işlemi başarısız veya limit yok');
        }
      },
      icon: const Icon(Icons.delete_outline),
      label: Text(l10n.deleteAllDuplicates),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: AppColors.error.withOpacity(0.85),
        foregroundColor: theme.colorScheme.onError,
        side: BorderSide(color: AppColors.error.withOpacity(0.9), width: 1.5),
      ),
    );
  }

  Widget _buildScanForm(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    // Premium durumunu kontrol et
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    final isPremium = isPremiumAsync.maybeWhen(
      data: (premium) => premium,
      orElse: () => false,
    );

    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(
      0.8,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kompakt info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppDecorations.floatingCard(
            borderRadius: 18,
            color: theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: containerColor.withOpacity(0.15),
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
                            color: containerColor.withOpacity(0.2),
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
                        color: containerColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Mode selection
        DuplicateModeSelector(
          currentMode: _duplicateMode,
          onModeChanged: (DuplicateDetectionMode mode) {
            // Anında mod değişimi - state'i güncelle
            setState(() {
              _duplicateMode = mode;
            });
          },
        ),
      ],
    );
  }
}

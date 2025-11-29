import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../../../core/services/preferences_service.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:lottie/lottie.dart';
import '../../../../application/blur_detection_provider.dart';
import '../../../../application/gallery_providers.dart';
import '../../../../../../core/services/sound_service.dart';
import '../../../../../../core/models/blur_photo.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../../../../app/theme/app_decorations.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/utils/view_refresh_cubit.dart';
import '../../../../../../core/utils/async_value.dart';
import 'widgets/blur_tab_shimmer.dart' show ScanFormShimmer;
import 'widgets/scan_progress_card.dart' show ScanProgressCard;
import 'widgets/modern_scan_button.dart' show ModernScanButton;
import 'widgets/blur_tab_helpers.dart'
    show estimateBlurScanDuration, formatEstimatedTime;
import 'widgets/blur_sensitivity_selector.dart' show BlurSensitivitySelector;
import '../widgets/sound_toggle_button.dart' show SoundToggleButton;

// Blur Tab
class BlurTab extends StatefulWidget {
  const BlurTab();

  @override
  State<BlurTab> createState() => BlurTabState();
}

class BlurTabState extends State<BlurTab> with CubitStateMixin<BlurTab> {
  double _blurThreshold = 0.5; // Default: Medium sensitivity
  final SoundService _soundService = SoundService();
  final PreferencesService _prefsService = PreferencesService();
  bool _isSoundEnabled = true;
  int _currentTipIndex = 0;
  Timer? _tipTimer;
  StreamSubscription? _blurDetectionSubscription;
  final List<int> _tipOrder = [];
  int _tipOrderIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSoundState();

    // Stream listener'ı ekle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final blurDetectionCubit = context.read<BlurDetectionCubit>();
      _blurDetectionSubscription = blurDetectionCubit.stream.listen((next) {
        if (!mounted) return;
        final previous = blurDetectionCubit.state;
        // Scan durumu veya tamamlanma durumu değiştiğinde ses kontrolü yap
        final wasScanning = previous.isScanning;
        final isScanning = next.isScanning;
        final hasCompleted = next.hasCompletedScan && !next.isScanning;

        debugPrint('🔍 [BlurTab] Stream event - wasScanning: $wasScanning, isScanning: $isScanning, hasCompleted: $hasCompleted');

        // Scan başladıysa ses çal
        if (isScanning && !wasScanning) {
          _soundService.playScannerSound();
        }
        // Scan durduysa veya tamamlandıysa ses durdur
        if ((!isScanning && wasScanning) || hasCompleted) {
          _soundService.stopScannerSound();
        }

        // Scan tamamlandığında tip rotation'ı durdur (bildirim ve navigation SwipePage'de yapılıyor)
        if (wasScanning && !isScanning && hasCompleted) {
          debugPrint('✅ [BlurTab] Scan completed (notification and navigation will be handled by SwipePage)');
          _stopTipRotation();
        }
      });
    });
  }

  @override
  void dispose() {
      _blurDetectionSubscription?.cancel();
    _tipTimer?.cancel();
    _soundService.stopScannerSound();
    super.dispose();
  }

  Future<void> _loadSoundState() async {
    _isSoundEnabled = await _prefsService.isScanSoundEnabled();
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedAlbum = context.watch<SelectedAlbumCubit>().state;
    final albumsAsync = context.watch<AlbumsCubit>().state;
    final blurState = context.watch<BlurDetectionCubit>().state;

    final isScanning = blurState.isScanning;

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

          // Eğer tarama tamamlandıysa, sonuç olsun ya da olmasın results view göster
          // Böylece no results ekranı da gösterilebilir
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
                      // Progress bilgisi
                      ScanProgressCard(
                        title:
                            blurState.currentAlbum ?? l10n.scanningBlurPhotos,
                        processed: blurState.processedCount,
                        total: blurState.totalCount,
                        fallbackLabel: l10n.scanningBlurPhotos,
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
                                theme.colorScheme.primaryContainer.withOpacity(
                                  0.3,
                                ),
                                theme.colorScheme.secondaryContainer
                                    .withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 20,
                                color: theme.colorScheme.primary,
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
                            context.read<BlurDetectionCubit>().cancel();
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
                        // Check if there are actual photos to delete
                        final allPhotos = <BlurPhoto>[];
                        for (final entry
                            in blurState.blurryPhotosByAlbum.entries) {
                          allPhotos.addAll(entry.value);
                        }
                        final hasPhotosToDelete = allPhotos.isNotEmpty;

                        final blurScanLimitAsync = context
                            .watch<BlurScanLimitCubit>()
                            .state;
                        final isPremiumAsync = context
                            .watch<PremiumCubit>()
                            .state;

                        return blurScanLimitAsync.when(
                          loading: () => hasPhotosToDelete
                              ? _buildStartScanButton(
                                  context,
                                  theme,
                                  l10n,
                                  selectedAlbums,
                                  isPremiumAsync,
                                )
                              : const SizedBox.shrink(),
                          error: (_, __) => hasPhotosToDelete
                              ? _buildStartScanButton(
                                  context,
                                  theme,
                                  l10n,
                                  selectedAlbums,
                                  isPremiumAsync,
                                )
                              : const SizedBox.shrink(),
                          data: (limit) {
                            final canScan =
                                limit > 0 || isPremiumAsync.valueOrNull == true;
                            if (!canScan && !hasPhotosToDelete) {
                              return const SizedBox.shrink();
                            }
                            return _buildStartScanButton(
                              context,
                              theme,
                              l10n,
                              selectedAlbums,
                              isPremiumAsync,
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

  Future<void> _toggleSound() async {
    // State zaten güncellendi, SoundService'in optimize edilmiş metodunu kullan
    final currentState = _isSoundEnabled;
    await _soundService.setSoundEnabled(currentState);

    // Eğer ses açıldıysa ve scan devam ediyorsa sesi başlat
    if (currentState) {
      final blurState = context.read<BlurDetectionCubit>().state;
      if (blurState.isScanning) {
        _soundService.playScannerSound();
      }
    }
  }

  Widget _buildStartScanButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<pm.AssetPathEntity> selectedAlbums,
    AsyncValue<bool> isPremiumAsync,
  ) {
    final blurState = context.watch<BlurDetectionCubit>().state;
    final isScanning = blurState.isScanning;
    final hasResults =
        blurState.hasCompletedScan || blurState.totalBlurryPhotos > 0;

    return isPremiumAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (isPremium) {
        final blurScanLimitAsync = context.watch<BlurScanLimitCubit>().state;
        return blurScanLimitAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (scanLimit) {
            final hasNoScanRights = !isPremium && scanLimit <= 0;

            // hasResults durumunda "View Last Results" ve "Start New Scan" butonları göster
            if (hasResults) {
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Scan state'ini temizle
                        context.read<BlurDetectionCubit>().clear();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.startNewScan),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(0, 56),
                        side: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        context.push('/results/blur');
                      },
                      icon: const Icon(Icons.visibility_rounded),
                      label: Text(l10n.viewLastResults),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(0, 56),
                        backgroundColor: AppColors.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.9),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return FutureBuilder<
                ({
                  int estimatedSeconds,
                  int totalPhotoCount,
                  bool hasLimitWarning,
                })>(
              future: estimateBlurScanDuration(selectedAlbums),
              builder: (context, snapshot) {
                final estimatedTimeText = snapshot.hasData
                    ? formatEstimatedTime(snapshot.data!.estimatedSeconds, l10n)
                    : null;

                final hasLimitWarning =
                    snapshot.hasData && snapshot.data!.hasLimitWarning;
                final totalPhotoCount =
                    snapshot.hasData ? snapshot.data!.totalPhotoCount : 0;

                return ModernScanButton(
                  context: context,
                  theme: theme,
                  l10n: l10n,
                  onPressed: isScanning || hasNoScanRights
                      ? null
                      : () async {
                          // Seçili albüm isimlerini hazırla
                          final albumNames =
                              selectedAlbums.map((a) => a.name).join(', ');

                          // Onay dialogu göster
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(l10n.startScan),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.blurDetectionDescription,
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer
                                          .withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.folder_rounded,
                                          size: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            albumNames,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: theme.colorScheme.primary,
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
                                    backgroundColor: theme.colorScheme.primary,
                                  ),
                                  child: Text(l10n.scan),
                                ),
                              ],
                            ),
                          );

                          // Kullanıcı onaylamadıysa veya dialog kapatıldıysa çık
                          if (confirmed != true || !mounted) return;

                          // Scan başlat
                          await context
                              .read<BlurDetectionCubit>()
                              .scanAlbums(
                                selectedAlbums,
                                blurThreshold: _blurThreshold,
                              );

                          if (!mounted) return;
                        },
                  icon: hasNoScanRights
                      ? Icons.block
                      : Icons.search_rounded,
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
      },
    );
  }

  Widget _buildScanForm(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
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
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.blur_on_rounded,
                  size: 28,
                  color: theme.colorScheme.onPrimaryContainer,
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
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.aiPowered,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.blurPhotoDetection,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.blurDetectionDescriptionFromAppBar,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        height: 1.4,
                        color: theme.colorScheme.onPrimaryContainer.withOpacity(
                          0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Sensitivity selection
        BlurSensitivitySelector(
          currentThreshold: _blurThreshold,
          onThresholdChanged: (double threshold) {
            // Anında mod değişimi - state'i güncelle
            setState(() {
              _blurThreshold = threshold;
            });
          },
        ),
      ],
    );
  }
}


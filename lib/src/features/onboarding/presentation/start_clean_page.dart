import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../../../l10n/app_localizations.dart';

import '../../onboarding/application/permissions_controller.dart';
import '../../gallery/application/gallery_stats_provider.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/services/preferences_service.dart';

class StartCleanPage extends ConsumerStatefulWidget {
  const StartCleanPage({super.key});

  @override
  ConsumerState<StartCleanPage> createState() => _StartCleanPageState();
}

class _StartCleanPageState extends ConsumerState<StartCleanPage> {
  final SoundService _soundService = SoundService();
  bool _isScannerPlaying = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 [StartCleanPage] initState çağrıldı');
    // Sayfa açıldığında izin durumunu kontrol et ve istatistikleri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        debugPrint('🚀 [StartCleanPage] İzin durumu kontrol ediliyor...');
        // Önce izin durumunu refresh et
        await ref.read(permissionsControllerProvider.notifier).refresh();

        if (!mounted) return;

        final permission = ref.read(permissionsControllerProvider);
        debugPrint('🚀 [StartCleanPage] İzin durumu: $permission');
        if (permission == GalleryPermissionStatus.authorized) {
          // İzin varsa istatistikleri kesinlikle yükle
          // Provider'ın permission değişikliğini algılaması için kısa bir bekleme
          debugPrint(
            '🚀 [StartCleanPage] İzin verildi, istatistikler yüklenecek...',
          );
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted) {
            // Provider'ı refresh et - cache varsa önce onu gösterir, sonra günceller
            debugPrint(
              '🚀 [StartCleanPage] GalleryStats provider refresh ediliyor',
            );
            ref.read(galleryStatsProvider.notifier).refresh();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    // Sayfa kapatıldığında scanner sesini durdur
    if (_isScannerPlaying) {
      _soundService.stopScannerSound();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(permissionsControllerProvider);
    final statsState = ref.watch(galleryStatsProvider);

    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(''),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: AppLocalizations.of(context)!.settings,
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient and soft shapes
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.08),
                    theme.colorScheme.secondary.withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Builder(
                    builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx)!;
                      return Text(
                        l10n.startCleaning,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx)!;
                      return Text(
                        l10n.swipeCardsDescription,
                    style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.9,
                          ),
                    ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Builder(
                    builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx)!;
                      return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                        children: [
                          _FeatureChip(icon: Icons.swipe, label: l10n.quickSwipe),
                          _FeatureChip(
                            icon: Icons.folder_open,
                            label: l10n.dragToFolder,
                          ),
                          _FeatureChip(icon: Icons.undo, label: l10n.undoSafety),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Galeri İstatistikleri - İzin verildiyse göster
                  if (permission == GalleryPermissionStatus.authorized)
                    Builder(
                      builder: (context) {
                        final stats = statsState.stats;
                        
                        // Loading veya error durumunda
                        if (statsState.isLoading && stats == null) {
                          // Scanner sesini çal
                          if (!_isScannerPlaying) {
                            _soundService.playScannerSound();
                            _isScannerPlaying = true;
                          }
                          
                          final l10n = AppLocalizations.of(context)!;
                          return Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
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
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Error durumu
                        if (statsState.error != null && stats == null) {
                          // Scanner sesini durdur
                          if (_isScannerPlaying) {
                            _soundService.stopScannerSound();
                            _isScannerPlaying = false;
                          }
                          
                          final l10n = AppLocalizations.of(context)!;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.error.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.galleryInfoNotAvailable,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l10n.tryAgain),
                                  onPressed: () {
                                    ref.read(galleryStatsProvider.notifier).refresh();
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Stats null ise (izin var ama cache yok)
                        if (stats == null) {
                          // Scanner sesini durdur
                          if (_isScannerPlaying) {
                            _soundService.stopScannerSound();
                            _isScannerPlaying = false;
                          }
                          
                          final l10n = AppLocalizations.of(context)!;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.error.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.galleryInfoNotAvailable,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l10n.tryAgain),
                                  onPressed: () {
                                    ref.read(galleryStatsProvider.notifier).refresh();
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Stats var - göster
                        // Scanner sesini durdur
                        if (_isScannerPlaying) {
                          _soundService.stopScannerSound();
                          _isScannerPlaying = false;
                        }

                        final l10n = AppLocalizations.of(context)!;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.photo_library,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.galleryInfo,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _StatRow(
                                icon: Icons.folder,
                                label: l10n.album,
                                value: '${stats.albumCount}',
                              ),
                              const SizedBox(height: 12),
                              _StatRow(
                                icon: Icons.photo,
                                label: l10n.photoVideo,
                                value: '${stats.mediaCount}',
                              ),
                              const SizedBox(height: 12),
                              _StatRow(
                                icon: Icons.storage,
                                label: l10n.totalSize,
                                value:
                                    '${stats.totalSizeMB.toStringAsFixed(1)} MB',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const Spacer(),
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 560),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 22,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Builder(
                        builder: (ctx) {
                          final l10n = AppLocalizations.of(ctx)!;
                          return permission == GalleryPermissionStatus.authorized
                              ? Builder(
                                  builder: (context) {
                                    final stats = statsState.stats;
                                    final isLoading = statsState.isLoading && stats == null;
                                    
                                    if (isLoading) {
                                      // İstatistikler yüklenirken butonu göster ama disabled yap
                                      return FilledButton.icon(
                                        icon: const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        label: Text(l10n.loading),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 32,
                                            vertical: 16,
                                          ),
                                        ),
                                        onPressed: null,
                                      );
                                    }
                                    
                                    if (stats == null) {
                                      // Stats yok - hata durumu
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 48,
                                            color: theme.colorScheme.error,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            l10n.galleryInfoNotLoaded,
                                            style: theme.textTheme.bodyMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          FilledButton(
                                            onPressed: () {
                                              ref.read(galleryStatsProvider.notifier).refresh();
                                            },
                                            child: Text(l10n.tryAgain),
                                          ),
                                        ],
                                      );
                                    }
                                    
                                    // Stats var - başlat butonu
                                    return FilledButton.icon(
                                      icon: const Icon(Icons.play_arrow),
                                      label: Text(l10n.startCleaningButton),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                      ),
                                      onPressed: () async {
                                        if (context.mounted) {
                                          // Temizlemeye başlandığını işaretle
                                          final prefsService = PreferencesService();
                                          await prefsService.setCleaningStarted(true);
                                          
                                          if (context.mounted) {
                                            context.go('/swipe');
                                          }
                                        }
                                      },
                                    );
                                  },
                                )
                              : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                                    Icon(
                                      Icons.photo_library_outlined,
                                      size: 72,
                                      color: theme.colorScheme.primary,
                                    ),
                          const SizedBox(height: 12),
                                    Text(
                                      l10n.grantPermissionToStart,
                                      style: theme.textTheme.titleMedium,
                                      textAlign: TextAlign.center,
                                    ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.play_arrow),
                                            label: Text(l10n.start),
                                  onPressed: () async {
                                              final ok = await ref
                                                  .read(
                                                    permissionsControllerProvider
                                                        .notifier,
                                                  )
                                                  .request();
                                    if (ok && context.mounted) {
                                                // İstatistikleri yenile - provider otomatik yüklenecek
                                                ref.read(galleryStatsProvider.notifier).refresh();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                                      onPressed: () => ref
                                          .read(
                                            permissionsControllerProvider.notifier,
                                          )
                                          .openSettings(),
                                      child: Text(l10n.managePermissionsInSettings),
                          ),
                          const SizedBox(height: 4),
                          Opacity(
                            opacity: 0.7,
                            child: Text(
                                        l10n.iosDeleteNote,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                                );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

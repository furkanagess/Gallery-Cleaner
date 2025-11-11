import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../application/permissions_controller.dart';
import '../../gallery/application/gallery_stats_provider.dart';
import '../../../../l10n/app_localizations.dart';

class PermissionRequestPage extends ConsumerStatefulWidget {
  const PermissionRequestPage({super.key});

  @override
  ConsumerState<PermissionRequestPage> createState() =>
      _PermissionRequestPageState();
}

class _PermissionRequestPageState extends ConsumerState<PermissionRequestPage> {
  bool _hasRequestedPermission = false;

  @override
  void initState() {
    super.initState();
    // İzin durumunu kontrol et ve eğer izin verilmemişse otomatik olarak izin iste
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final permission = ref.read(permissionsControllerProvider);
      if (permission != GalleryPermissionStatus.authorized) {
        // Onboarding bittikten sonra 500ms sonra otomatik olarak izin iste
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_hasRequestedPermission) {
            _requestPermission();
          }
        });
      }
    });
  }

  Future<void> _requestPermission() async {
    if (_hasRequestedPermission) return;

    // İzin durumunu tekrar kontrol et
    final currentPermission = ref.read(permissionsControllerProvider);
    if (currentPermission == GalleryPermissionStatus.authorized) {
      // İzin zaten verilmişse işlem yapma
      return;
    }

    _hasRequestedPermission = true;

    // OS'un native izin dialog'unu göster
    final ok = await ref.read(permissionsControllerProvider.notifier).request();

    if (!ok && mounted) {
      // İzin reddedildiyse tekrar deneme için flag'i sıfırla
      _hasRequestedPermission = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(permissionsControllerProvider);
    final statsState = ref.watch(galleryStatsProvider);

    ref.listen<GalleryPermissionStatus>(permissionsControllerProvider, (
      prev,
      next,
    ) {
      if (next == GalleryPermissionStatus.authorized &&
          context.mounted &&
          prev != next) {
        // İzin yeni verildiyse swipe page'e yönlendir
        // Analiz başlatma işlemi _requestPermission() içinde yapılıyor (sadece ilk defa)
        Future.microtask(() {
          if (mounted) {
            // Swipe page'e yönlendir
            context.go('/swipe');
          }
        });
      }
    });

    final theme = Theme.of(context);

    // İzin verilmişse istatistikleri göster
    if (permission == GalleryPermissionStatus.authorized) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return Text(l10n.appTitle);
            },
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // Background gradient
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
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.9),
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
                            _FeatureChip(
                              icon: Icons.swipe,
                              label: l10n.quickSwipe,
                            ),
                            _FeatureChip(
                              icon: Icons.folder_open,
                              label: l10n.dragToFolder,
                            ),
                            _FeatureChip(
                              icon: Icons.undo,
                              label: l10n.undoSafety,
                            ),
                          ],
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
                          builder: (context) {
                            final stats = statsState.stats;
                            final isLoading =
                                statsState.isLoading && stats == null;
                            final hasError =
                                statsState.error != null && stats == null;

                            if (isLoading) {
                              return Center(
                                child: SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: Lottie.asset(
                                    'assets/lottie/loading.json',
                                    fit: BoxFit.contain,
                                    repeat: true,
                                  ),
                                ),
                              );
                            }

                            if (hasError) {
                              final l10n = AppLocalizations.of(context)!;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 72,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.errorMessage(
                                      statsState.error?.toString() ?? '',
                                    ),
                                    style: theme.textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: () {
                                      ref
                                          .read(galleryStatsProvider.notifier)
                                          .refresh();
                                    },
                                    child: Text(l10n.tryAgain),
                                  ),
                                ],
                              );
                            }

                            if (stats == null) {
                              return Center(
                                child: SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: Lottie.asset(
                                    'assets/lottie/loading.json',
                                    fit: BoxFit.contain,
                                    repeat: true,
                                  ),
                                ),
                              );
                            }

                            final l10n = AppLocalizations.of(context)!;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.photo_library,
                                  size: 72,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.galleryInfo,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 24),
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
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text(l10n.startCleaningButton),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: () {
                                    if (context.mounted) {
                                      context.go('/swipe');
                                    }
                                  },
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

    // İzin isteniyor
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.secondary.withOpacity(0.05),
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
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 120,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 32),
                  Builder(
                    builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx)!;
                      return Text(
                        l10n.weNeedYourAccessTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx)!;
                      return Text(
                        l10n.galleryPermissionDescription,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.8,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context)!;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PermissionFeature(
                              icon: Icons.swipe,
                              title: l10n.quickCleanupTitle,
                              description: l10n.quickCleanupDescription,
                            ),

                            const SizedBox(height: 16),
                            _PermissionFeature(
                              icon: Icons.blur_on,
                              title:
                                  '${l10n.blurPhotoDetection} - ${l10n.aiPowered}',
                              description: l10n.blurDetectionDescription,
                            ),
                            const SizedBox(height: 16),
                            _PermissionFeature(
                              icon: Icons.content_copy,
                              title:
                                  '${l10n.duplicatePhotoDetection} - ${l10n.aiPowered}',
                              description:
                                  l10n.duplicateDetectionDescriptionFromAppBar,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  Builder(
                    builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx)!;
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.lock_open),
                            label: Text(l10n.allowAccess),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _requestPermission,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx)!;
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => ref
                                .read(permissionsControllerProvider.notifier)
                                .openSettings(),
                            child: Text(l10n.openSettings),
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
      ),
    );
  }
}

class _PermissionFeature extends StatelessWidget {
  const _PermissionFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
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
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../onboarding/application/permissions_controller.dart';
import '../../gallery/application/gallery_stats_provider.dart';
import '../../../core/services/sound_service.dart';

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
            // Provider'ı invalidate ederek yeniden yükle
            debugPrint(
              '🚀 [StartCleanPage] GalleryStats provider invalidate ediliyor',
            );
            ref.invalidate(galleryStatsProvider);
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
    final statsAsync = ref.watch(galleryStatsProvider);

    // İzin durumu değiştiğinde istatistikleri yükle
    ref.listen<GalleryPermissionStatus>(permissionsControllerProvider, (
      prev,
      next,
    ) {
      debugPrint(
        '🚀 [StartCleanPage] Permission durumu değişti: $prev -> $next',
      );
      if (next == GalleryPermissionStatus.authorized &&
          context.mounted &&
          prev != next) {
        // İzin yeni verildiyse istatistikleri kesinlikle yükle
        debugPrint(
          '🚀 [StartCleanPage] İzin yeni verildi, stats yüklenecek...',
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            // Invalidate kullanarak provider'ı tamamen yeniden yükle
            debugPrint(
              '🚀 [StartCleanPage] GalleryStats provider invalidate ediliyor (permission değişikliği)',
            );
            ref.invalidate(galleryStatsProvider);
          }
        });
      }
    });

    // İzin varsa ama stats null veya loading durumundaysa refresh et
    if (permission == GalleryPermissionStatus.authorized && mounted) {
      statsAsync.when(
        data: (stats) {
          debugPrint(
            '🚀 [StartCleanPage] Stats data: ${stats != null ? "Var (${stats.albumCount} albüm, ${stats.mediaCount} medya)" : "Null"}',
          );
          // Data null ise tekrar yükle (izin var ama stats yüklenmemiş)
          if (stats == null) {
            debugPrint('🚀 [StartCleanPage] Stats null, tekrar yüklenecek...');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.invalidate(galleryStatsProvider);
              }
            });
          }
        },
        loading: () {
          debugPrint('🚀 [StartCleanPage] Stats loading durumunda...');
          // Loading durumunda - eğer çok uzun sürerse (5 saniye) tekrar dene
          // Bu durumda bir şey yapma, provider zaten yükleniyor
        },
        error: (error, stack) {
          debugPrint('🚀 [StartCleanPage] Stats error: $error');
          // Hata varsa tekrar yükle
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.invalidate(galleryStatsProvider);
            }
          });
        },
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(''),
        centerTitle: true,
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
                  Text(
                    'Galerini\ntemizlemeye başla',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kartları sağa kaydır: Tut • sola kaydır: Sil. Üst hedeflere sürükleyerek klasörlere taşı.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _FeatureChip(icon: Icons.swipe, label: 'Hızlı swipe'),
                      _FeatureChip(
                        icon: Icons.folder_open,
                        label: 'Klasöre sürükle',
                      ),
                      _FeatureChip(icon: Icons.undo, label: 'Undo güvenliği'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Galeri İstatistikleri - İzin verildiyse göster
                  if (permission == GalleryPermissionStatus.authorized)
                    statsAsync.when(
                      data: (stats) {
                        // Scanner sesini durdur
                        if (_isScannerPlaying) {
                          _soundService.stopScannerSound();
                          _isScannerPlaying = false;
                        }

                        // Stats null ise hata mesajı göster
                        if (stats == null) {
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
                                  'Galeri bilgileri alınamadı',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Tekrar Dene'),
                                  onPressed: () {
                                    ref.invalidate(galleryStatsProvider);
                                  },
                                ),
                              ],
                            ),
                          );
                        }
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
                                    'Galeri Bilgileri',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _StatRow(
                                icon: Icons.folder,
                                label: 'Albüm',
                                value: '${stats.albumCount}',
                              ),
                              const SizedBox(height: 12),
                              _StatRow(
                                icon: Icons.photo,
                                label: 'Fotoğraf & Video',
                                value: '${stats.mediaCount}',
                              ),
                              const SizedBox(height: 12),
                              _StatRow(
                                icon: Icons.storage,
                                label: 'Toplam Boyut',
                                value:
                                    '${stats.totalSizeMB.toStringAsFixed(1)} MB',
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () {
                        // Loading başladığında scanner sesini çal
                        if (!_isScannerPlaying) {
                          _soundService.playScannerSound();
                          _isScannerPlaying = true;
                        }

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
                              // Lottie animasyonu
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
                                'Galeri bilgileri yükleniyor...',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Bu işlem birkaç saniye sürebilir lütfen bekleyiniz',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                      error: (error, stack) {
                        // Hata durumunda scanner sesini durdur
                        if (_isScannerPlaying) {
                          _soundService.stopScannerSound();
                          _isScannerPlaying = false;
                        }

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
                                'Galeri bilgileri alınamadı',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tekrar Dene'),
                                onPressed: () {
                                  ref.invalidate(galleryStatsProvider);
                                },
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
                      child: permission == GalleryPermissionStatus.authorized
                          ? statsAsync.when(
                              data: (stats) {
                                if (stats == null) {
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
                                    label: const Text('Yükleniyor...'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                    ),
                                    onPressed: null,
                                  );
                                }
                                return FilledButton.icon(
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Temizlemeye Başla'),
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
                                );
                              },
                              loading: () => FilledButton.icon(
                                icon: const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                label: const Text('Yükleniyor...'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: null,
                              ),
                              error: (error, stack) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Galeri bilgileri yüklenemedi',
                                    style: theme.textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: () {
                                      ref.refresh(galleryStatsProvider);
                                    },
                                    child: const Text('Tekrar Dene'),
                                  ),
                                ],
                              ),
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
                                  'Başlamak için fotoğraf erişimine izin ver',
                                  style: theme.textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('Başla'),
                                        onPressed: () async {
                                          final ok = await ref
                                              .read(
                                                permissionsControllerProvider
                                                    .notifier,
                                              )
                                              .request();
                                          if (ok && context.mounted) {
                                            // İstatistikleri topla - provider otomatik yüklenecek
                                            ref.refresh(galleryStatsProvider);
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
                                  child: const Text('İzinleri Ayarlarda Yönet'),
                                ),
                                const SizedBox(height: 4),
                                Opacity(
                                  opacity: 0.7,
                                  child: Text(
                                    "iOS'ta silmeler \"Recently Deleted\"e taşınır ve 30 gün içinde geri alınabilir.",
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
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

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../application/permissions_controller.dart';
import '../../gallery/application/gallery_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app/theme/app_colors.dart';

class PermissionRequestPage extends StatefulWidget {
  const PermissionRequestPage({super.key});

  @override
  State<PermissionRequestPage> createState() => _PermissionRequestPageState();
}

class _PermissionRequestPageState extends State<PermissionRequestPage> {
  bool _hasRequestedPermission = false;
  StreamSubscription<GalleryPermissionStatus>? _permissionSubscription;
  GalleryPermissionStatus? _lastPermission;

  @override
  void initState() {
    super.initState();
    // İzin durumunu kontrol et ve eğer izin verilmemişse otomatik olarak izin iste
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final permission = context.read<PermissionsCubit>().state;
      _lastPermission = permission;
      if (permission != GalleryPermissionStatus.authorized) {
        // Onboarding bittikten sonra 500ms sonra otomatik olarak izin iste
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_hasRequestedPermission) {
            _requestPermission();
          }
        });
      }
    });
    _permissionSubscription =
        context.read<PermissionsCubit>().stream.listen((next) {
      final previous = _lastPermission;
      _lastPermission = next;
      if (next == GalleryPermissionStatus.authorized &&
          context.mounted &&
          previous != next) {
        _waitForPhotosAndNavigate(context);
      }
    });
  }

  @override
  void dispose() {
    _permissionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    if (_hasRequestedPermission) return;

    // İzin durumunu tekrar kontrol et
    final currentPermission = context.read<PermissionsCubit>().state;
    if (currentPermission == GalleryPermissionStatus.authorized) {
      // İzin zaten verilmişse işlem yapma
      return;
    }

    _hasRequestedPermission = true;

    // OS'un native izin dialog'unu göster
    final ok = await context.read<PermissionsCubit>().request();

    if (!ok && mounted) {
      // İzin reddedildiyse tekrar deneme için flag'i sıfırla
      _hasRequestedPermission = false;
    }
  }

  /// İzin verildikten sonra fotoğrafların yüklendiğinden emin ol ve swipe page'e geçiş yap
  Future<void> _waitForPhotosAndNavigate(BuildContext context) async {
    debugPrint('🔄 [PermissionRequestPage] İzin verildi, fotoğrafların yüklenmesi bekleniyor...');

    // İlk gecikme - PhotoManager'ın hazır olması için
    final initialDelay = Platform.isIOS 
        ? const Duration(milliseconds: 800) 
        : const Duration(milliseconds: 300);
    await Future.delayed(initialDelay);

    if (!mounted || !context.mounted) return;

    // Album listesinin yüklendiğini bekle (maksimum 5 saniye, her 300ms'de bir kontrol)
    bool albumsReady = false;
    for (int attempt = 0; attempt < 17; attempt++) {
      if (!mounted || !context.mounted) return;

      final albumsAsync = context.read<AlbumsCubit>().state;
      final albums = albumsAsync.maybeWhen(
        data: (albums) => albums,
        orElse: () => <dynamic>[],
      );

      if (albums.isNotEmpty) {
        debugPrint('✅ [PermissionRequestPage] Album listesi yüklendi: ${albums.length} album');
        albumsReady = true;
        break;
      }

      // Hala yükleniyorsa veya boşsa bekle
      if (albumsAsync.isLoading) {
        debugPrint('⏳ [PermissionRequestPage] Album listesi yükleniyor... (attempt ${attempt + 1})');
      } else {
        debugPrint('⚠️ [PermissionRequestPage] Album listesi boş, yeniden deniyor... (attempt ${attempt + 1})');
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!albumsReady) {
      debugPrint('⚠️ [PermissionRequestPage] Album listesi yüklenemedi, yine de swipe page\'e geçiliyor...');
      // Yine de swipe page'e geç (kullanıcı deneyimi için)
      if (mounted && context.mounted) {
        context.go('/swipe');
      }
      return;
    }

    // Asset'lerin yüklendiğini bekle (maksimum 5 saniye, her 300ms'de bir kontrol)
    bool assetsReady = false;
    for (int attempt = 0; attempt < 17; attempt++) {
      if (!mounted || !context.mounted) return;

      final assetsAsync = context.read<GalleryPagingCubit>().state;
      final assets = assetsAsync.maybeWhen(
        data: (assets) => assets,
        orElse: () => <dynamic>[],
      );

      if (assets.isNotEmpty) {
        debugPrint('✅ [PermissionRequestPage] Fotoğraflar yüklendi: ${assets.length} fotoğraf');
        assetsReady = true;
        break;
      }

      // Hala yükleniyorsa bekle
      if (assetsAsync.isLoading) {
        debugPrint('⏳ [PermissionRequestPage] Fotoğraflar yükleniyor... (attempt ${attempt + 1})');
      } else if (assetsAsync.hasError) {
        debugPrint('⚠️ [PermissionRequestPage] Fotoğraf yükleme hatası, yeniden deniyor... (attempt ${attempt + 1})');
        // Hata varsa reload'u tetikle
        context.read<GalleryPagingCubit>().reload();
      } else {
        debugPrint('⚠️ [PermissionRequestPage] Fotoğraflar boş, yeniden deniyor... (attempt ${attempt + 1})');
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!assetsReady) {
      debugPrint('⚠️ [PermissionRequestPage] Fotoğraflar yüklenemedi, yine de swipe page\'e geçiliyor...');
      // Yine de swipe page'e geç (kullanıcı deneyimi için)
      if (mounted && context.mounted) {
        context.go('/swipe');
      }
      return;
    }

    // Her şey hazır, swipe page'e geç
    debugPrint('✅ [PermissionRequestPage] Fotoğraflar hazır, swipe page\'e geçiliyor...');
    if (mounted && context.mounted) {
      context.go('/swipe');
    }
  }

  @override
  Widget build(BuildContext context) {
    final permission = context.watch<PermissionsCubit>().state;

    final theme = Theme.of(context);

    // İzin verilmişse loading ekranını göster
    if (permission == GalleryPermissionStatus.authorized) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Lottie.asset(
                      'assets/lottie/gallery_loading.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    l10n.loadingYourGallery,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      l10n.loadingYourGalleryDescription,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    // İzin isteniyor
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Stack(
        children: [
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
                  // Privacy and Security Info
                  Builder(
                    builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx)!;
                      return Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.security,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.privacySecurityInfo,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface.withOpacity(0.9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _PrivacyBulletPoint(
                              text: l10n.privacySecurityPoint1,
                              theme: theme,
                            ),
                            const SizedBox(height: 8),
                            _PrivacyBulletPoint(
                              text: l10n.privacySecurityPoint2,
                              theme: theme,
                            ),
                            const SizedBox(height: 8),
                            _PrivacyBulletPoint(
                              text: l10n.privacySecurityPoint3,
                              theme: theme,
                            ),
                          ],
                        ),
                      );
                    },
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
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
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
                            onPressed: () => context
                                .read<PermissionsCubit>()
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

class _PrivacyBulletPoint extends StatelessWidget {
  const _PrivacyBulletPoint({
    required this.text,
    required this.theme,
  });

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}


import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/services/preferences_service.dart';
import '../application/permissions_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../gallery/application/gallery_providers.dart'
    show PremiumCubit, AlbumsCubit, GalleryPagingCubit;

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _isAnimationCompleted = false;

  void _onAnimationComplete() {
    if (!mounted || _isAnimationCompleted) return;
    _isAnimationCompleted = true;
    debugPrint(
      '✅ [SplashPage] Lottie animasyonu tamamlandı, yönlendirme yapılıyor...',
    );
    _navigateToNext();
  }

  /// İzin verildikten sonra fotoğrafların yüklendiğinden emin ol ve swipe page'e geçiş yap
  Future<void> _waitForPhotosAndNavigate() async {
    debugPrint(
      '🔄 [SplashPage] İzin verilmiş, fotoğrafların yüklenmesi bekleniyor...',
    );

    // İlk gecikme - PhotoManager'ın hazır olması için
    final initialDelay = Platform.isIOS
        ? const Duration(milliseconds: 800)
        : const Duration(milliseconds: 300);
    await Future.delayed(initialDelay);

    if (!mounted) return;

    // AlbumsCubit'i refresh et
    context.read<AlbumsCubit>().refresh();

    // Album listesinin yüklendiğini bekle (maksimum 5 saniye, her 300ms'de bir kontrol)
    bool albumsReady = false;
    for (int attempt = 0; attempt < 17; attempt++) {
      if (!mounted) return;

      final albumsAsync = context.read<AlbumsCubit>().state;
      final albums = albumsAsync.maybeWhen(
        data: (albums) => albums,
        orElse: () => <dynamic>[],
      );

      if (albums.isNotEmpty) {
        debugPrint(
          '✅ [SplashPage] Album listesi yüklendi: ${albums.length} album',
        );
        albumsReady = true;
        break;
      }

      // Hala yükleniyorsa veya boşsa bekle
      if (albumsAsync.isLoading) {
        debugPrint(
          '⏳ [SplashPage] Album listesi yükleniyor... (attempt ${attempt + 1})',
        );
      } else {
        debugPrint(
          '⚠️ [SplashPage] Album listesi boş, yeniden deniyor... (attempt ${attempt + 1})',
        );
        // Eğer loading değilse ve boşsa, refresh yap
        context.read<AlbumsCubit>().refresh();
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!albumsReady) {
      debugPrint(
        '⚠️ [SplashPage] Album listesi yüklenemedi, yine de swipe page\'e geçiliyor...',
      );
      // Yine de swipe page'e geç (kullanıcı deneyimi için)
      if (mounted) {
        context.go('/swipe');
      }
      return;
    }

    // Asset'lerin yüklendiğini bekle (maksimum 5 saniye, her 300ms'de bir kontrol)
    bool assetsReady = false;
    for (int attempt = 0; attempt < 17; attempt++) {
      if (!mounted) return;

      final assetsAsync = context.read<GalleryPagingCubit>().state;
      final assets = assetsAsync.maybeWhen(
        data: (assets) => assets,
        orElse: () => <dynamic>[],
      );

      if (assets.isNotEmpty) {
        debugPrint(
          '✅ [SplashPage] Fotoğraflar yüklendi: ${assets.length} fotoğraf',
        );
        assetsReady = true;
        break;
      }

      // Hala yükleniyorsa bekle
      if (assetsAsync.isLoading) {
        debugPrint(
          '⏳ [SplashPage] Fotoğraflar yükleniyor... (attempt ${attempt + 1})',
        );
      } else if (assetsAsync.hasError) {
        debugPrint(
          '⚠️ [SplashPage] Fotoğraf yükleme hatası, yeniden deniyor... (attempt ${attempt + 1})',
        );
        // Hata varsa reload'u tetikle
        context.read<GalleryPagingCubit>().reload();
      } else {
        debugPrint(
          '⚠️ [SplashPage] Fotoğraflar boş, yeniden deniyor... (attempt ${attempt + 1})',
        );
        // Eğer loading değilse ve boşsa, reload yap
        context.read<GalleryPagingCubit>().reload();
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!assetsReady) {
      debugPrint(
        '⚠️ [SplashPage] Fotoğraflar yüklenemedi, yine de swipe page\'e geçiliyor...',
      );
      // Yine de swipe page'e geç (kullanıcı deneyimi için)
      if (mounted) {
        context.go('/swipe');
      }
      return;
    }

    // Her şey hazır, swipe page'e geç
    debugPrint('✅ [SplashPage] Fotoğraflar hazır, swipe page\'e geçiliyor...');
    if (mounted) {
      context.go('/swipe');
    }
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;

    // Onboarding durumunu kontrol et
    final preferencesService = context.read<PreferencesService>();
    final onboardingCompleted = await preferencesService
        .isOnboardingCompleted();

    if (!mounted) return;

    if (!onboardingCompleted) {
      // Onboarding tamamlanmamışsa onboarding'e git
      context.go('/onboarding');
      return;
    }

    // Onboarding tamamlanmışsa izin durumunu kontrol et
    final permissionController = context.read<PermissionsCubit>();
    await permissionController.refresh();

    if (!mounted) return;

    final permissionStatus = permissionController.state;

    if (permissionStatus == GalleryPermissionStatus.authorized) {
      // İzin verilmişse galeri yüklendiğinden emin ol ve swipe page'e geç
      debugPrint(
        '🚀 [SplashPage] İzin verilmiş, galeri yüklendiğinden emin olunuyor...',
      );

      if (!mounted) return;

      await _waitForPhotosAndNavigate();
    } else {
      // İzin verilmemişse permission page'e git
      context.go('/permission');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final textPrimaryColor = AppColors.textPrimary(brightness);
    final textSecondaryColor = AppColors.textSecondary(brightness);
    final lottieTintColor = textPrimaryColor;
    final titleGradientColors = brightness == Brightness.dark
        ? [textPrimaryColor, textPrimaryColor.withOpacity(0.85)]
        : [textPrimaryColor, textPrimaryColor.withOpacity(0.7)];

    return Builder(
      builder: (builderContext) {
        final isPremiumAsync = builderContext.watch<PremiumCubit>().state;
        final isPremium = isPremiumAsync.maybeWhen(
          data: (premium) => premium,
          orElse: () => false,
        );
        final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(
          0.8,
        );
        final glowShadowColor = brightness == Brightness.dark
            ? AppColors.accent
            : containerColor;

        return Scaffold(
          backgroundColor: theme.colorScheme.background,
          body: Container(
            child: Stack(
              children: [
                // Decorative background elements
                Positioned(
                  top: -100,
                  right: -80,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accent.withOpacity(0.15),
                          AppColors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -120,
                  left: -100,
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.secondary.withOpacity(0.12),
                          AppColors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Main content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Lottie animasyonu with modern styling
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: containerColor.withOpacity(0.25),
                              blurRadius: 40,
                              spreadRadius: 8,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.15),
                              blurRadius: 60,
                              spreadRadius: 4,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            lottieTintColor,
                            BlendMode.srcATop,
                          ),
                          child: Lottie.asset(
                            'assets/lottie/loading.json',
                            fit: BoxFit.contain,
                            repeat: false,
                            onLoaded: (composition) {
                              final fullDuration = composition.duration;
                              final quarterDuration = Duration(
                                milliseconds: fullDuration.inMilliseconds ~/ 4,
                              );
                              debugPrint(
                                '⏱️ [SplashPage] Lottie animasyonu yüklendi, tam süre: $fullDuration, çeyrek süre: $quarterDuration',
                              );

                              Future.delayed(quarterDuration, () {
                                if (mounted && !_isAnimationCompleted) {
                                  _onAnimationComplete();
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      // App ismi with modern gradient text
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: titleGradientColors,
                        ).createShader(bounds),
                        child: Text(
                          'Gallery Cleaner',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 32,
                            letterSpacing: -0.5,
                            color: textPrimaryColor,
                            shadows: [
                              Shadow(
                                color: glowShadowColor.withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                              Shadow(
                                color: glowShadowColor.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Subtitle
                      Text(
                        'Clean & organize gallery with AI.\nRemove duplicates and blurry shots easily.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          letterSpacing: 0.3,
                          height: 1.4,
                          color: textSecondaryColor.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

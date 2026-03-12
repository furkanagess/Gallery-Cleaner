import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/services/preferences_service.dart';
import '../application/permissions_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../gallery/application/gallery_providers.dart'
    show AlbumsCubit, GalleryPagingCubit;

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

  /// İzin verildikten sonra fotoğrafların yüklendiğinden emin ol ve swipe page'e geçiş yap.
  /// Crash-free: context sadece başta kullanılır, döngülerde cubit referansları kullanılır; hata durumunda /swipe'a gidilir.
  Future<void> _waitForPhotosAndNavigate() async {
    try {
      debugPrint(
        '🔄 [SplashPage] İzin verilmiş, fotoğrafların yüklenmesi bekleniyor...',
      );

      final initialDelay = Platform.isIOS
          ? const Duration(milliseconds: 800)
          : const Duration(milliseconds: 300);
      await Future.delayed(initialDelay);

      if (!mounted) return;

      final albumsCubit = context.read<AlbumsCubit>();
      final galleryCubit = context.read<GalleryPagingCubit>();
      try {
        albumsCubit.refresh();
      } catch (e, st) {
        debugPrint('⚠️ [SplashPage] AlbumsCubit.refresh error: $e');
        debugPrint('$st');
      }

      bool albumsReady = false;
      for (int attempt = 0; attempt < 17; attempt++) {
        if (!mounted) return;

        final albumsAsync = albumsCubit.state;
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

        if (albumsAsync.isLoading) {
          debugPrint(
            '⏳ [SplashPage] Album listesi yükleniyor... (attempt ${attempt + 1})',
          );
        } else {
          debugPrint(
            '⚠️ [SplashPage] Album listesi boş, yeniden deniyor... (attempt ${attempt + 1})',
          );
          try {
            albumsCubit.refresh();
          } catch (e, st) {
            debugPrint('⚠️ [SplashPage] AlbumsCubit.refresh error: $e');
            debugPrint('$st');
          }
        }

        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
      }

      if (!albumsReady) {
        debugPrint(
          '⚠️ [SplashPage] Album listesi yüklenemedi, yine de swipe page\'e geçiliyor...',
        );
        if (mounted) context.go('/swipe');
        return;
      }

      bool assetsReady = false;
      for (int attempt = 0; attempt < 17; attempt++) {
        if (!mounted) return;

        final assetsAsync = galleryCubit.state;
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

        if (assetsAsync.isLoading) {
          debugPrint(
            '⏳ [SplashPage] Fotoğraflar yükleniyor... (attempt ${attempt + 1})',
          );
        } else if (assetsAsync.hasError) {
          debugPrint(
            '⚠️ [SplashPage] Fotoğraf yükleme hatası, yeniden deniyor... (attempt ${attempt + 1})',
          );
          try {
            galleryCubit.reload();
          } catch (e, st) {
            debugPrint('⚠️ [SplashPage] GalleryPagingCubit.reload error: $e');
            debugPrint('$st');
          }
        } else {
          debugPrint(
            '⚠️ [SplashPage] Fotoğraflar boş, yeniden deniyor... (attempt ${attempt + 1})',
          );
          try {
            galleryCubit.reload();
          } catch (e, st) {
            debugPrint('⚠️ [SplashPage] GalleryPagingCubit.reload error: $e');
            debugPrint('$st');
          }
        }

        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
      }

      if (!assetsReady) {
        debugPrint(
          '⚠️ [SplashPage] Fotoğraflar yüklenemedi, yine de swipe page\'e geçiliyor...',
        );
      } else {
        debugPrint(
          '✅ [SplashPage] Fotoğraflar hazır, swipe page\'e geçiliyor...',
        );
      }
      if (mounted) context.go('/swipe');
    } catch (e, st) {
      debugPrint('⚠️ [SplashPage] _waitForPhotosAndNavigate error: $e');
      debugPrint('$st');
      if (mounted) context.go('/swipe');
    }
  }

  Future<void> _navigateToNext() async {
    try {
      if (!mounted) return;

      final preferencesService = context.read<PreferencesService>();
      final onboardingCompleted = await preferencesService
          .isOnboardingCompleted();

      if (!mounted) return;

      if (!onboardingCompleted) {
        context.go('/onboarding');
        return;
      }

      final permissionController = context.read<PermissionsCubit>();
      await permissionController.refresh();

      if (!mounted) return;

      final permissionStatus = permissionController.state;

      if (permissionStatus == GalleryPermissionStatus.authorized) {
        debugPrint(
          '🚀 [SplashPage] İzin verilmiş, galeri yüklendiğinden emin olunuyor...',
        );
        if (!mounted) return;
        await _waitForPhotosAndNavigate();
      } else {
        context.go('/permission');
      }
    } catch (e, st) {
      debugPrint('⚠️ [SplashPage] _navigateToNext error: $e');
      debugPrint('$st');
      if (mounted) context.go('/swipe');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimaryColor = AppColors.textPrimaryDark;
    final textSecondaryColor = AppColors.textSecondaryDark;
    final lottieTintColor = textPrimaryColor;
    final titleGradientColors = [
      textPrimaryColor,
      textPrimaryColor.withValues(alpha: 0.85),
    ];

    return Builder(
      builder: (builderContext) {
        final containerColor = AppColors.accent.withValues(alpha: 0.8);
        final glowShadowColor = AppColors.accent;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Stack(
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
                        AppColors.accent.withValues(alpha: 0.15),
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
                        AppColors.secondary.withValues(alpha: 0.12),
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
                    // Gallery Lottie animasyonu with modern styling (sabit)
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: containerColor.withValues(alpha: 0.25),
                            blurRadius: 40,
                            spreadRadius: 8,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.15),
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
                              color: glowShadowColor.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                            Shadow(
                              color: glowShadowColor.withValues(alpha: 0.35),
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
                        color: textSecondaryColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

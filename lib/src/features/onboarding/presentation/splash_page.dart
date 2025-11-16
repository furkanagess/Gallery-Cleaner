import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/services/preferences_service.dart';
import '../application/permissions_controller.dart';
import '../../../app/theme/app_colors.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _isAnimationCompleted = false;

  void _onAnimationComplete() {
    if (!mounted || _isAnimationCompleted) return;
    _isAnimationCompleted = true;
    debugPrint('✅ [SplashPage] Lottie animasyonu tamamlandı, yönlendirme yapılıyor...');
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;
    
    // Onboarding durumunu kontrol et
    final preferencesService = PreferencesService();
    final onboardingCompleted = await preferencesService.isOnboardingCompleted();
    
    if (!mounted) return;
    
    if (!onboardingCompleted) {
      // Onboarding tamamlanmamışsa onboarding'e git
      context.go('/onboarding');
      return;
    }
    
    // Onboarding tamamlanmışsa izin durumunu kontrol et
    final permissionController = ref.read(permissionsControllerProvider.notifier);
    await permissionController.refresh();
    
    if (!mounted) return;
    
    final permissionStatus = ref.read(permissionsControllerProvider);
    
    if (permissionStatus == GalleryPermissionStatus.authorized) {
      // İzin verilmişse swipe page'e git
      // iOS'ta provider'ların hazır olması için kısa bir gecikme ekle
      debugPrint('🚀 [SplashPage] İzin verilmiş, swipe page\'e yönlendiriliyor (with delay)');
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) return;
      
      context.go('/swipe');
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
    final glowShadowColor =
        brightness == Brightness.dark ? AppColors.accent : AppColors.primary;
    final lottieTintColor = textPrimaryColor;
    final titleGradientColors = brightness == Brightness.dark
        ? [
            textPrimaryColor,
            textPrimaryColor.withOpacity(0.85),
          ]
        : [
            textPrimaryColor,
            textPrimaryColor.withOpacity(0.7),
          ];
    
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
                          color: AppColors.primary.withOpacity(0.25),
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
                    debugPrint('⏱️ [SplashPage] Lottie animasyonu yüklendi, tam süre: $fullDuration, çeyrek süre: $quarterDuration');
                    
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
  }
}


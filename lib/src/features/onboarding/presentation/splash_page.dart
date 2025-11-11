import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/services/preferences_service.dart';
import '../application/permissions_controller.dart';

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
      // İzin verilmişse direkt swipe page'e git
      debugPrint('🚀 [SplashPage] İzin verilmiş, swipe page\'e yönlendiriliyor');
      context.go('/swipe');
    } else {
      // İzin verilmemişse permission page'e git
      context.go('/permission');
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Container(
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie animasyonu - bir kere çal ve bitince navigate et
              SizedBox(
                width: 200,
                height: 200,
                child: Lottie.asset(
                  'assets/lottie/loading.json',
                  fit: BoxFit.contain,
                  repeat: false, // Bir kere çal, tekrarlama
                  onLoaded: (composition) {
                    // Animasyon yüklendiğinde süreyi al ve çeyreğini bekle
                    final fullDuration = composition.duration;
                    final quarterDuration = Duration(
                      milliseconds: fullDuration.inMilliseconds ~/ 4,
                    );
                    debugPrint('⏱️ [SplashPage] Lottie animasyonu yüklendi, tam süre: $fullDuration, çeyrek süre: $quarterDuration');
                    
                    // Animasyonun çeyreği tamamlanınca navigate et
                    Future.delayed(quarterDuration, () {
                      if (mounted && !_isAnimationCompleted) {
                        _onAnimationComplete();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 32),
              // App ismi
              Text(
                'Gallery Cleaner',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


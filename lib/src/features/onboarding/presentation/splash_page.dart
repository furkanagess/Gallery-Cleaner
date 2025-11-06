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
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Minimum splash gösterim süresi (animasyonun tamamlanması için)
    await Future.delayed(const Duration(seconds: 3));
    
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
      // İzin verilmişse temizlemeye başlanıp başlanmadığını kontrol et
      final cleaningStarted = await preferencesService.isCleaningStarted();
      
      if (!mounted) return;
      
      if (cleaningStarted) {
        // Temizlemeye başlanmışsa direkt swipe page'e git
        debugPrint('🚀 [SplashPage] Temizlemeye başlanmış, swipe page\'e yönlendiriliyor');
        context.go('/swipe');
      } else {
        // Temizlemeye başlanmamışsa start clean page'e git
        debugPrint('🚀 [SplashPage] Temizlemeye başlanmamış, start clean page\'e yönlendiriliyor');
        context.go('/start');
      }
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
              // Lottie animasyonu
              SizedBox(
                width: 200,
                height: 200,
                child: Lottie.asset(
                  'assets/lottie/loading.json',
                  fit: BoxFit.contain,
                  repeat: true,
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


import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/presentation/splash_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/onboarding/presentation/permission_request_page.dart';
import '../features/gallery/presentation/pages/swipe_page.dart';
import '../features/gallery/presentation/pages/gallery_stats_page.dart';
import '../features/gallery/presentation/pages/gallery_report_page.dart';
import '../features/gallery/presentation/pages/results_page.dart';
import '../features/gallery/presentation/pages/review_delete_photos_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/paywall_page.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final location = state.uri.path;

      // Splash ve onboarding sayfalarında redirect yapma
      // Splash page kendi içinde animasyon bitince route edecek
      if (location == '/splash' ||
          location == '/onboarding' ||
          location == '/permission' ||
          location == '/swipe' ||
          location == '/gallery-report' ||
          location == '/review-delete-photos' ||
          location.startsWith('/settings') ||
          location.startsWith('/duplicates') ||
          location.startsWith('/blur') ||
          location.startsWith('/gallery') ||
          location.startsWith('/history') ||
          location.startsWith('/results')) {
        return null; // Bu sayfalarda redirect yapma
      }

      // Root path'ten geliyorsak splash page'e yönlendir
      if (location == '/') {
        return '/splash';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'root',
        redirect: (context, state) {
          // Bu route'a asla gelinmemeli, redirect'te splash'e yönlendirilecek
          // Ama yine de bir fallback ekleyelim
          return '/splash';
        },
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => SplashPage(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/permission',
        name: 'permission',
        builder: (context, state) => const PermissionRequestPage(),
      ),
      GoRoute(
        path: '/swipe',
        name: 'swipe',
        builder: (BuildContext context, GoRouterState state) {
          return const SwipePage() as Widget;
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/paywall',
        name: 'paywall',
        builder: (BuildContext context, GoRouterState state) {
          return const PaywallPage() as Widget;
        },
      ),
      GoRoute(
        path: '/gallery/stats',
        name: 'galleryStats',
        builder: (context, state) => const GalleryStatsPage(),
      ),
      GoRoute(
        path: '/gallery-report',
        name: 'galleryReport',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const GalleryReportPage(),
            transitionDuration: const Duration(milliseconds: 500),
            reverseTransitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              final slideTween =
                  Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                      .chain(CurveTween(curve: Curves.easeOut));
              final fadeTween =
                  Tween<double>(begin: 0.0, end: 1.0).chain(
                CurveTween(curve: Curves.easeOut),
              );

              return FadeTransition(
                opacity: curved.drive(fadeTween),
                child: SlideTransition(
                  position: curved.drive(slideTween),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.985, end: 1.0)
                        .animate(curved),
                    child: child,
                  ),
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/results/:type',
        name: 'results',
        builder: (BuildContext context, GoRouterState state) {
          final type = state.pathParameters['type'] ?? 'blur';
          return ResultsPage(resultType: type) as Widget;
        },
      ),
      // Fallback route for /results without type parameter
      GoRoute(path: '/results', redirect: (context, state) => '/results/blur'),
      GoRoute(
        path: '/review-delete-photos',
        name: 'reviewDeletePhotos',
        builder: (context, state) => const ReviewDeletePhotosPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Navigation error: ${state.error}',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

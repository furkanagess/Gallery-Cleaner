import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/presentation/splash_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/onboarding/presentation/permission_request_page.dart';
import '../features/gallery/presentation/pages/swipe_page.dart';
import '../features/gallery/presentation/pages/gallery_stats_page.dart';
import '../features/gallery/presentation/pages/results_page.dart';
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
        path: '/results/:type',
        name: 'results',
        builder: (BuildContext context, GoRouterState state) {
          final type = state.pathParameters['type'] ?? 'blur';
          return ResultsPage(resultType: type) as Widget;
        },
      ),
      // Fallback route for /results without type parameter
      GoRoute(path: '/results', redirect: (context, state) => '/results/blur'),
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

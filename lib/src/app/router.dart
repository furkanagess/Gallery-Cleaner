import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/presentation/splash_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/onboarding/presentation/permission_request_page.dart';
import '../features/onboarding/presentation/start_clean_page.dart';
import '../features/gallery/presentation/pages/swipe_page.dart';
import '../features/gallery/presentation/pages/history_page.dart';
import '../features/settings/presentation/settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
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
        path: '/start',
        name: 'start',
        builder: (context, state) => const StartCleanPage(),
      ),
      GoRoute(
        path: '/swipe',
        name: 'swipe',
        builder: (context, state) => const SwipePage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/history/full',
        name: 'fullHistory',
        builder: (context, state) => const FullHistoryPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Navigation error: ${state.error}', textAlign: TextAlign.center),
      ),
    ),
  );
});


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/presentation/splash_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/onboarding/presentation/permission_request_page.dart';
import '../features/onboarding/presentation/start_clean_page.dart';
import '../features/gallery/presentation/pages/swipe_page.dart';

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
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Navigation error: ${state.error}', textAlign: TextAlign.center),
      ),
    ),
  );
});


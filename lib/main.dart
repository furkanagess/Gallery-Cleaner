import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'firebase_options.dart';
import 'src/app/app.dart';
import 'src/core/services/ads_initializer.dart';
import 'src/core/services/apple_search_ads_service.dart';
import 'src/core/services/revenuecat_service.dart';
import 'src/core/utils/app_logger.dart';
import 'src/core/services/preferences_service.dart';
import 'src/core/services/media_library_service.dart';
import 'src/core/services/blur_detection_service.dart';
import 'src/core/services/duplicate_detection_service.dart';
import 'src/core/services/fcm_service.dart';
import 'src/features/onboarding/application/onboarding_controller.dart';
import 'src/features/onboarding/application/permissions_controller.dart';
import 'src/features/settings/application/theme_controller.dart';
import 'src/features/settings/application/locale_controller.dart';
import 'src/features/gallery/application/gallery_providers.dart';
import 'src/features/gallery/application/folder_targets_provider.dart';
import 'src/features/gallery/application/review_history_controller.dart';
import 'src/features/gallery/application/review_actions_controller.dart';
import 'src/features/gallery/application/blur_detection_provider.dart';
import 'src/features/gallery/application/duplicate_detection_provider.dart';
import 'src/features/gallery/application/gallery_stats_provider.dart';

/// Background message handler
/// Bu fonksiyon top-level olmalı (class dışında)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.i('📱 [FCMService] Background message received');
  AppLogger.i('📱 [FCMService] Message data: ${message.data}');
  AppLogger.i(
    '📱 [FCMService] Message notification: ${message.notification?.title}',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
    AppLogger.i('✅ [main] .env file loaded');
  } catch (e) {
    AppLogger.w('⚠️ [main] Failed to load .env file: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    AppLogger.i('✅ [main] Firebase initialized');

    // Initialize Firebase Cloud Messaging
    try {
      // Background message handler'ı register et
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // FCM servisini initialize et
      await FCMService.instance.initialize();
      AppLogger.i('✅ [main] FCM initialized');

      // FCM token'ı al ve logla (test için)
      final fcmToken = await FCMService.instance.getToken();
      if (fcmToken != null) {
        AppLogger.i('📱 [main] FCM Token: $fcmToken');
      }
    } catch (e) {
      AppLogger.e('⚠️ [main] Failed to initialize FCM: $e');
    }
  } catch (e) {
    AppLogger.e('⚠️ [main] Failed to initialize Firebase: $e');
  }

  await AdsInitializer.instance.initializeOnLaunch();

  final preferencesService = PreferencesService();
  final mediaLibraryService = MediaLibraryService();
  final blurDetectionService = BlurDetectionService();
  final duplicateDetectionService = DuplicateDetectionService();
  final onboardingController = OnboardingController(preferencesService);

  // Initialize RevenueCat
  try {
    await RevenueCatService.instance.initialize();

    // Initialize Apple Search Ads attribution (iOS only)
    // This should be called after RevenueCat is initialized
    try {
      await AppleSearchAdsService.instance.initialize();
    } catch (e) {
      AppLogger.w('⚠️ [main] Failed to initialize Apple Search Ads: $e');
      // Continue app startup even if attribution fails
    }
  } catch (e) {
    AppLogger.e('⚠️ [main] Failed to initialize RevenueCat: $e');
    // Continue app startup even if purchases fail to initialize
  }

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: preferencesService),
        RepositoryProvider.value(value: mediaLibraryService),
        RepositoryProvider.value(value: blurDetectionService),
        RepositoryProvider.value(value: duplicateDetectionService),
        RepositoryProvider.value(value: onboardingController),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => PermissionsCubit()),
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(create: (_) => LocaleCubit()),
          BlocProvider(
            create: (context) => SelectedAlbumCubit(
              preferencesService: context.read<PreferencesService>(),
            ),
          ),
          BlocProvider(
            create: (context) => AlbumsCubit(
              mediaLibraryService: context.read<MediaLibraryService>(),
              permissionsCubit: context.read<PermissionsCubit>(),
              selectedAlbumCubit: context.read<SelectedAlbumCubit>(),
              preferencesService: context.read<PreferencesService>(),
            ),
          ),
          BlocProvider(create: (_) => AlbumFilterCubit()),
          BlocProvider(create: (_) => AlbumSortOrderCubit()),
          BlocProvider(
            create: (context) => GalleryPagingCubit(
              mediaLibraryService: context.read<MediaLibraryService>(),
              selectedAlbumCubit: context.read<SelectedAlbumCubit>(),
              permissionsCubit: context.read<PermissionsCubit>(),
              albumFilterCubit: context.read<AlbumFilterCubit>(),
              albumSortOrderCubit: context.read<AlbumSortOrderCubit>(),
            ),
          ),
          BlocProvider(
            create: (context) =>
                DeleteLimitCubit(context.read<PreferencesService>()),
          ),
          BlocProvider(
            create: (context) =>
                PremiumCubit(context.read<PreferencesService>()),
          ),
          BlocProvider(
            create: (context) =>
                GeneralScanLimitCubit(context.read<PreferencesService>()),
          ),
          BlocProvider(
            create: (context) =>
                BlurScanLimitCubit(context.read<PreferencesService>()),
          ),
          BlocProvider(
            create: (context) =>
                DuplicateScanLimitCubit(context.read<PreferencesService>()),
          ),
          BlocProvider(
            create: (context) =>
                FolderTargetsCubit(albumsCubit: context.read<AlbumsCubit>()),
          ),
          BlocProvider(create: (_) => ReviewHistoryCubit()),
          BlocProvider(
            create: (context) => ReviewActionsCubit(
              mediaLibraryService: context.read<MediaLibraryService>(),
              reviewHistoryCubit: context.read<ReviewHistoryCubit>(),
            ),
          ),
          BlocProvider(
            create: (context) => GalleryStatsCubit(
              mediaLibraryService: context.read<MediaLibraryService>(),
              preferencesService: context.read<PreferencesService>(),
              permissionsCubit: context.read<PermissionsCubit>(),
            ),
          ),
          BlocProvider(
            create: (context) => BlurDetectionCubit(
              blurDetectionService: context.read<BlurDetectionService>(),
              preferencesService: context.read<PreferencesService>(),
              mediaLibraryService: context.read<MediaLibraryService>(),
              permissionsCubit: context.read<PermissionsCubit>(),
              onScanLimitChanged: () =>
                  context.read<BlurScanLimitCubit>().refresh(),
            ),
          ),
          BlocProvider(
            create: (context) => DuplicateDetectionCubit(
              duplicateDetectionService: context
                  .read<DuplicateDetectionService>(),
              preferencesService: context.read<PreferencesService>(),
              mediaLibraryService: context.read<MediaLibraryService>(),
              permissionsCubit: context.read<PermissionsCubit>(),
              albumsCubit: context.read<AlbumsCubit>(),
              onScanLimitChanged: () =>
                  context.read<DuplicateScanLimitCubit>().refresh(),
            ),
          ),
          BlocProvider(create: (_) => TabSelectionCubit()),
        ],
        child: const App(),
      ),
    ),
  );
}

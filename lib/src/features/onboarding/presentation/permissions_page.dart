import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../../l10n/app_localizations.dart';
import '../application/permissions_controller.dart';
import '../../gallery/application/gallery_providers.dart' show PremiumCubit;

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  late final StreamSubscription<GalleryPermissionStatus> _subscription;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<PermissionsCubit>();
    _subscription = cubit.stream.listen((next) {
      if (next == GalleryPermissionStatus.authorized && mounted) {
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.watch<PermissionsCubit>();
    final status = cubit.state;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.galleryPermission)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Builder(
              builder: (iconContext) {
                final isPremiumAsync = iconContext.watch<PremiumCubit>().state;
                final isPremium = isPremiumAsync.maybeWhen(
                  data: (premium) => premium,
                  orElse: () => false,
                );
                final containerColor = Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer.withOpacity(0.8);
                return Icon(
                  Icons.photo_library_outlined,
                  size: 72,
                  color: containerColor,
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              l10n.photoLibraryAccessRequired,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.permissionRequestDescription,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (status == GalleryPermissionStatus.denied ||
                status == GalleryPermissionStatus.unknown) ...[
              Builder(
                builder: (buttonContext) {
                  final isPremiumAsync = buttonContext
                      .watch<PremiumCubit>()
                      .state;
                  final isPremium = isPremiumAsync.maybeWhen(
                    data: (premium) => premium,
                    orElse: () => false,
                  );
                  final containerColor = Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer.withOpacity(0.8);
                  return FilledButton(
                    onPressed: () => context.read<PermissionsCubit>().request(),
                    style: FilledButton.styleFrom(
                      backgroundColor: containerColor,
                      foregroundColor: Colors.white,
                      side: BorderSide(color: containerColor, width: 1.5),
                    ),
                    child: Text(l10n.allowAccess),
                  );
                },
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (buttonContext) {
                  final isPremiumAsync = buttonContext
                      .watch<PremiumCubit>()
                      .state;
                  final isPremium = isPremiumAsync.maybeWhen(
                    data: (premium) => premium,
                    orElse: () => false,
                  );
                  final containerColor = Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer.withOpacity(0.8);
                  return TextButton(
                    onPressed: () =>
                        context.read<PermissionsCubit>().openSettings(),
                    style: TextButton.styleFrom(
                      foregroundColor: containerColor,
                      side: BorderSide(
                        color: containerColor.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Text(l10n.openSettings),
                  );
                },
              ),
            ] else ...[
              Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Lottie.asset(
                    'assets/lottie/loading.json',
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Builder(
              builder: (buttonContext) {
                final isPremiumAsync = buttonContext
                    .watch<PremiumCubit>()
                    .state;
                final isPremium = isPremiumAsync.maybeWhen(
                  data: (premium) => premium,
                  orElse: () => false,
                );
                final containerColor = Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer.withOpacity(0.8);
                return TextButton(
                  onPressed: () => context.read<PermissionsCubit>().refresh(),
                  style: TextButton.styleFrom(
                    foregroundColor: containerColor,
                    side: BorderSide(
                      color: containerColor.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Text(l10n.checkAgain),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

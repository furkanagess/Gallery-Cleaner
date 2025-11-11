import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../../l10n/app_localizations.dart';
import '../application/permissions_controller.dart';

class PermissionsPage extends ConsumerWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen<GalleryPermissionStatus>(permissionsControllerProvider, (prev, next) {
      if (next == GalleryPermissionStatus.authorized) {
        context.go('/');
      }
    });

    final status = ref.watch(permissionsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.galleryPermission)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.photo_library_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(l10n.photoLibraryAccessRequired, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l10n.permissionRequestDescription, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (status == GalleryPermissionStatus.denied || status == GalleryPermissionStatus.unknown) ...[
              FilledButton(
                onPressed: () => ref.read(permissionsControllerProvider.notifier).request(),
                child: Text(l10n.allowAccess),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(permissionsControllerProvider.notifier).openSettings(),
                child: Text(l10n.openSettings),
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
            TextButton(
              onPressed: () => ref.read(permissionsControllerProvider.notifier).refresh(),
              child: Text(l10n.checkAgain),
            ),
          ],
        ),
      ),
    );
  }
}


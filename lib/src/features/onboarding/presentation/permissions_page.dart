import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/permissions_controller.dart';

class PermissionsPage extends ConsumerWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<GalleryPermissionStatus>(permissionsControllerProvider, (prev, next) {
      if (next == GalleryPermissionStatus.authorized) {
        context.go('/');
      }
    });

    final status = ref.watch(permissionsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Galeri İzni')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.photo_library_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Fotoğraf kütüphanesine erişim gerekli', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Swipe ile düzenlemek için fotoğraflarına erişim iznine ihtiyacımız var. İstediğin zaman ayarlardan yönetebilirsin.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (status == GalleryPermissionStatus.denied || status == GalleryPermissionStatus.unknown) ...[
              FilledButton(
                onPressed: () => ref.read(permissionsControllerProvider.notifier).request(),
                child: const Text('İzin Ver'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(permissionsControllerProvider.notifier).openSettings(),
                child: const Text('Ayarları Aç'),
              ),
            ] else ...[
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(permissionsControllerProvider.notifier).refresh(),
              child: const Text('Yeniden Kontrol Et'),
            ),
          ],
        ),
      ),
    );
  }
}


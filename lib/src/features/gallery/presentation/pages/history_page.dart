import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/review_actions_controller.dart';
import '../../application/review_history_controller.dart';
import '../../../../app/theme/app_theme.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(reviewHistoryControllerProvider);
    final pending = ref.watch(reviewActionsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş ve Kuyruk'),
        actions: [
          if (pending.isNotEmpty)
            TextButton(
              onPressed: () {
                // Undo all pending deletes
                while (ref.read(reviewActionsControllerProvider).isNotEmpty) {
                  ref.read(reviewActionsControllerProvider.notifier).undoLast();
                }
              },
              child: const Text('Undo All', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: history.isEmpty
          ? const Center(child: Text('Henüz geçmiş yok.'))
          : ListView.separated(
              itemBuilder: (ctx, i) {
                final item = history[i];
                final color = switch (item.type) {
                  ReviewActionType.keep => Colors.green,
                  ReviewActionType.delete => Colors.red,
                  ReviewActionType.move => Colors.blue,
                };
                final statusLabel = switch (item.status) {
                  ReviewActionStatus.pending => 'Bekliyor',
                  ReviewActionStatus.applied => 'Uygulandı',
                  ReviewActionStatus.undone => 'Geri Alındı',
                };
                return ListTile(
                  leading: CircleAvatar(backgroundColor: color, child: const Icon(Icons.image, color: Colors.white)),
                  title: Text(item.assetId, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${item.type.name.toUpperCase()} • $statusLabel'),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: history.length,
            ),
      bottomNavigationBar: pending.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          while (ref.read(reviewActionsControllerProvider).isNotEmpty) {
                            ref.read(reviewActionsControllerProvider.notifier).undoLast();
                          }
                        },
                        child: const Text('Hepsini Undo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final deletedCount = await ref.read(reviewActionsControllerProvider.notifier).applyPendingDeletes();
                          if (context.mounted && deletedCount > 0) {
                            _showDeleteSuccessDialog(context, deletedCount);
                          }
                        },
                        child: const Text('Silme İşlemlerini Uygula'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

void _showDeleteSuccessDialog(BuildContext context, int deletedCount) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (Theme.of(context).extension<AppSemanticColors>()?.delete ?? Theme.of(context).colorScheme.error).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 48,
                color: Theme.of(context).extension<AppSemanticColors>()?.delete ??
                    Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Başarılı!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '$deletedCount fotoğraf başarıyla silindi.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Tamam'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}



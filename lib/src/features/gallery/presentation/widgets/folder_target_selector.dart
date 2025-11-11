import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:lottie/lottie.dart';

import '../../application/folder_targets_provider.dart';
import '../../application/gallery_providers.dart';
import '../../../../app/theme/app_theme.dart';

class FolderTargetSelectorSheet extends ConsumerStatefulWidget {
  const FolderTargetSelectorSheet({super.key});

  @override
  ConsumerState<FolderTargetSelectorSheet> createState() => _FolderTargetSelectorSheetState();
}

class _FolderTargetSelectorSheetState extends ConsumerState<FolderTargetSelectorSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<AppSemanticColors>();
    final albumsAsync = ref.watch(albumsProvider);
    final selectedIds = ref.watch(folderTargetsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_open, color: sem?.targetHover ?? theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Hedef Klasörleri', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Bitti'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Klasör ara...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
            const SizedBox(height: 12),
            albumsAsync.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
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
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Klasörler yüklenemedi: $e'),
              ),
              data: (albums) {
                final filtered = _query.isEmpty
                    ? albums
                    : albums.where((a) => a.name.toLowerCase().contains(_query)).toList();
                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Eşleşen klasör yok.')),
                  );
                }
                return Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.2,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final pm.AssetPathEntity album = filtered[index];
                      final bool isSelected = selectedIds.contains(album.id);
                      return _SelectableChip(
                        label: album.name,
                        selected: isSelected,
                        onTap: () => ref.read(folderTargetsProvider.notifier).toggle(album.id),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    final all = ref.read(albumsProvider).maybeWhen(data: (a) => a, orElse: () => <pm.AssetPathEntity>[]);
                    if (all.isEmpty) return;
                    final firstFour = all.take(4).map((e) => e.id).toList();
                    for (final id in firstFour) {
                      if (!selectedIds.contains(id)) {
                        ref.read(folderTargetsProvider.notifier).toggle(id);
                      }
                    }
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Önerilenleri Ekle'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    for (final id in List<String>.from(ref.read(folderTargetsProvider))) {
                      ref.read(folderTargetsProvider.notifier).toggle(id);
                    }
                  },
                  child: const Text('Temizle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? theme.colorScheme.primary : theme.dividerColor),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.check_circle : Icons.folder, size: 18, color: selected ? theme.colorScheme.primary : null),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



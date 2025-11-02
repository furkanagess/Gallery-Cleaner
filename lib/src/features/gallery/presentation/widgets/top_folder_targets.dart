import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../../../../app/theme/app_theme.dart';

class TopFolderTargets extends ConsumerWidget {
  const TopFolderTargets({super.key, required this.albums, required this.hoverIndex});
  final List<pm.AssetPathEntity> albums;
  final int? hoverIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final album = albums[index];
          final hovered = hoverIndex == index;
          return _TargetChip(
            key: ValueKey('target_${album.id}'),
            label: album.name,
            hovered: hovered,
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: albums.length,
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({super.key, required this.label, required this.hovered});
  final String label;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hovered ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hovered ? (sem?.targetHover ?? Theme.of(context).colorScheme.primary) : Theme.of(context).dividerColor,
        ),
        boxShadow: hovered
            ? [
                BoxShadow(
                  color: (sem?.targetHover ?? Theme.of(context).colorScheme.primary).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder, color: hovered ? Theme.of(context).colorScheme.onPrimaryContainer : null),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}



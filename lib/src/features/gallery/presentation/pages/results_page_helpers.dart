import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:lottie/lottie.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/models/blur_photo.dart';
import '../../../../core/models/duplicate_photo.dart';
import '../../application/blur_detection_provider.dart';
import '../../application/duplicate_detection_provider.dart';
import '../../application/gallery_providers.dart';

// Helper methods for results page
Widget buildModernStatCard(
  ThemeData theme,
  IconData icon,
  String value,
  String label,
  Color backgroundColor,
) {
  return Container(
    height: 140, // Sabit yükseklik
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          size: 20,
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            maxLines: 1,
          ),
        ),
      ],
    ),
  );
}

Widget buildBlurGridView(
  BuildContext context,
  List<BlurPhoto> allPhotos,
  ThemeData theme,
  AppLocalizations l10n,
  WidgetRef ref,
) {
  return GridView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.8,
    ),
    itemCount: allPhotos.length,
    itemBuilder: (context, index) {
      final photo = allPhotos[index];
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300 + (index * 50)),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: buildBlurPhotoCard(context, photo, theme, l10n, ref),
      );
    },
  );
}

Widget buildBlurPhotoCard(
  BuildContext context,
  BlurPhoto photo,
  ThemeData theme,
  AppLocalizations l10n,
  WidgetRef ref,
) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: theme.colorScheme.surface,
        child: InkWell(
          onTap: () => showBlurPhotoDetail(context, photo, theme, l10n),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FutureBuilder<Uint8List?>(
                      future: photo.asset.thumbnailDataWithSize(
                        const pm.ThumbnailSize(400, 400),
                        quality: 85,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Lottie.asset(
                                  'assets/lottie/loading.json',
                                  fit: BoxFit.contain,
                                  repeat: true,
                                ),
                              ),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Container(
                            color: theme.colorScheme.errorContainer,
                            child: Icon(
                              Icons.error_outline,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          );
                        }
                        if (snapshot.hasData) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: theme.colorScheme.errorContainer,
                                child: Icon(
                                  Icons.broken_image,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              );
                            },
                          );
                        }
                        return Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.photo,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        );
                      },
                    ),
                    // Delete button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Material(
                        color: AppColors.black.withValues(alpha: 0.5),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => deleteBlurPhoto(context, photo, theme, l10n, ref),
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> deleteBlurPhoto(
  BuildContext context,
  BlurPhoto photo,
  ThemeData theme,
  AppLocalizations l10n,
  WidgetRef ref,
) async {
  final problemType = getBlurProblemTypeLabel(photo, l10n);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deletePhoto),
      content: Text(l10n.deletePhotoMessage(problemType.toLowerCase())),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final deletedCount = await ref
      .read(blurDetectionProvider.notifier)
      .deleteBlurryPhotos([photo]);

  if (!context.mounted) return;

  await ref.read(deleteLimitProvider.notifier).decrease(deletedCount);
}

String getBlurProblemTypeLabel(BlurPhoto photo, AppLocalizations l10n) {
  if (photo.isPixelated()) {
    if (photo.isBlurry()) {
      return l10n.blurryAndPixelated;
    }
    return l10n.pixelated;
  }
  if (photo.isBlurry()) {
    return l10n.blurry;
  }
  return l10n.sharp;
}

Future<void> showBlurPhotoDetail(
  BuildContext context,
  BlurPhoto photo,
  ThemeData theme,
  AppLocalizations l10n,
) async {
  await showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: FutureBuilder<Uint8List?>(
                future: photo.asset.thumbnailDataWithSize(
                  const pm.ThumbnailSize(800, 800),
                  quality: 90,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 300,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasData) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                    );
                  }
                  return Container(
                    height: 300,
                    color: theme.colorScheme.errorContainer,
                    child: Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  );
                },
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    getBlurProblemTypeLabel(photo, l10n),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Blur Score: ${photo.blurScore.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget buildDuplicateGrid(
  BuildContext context,
  DuplicateDetectionState state,
  ThemeData theme,
  AppLocalizations l10n,
  WidgetRef ref,
) {
  final allGroups = <DuplicatePhotoGroup>[];
  for (final entry in state.duplicatesByAlbum.entries) {
    allGroups.addAll(entry.value);
  }

  if (allGroups.isEmpty) {
    return const SizedBox.shrink();
  }

  return GridView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    physics: const BouncingScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.82,
    ),
    itemCount: allGroups.length,
    itemBuilder: (context, index) {
      final group = allGroups[index];
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300 + (index * 50)),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: buildDuplicateGroupCard(
          context,
          group,
          theme,
          l10n,
          ref,
        ),
      );
    },
  );
}

Widget buildDuplicateGroupCard(
  BuildContext context,
  DuplicatePhotoGroup group,
  ThemeData theme,
  AppLocalizations l10n,
  WidgetRef ref,
) {
  final toDelete = group.duplicatesToDelete;
  final isDark = theme.brightness == Brightness.dark;

  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
    builder: (context, scale, child) {
      return Transform.scale(
        scale: 0.95 + (scale * 0.05),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withOpacity(isDark ? 0.3 : 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppColors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: () => showDuplicateGroupDetail(context, group, theme, l10n, ref),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.surface.withOpacity(isDark ? 0.95 : 0.98),
                        theme.colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.8 : 0.9),
                      ],
                    ),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Image with overlay gradient
                            FutureBuilder<Uint8List?>(
                              future: group.keepAsset.thumbnailDataWithSize(
                                const pm.ThumbnailSize(500, 500),
                                quality: 90,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          theme.colorScheme.surfaceContainerHighest,
                                          theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Lottie.asset(
                                          'assets/lottie/loading.json',
                                          fit: BoxFit.contain,
                                          repeat: true,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                if (snapshot.hasData) {
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                      ),
                                      // Gradient overlay for better text readability
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                AppColors.transparent,
                                                AppColors.black.withValues(alpha: 0.4),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.errorContainer,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.errorContainer,
                                        theme.colorScheme.errorContainer.withOpacity(0.7),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.error_outline,
                                    color: theme.colorScheme.onErrorContainer,
                                    size: 32,
                                  ),
                                );
                              },
                            ),
                            // Modern badge with icon
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.error.withOpacity(0.95),
                                      AppColors.error.withOpacity(0.85),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.error.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 14,
                                      color: AppColors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${toDelete.length}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Keep badge
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.success.withOpacity(0.95),
                                      AppColors.success.withOpacity(0.85),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.success.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 14,
                                      color: AppColors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.keep,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Modern info section
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.surface.withOpacity(isDark ? 0.95 : 0.98),
                              theme.colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.85 : 0.92),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(isDark ? 0.2 : 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.collections_rounded,
                                size: 18,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${group.assets.length} ${l10n.photo}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${toDelete.length} ${l10n.duplicateTab}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showDuplicateGroupDetail(
  BuildContext context,
  DuplicatePhotoGroup group,
  ThemeData theme,
  AppLocalizations l10n,
  WidgetRef ref,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.transparent,
    builder: (context) => DuplicateGroupDetailSheet(
      group: group,
      onDelete: () {
        Navigator.of(context).pop();
        deleteDuplicateGroup(context, group, theme, l10n, ref);
      },
    ),
  );
}

Future<void> deleteDuplicateGroup(
  BuildContext context,
  DuplicatePhotoGroup group,
  ThemeData theme,
  AppLocalizations l10n,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteDuplicates),
      content: Text(
        l10n.deleteDuplicatesMessage(group.duplicatesToDelete.length),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            side: BorderSide(
              color: AppColors.error.withOpacity(0.9),
              width: 1.5,
            ),
          ),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final deletedCount = await ref
      .read(duplicateDetectionProvider.notifier)
      .deleteDuplicates([group]);

  if (!context.mounted) return;

  await ref.read(deleteLimitProvider.notifier).decrease(deletedCount);
}

class DuplicateGroupDetailSheet extends StatelessWidget {
  const DuplicateGroupDetailSheet({
    super.key,
    required this.group,
    required this.onDelete,
  });

  final DuplicatePhotoGroup group;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final sortedAssets = List<pm.AssetEntity>.from(group.assets)
      ..sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
    final keepAsset = group.keepAsset;
    final toDelete = group.duplicatesToDelete;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Modern Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.collections_rounded,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.duplicateGroup,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sortedAssets.length} ${l10n.photo}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Modern Photos grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: sortedAssets.length,
              itemBuilder: (context, index) {
                final asset = sortedAssets[index];
                final isKeep = asset.id == keepAsset.id;
                final isToDelete = toDelete.any((a) => a.id == asset.id);
                final isDark = theme.brightness == Brightness.dark;

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  curve: Curves.easeOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: 0.95 + (scale * 0.05),
                      child: Opacity(
                        opacity: scale,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(isDark ? 0.3 : 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Material(
                        color: AppColors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            // Photo detail açılabilir
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.surface.withOpacity(isDark ? 0.95 : 0.98),
                                  theme.colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.8 : 0.9),
                                ],
                              ),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(isDark ? 0.2 : 0.15),
                                width: 1.5,
                              ),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Image with overlay gradient
                                FutureBuilder<Uint8List?>(
                                  future: asset.thumbnailDataWithSize(
                                    const pm.ThumbnailSize(600, 600),
                                    quality: 90,
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              theme.colorScheme.surfaceContainerHighest,
                                              theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    if (snapshot.hasData) {
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                          ),
                                          // Gradient overlay for better badge readability
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    AppColors.transparent,
                                                    AppColors.black.withValues(alpha: 0.3),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.errorContainer,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            theme.colorScheme.errorContainer,
                                            theme.colorScheme.errorContainer.withOpacity(0.7),
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.error_outline,
                                        color: theme.colorScheme.onErrorContainer,
                                        size: 32,
                                      ),
                                    );
                                  },
                                ),
                                // Modern Keep badge
                                if (isKeep)
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.success.withOpacity(0.95),
                                            AppColors.success.withOpacity(0.85),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.white.withOpacity(0.3),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.success.withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 14,
                                            color: AppColors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.keep,
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Modern Delete badge
                                if (isToDelete)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.error.withOpacity(0.95),
                                            AppColors.error.withOpacity(0.85),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.white.withOpacity(0.3),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.error.withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            size: 14,
                                            color: AppColors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.delete,
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Modern Delete button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.deleteDuplicates),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: AppColors.error.withOpacity(0.85),
                    foregroundColor: theme.colorScheme.onError,
                    side: BorderSide(
                      color: AppColors.error.withOpacity(0.9),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_three_d_button.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/models/blur_photo.dart';
import '../../../../core/models/duplicate_photo.dart';
import '../../application/blur_detection_provider.dart';
import '../../application/duplicate_detection_provider.dart';
import '../../application/gallery_providers.dart';
import '../../../../core/services/interstitial_ads_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../application/asset_size_helper.dart';
import '../../../../core/utils/async_value.dart';

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
  AppLocalizations l10n, {
  bool shrinkWrap = false,
  ScrollPhysics? physics,
}) {
  return GridView.builder(
    shrinkWrap: shrinkWrap,
    physics: physics,
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
        child: buildBlurPhotoCard(context, photo, theme, l10n),
      );
    },
  );
}

Widget buildBlurPhotoCard(
  BuildContext context,
  BlurPhoto photo,
  ThemeData theme,
  AppLocalizations l10n,
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
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: theme.colorScheme.errorContainer,
                                    child: Icon(
                                      Icons.broken_image,
                                      color:
                                          theme.colorScheme.onErrorContainer,
                                    ),
                                  );
                                },
                              ),
                              // Fotoğraf tarihi - sol üst köşe
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.9),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    DateFormat('dd.MM.yyyy')
                                        .format(photo.asset.createDateTime),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                          onTap: () =>
                              deleteBlurPhoto(context, photo, theme, l10n),
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

  // BlurDetectionCubit kullanarak silme işlemini yap
  final blurCubit = context.read<BlurDetectionCubit>();
  final deleteResult = await blurCubit.deleteBlurryPhotos([photo]);
  if (!context.mounted) return;
  await showDeleteSuccessDialog(
    context,
    deleteResult.deletedCount,
    deletedSizeMB: deleteResult.deletedSizeMB,
  );
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
  final isBlurry = photo.isBlurry();
  final isPixelated = photo.isPixelated();
  final problemType = getBlurProblemTypeLabel(photo, l10n);

  // Problem tipine göre renk belirle
  final problemColor = isPixelated && isBlurry
      ? AppColors.secondary
      : isPixelated
      ? AppColors.blurTab
      : AppColors.error;

  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface.withOpacity(0.95),
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              problemColor.withOpacity(0.2),
                              problemColor.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: problemColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPixelated && isBlurry
                                  ? Icons.auto_fix_high_rounded
                                  : isPixelated
                                  ? Icons.grid_off_rounded
                                  : Icons.blur_on_rounded,
                              size: 16,
                              color: problemColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              problemType,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: problemColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Photo
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: FutureBuilder<Uint8List?>(
                        future: photo.asset.thumbnailDataWithSize(
                          const pm.ThumbnailSize(1000, 1000),
                          quality: 95,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Container(
                              height: 400,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.surfaceContainerHighest,
                                    theme.colorScheme.surfaceContainerHighest
                                        .withOpacity(0.5),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: problemColor,
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasData) {
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                            );
                          }
                          return Container(
                            height: 400,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.errorContainer,
                                  theme.colorScheme.errorContainer.withOpacity(
                                    0.7,
                                  ),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 48,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Failed to load image',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Info Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Blur Score Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              problemColor.withOpacity(0.15),
                              problemColor.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: problemColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: problemColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.analytics_rounded,
                                color: problemColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Blur Score',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    photo.blurScore.toStringAsFixed(2),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: problemColor,
                                      fontSize: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Delete Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await deleteBlurPhoto(context, photo, theme, l10n);
                          },
                          icon: const Icon(Icons.delete_rounded, size: 20),
                          label: Text(l10n.deletePhoto),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: AppColors.error.withOpacity(0.9),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget buildDuplicateGrid(
  BuildContext context,
  DuplicateDetectionState state,
  ThemeData theme,
  AppLocalizations l10n, {
  bool shrinkWrap = false,
  ScrollPhysics? physics,
}) {
  final allGroups = <DuplicatePhotoGroup>[];
  for (final entry in state.duplicatesByAlbum.entries) {
    allGroups.addAll(entry.value);
  }

  if (allGroups.isEmpty) {
    return const SizedBox.shrink();
  }

  return GridView.builder(
    shrinkWrap: shrinkWrap,
    physics: physics ?? const BouncingScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        child: buildDuplicateGroupCard(context, group, theme, l10n),
      );
    },
  );
}

Widget buildDuplicateGroupCard(
  BuildContext context,
  DuplicatePhotoGroup group,
  ThemeData theme,
  AppLocalizations l10n,
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
                onTap: () =>
                    showDuplicateGroupDetail(context, group, theme, l10n),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.surface.withOpacity(
                          isDark ? 0.95 : 0.98,
                        ),
                        theme.colorScheme.surfaceContainerHighest.withOpacity(
                          isDark ? 0.8 : 0.9,
                        ),
                      ],
                    ),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(
                        isDark ? 0.2 : 0.15,
                      ),
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
                                          theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          theme
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withOpacity(0.7),
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
                                                AppColors.black.withValues(
                                                  alpha: 0.4,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Fotoğraf tarihi - sol alt köşe
                                      Positioned(
                                        bottom: 10,
                                        left: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.55),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withOpacity(0.9),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            DateFormat('dd.MM.yyyy').format(
                                              group.keepAsset.createDateTime,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2,
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
                                        theme.colorScheme.errorContainer
                                            .withOpacity(0.7),
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
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
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
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
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
                              theme.colorScheme.surface.withOpacity(
                                isDark ? 0.95 : 0.98,
                              ),
                              theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(isDark ? 0.85 : 0.92),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(
                                  isDark ? 0.2 : 0.15,
                                ),
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
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
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
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.transparent,
    builder: (context) => DuplicateGroupDetailSheet(
      group: group,
    ),
  );
}

Future<void> deleteDuplicateGroup(
  BuildContext context,
  DuplicatePhotoGroup group,
  ThemeData theme,
  AppLocalizations l10n,
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

  // BLoC kullanarak duplicate'leri sil
  final duplicateCubit = context.read<DuplicateDetectionCubit>();
  final deleteResult = await duplicateCubit.deleteDuplicates([group]);

  if (!context.mounted) return;

  // Delete limit'i azalt
  final deleteLimitCubit = context.read<DeleteLimitCubit>();
  await deleteLimitCubit.decrease(deleteResult.deletedCount);

  if (!context.mounted || deleteResult.deletedCount <= 0) return;
  await showDeleteSuccessDialog(
    context,
    deleteResult.deletedCount,
    deletedSizeMB: deleteResult.deletedSizeMB,
  );
}

Future<void> showDeleteSuccessDialog(
  BuildContext context,
  int deletedCount, {
  double deletedSizeMB = 0.0,
}) async {
  debugPrint(
    '🎯 [ResultsPageHelpers] showDeleteSuccessDialog çağrıldı - deletedCount: $deletedCount, deletedSizeMB: $deletedSizeMB',
  );

  if (!context.mounted || deletedCount <= 0) {
    debugPrint(
      '❌ [ResultsPageHelpers] Context not mounted or deletedCount <= 0, dialog gösterilmeyecek',
    );
    return;
  }

  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  debugPrint('🔍 [ResultsPageHelpers] Checking premium status for dialog...');
  final prefsService = PreferencesService();
  final isPremium = await prefsService.isPremium();
  debugPrint('💰 [ResultsPageHelpers] Premium status: $isPremium');

  if (!isPremium) {
    debugPrint(
      '📱 [ResultsPageHelpers] Non-premium user, showing interstitial ad...',
    );
    try {
      final adService = InterstitialAdsService.instance;
      try {
        debugPrint(
          '📱 [ResultsPageHelpers] Attempting to show preloaded ad...',
        );
        final adShown = await adService
            .showAd()
            .timeout(
              const Duration(seconds: 35),
              onTimeout: () {
                debugPrint(
                  '⚠️ [ResultsPageHelpers] Ad showing timeout, continuing to show dialog',
                );
                return false;
              },
            )
            .catchError((e) {
              debugPrint(
                '⚠️ [ResultsPageHelpers] Ad showing error: $e, continuing to show dialog',
              );
              return false;
            });

        debugPrint('📱 [ResultsPageHelpers] Ad shown result: $adShown');

        if (adShown == true) {
          debugPrint(
            '📱 [ResultsPageHelpers] Ad was shown, waiting 500ms before dialog...',
          );
          await Future.delayed(const Duration(milliseconds: 500));

          // InterstitialAdsService zaten ad sayacını artırdı ve 3'e ulaştığında callback çağıracak
          // Burada ek bir işlem yapmaya gerek yok
        } else {
          debugPrint(
            '📱 [ResultsPageHelpers] Ad was not shown, proceeding to dialog...',
          );
        }
      } catch (e) {
        debugPrint(
          '⚠️ [ResultsPageHelpers] Error showing ad: $e, continuing to show dialog',
        );
      }
    } catch (e) {
      debugPrint(
        '⚠️ [ResultsPageHelpers] Error in ad flow: $e, continuing to show dialog',
      );
    }
  } else {
    debugPrint('💰 [ResultsPageHelpers] Premium user, skipping ad...');
  }

  if (!context.mounted) {
    debugPrint(
      '❌ [ResultsPageHelpers] Context not mounted after ad flow, cannot show dialog',
    );
    return;
  }

  debugPrint(
    '✅ [ResultsPageHelpers] Showing cleanup complete dialog - deletedCount: $deletedCount, deletedSizeMB: $deletedSizeMB',
  );

  try {
    await Future.delayed(Duration.zero);
    if (!context.mounted) {
      debugPrint(
        '❌ [ResultsPageHelpers] Context not mounted after delay, cannot show dialog',
      );
      return;
    }

    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: AppColors.black.withOpacity(0.5),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.85 + (value * 0.15),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Stack(
              children: [
                Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withOpacity(0.2),
                    blurRadius: 32,
                    spreadRadius: 0,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                      // Success icon with background - New Year themed
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 80,
                        height: 80,
                    child: Lottie.asset(
                              'assets/new_year/Santa surprise gift.json',
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                    ),
                  ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.cleanupComplete,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  // Big animated MB headline
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: deletedSizeMB),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (context, animMb, _) {
                      final shownMb =
                          animMb.clamp(0, deletedSizeMB).toStringAsFixed(
                                animMb >= 100 ? 0 : 1,
                              );
                      return Column(
                        children: [
                          Text(
                            '$shownMb MB',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 40,
                              color: theme.colorScheme.primary,
                              letterSpacing: -1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          TweenAnimationBuilder<double>(
                            tween:
                                Tween(begin: 0, end: deletedCount.toDouble()),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (context, animCount, __) {
                              final shownCount = animCount
                                  .clamp(0, deletedCount.toDouble())
                                  .round();
                              return Text(
                                '${shownCount.toString()} ${shownCount == 1 ? l10n.photo : l10n.photos}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  // Animated stats (compact card)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: deletedCount.toDouble()),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, animCount, _) {
                      final shownCount =
                          animCount.clamp(0, deletedCount.toDouble()).round();

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: deletedSizeMB),
                        duration: const Duration(milliseconds: 1100),
                        curve: Curves.easeOutCubic,
                        builder: (context, animMb, __) {
                          final shownMb =
                              animMb.clamp(0, deletedSizeMB).toStringAsFixed(
                                    animMb >= 100 ? 0 : 1,
                                  );

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                    decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primary.withOpacity(0.12),
                                  theme.colorScheme.secondary.withOpacity(0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.2),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      theme.colorScheme.shadow.withOpacity(0.12),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                    child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                      children: [
                                      Text(
                                        l10n.photoUnit,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.7),
                                        ),
                            ),
                                      const SizedBox(height: 4),
                  Text(
                                        shownCount.toString(),
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                                ),
                                Container(
                                  width: 1,
                                  height: 42,
                                  color: theme.colorScheme.outline
                                      .withOpacity(0.1),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                          children: [
                                      Text(
                                        'MB',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.7),
                                        ),
                            ),
                                      const SizedBox(height: 4),
                            Text(
                                        shownMb,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                                  ),
                        ),
                      ],
                    ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.cleanupCompleteMessageWithCountAndSize(
                      deletedCount,
                      deletedSizeMB.toStringAsFixed(1),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.75),
                      fontSize: 15,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // Upsell CTA
                      AppThreeDButton(
                    label: 'Get unlimited deletions',
                    icon: Icons.workspace_premium_rounded,
                    baseColor: theme.colorScheme.primary,
                        textColor: AppColors.white,
                        fullWidth: true,
                        height: 56,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.go('/paywall');
                    },
                  ),
                  const SizedBox(height: 14),
                  // Compact done button
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                      child: Text(
                        l10n.done,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                        ],
                      ),
                ),
                // Decorative New Year elements
                Positioned(
                  top: -30,
                  right: -30,
                  child: Opacity(
                    opacity: 0.3,
                    child: Image.asset(
                      'assets/new_year/gift-box.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -20,
                  left: -20,
                  child: Opacity(
                    opacity: 0.25,
                    child: Image.asset(
                      'assets/new_year/candy-cane.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
            ),
          ),
        );
      },
    );
  } catch (e) {
    debugPrint('❌ [ResultsPageHelpers] Error showing dialog: $e');
  }
}

class DuplicateGroupDetailSheet extends StatefulWidget {
  const DuplicateGroupDetailSheet({
    super.key,
    required this.group,
  });

  final DuplicatePhotoGroup group;

  @override
  State<DuplicateGroupDetailSheet> createState() =>
      _DuplicateGroupDetailSheetState();
}

class _DuplicateGroupDetailSheetState
    extends State<DuplicateGroupDetailSheet> {
  late final List<pm.AssetEntity> _sortedAssets;
  late final Set<String> _selectedIds; // Silinecekler

  @override
  void initState() {
    super.initState();
    _sortedAssets = List<pm.AssetEntity>.from(widget.group.assets)
      ..sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
    _selectedIds =
        widget.group.duplicatesToDelete.map((a) => a.id).toSet(); // varsayılan
  }

  void _toggleSelection(String assetId) {
    setState(() {
      if (_selectedIds.contains(assetId)) {
        // En az bir fotoğraf silinmeden kalmalı, tümünü seçili yapma
        if (_selectedIds.length == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Keep at least one photo'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedIds.remove(assetId);
      } else {
        _selectedIds.add(assetId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

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
                        '${_sortedAssets.length} ${l10n.photo}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
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
              key: const PageStorageKey('duplicate_group_grid'),
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _sortedAssets.length,
              itemBuilder: (context, index) {
                final asset = _sortedAssets[index];
                final isToDelete = _selectedIds.contains(asset.id);

                return _PhotoGridItem(
                  key: ValueKey('photo_${asset.id}_$isToDelete'),
                  asset: asset,
                  isToDelete: isToDelete,
                  theme: theme,
                  l10n: l10n,
                  isDark: isDark,
                  onTap: () => _toggleSelection(asset.id),
                );
              },
            ),
          ),
          // Selection summary + action
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                                          Text(
                        l10n.keep,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.8,
                          ),
                                                ),
                                          ),
                      Text(
                        '${_sortedAssets.length - _selectedIds.length}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                              ],
                            ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.delete,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                      Text(
                        '${_selectedIds.length}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                ),
              ],
            ),
                  const SizedBox(height: 12),
                  BlocBuilder<DeleteLimitCubit, AsyncValue<int>>(
                    builder: (context, deleteLimitAsync) {
                      final deleteLimit = deleteLimitAsync.maybeWhen(
                        data: (limit) => limit,
                        orElse: () => 0,
                      );
                      final hasRights = deleteLimit > 0;

                      return AppThreeDButton(
                        label: hasRights
                            ? l10n.deleteDuplicates
                            : l10n.getUnlimitedDeletions,
                        icon: hasRights
                            ? Icons.delete_outline
                            : Icons.workspace_premium_rounded,
                        baseColor: AppColors.error,
                        textColor: AppColors.white,
                        fullWidth: true,
                        height: 56,
                        onPressed: () async {
                          // Silme hakkı yoksa paywall'a yönlendir
                          if (!hasRights) {
                            context.push('/paywall');
                            return;
                          }

                          if (_selectedIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.noPhotosToDelete),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(l10n.deleteDuplicates),
                              content: Text(
                                l10n.deleteDuplicatesMessage(_selectedIds.length),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text(l10n.cancel),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
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

                          if (confirmed != true || !mounted) return;

                          final duplicateCubit =
                              context.read<DuplicateDetectionCubit>();
                          final deleteResult =
                              await duplicateCubit.deleteSelectedDuplicateAssets(
                            _selectedIds.toList(),
                            groupHash: widget.group.hash,
                          );

                          if (!mounted) return;

                          final deleteLimitCubit =
                              context.read<DeleteLimitCubit>();
                          await deleteLimitCubit.decrease(
                            deleteResult.deletedCount,
                          );

                          if (!mounted || deleteResult.deletedCount <= 0) return;

                          await showDeleteSuccessDialog(
                            context,
                            deleteResult.deletedCount,
                            deletedSizeMB: deleteResult.deletedSizeMB,
                          );

                          if (mounted) {
                            Navigator.of(context).pop(); // sheet kapat
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized photo grid item widget to prevent flicker
class _PhotoGridItem extends StatelessWidget {
  const _PhotoGridItem({
    super.key,
    required this.asset,
    required this.isToDelete,
    required this.theme,
    required this.l10n,
    required this.isDark,
    required this.onTap,
  });

  final pm.AssetEntity asset;
  final bool isToDelete;
  final ThemeData theme;
  final AppLocalizations l10n;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(
                            isDark ? 0.3 : 0.2,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: AppColors.black.withValues(
                            alpha: isDark ? 0.3 : 0.15,
                          ),
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
            onTap: onTap,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.surface.withOpacity(
                                    isDark ? 0.95 : 0.98,
                                  ),
                                  theme.colorScheme.surfaceContainerHighest
                                      .withOpacity(isDark ? 0.8 : 0.9),
                                ],
                              ),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(
                                  isDark ? 0.2 : 0.15,
                                ),
                                width: 1.5,
                              ),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Image with overlay gradient
                                FutureBuilder<Uint8List?>(
                    key: ValueKey('thumb_${asset.id}'),
                                  future: asset.thumbnailDataWithSize(
                                    const pm.ThumbnailSize(600, 600),
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
                                theme.colorScheme.surfaceContainerHighest
                                                  .withOpacity(0.7),
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
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
                              key: ValueKey('img_${asset.id}'),
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
                                                    AppColors.black.withValues(
                                                      alpha: 0.3,
                                                    ),
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
                                            theme.colorScheme.errorContainer
                                                .withOpacity(0.7),
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
                  // Selection badge (keep/delete toggle)
                                  Positioned(
                                    top: 10,
                                    left: 10,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                          colors: isToDelete
                              ? [
                                  AppColors.error.withOpacity(0.95),
                                  AppColors.error.withOpacity(0.85),
                                ]
                              : [
                                            AppColors.success.withOpacity(0.95),
                                            AppColors.success.withOpacity(0.85),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                          color: AppColors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                            color: (isToDelete
                                    ? AppColors.error
                                    : AppColors.success)
                                                .withOpacity(0.4),
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
                            isToDelete
                                ? Icons.delete_forever_rounded
                                : Icons.check_circle_outline,
                                            size: 14,
                                            color: AppColors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                            isToDelete ? l10n.delete : l10n.keep,
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
                  // Photo size badge (bottom right)
                                  Positioned(
                    bottom: 10,
                                    right: 10,
                    child: FutureBuilder<int>(
                      key: ValueKey('size_${asset.id}'),
                      future: estimateAssetSize(asset),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        if (snapshot.hasData && snapshot.data! > 0) {
                          final sizeMB = snapshot.data! / (1024 * 1024);
                          final sizeText = sizeMB >= 1
                              ? '${sizeMB.toStringAsFixed(1)} MB'
                              : '${(sizeMB * 1024).toStringAsFixed(0)} KB';
                          return Container(
                                      padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                              color: AppColors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                color: AppColors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                            ),
                            child: Text(
                              sizeText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                            color: AppColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.3,
                    ),
                  ),
                );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                ),
              ],
            ),
                    ),
                  ),
                ),
      ),
    );
  }
}

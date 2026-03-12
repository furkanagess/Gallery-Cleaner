// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_three_d_button.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/gallery_providers.dart';
import '../../../../core/services/preferences_service.dart';
import '../../application/blur_detection_provider.dart';
import '../../application/duplicate_detection_provider.dart';
import '../../../../core/models/blur_photo.dart';
import '../../../../core/models/duplicate_photo.dart';
import '../../../../core/utils/async_value.dart';
import 'results_page_helpers.dart';

class ResultsPage extends StatelessWidget {
  final String resultType;

  const ResultsPage({super.key, required this.resultType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blurState = context.watch<BlurDetectionCubit>().state;
    final duplicateState = context.watch<DuplicateDetectionCubit>().state;

    // resultType'a göre hangi sonuçları göstereceğimizi belirle
    final isBlur = resultType == 'blur';
    final isDuplicate = resultType == 'duplicate';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: const SizedBox.shrink(),
        leading: IconButton(
          icon: Icon(
            Platform.isIOS
                ? CupertinoIcons.chevron_back
                : Icons.arrow_back_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/swipe');
            }
          },
        ),
      ),
      body: isBlur
          ? BlocProvider<BlurSelectionCubit>(
              create: (_) => BlurSelectionCubit(),
              child: _BlurResultsTab(state: blurState),
            )
          : isDuplicate
          ? BlocProvider<DuplicateSelectionCubit>(
              create: (_) => DuplicateSelectionCubit(),
              child: _DuplicateResultsTab(state: duplicateState),
            )
          : Center(
              child: Text(
                'Invalid result type: $resultType',
                style: theme.textTheme.bodyLarge,
              ),
            ),
    );
  }
}

class _BlurResultsTab extends StatefulWidget {
  final BlurDetectionState state;

  const _BlurResultsTab({required this.state});

  @override
  State<_BlurResultsTab> createState() => _BlurResultsTabState();
}

class _BlurResultsTabState extends State<_BlurResultsTab> {
  List<BlurPhoto> get _allPhotos {
    final list = <BlurPhoto>[];
    for (final entry in widget.state.blurryPhotosByAlbum.entries) {
      list.addAll(entry.value);
    }
    list.sort((a, b) => a.blurScore.compareTo(b.blurScore));
    return list;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final allPhotos = _allPhotos;
      if (allPhotos.isEmpty) return;
      final allIds = allPhotos.map((p) => p.asset.id).toList();
      context.read<BlurSelectionCubit>().selectAll(allIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final allPhotos = _allPhotos;

    if (allPhotos.isEmpty) {
      return _buildNoResultsView(context, theme, l10n, true);
    }

    // GridView BlocBuilder DIŞINDA - seçim değişince liste hiç rebuild olmaz; sadece bar ve buton güncellenir
    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 120),
          cacheExtent: 500,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: 0.8,
          ),
          itemCount: allPhotos.length,
          itemBuilder: (context, index) {
            final photo = allPhotos[index];
            return _BlurPhotoGridItem(
              key: ValueKey(photo.asset.id),
              photo: photo,
              theme: theme,
              l10n: l10n,
              index: index,
            );
          },
        ),
        // Bar ve buton sadece seçim değişince rebuild olur
        BlocBuilder<BlurSelectionCubit, Set<String>>(
          builder: (context, selectedIds) {
            final selectedPhotos = allPhotos
                .where((p) => selectedIds.contains(p.asset.id))
                .toList();
            final selectedTotalMB = selectedPhotos.fold(
              0.0,
              (sum, p) => sum + p.estimatedSizeMB,
            );
            final selectedCount = selectedIds.length;
            return Stack(
              children: [
                Positioned(
                  left: 16,
                  right: 16,
                  top: 8,
                  child: _buildBlurTopBar(
                    context,
                        theme,
                    l10n,
                    selectedCount,
                    selectedTotalMB,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 32,
                  child: SafeArea(
                    child: _buildDeleteButton(
                  context,
                  theme,
                  l10n,
                      allPhotos,
                      selectedPhotos: selectedPhotos,
                      selectedIds: selectedIds,
                ),
              ),
            ),
          ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBlurTopBar(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    int selectedCount,
    double selectedTotalMB,
  ) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      opacity: selectedCount > 0 ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: selectedCount > 0 ? Offset.zero : const Offset(0, -0.15),
        child: AnimatedScale(
          scale: selectedCount > 0 ? 1.0 : 0.9,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: IgnorePointer(
            ignoring: selectedCount == 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
                    theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.9,
                    ),
                    theme.colorScheme.surface.withValues(alpha: 0.96),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
        border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
                    padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 22,
                      color: theme.colorScheme.primary,
                    ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                        Text(
                          l10n.youWillBeSaved,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutBack,
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: Row(
                            key: ValueKey(
                              'blur-summary-$selectedCount-${selectedTotalMB.toStringAsFixed(1)}',
                            ),
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                selectedCount.toString(),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.photoUnit,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                selectedTotalMB.toStringAsFixed(
                                  selectedTotalMB >= 100 ? 0 : 1,
                                ),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'MB',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                  ),
                ),
              ],
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
      ),
    );
  }

  Widget _buildDeleteButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<BlurPhoto> allPhotos, {
    required List<BlurPhoto> selectedPhotos,
    required Set<String> selectedIds,
  }) {
    return BlocBuilder<DeleteLimitCubit, AsyncValue<int>>(
      builder: (context, deleteLimitAsync) {
        final deleteLimit = deleteLimitAsync.maybeWhen(
          data: (limit) => limit,
          orElse: () => 0,
        );
        final hasRights = deleteLimit > 0;
        final label = hasRights
            ? (selectedIds.isNotEmpty
                  ? l10n.deletePhotos(selectedPhotos.length)
                  : l10n.deleteAllBlurryPhotos)
            : l10n.getUnlimitedDeletions;

        return AppThreeDButton(
          label: label,
          icon: hasRights
              ? Icons.delete_outline
              : Icons.workspace_premium_rounded,
          baseColor: AppColors.error,
          textColor: AppColors.white,
          fullWidth: true,
          height: 56,
          onPressed: () async {
            if (!hasRights) {
              context.push('/paywall');
              return;
            }

            final toDelete = selectedIds.isNotEmpty
                ? selectedPhotos
                : allPhotos;

            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.deletePhoto),
                content: Text(
                  selectedIds.isNotEmpty
                      ? l10n.deleteAllBlurryPhotosMessage(toDelete.length)
                      : l10n.deleteAllBlurryPhotosMessage(allPhotos.length),
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
                      side: BorderSide(color: AppColors.error, width: 1.5),
                    ),
                    child: Text(l10n.delete),
                  ),
                ],
              ),
            );

            if (confirmed != true || !context.mounted) return;

            final blurCubit = context.read<BlurDetectionCubit>();
            final deleteResult = await blurCubit.deleteBlurryPhotos(toDelete);
            if (context.mounted) {
              context.read<BlurSelectionCubit>().clear();
            }

            if (!context.mounted) return;

            final rootNavigatorContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;

            final deleteLimitCubit = context.read<DeleteLimitCubit>();
            await deleteLimitCubit.decrease(deleteResult.deletedCount);

            debugPrint(
              '🎯 [ResultsPage] Blur - About to show delete success dialog - deletedCount: ${deleteResult.deletedCount}, deletedSizeMB: ${deleteResult.deletedSizeMB}, context.mounted: ${context.mounted}',
            );

            if (deleteResult.deletedCount > 0) {
              if (context.mounted) {
                debugPrint(
                  '✅ [ResultsPage] Blur - Context is mounted and deletedCount > 0, calling showDeleteSuccessDialog...',
                );
                await showDeleteSuccessDialog(
                  context,
                  deleteResult.deletedCount,
                  deletedSizeMB: deleteResult.deletedSizeMB,
                );
                // Swipe deck'i başa sar
                final prefs = PreferencesService();
                final selectedAlbum = context
                    .read<SelectedAlbumCubit?>()
                    ?.state;
                await prefs.saveSwipeIndex(0, selectedAlbum?.id);
                debugPrint(
                  '✅ [ResultsPage] Blur - showDeleteSuccessDialog completed',
                );
              } else {
                debugPrint(
                  '⚠️ [ResultsPage] Blur - Context not mounted after decrease, using rootNavigator context...',
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    showDeleteSuccessDialog(
                      rootNavigatorContext,
                      deleteResult.deletedCount,
                      deletedSizeMB: deleteResult.deletedSizeMB,
                    );
                  } catch (e) {
                    debugPrint(
                      '❌ [ResultsPage] Blur - Error showing dialog with rootNavigator context: $e',
                    );
                  }
                });
              }
            } else {
              debugPrint(
                '⚠️ [ResultsPage] Blur - deletedCount is 0, dialog gösterilmeyecek',
              );
            }
          },
        );
      },
    );
  }

  Widget _buildNoResultsView(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    bool isBlur,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isBlur ? AppColors.primary : AppColors.secondary)
                        .withValues(alpha: 0.15),
                    (isBlur ? AppColors.secondary : AppColors.primary)
                        .withValues(alpha:0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isBlur ? AppColors.primary : AppColors.secondary)
                        .withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 8,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.5,
                          colors: [
                            AppColors.accent.withValues(alpha:0.1),
                            AppColors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (isBlur ? AppColors.primary : AppColors.secondary)
                                  .withValues(alpha:0.1),
                          border: Border.all(
                            color:
                                (isBlur
                                        ? AppColors.primary
                                        : AppColors.secondary)
                                    .withValues(alpha:0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isBlur
                              ? Icons.image_not_supported_rounded
                              : Icons.collections_rounded,
                          size: 64,
                          color: isBlur
                              ? AppColors.primary
                              : AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              isBlur
                  ? l10n.noBlurryPhotosFoundTitle
                  : l10n.noDuplicatesFoundTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 28,
                letterSpacing: -0.8,
                color: theme.colorScheme.onSurface,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(
                    isBlur
                        ? l10n.scanCompletedSuccessfully
                        : l10n.scanCompletedSuccessfullyDuplicate,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.6,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isBlur
                        ? l10n.noBlurryPhotosFound
                        : l10n.noDuplicatePhotosFound,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                      height: 1.5,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Builder(
              builder: (context) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.primary.withValues(alpha:0.85),
                        AppColors.accent.withValues(alpha:0.75),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha:0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha:0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FilledButton.icon(
                    onPressed: () {
                      if (isBlur) {
                        context.read<BlurDetectionCubit>().clear();
                      } else {
                        context.read<DuplicateDetectionCubit>().clear();
                      }
                      context.pop();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    label: Text(
                      l10n.startNewScan,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                      minimumSize: const Size(240, 56),
                      backgroundColor: AppColors.transparent,
                      foregroundColor: AppColors.white,
                      shadowColor: AppColors.transparent,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Grid item - review_delete_photos_page _PhotoGridItem ile aynı: thumbnail BlocBuilder DIŞINDA, sadece overlay rebuild olur
class _BlurPhotoGridItem extends StatelessWidget {
  const _BlurPhotoGridItem({
    super.key,
    required this.photo,
    required this.theme,
    required this.l10n,
    required this.index,
  });

  final BlurPhoto photo;
  final ThemeData theme;
  final AppLocalizations l10n;
  final int index;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        key: ValueKey('tween-${photo.asset.id}'),
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
        child: Container(
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
                onTap: () => context.read<BlurSelectionCubit>().toggleSelection(
                  photo.asset.id,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Thumbnail - BlocBuilder DIŞINDA, tıklanınca yeniden build olmaz
                          FutureBuilder<Uint8List?>(
                            future: photo.asset.thumbnailDataWithSize(
                              const pm.ThumbnailSize(400, 400),
                              quality: 85,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
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
                              if (snapshot.hasData && snapshot.data != null) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                      cacheWidth: 400,
                                      cacheHeight: 400,
                                      gaplessPlayback: true,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: theme
                                                  .colorScheme
                                                  .errorContainer,
                                              child: Icon(
                                                Icons.broken_image,
                                                color: theme
                                                    .colorScheme
                                                    .onErrorContainer,
                                              ),
                                            );
                                          },
                                    ),
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.black.withValues(
                                            alpha: 0.55,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          DateFormat(
                                            'dd.MM.yyyy',
                                          ).format(photo.asset.createDateTime),
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.black.withValues(
                                            alpha: 0.55,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${photo.estimatedSizeMB.toStringAsFixed(1)} MB',
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Container(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.photo,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Sadece seçim overlay'i BlocBuilder içinde - sadece bu kısım rebuild olur
                          BlocBuilder<BlurSelectionCubit, Set<String>>(
                            buildWhen: (previous, current) {
                              final wasSelected = previous.contains(
                                photo.asset.id,
                              );
                              final isSelected = current.contains(
                                photo.asset.id,
                              );
                              return wasSelected != isSelected;
                            },
                            builder: (context, selectedIds) {
                              final isSelected = selectedIds.contains(
                                photo.asset.id,
                              );
                              if (!isSelected) {
                                return const SizedBox.shrink();
                              }
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.error,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
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
  }
}

/// Duplicate grid item - blur ile aynı: thumbnail dışarı, sadece overlay BlocBuilder içinde
class _DuplicatePhotoGridItem extends StatelessWidget {
  const _DuplicatePhotoGridItem({
    super.key,
    required this.item,
    required this.theme,
    required this.l10n,
    required this.index,
    required this.onToggle,
  });

  final _DuplicatePhotoItem item;
  final ThemeData theme;
  final AppLocalizations l10n;
  final int index;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    final photo = item;
    final asset = photo.asset;
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        key: ValueKey('tween-dup-${asset.id}'),
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
        child: Container(
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
                onTap: () => onToggle(asset.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FutureBuilder<Uint8List?>(
                            future: asset.thumbnailDataWithSize(
                              const pm.ThumbnailSize(400, 400),
                              quality: 85,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
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
                              if (snapshot.hasData && snapshot.data != null) {
    return Stack(
                                  fit: StackFit.expand,
      children: [
                                    Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                      cacheWidth: 400,
                                      cacheHeight: 400,
                                      gaplessPlayback: true,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: theme
                                                  .colorScheme
                                                  .errorContainer,
                                              child: Icon(
                                                Icons.broken_image,
                                                color: theme
                                                    .colorScheme
                                                    .onErrorContainer,
                                              ),
                                            );
                                          },
                                    ),
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.black.withValues(
                                            alpha: 0.55,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          DateFormat(
                                            'dd.MM.yyyy',
                                          ).format(asset.createDateTime),
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.black.withValues(
                                            alpha: 0.55,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${photo.sizeMB.toStringAsFixed(1)} MB',
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Container(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.photo,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              );
                            },
                          ),
                          BlocBuilder<DuplicateSelectionCubit, Set<String>>(
                            buildWhen: (previous, current) {
                              final wasSelected = previous.contains(asset.id);
                              final isSelected = current.contains(asset.id);
                              return wasSelected != isSelected;
                            },
                            builder: (context, selectedIds) {
                              final isSelected = selectedIds.contains(asset.id);
                              if (!isSelected) {
                                return const SizedBox.shrink();
                              }
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.error,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
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
  }
}

/// Grup kartı: açılır/kapanır başlık (sağ üst ikon) + gruptaki fotoğrafların seçilebilir grid'i
class _DuplicateGroupCard extends StatefulWidget {
  const _DuplicateGroupCard({
    super.key,
    required this.group,
    required this.theme,
    required this.l10n,
  });

  final DuplicatePhotoGroup group;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  State<_DuplicateGroupCard> createState() => _DuplicateGroupCardState();
}

class _DuplicateGroupCardState extends State<_DuplicateGroupCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final theme = widget.theme;
    final l10n = widget.l10n;
    final toDelete = group.duplicatesToDelete;
    if (toDelete.isEmpty) return const SizedBox.shrink();
    final sizePerPhoto = group.spaceToSaveMB / group.duplicateCount;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.4),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha:0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık satırı: sol tarafta metin, sağ üstte aç/kapa ikonu
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
              child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                  Icon(
                        Icons.collections_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                      ),
                  const SizedBox(width: 8),
                    Expanded(
                    child: Text(
                      '${group.duplicateCount} ${l10n.photoUnit} • ${group.spaceToSaveMB.toStringAsFixed(1)} MB',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 24,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxH = constraints.maxHeight.clamp(
                          0.0,
                          double.infinity,
                        );
                        if (maxH <= 0) {
                          return const SizedBox(height: 0);
                        }
                        const crossAxisCount = 2;
                        const crossAxisSpacing = 8.0;
                        const mainAxisSpacing = 8.0;
                        const childAspectRatio = 0.8;
                        final width = constraints.maxWidth.clamp(
                          0.0,
                          double.infinity,
                        );
                        if (width <= 0) {
                          return const SizedBox(height: 0);
                        }
                        final cellWidth =
                            (width - (crossAxisCount - 1) * crossAxisSpacing) /
                            crossAxisCount;
                        final cellHeight = cellWidth / childAspectRatio;
                        final rowCount = (toDelete.length / crossAxisCount)
                            .ceil();
                        final gridHeight =
                            (rowCount * cellHeight +
                                    (rowCount - 1) * mainAxisSpacing)
                                .clamp(0.0, double.infinity);
                        final safeHeight = gridHeight.clamp(0.0, maxH);

                        return SizedBox(
                          height: safeHeight,
                          child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: crossAxisSpacing,
                                  mainAxisSpacing: mainAxisSpacing,
                                  childAspectRatio: childAspectRatio,
                                ),
                            itemCount: toDelete.length,
                            itemBuilder: (context, index) {
                              final asset = toDelete[index];
                              final item = _DuplicatePhotoItem(
                                asset,
                                sizePerPhoto,
                              );
                              final duplicateCubit = context
                                  .read<DuplicateSelectionCubit>();
                              return _DuplicatePhotoGridItem(
                                key: ValueKey(asset.id),
                                item: item,
                                theme: theme,
                                l10n: l10n,
                                index: index,
                                onToggle: duplicateCubit.toggleSelection,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  )
                : const SizedBox(height: 0),
            ),
          ],
        ),
    );
  }
}

/// Duplicate sonuçları için düz liste öğesi (blur ile aynı yapı)
class _DuplicatePhotoItem {
  const _DuplicatePhotoItem(this.asset, this.sizeMB);
  final pm.AssetEntity asset;
  final double sizeMB;
}

class _DuplicateResultsTab extends StatefulWidget {
  final DuplicateDetectionState state;

  const _DuplicateResultsTab({required this.state});

  @override
  State<_DuplicateResultsTab> createState() => _DuplicateResultsTabState();
}

class _DuplicateResultsTabState extends State<_DuplicateResultsTab> {
  List<DuplicatePhotoGroup> get _allGroups {
    final list = <DuplicatePhotoGroup>[];
    final seenHashes = <String>{};
    for (final entry in widget.state.duplicatesByAlbum.entries) {
      for (final group in entry.value) {
        if (group.duplicatesToDelete.isEmpty) continue;
        // Aynı grup farklı albüm entry'lerinde yer alıyorsa tekrarı engelle
        if (seenHashes.add(group.hash)) {
          list.add(group);
        }
      }
    }
    return list;
  }

  /// Tüm duplicate fotoğraf id'leri (selectAll için)
  List<String> get _allPhotoIds {
    final ids = <String>[];
    for (final group in _allGroups) {
      for (final asset in group.duplicatesToDelete) {
        ids.add(asset.id);
      }
    }
    return ids;
  }

  /// Seçili toplam MB hesaplamak için asset id -> sizeMB
  Map<String, double> get _assetToSizeMB {
    final map = <String, double>{};
    for (final group in _allGroups) {
      if (group.duplicateCount == 0) continue;
      final sizePerPhoto = group.spaceToSaveMB / group.duplicateCount;
      for (final asset in group.duplicatesToDelete) {
        map[asset.id] = sizePerPhoto;
      }
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final ids = _allPhotoIds;
      if (ids.isEmpty) return;
      context.read<DuplicateSelectionCubit>().selectAll(ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final groups = _allGroups;

    if (groups.isEmpty) {
      return _buildNoResultsView(context, theme, l10n, false);
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 100, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final group = groups[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _DuplicateGroupCard(
                      key: ValueKey(group.hash),
                      group: group,
                      theme: theme,
                      l10n: l10n,
                    ),
                  );
                }, childCount: groups.length),
              ),
            ),
          ],
        ),
        BlocBuilder<DuplicateSelectionCubit, Set<String>>(
          builder: (context, selectedIds) {
            final selectedTotalMB = selectedIds.fold<double>(
              0.0,
              (sum, id) => sum + (_assetToSizeMB[id] ?? 0),
            );
            final selectedCount = selectedIds.length;
            return Stack(
              children: [
                Positioned(
                  left: 16,
                  right: 16,
                  top: 8,
                  child: _buildDuplicateTopBar(
                    context,
                    theme,
                    l10n,
                    selectedCount,
                    selectedTotalMB,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 32,
                  child: SafeArea(
                    child: _buildDuplicateDeleteButton(
                      context,
                      theme,
                      l10n,
                      selectedIds: selectedIds,
                      assetToSizeMB: _assetToSizeMB,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDuplicateTopBar(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    int selectedCount,
    double selectedTotalMB,
  ) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      opacity: selectedCount > 0 ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: selectedCount > 0 ? Offset.zero : const Offset(0, -0.15),
        child: AnimatedScale(
          scale: selectedCount > 0 ? 1.0 : 0.9,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: IgnorePointer(
            ignoring: selectedCount == 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
                    theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.98),
                    theme.colorScheme.surface.withValues(alpha:0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha:0.25),
                  width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha:0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
          ),
        ],
      ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha:0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 22,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
                        Text(
                          l10n.youWillBeSaved,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(alpha:0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutBack,
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: Row(
                            key: ValueKey(
                              'dup-summary-$selectedCount-${selectedTotalMB.toStringAsFixed(1)}',
                            ),
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                selectedCount.toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.photoUnit,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha:0.8),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                selectedTotalMB.toStringAsFixed(
                                  selectedTotalMB >= 100 ? 0 : 1,
                                ),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'MB',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha:0.8),
            ),
          ),
        ],
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
      ),
    );
  }

  Widget _buildDuplicateDeleteButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n, {
    required Set<String> selectedIds,
    required Map<String, double> assetToSizeMB,
  }) {
    return BlocBuilder<DeleteLimitCubit, AsyncValue<int>>(
      builder: (context, deleteLimitAsync) {
        final deleteLimit = deleteLimitAsync.maybeWhen(
          data: (limit) => limit,
          orElse: () => 0,
        );
        final hasRights = deleteLimit > 0;
        final count = selectedIds.length;
        final label = hasRights
            ? (count > 0 ? l10n.deletePhotos(count) : l10n.deleteAllDuplicates)
            : l10n.getUnlimitedDeletions;

        return AppThreeDButton(
          label: label,
          icon: hasRights
              ? Icons.delete_outline
              : Icons.workspace_premium_rounded,
          baseColor: AppColors.error,
          textColor: AppColors.white,
          fullWidth: true,
          height: 56,
          onPressed: () async {
            if (!hasRights) {
              context.push('/paywall');
              return;
            }
            final idsToDelete = List<String>.from(selectedIds);
            if (idsToDelete.isEmpty) return;

            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.deleteAllDuplicates),
                content: Text(
                  l10n.deleteAllDuplicatesMessage(idsToDelete.length),
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
                      side: BorderSide(color: AppColors.error, width: 1.5),
                    ),
                    child: Text(l10n.delete),
                  ),
                ],
              ),
            );

            if (confirmed != true || !context.mounted) return;

            final duplicateCubit = context.read<DuplicateDetectionCubit>();
            final deleteResult = await duplicateCubit
                .deleteSelectedDuplicateAssets(idsToDelete);
            if (context.mounted) {
              context.read<DuplicateSelectionCubit>().clear();
            }
            if (!context.mounted) return;

            final rootNavigatorContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;
            final deleteLimitCubit = context.read<DeleteLimitCubit>();
            await deleteLimitCubit.decrease(deleteResult.deletedCount);

            if (deleteResult.deletedCount > 0) {
              if (context.mounted) {
                await showDeleteSuccessDialog(
                  context,
                  deleteResult.deletedCount,
                  deletedSizeMB: deleteResult.deletedSizeMB,
                );
                final prefs = PreferencesService();
                final selectedAlbum = context
                    .read<SelectedAlbumCubit?>()
                    ?.state;
                await prefs.saveSwipeIndex(0, selectedAlbum?.id);
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    showDeleteSuccessDialog(
                      rootNavigatorContext,
                      deleteResult.deletedCount,
                      deletedSizeMB: deleteResult.deletedSizeMB,
                    );
                  } catch (_) {}
                });
              }
            }
          },
        );
      },
    );
  }

  Widget _buildNoResultsView(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    bool isBlur,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isBlur ? AppColors.primary : AppColors.secondary)
                        .withValues(alpha:0.15),
                    (isBlur ? AppColors.secondary : AppColors.primary)
                        .withValues(alpha:0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isBlur ? AppColors.primary : AppColors.secondary)
                        .withValues(alpha:0.2),
                    blurRadius: 40,
                    spreadRadius: 8,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: RadialGradient(
                          center: Alignment.topRight,
                          radius: 1.5,
                          colors: [
                            AppColors.accent.withValues(alpha:0.1),
                            AppColors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (isBlur ? AppColors.primary : AppColors.secondary)
                                  .withValues(alpha:0.1),
                          border: Border.all(
                            color:
                                (isBlur
                                        ? AppColors.primary
                                        : AppColors.secondary)
                                    .withValues(alpha:0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isBlur
                              ? Icons.image_not_supported_rounded
                              : Icons.collections_rounded,
                          size: 64,
                          color: isBlur
                              ? AppColors.primary
                              : AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              isBlur
                  ? l10n.noBlurryPhotosFoundTitle
                  : l10n.noDuplicatesFoundTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 28,
                letterSpacing: -0.8,
                color: theme.colorScheme.onSurface,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(
                    isBlur
                        ? l10n.scanCompletedSuccessfully
                        : l10n.scanCompletedSuccessfullyDuplicate,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.6,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isBlur
                        ? l10n.noBlurryPhotosFound
                        : l10n.noDuplicatePhotosFound,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                      height: 1.5,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Builder(
              builder: (context) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.primary.withValues(alpha:0.85),
                        AppColors.accent.withValues(alpha:0.75),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha:0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha:0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FilledButton.icon(
                    onPressed: () {
                      if (isBlur) {
                        context.read<BlurDetectionCubit>().clear();
                      } else {
                        context.read<DuplicateDetectionCubit>().clear();
                      }
                      context.pop();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    label: Text(
                      l10n.startNewScan,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                      minimumSize: const Size(240, 56),
                      backgroundColor: AppColors.transparent,
                      foregroundColor: AppColors.white,
                      shadowColor: AppColors.transparent,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

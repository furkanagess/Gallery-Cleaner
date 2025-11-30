import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/gallery_providers.dart';
import '../../application/blur_detection_provider.dart';
import '../../application/duplicate_detection_provider.dart';
import '../../../../core/models/blur_photo.dart';
import 'results_page_helpers.dart';

class ResultsPage extends StatelessWidget {
  final String resultType;

  const ResultsPage({super.key, required this.resultType});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final blurState = context.watch<BlurDetectionCubit>().state;
    final duplicateState = context.watch<DuplicateDetectionCubit>().state;

    // resultType'a göre hangi sonuçları göstereceğimizi belirle
    final isBlur = resultType == 'blur';
    final isDuplicate = resultType == 'duplicate';

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Swipe page'e geri dön (state'i temizleme - böylece "View Last Results" butonu görünür kalır)
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/swipe');
            }
          },
        ),
        title: Text(
          isBlur ? l10n.blurTab : l10n.duplicateTab,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: isBlur
          ? _BlurResultsTab(state: blurState)
          : isDuplicate
          ? _DuplicateResultsTab(state: duplicateState)
          : Center(
              child: Text(
                'Invalid result type: $resultType',
                style: theme.textTheme.bodyLarge,
              ),
            ),
    );
  }
}

class _BlurResultsTab extends StatelessWidget {
  final BlurDetectionState state;

  const _BlurResultsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final allPhotos = <BlurPhoto>[];
    for (final entry in state.blurryPhotosByAlbum.entries) {
      allPhotos.addAll(entry.value);
    }
    allPhotos.sort((a, b) => a.blurScore.compareTo(b.blurScore));

    if (allPhotos.isEmpty) {
      return _buildNoResultsView(context, theme, l10n, true);
    }

    return Stack(
      children: [
        // Main content with padding for floating button - scrollable
        CustomScrollView(
          slivers: [
            // Compact Stats Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCompactStatCard(
                        theme,
                        Icons.photo_library_rounded,
                        '${allPhotos.length}',
                        l10n.photo,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCompactStatCard(
                        theme,
                        Icons.storage_rounded,
                        '${state.totalSpaceToSaveMB.toStringAsFixed(1)} MB',
                        l10n.spaceToSave,
                        AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Photos Grid with bottom padding for floating button
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverToBoxAdapter(
                child: buildBlurGridView(
                  context,
                  allPhotos,
                  theme,
                  l10n,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                ),
              ),
            ),
          ],
        ),
        // Floating Delete Button
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Builder(
              builder: (context) {
                final hasPhotosToDelete = allPhotos.isNotEmpty;
                if (!hasPhotosToDelete) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: _buildDeleteButton(context, theme, l10n, allPhotos),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStatCard(
    ThemeData theme,
    IconData icon,
    String value,
    String label,
    Color accentColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(isDark ? 0.18 : 0.1),
            accentColor.withOpacity(isDark ? 0.12 : 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(isDark ? 0.25 : 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isDark ? 0.15 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<BlurPhoto> allPhotos,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppColors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.deleteAllBlurryPhotos),
                content: Text(
                  l10n.deleteAllBlurryPhotosMessage(allPhotos.length),
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

            // BLoC kullanarak blur fotoğraflarını sil
            final blurCubit = context.read<BlurDetectionCubit>();
            final deletedCount = await blurCubit.deleteAllBlurryPhotos();

            if (!context.mounted) return;

            // Root navigator context'ini kaydet - widget rebuild edilirse context kaybolabilir
            final rootNavigatorContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;

            // Delete limit'i azalt
            final deleteLimitCubit = context.read<DeleteLimitCubit>();
            await deleteLimitCubit.decrease(deletedCount);

            // Cleanup complete dialogunu göster
            debugPrint(
              '🎯 [ResultsPage] Blur - About to show delete success dialog - deletedCount: $deletedCount, context.mounted: ${context.mounted}',
            );

            // Context mounted kontrolünü decrease'dan sonra tekrar yap
            if (deletedCount > 0) {
              // Önce normal context'i kontrol et
              if (context.mounted) {
                debugPrint(
                  '✅ [ResultsPage] Blur - Context is mounted and deletedCount > 0, calling showDeleteSuccessDialog...',
                );
                await showDeleteSuccessDialog(context, deletedCount);
                debugPrint(
                  '✅ [ResultsPage] Blur - showDeleteSuccessDialog completed',
                );
              } else {
                // Context unmount olmuşsa, root navigator context'ini kullan
                debugPrint(
                  '⚠️ [ResultsPage] Blur - Context not mounted after decrease, using rootNavigator context...',
                );
                // Bir sonraki frame'de root context ile dene
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    showDeleteSuccessDialog(rootNavigatorContext, deletedCount);
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
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.deleteAllBlurryPhotos),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: AppColors.error,
            foregroundColor: theme.colorScheme.onError,
            side: BorderSide(color: AppColors.error, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
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
                        .withOpacity(0.15),
                    (isBlur ? AppColors.secondary : AppColors.primary)
                        .withOpacity(0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isBlur ? AppColors.primary : AppColors.secondary)
                        .withOpacity(0.2),
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
                            AppColors.accent.withOpacity(0.1),
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
                                  .withOpacity(0.1),
                          border: Border.all(
                            color:
                                (isBlur
                                        ? AppColors.primary
                                        : AppColors.secondary)
                                    .withOpacity(0.3),
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
                        AppColors.primary.withOpacity(0.85),
                        AppColors.accent.withOpacity(0.75),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
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

class _DuplicateResultsTab extends StatelessWidget {
  final DuplicateDetectionState state;

  const _DuplicateResultsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final albumEntries = state.duplicatesByAlbum.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    if (albumEntries.isEmpty) {
      return _buildNoResultsView(context, theme, l10n, false);
    }

    return Stack(
      children: [
        // Main content with padding for floating button - scrollable
        CustomScrollView(
          slivers: [
            // Modern Stats Cards with gradient
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedStatCard(
                        theme,
                        Icons.collections_rounded,
                        '${state.totalGroups}',
                        l10n.group,
                        AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildEnhancedStatCard(
                        theme,
                        Icons.photo_library_rounded,
                        '${state.totalDuplicatePhotos}',
                        l10n.photo,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildEnhancedStatCard(
                        theme,
                        Icons.storage_rounded,
                        '${state.totalSpaceToSaveMB.toStringAsFixed(1)} MB',
                        l10n.spaceToSave,
                        AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Duplicate Grid with bottom padding for floating button
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverToBoxAdapter(
                child: buildDuplicateGrid(
                  context,
                  state,
                  theme,
                  l10n,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                ),
              ),
            ),
          ],
        ),
        // Floating Delete Button
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Builder(
              builder: (context) {
                final hasPhotosToDelete = state.totalDuplicatePhotos > 0;
                if (!hasPhotosToDelete) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: _buildDeleteButton(context, theme, l10n, state),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedStatCard(
    ThemeData theme,
    IconData icon,
    String value,
    String label,
    Color accentColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 140, // Sabit yükseklik
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(isDark ? 0.2 : 0.12),
            accentColor.withOpacity(isDark ? 0.15 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withOpacity(isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isDark ? 0.2 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppColors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(isDark ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    DuplicateDetectionState state,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppColors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.deleteAllDuplicates),
                content: Text(
                  l10n.deleteAllDuplicatesMessage(state.totalDuplicatePhotos),
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

            // BLoC kullanarak duplicate fotoğrafları sil
            final duplicateCubit = context.read<DuplicateDetectionCubit>();
            final deletedCount = await duplicateCubit.deleteAllDuplicates();

            if (!context.mounted) return;

            // Root navigator context'ini kaydet - widget rebuild edilirse context kaybolabilir
            final rootNavigatorContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;

            // Delete limit'i azalt
            final deleteLimitCubit = context.read<DeleteLimitCubit>();
            await deleteLimitCubit.decrease(deletedCount);

            // Cleanup complete dialogunu göster
            debugPrint(
              '🎯 [ResultsPage] Duplicate - About to show delete success dialog - deletedCount: $deletedCount, context.mounted: ${context.mounted}',
            );

            // Context mounted kontrolünü decrease'dan sonra tekrar yap
            if (deletedCount > 0) {
              // Önce normal context'i kontrol et
              if (context.mounted) {
                debugPrint(
                  '✅ [ResultsPage] Duplicate - Context is mounted and deletedCount > 0, calling showDeleteSuccessDialog...',
                );
                await showDeleteSuccessDialog(context, deletedCount);
                debugPrint(
                  '✅ [ResultsPage] Duplicate - showDeleteSuccessDialog completed',
                );
              } else {
                // Context unmount olmuşsa, root navigator context'ini kullan
                debugPrint(
                  '⚠️ [ResultsPage] Duplicate - Context not mounted after decrease, using rootNavigator context...',
                );
                // Bir sonraki frame'de root context ile dene
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    showDeleteSuccessDialog(rootNavigatorContext, deletedCount);
                  } catch (e) {
                    debugPrint(
                      '❌ [ResultsPage] Duplicate - Error showing dialog with rootNavigator context: $e',
                    );
                  }
                });
              }
            } else {
              debugPrint(
                '⚠️ [ResultsPage] Duplicate - deletedCount is 0, dialog gösterilmeyecek',
              );
            }
          },
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.deleteAllDuplicates),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: AppColors.error,
            foregroundColor: theme.colorScheme.onError,
            side: BorderSide(color: AppColors.error, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
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
                        .withOpacity(0.15),
                    (isBlur ? AppColors.secondary : AppColors.primary)
                        .withOpacity(0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isBlur ? AppColors.primary : AppColors.secondary)
                        .withOpacity(0.2),
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
                            AppColors.accent.withOpacity(0.1),
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
                                  .withOpacity(0.1),
                          border: Border.all(
                            color:
                                (isBlur
                                        ? AppColors.primary
                                        : AppColors.secondary)
                                    .withOpacity(0.3),
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
                        AppColors.primary.withOpacity(0.85),
                        AppColors.accent.withOpacity(0.75),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
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

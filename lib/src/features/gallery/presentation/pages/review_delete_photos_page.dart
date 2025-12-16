import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:lottie/lottie.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../application/review_actions_controller.dart';
import '../../application/gallery_providers.dart'
    show
        ReviewDeleteSelectionCubit,
        DeleteLimitCubit,
        SelectedAlbumCubit,
        GalleryPagingCubit;
import '../../../../core/services/preferences_service.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_three_d_button.dart';
import '../../../../app/theme/app_theme.dart';

class ReviewDeletePhotosPage extends StatefulWidget {
  const ReviewDeletePhotosPage({super.key});

  @override
  State<ReviewDeletePhotosPage> createState() => _ReviewDeletePhotosPageState();
}

// Grid item widget'ı - rebuild optimizasyonu için ayrı widget
class _PhotoGridItem extends StatelessWidget {
  const _PhotoGridItem({
    super.key,
    required this.action,
    required this.onTap,
    required this.theme,
  });

  final PendingDeleteAction action;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Her item kendi selection state'ini dinler - sadece bu item rebuild olur
    return BlocBuilder<ReviewDeleteSelectionCubit, Set<String>>(
      buildWhen: (previous, current) {
        // Sadece bu item'ın seçim durumu değiştiğinde rebuild et
        final wasSelected = previous.contains(action.asset.id);
        final isSelected = current.contains(action.asset.id);
        return wasSelected != isSelected;
      },
      builder: (context, selectedIds) {
        final isSelected = selectedIds.contains(action.asset.id);
        final sizeMB = action.fileSizeBytes > 0
            ? action.fileSizeBytes / (1024 * 1024)
            : 0.0;

        return RepaintBoundary(
          child: AnimatedScale(
            scale: isSelected ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            child: GestureDetector(
              onTap: onTap,
              child: Stack(
                children: [
                  // Thumbnail - sadece bir kez build edilir
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FutureBuilder<Uint8List?>(
                        future: action.asset.thumbnailDataWithSize(
                          const ThumbnailSize(400, 400),
                          quality: 85,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              cacheWidth: 400,
                              cacheHeight: 400,
                              gaplessPlayback: true, // Flicker'ı önlemek için
                            );
                          }
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Seçim overlay'i - Sade border (daha sade)
                  if (isSelected)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error, width: 2),
                      ),
                    ),
                  // Boyut etiketi - sol alt
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${sizeMB.toStringAsFixed(sizeMB >= 100 ? 0 : 1)} MB',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  // Çöp kutusu ikonu - Sağ üstte (seçili fotoğraflar için)
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReviewDeletePhotosPageState extends State<ReviewDeletePhotosPage> {
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    // Başlangıçta tüm fotoğrafları seçili yap - route'u yavaşlatmamak için microtask kullan
    Future.microtask(() {
      if (!mounted) return;
      final pendingActions = context.read<ReviewActionsCubit>().state;
      final selectionCubit = context.read<ReviewDeleteSelectionCubit>();
      final allIds = pendingActions.map((action) => action.asset.id).toList();
      selectionCubit.selectAll(allIds);
    });
  }

  @override
  void dispose() {
    // Sayfa kapanırken seçimleri temizle
    context.read<ReviewDeleteSelectionCubit>().clear();
    super.dispose();
  }

  void _togglePhotoSelection(String photoId) {
    context.read<ReviewDeleteSelectionCubit>().toggleSelection(photoId);
  }

  Widget _buildSnowflakesBackground(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final random = math.Random();

    // Tema uyumlu renk paleti
    final List<Color> palette = isDark
        ? [
            Colors.white.withOpacity(0.75),
            theme.colorScheme.primary.withOpacity(0.82),
            theme.colorScheme.secondary.withOpacity(0.68),
          ]
        : [
            theme.colorScheme.primary.withOpacity(0.72),
            theme.colorScheme.secondary.withOpacity(0.65),
            Colors.white.withOpacity(0.6),
          ];

    return Stack(
      children: List.generate(20, (index) {
        final top = random.nextDouble() * 1000; // Random top position
        final left = random.nextDouble() * 400; // Random left position
        final opacity = 0.15 + random.nextDouble() * 0.45; // Random opacity
        final size = 18.0 + random.nextDouble() * 12.0; // Random size
        final rotationDeg = random.nextDouble() * 360; // Random rotation
        final color = palette[random.nextInt(palette.length)]; // Random color from palette

        return Positioned(
          top: top,
          left: left,
          child: Opacity(
            opacity: opacity.clamp(0.15, 0.8),
            child: Transform.rotate(
              angle: rotationDeg * math.pi / 180,
              child: Image.asset(
                'assets/new_year/snowflake.png',
                width: size,
                height: size,
                fit: BoxFit.contain,
                color: color,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
        );
      }),
    );
  }


  Future<void> _deleteSelectedPhotos() async {
    final selectedIds = context.read<ReviewDeleteSelectionCubit>().state;
    if (selectedIds.isEmpty || _isDeleting) return;

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pendingActions = context.read<ReviewActionsCubit>().state;

    // Seçili fotoğrafların toplam boyutu (MB)
    final selectedActions = pendingActions.where(
      (a) => selectedIds.contains(a.asset.id),
    );
    final totalBytes = selectedActions.fold<int>(
      0,
      (sum, a) => sum + a.fileSizeBytes,
    );
    final totalMB = totalBytes > 0 ? totalBytes / (1024 * 1024) : 0.0;
    final totalMBText = totalMB.toStringAsFixed(totalMB >= 100 ? 0 : 1);

    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.deletePhoto,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.deletePhotos(selectedIds.length),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  selectedIds.length.toString(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.photoUnit,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  totalMBText,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'MB',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.mbFreed(totalMBText),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n.cancel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              side: BorderSide(color: theme.colorScheme.error, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l10n.delete,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final reviewActionsCubit = context.read<ReviewActionsCubit>();
      final deleteLimitCubit = context.read<DeleteLimitCubit>();

      // Seçili olmayan fotoğrafları pending listesinden kaldır
      final pendingActions = reviewActionsCubit.state;
      final currentSelectedIds = context
          .read<ReviewDeleteSelectionCubit>()
          .state;
      final actionsToRemove = pendingActions
          .where((action) => !currentSelectedIds.contains(action.asset.id))
          .toList();

      for (final action in actionsToRemove) {
        await reviewActionsCubit.undoDecision(action.asset, wasKeep: false);
      }

      // Delete limit'i kontrol et
      final deleteLimit = await deleteLimitCubit.currentLimit();
      final selectedCount = currentSelectedIds.length;

      // Delete limit'e göre maksimum silinebilecek fotoğraf sayısını belirle
      final maxDeleteCount = deleteLimit < 999999999
          ? (selectedCount > deleteLimit ? deleteLimit : selectedCount)
          : selectedCount;

      if (maxDeleteCount < selectedCount) {
        // Limit aşıldı, kullanıcıya bildir
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleteLimitReached(maxDeleteCount)),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }

      // Silme işlemini başlat
      final deleteResult = await reviewActionsCubit.applyPendingDeletes(
        maxDeleteCount: maxDeleteCount,
      );

      if (deleteResult.deletedCount > 0) {
        // Delete limit'i azalt
        await deleteLimitCubit.decrease(deleteResult.deletedCount);

        if (mounted) {
          // Başarılı silme sonrası animasyonlu özet bottom sheet'ini göster
          // Dialog'u hemen göster ki "no photos to delete" ekranı görünmesin
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.transparent,
            isDismissible: false,
            enableDrag: false,
            builder: (sheetContext) {
              return _DeleteSummaryBottomSheet(
                deletedCount: deleteResult.deletedCount,
                deletedSizeMB: deleteResult.deletedSizeMB,
                onDone: () async {
                  Navigator.of(sheetContext).pop();
                  
                  if (mounted) {
                    // Kalan tüm pending actions'ları temizle
                    final remainingPendingActions = reviewActionsCubit.state;
                    if (remainingPendingActions.isNotEmpty) {
                      // Tüm kalan pending actions'ları undo et
                      for (final action in remainingPendingActions) {
                        await reviewActionsCubit.undoDecision(
                          action.asset,
                          wasKeep: false,
                        );
                      }
                    }

                    // Silinen fotoğrafları deckte tekrar görünmemesi için galeriyi yenile
                    try {
                      context.read<GalleryPagingCubit>().reload();
                    } catch (e) {
                      debugPrint('⚠️ [ReviewDeletePhotosPage] Gallery reload failed: $e');
                    }

                    // Swipe tab'ına geri dön ve swipe deck'i başa al
                    // Swipe index'ini 0 yap
                    final prefsService = PreferencesService();
                    final selectedAlbum = context.read<SelectedAlbumCubit>().state;
                    await prefsService.saveSwipeIndex(0, selectedAlbum?.id);

                    context.go('/swipe');
                  }
                },
              );
            },
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorOccurred),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [ReviewDeletePhotosPage] Silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurred),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/new_year/santa-claus.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.reviewDeletePhotos,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: theme.colorScheme.onBackground,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(
            Platform.isIOS
                ? CupertinoIcons.chevron_back
                : Icons.arrow_back_rounded,
            color: theme.colorScheme.onBackground,
          ),
          onPressed: () => context.go('/swipe'),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // New Year snowflakes background
          Positioned.fill(
            child: _buildSnowflakesBackground(theme),
          ),
          BlocBuilder<ReviewActionsCubit, List<PendingDeleteAction>>(
            builder: (context, pendingActions) {
              if (pendingActions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 70,
                            color: theme.colorScheme.primary.withOpacity(0.18),
                          ),
                          Image.asset(
                            'assets/new_year/christmas-tree.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noPhotosToDelete,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return BlocBuilder<ReviewDeleteSelectionCubit, Set<String>>(
                builder: (context, selectedIds) {
                  // Seçili fotoğraf sayısı ve toplam boyut (MB)
                  final selectedCount = selectedIds.length;
                  final selectedActions = pendingActions.where(
                    (a) => selectedIds.contains(a.asset.id),
                  );
                  final totalBytes = selectedActions.fold<int>(
                    0,
                    (sum, a) => sum + a.fileSizeBytes,
                  );
                  final totalMB = totalBytes > 0
                      ? totalBytes / (1024 * 1024)
                      : 0.0;
                  final totalMBText = totalMB.toStringAsFixed(
                    totalMB >= 100 ? 0 : 1,
                  );

                  return Stack(
                    children: [
                      // GridView - Fotoğraflar
                      GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 100, 16, 100),
                        cacheExtent:
                            500, // Cache extent'i artır - daha hızlı scroll
                        addAutomaticKeepAlives:
                            false, // Görünmeyen item'ları dispose et
                        addRepaintBoundaries:
                            true, // Her item için repaint boundary
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.0,
                            ),
                        itemCount: pendingActions.length,
                        itemBuilder: (context, index) {
                          final action = pendingActions[index];
                          final photoId = action.asset.id;

                          // Her item için unique key kullan - rebuild'i optimize et
                          return _PhotoGridItem(
                            key: ValueKey(photoId),
                            action: action,
                            onTap: () => _togglePhotoSelection(photoId),
                            theme: theme,
                          );
                        },
                      ),
                      // Üst bilgi barı - kaç fotoğraf ve kaç MB temizlenecek
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 8,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          opacity: selectedCount > 0 ? 1.0 : 0.0,
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            offset: selectedCount > 0
                                ? Offset.zero
                                : const Offset(0, -0.15),
                            child: AnimatedScale(
                              scale: selectedCount > 0 ? 1.0 : 0.9,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutBack,
                              child: IgnorePointer(
                                ignoring: selectedCount == 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.98),
                                        theme.colorScheme.surface.withOpacity(
                                          0.96,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.25),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.shadow
                                            .withOpacity(0.18),
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
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.16),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Image.asset(
                                          'assets/new_year/snowman.png',
                                          width: 22,
                                          height: 22,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              l10n.youWillBeSaved,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.7),
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              transitionBuilder:
                                                  (child, animation) {
                                                    return FadeTransition(
                                                      opacity: animation,
                                                      child: ScaleTransition(
                                                        scale: CurvedAnimation(
                                                          parent: animation,
                                                          curve: Curves
                                                              .easeOutBack,
                                                        ),
                                                        child: child,
                                                      ),
                                                    );
                                                  },
                                              child: Row(
                                                key: ValueKey(
                                                  'summary-$selectedCount-$totalMBText',
                                                ),
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.baseline,
                                                textBaseline:
                                                    TextBaseline.alphabetic,
                                                children: [
                                                  Text(
                                                    selectedCount.toString(),
                                                    style: theme
                                                        .textTheme
                                                        .headlineSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    l10n.photoUnit,
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface
                                                              .withOpacity(0.8),
                                                        ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    totalMBText,
                                                    style: theme
                                                        .textTheme
                                                        .headlineSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: theme
                                                              .colorScheme
                                                              .error,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'MB',
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface
                                                              .withOpacity(0.8),
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
                        ),
                      ),
                      // Silme butonu - Stack ile havada (daha yukarıda)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 32,
                        child:
                            BlocBuilder<
                              ReviewActionsCubit,
                              List<PendingDeleteAction>
                            >(
                              builder: (context, pendingActions) {
                                if (selectedCount == 0 ||
                                    pendingActions.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                final errorColor =
                                    Theme.of(
                                      context,
                                    ).extension<AppSemanticColors>()?.delete ??
                                    Theme.of(context).colorScheme.error;

                                final deleteLimitCubit =
                                    context.watch<DeleteLimitCubit>();
                                final currentLimit =
                                    deleteLimitCubit.state.maybeWhen(
                                  data: (limit) => limit,
                                  orElse: () => 0,
                                );

                                final bool hasRights = currentLimit > 0;
                                final label = !hasRights
                                    ? l10n.noRightsLeft
                                    : _isDeleting
                                    ? l10n.deleting
                                    : l10n.delete;

                                return AppThreeDButton(
                                  label: label,
                                  icon: _isDeleting
                                      ? null
                                      : Icons.delete_outline_rounded,
                                  onPressed: _isDeleting
                                      ? () {}
                                      : () {
                                          if (!hasRights) {
                                            context.push('/paywall');
                                            return;
                                          }
                                          _deleteSelectedPhotos();
                                        },
                                  baseColor: errorColor,
                                  textColor: AppColors.white,
                                  fullWidth: true,
                                  height: 56,
                                  fontSize: 14,
                                );
                              },
                            ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeleteSummaryBottomSheet extends StatefulWidget {
  const _DeleteSummaryBottomSheet({
    required this.deletedCount,
    required this.deletedSizeMB,
    required this.onDone,
  });

  final int deletedCount;
  final double deletedSizeMB;
  final VoidCallback onDone;

  @override
  State<_DeleteSummaryBottomSheet> createState() => _DeleteSummaryBottomSheetState();
}

class _DeleteSummaryBottomSheetState extends State<_DeleteSummaryBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _countAnimation;
  late final Animation<double> _sizeAnimation;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _countAnimation = Tween<double>(
      begin: 0,
      end: widget.deletedCount.toDouble(),
    ).animate(curved);

    _sizeAnimation = Tween<double>(
      begin: 0,
      end: widget.deletedSizeMB,
    ).animate(curved);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _showConfetti = true;
        });
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDialogSnowflakes(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final random = math.Random();

    // Tema uyumlu renk paleti (daha hafif opacity)
    final List<Color> palette = isDark
        ? [
            Colors.white.withOpacity(0.5),
            theme.colorScheme.primary.withOpacity(0.55),
            theme.colorScheme.secondary.withOpacity(0.45),
          ]
        : [
            theme.colorScheme.primary.withOpacity(0.48),
            theme.colorScheme.secondary.withOpacity(0.43),
            Colors.white.withOpacity(0.4),
          ];

    return Opacity(
      opacity: 0.18,
      child: Stack(
        children: List.generate(15, (index) {
          final top = random.nextDouble() * 300; // Random top position
          final left = random.nextDouble() * 300; // Random left position
          final opacity = 0.1 + random.nextDouble() * 0.3; // Random opacity
          final size = 14.0 + random.nextDouble() * 10.0; // Random size
          final rotationDeg = random.nextDouble() * 360; // Random rotation
          final color = palette[random.nextInt(palette.length)]; // Random color from palette

          return Positioned(
            top: top,
            left: left,
            child: Opacity(
              opacity: opacity.clamp(0.1, 0.6),
              child: Transform.rotate(
                angle: rotationDeg * math.pi / 180,
                child: Image.asset(
                  'assets/new_year/snowflake.png',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  color: color,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface.withOpacity(0.98),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.98),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: Stack(
          children: [
            // Hafif kar efekti arka plan
            Positioned.fill(
              child: _buildDialogSnowflakes(theme),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(
                              0.12,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Image.asset(
                            'assets/new_year/christmas-tree.png',
                            width: 26,
                            height: 26,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.cleanupCompleteMessage,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final animatedCount = _countAnimation.value
                            .round()
                            .clamp(0, widget.deletedCount);
                        final animatedMB = _sizeAnimation.value.clamp(
                          0.0,
                          widget.deletedSizeMB,
                        );
                        final sizeText = animatedMB.toStringAsFixed(
                          animatedMB >= 100 ? 0 : 1,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  animatedCount.toString(),
                                  style: theme.textTheme.displaySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: theme.colorScheme.primary,
                                      ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.photoUnit,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.8),
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  sizeText,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.error,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'MB',
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.8),
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.mbFreed(sizeText),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.75),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: widget.onDone,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          foregroundColor: theme.colorScheme.primary,
                        ),
                        child: Text(
                          l10n.done,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showConfetti)
              Positioned(
                top: -40,
                left: -10,
                right: -10,
                height: 160,
                child: IgnorePointer(
                  child: Lottie.asset(
                    'assets/lottie/Confeti.json',
                    fit: BoxFit.cover,
                    repeat: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

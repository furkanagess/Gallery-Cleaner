import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../application/review_actions_controller.dart';
import '../../application/gallery_providers.dart'
    show ReviewDeleteSelectionCubit, DeleteLimitCubit;
import '../../../../app/theme/app_colors.dart';

class ReviewDeletePhotosPage extends StatefulWidget {
  const ReviewDeletePhotosPage({super.key});

  @override
  State<ReviewDeletePhotosPage> createState() => _ReviewDeletePhotosPageState();
}

class _ReviewDeletePhotosPageState extends State<ReviewDeletePhotosPage>
    with TickerProviderStateMixin {
  bool _isDeleting = false;

  // 3D buton animasyon controller'ı
  late AnimationController _deleteButtonController;
  late Animation<double> _deleteButtonScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Delete butonu animasyon controller'ı
    _deleteButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _deleteButtonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _deleteButtonController, curve: Curves.easeInOut),
    );

    // Başlangıçta tüm fotoğrafları seçili yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingActions = context.read<ReviewActionsCubit>().state;
      final selectionCubit = context.read<ReviewDeleteSelectionCubit>();
      final allIds = pendingActions.map((action) => action.asset.id).toList();
      selectionCubit.selectAll(allIds);
    });
  }

  @override
  void dispose() {
    _deleteButtonController.dispose();
    // Sayfa kapanırken seçimleri temizle
    context.read<ReviewDeleteSelectionCubit>().clear();
    super.dispose();
  }

  void _togglePhotoSelection(String photoId) {
    context.read<ReviewDeleteSelectionCubit>().toggleSelection(photoId);
  }

  Future<void> _deleteSelectedPhotos() async {
    final selectedIds = context.read<ReviewDeleteSelectionCubit>().state;
    if (selectedIds.isEmpty || _isDeleting) return;

    final l10n = AppLocalizations.of(context)!;

    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePhoto),
        content: Text(l10n.deletePhotos(selectedIds.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.delete),
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
          // Başarı mesajı göster
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.deletedSuccessfully(deleteResult.deletedCount),
              ),
              backgroundColor: AppColors.success,
            ),
          );

          // Geri dön
          context.pop();
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
        title: Text(l10n.reviewDeletePhotos),
        leading: IconButton(
          icon: Platform.isIOS
              ? const Icon(CupertinoIcons.chevron_left)
              : const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<ReviewActionsCubit, List<PendingDeleteAction>>(
        builder: (context, pendingActions) {
          if (pendingActions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noPhotosToDelete,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return BlocBuilder<ReviewDeleteSelectionCubit, Set<String>>(
            builder: (context, selectedIds) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: pendingActions.length,
                itemBuilder: (context, index) {
                  final action = pendingActions[index];
                  final photoId = action.asset.id;
                  final isSelected = selectedIds.contains(photoId);

                  return GestureDetector(
                    onTap: () => _togglePhotoSelection(photoId),
                    child: Stack(
                      children: [
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
                        // Seçim overlay'i - Kırmızı border
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.error
                                    : Colors.transparent,
                                width: 3,
                              ),
                              color: isSelected
                                  ? AppColors.error.withOpacity(0.2)
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                        // Çöp kutusu ikonu (seçili fotoğraflar için)
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton:
          BlocBuilder<ReviewDeleteSelectionCubit, Set<String>>(
            builder: (context, selectedIds) {
              return BlocBuilder<ReviewActionsCubit, List<PendingDeleteAction>>(
                builder: (context, pendingActions) {
                  final selectedCount = selectedIds.length;
                  if (selectedCount == 0 || pendingActions.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return AnimatedBuilder(
                    animation: _deleteButtonController,
                    builder: (context, child) {
                      final scale = _deleteButtonScaleAnimation.value;
                      final isPressed = scale < 1.0;

                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: isPressed
                                ? [
                                    // Basılı durumda - içe doğru gölge
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                      spreadRadius: 0,
                                    ),
                                  ]
                                : [
                                    // Normal durumda - daktilo tuşu gölgesi
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.4),
                                      blurRadius: 0,
                                      offset: const Offset(0, 6),
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.3),
                                      blurRadius: 0,
                                      offset: const Offset(0, 4),
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.2),
                                      blurRadius: 0,
                                      offset: const Offset(0, 2),
                                      spreadRadius: 0,
                                    ),
                                    // Alt derin gölge
                                    BoxShadow(
                                      color: AppColors.black.withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                      spreadRadius: 0,
                                    ),
                                  ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(28),
                              border: Border(
                                top: BorderSide(
                                  color: isPressed
                                      ? AppColors.black.withOpacity(0.3)
                                      : AppColors.white.withOpacity(0.6),
                                  width: isPressed ? 1.0 : 2.0,
                                ),
                                left: BorderSide(
                                  color: isPressed
                                      ? AppColors.black.withOpacity(0.3)
                                      : AppColors.white.withOpacity(0.6),
                                  width: isPressed ? 1.0 : 2.0,
                                ),
                                right: BorderSide(
                                  color: isPressed
                                      ? AppColors.white.withOpacity(0.3)
                                      : AppColors.black.withOpacity(0.4),
                                  width: isPressed ? 1.0 : 2.0,
                                ),
                                bottom: BorderSide(
                                  color: isPressed
                                      ? AppColors.white.withOpacity(0.3)
                                      : AppColors.black.withOpacity(0.4),
                                  width: isPressed ? 1.0 : 2.0,
                                ),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTapDown: (_) {
                                  if (!_isDeleting) {
                                    _deleteButtonController.forward();
                                  }
                                },
                                onTapUp: (_) {
                                  _deleteButtonController.reverse();
                                  if (!_isDeleting) {
                                    _deleteSelectedPhotos();
                                  }
                                },
                                onTapCancel: () {
                                  _deleteButtonController.reverse();
                                },
                                borderRadius: BorderRadius.circular(28),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _isDeleting
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.delete,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isDeleting
                                            ? l10n.deleting
                                            : l10n.deletePhotos(selectedCount),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
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
                },
              );
            },
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

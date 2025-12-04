import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../application/gallery_providers.dart';
import '../../../../../application/review_history_controller.dart';
import '../../../../../../../../src/core/services/media_library_service.dart';
import '../../../../../../../../src/core/services/preferences_service.dart';
import '../../../../../../../../src/app/theme/app_colors.dart' show AppColors;
import '../../../../../../../../l10n/app_localizations.dart' show AppLocalizations;
import 'album_selection_sheet.dart';

// Helper function to check if a global position is over a widget's bounds
bool isPositionOverWidget(GlobalKey key, Offset globalPosition) {
  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return false;

  final widgetPosition = renderBox.localToGlobal(Offset.zero);
  final widgetSize = renderBox.size;

  return globalPosition.dx >= widgetPosition.dx &&
      globalPosition.dx <= widgetPosition.dx + widgetSize.width &&
      globalPosition.dy >= widgetPosition.dy &&
      globalPosition.dy <= widgetPosition.dy + widgetSize.height;
}

// Helper function to get widget center position in global coordinates
Offset? getWidgetCenter(GlobalKey key) {
  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return null;

  final widgetPosition = renderBox.localToGlobal(Offset.zero);
  final widgetSize = renderBox.size;

  return Offset(
    widgetPosition.dx + widgetSize.width / 2,
    widgetPosition.dy + widgetSize.height / 2,
  );
}

int topIndexHint(List<pm.AssetEntity> list, pm.AssetEntity current) {
  return list.indexWhere((e) => e.id == current.id);
}

// Public wrapper for maybePrefetch
void maybePrefetch(
  BuildContext context,
  List<pm.AssetEntity> assets,
  pm.AssetEntity current,
) {
  if (assets.length - topIndexHint(assets, current) < 6) {
    context.read<GalleryPagingCubit>().loadMore();
  }
}

// Public wrapper for showAlbumSelectionDialog
Future<void> showAlbumSelectionDialog(
  BuildContext context,
  pm.AssetEntity asset,
  List<pm.AssetEntity> assets,
) async {
  debugPrint('📁 [SwipePage] Albüm seçim dialogu açılıyor');

  final albumsAsync = context.read<AlbumsCubit>().state;

  // Albümleri bekle
  final albums = albumsAsync.when(
    data: (albums) {
      final filtered = albums.where((a) => !a.isAll).toList();
      debugPrint('📁 [SwipePage] ${filtered.length} albüm bulundu');
      return filtered;
    },
    loading: () {
      debugPrint('📁 [SwipePage] Albümler yükleniyor...');
      return <pm.AssetPathEntity>[];
    },
    error: (error, stack) {
      debugPrint('📁 [SwipePage] Albüm yükleme hatası: $error');
      return <pm.AssetPathEntity>[];
    },
  );

  if (!context.mounted) {
    debugPrint('📁 [SwipePage] Context unmounted, dialog açılmıyor');
    return;
  }

  if (albums.isEmpty) {
    debugPrint('📁 [SwipePage] Albüm bulunamadı');
    return;
  }

  debugPrint('📁 [SwipePage] Albüm seçim dialogu gösteriliyor...');

  // Albüm seçim dialogunu göster
  final selectedAlbum = await showModalBottomSheet<pm.AssetPathEntity>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.transparent,
    builder: (context) => AlbumSelectionSheet(albums: albums),
  );

  debugPrint('📁 [SwipePage] Seçilen albüm: ${selectedAlbum?.name ?? "null"}');

  if (selectedAlbum != null && context.mounted) {
    debugPrint(
      '📁 [SwipePage] Albüme taşıma işlemi başlatılıyor: ${asset.id} -> ${selectedAlbum.name}',
    );
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Seçilen albüme taşı
    bool ok = false;
    try {
      ok = await context.read<MediaLibraryService>().moveAssetToAlbum(
        asset: asset,
        album: selectedAlbum,
      );
      debugPrint('📁 [SwipePage] moveAssetToAlbum sonucu: $ok');
    } catch (e, st) {
      debugPrint('🛑 [SwipePage] moveAssetToAlbum exception: $e');
      debugPrint('🛑 [SwipePage] Stack trace: $st');
      ok = false;
    }

    if (ok && context.mounted) {
      debugPrint(
        '✅ [SwipePage] Albüme taşıma başarılı: ${asset.id} → ${selectedAlbum.id}',
      );

      await context.read<ReviewHistoryCubit>().addMoveFromAsset(
        asset,
        selectedAlbum.id,
      );

      // Başarı haptic feedback
      HapticFeedback.lightImpact();

      maybePrefetch(context, assets, asset);
    } else if (context.mounted) {
      debugPrint(
        '❌ [SwipePage] Albüme taşıma BAŞARISIZ: ${asset.id} → ${selectedAlbum.id}',
      );
      // Hata haptic feedback
      HapticFeedback.heavyImpact();
    }
  }
}

/// Rate us dialog'unu göster
Future<void> showRateUsDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final prefsService = PreferencesService();

  // Store URLs
  const playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.furkanages.gallerycleaner';
  const appStoreUrl =
      'https://apps.apple.com/us/app/gallery-cleaner-swipe-photo/id6754893118';

  Future<void> openStore() async {
    final url = Platform.isAndroid ? playStoreUrl : appStoreUrl;
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Store'a gidildiyse dialog'un gösterildiğini işaretle
        await prefsService.setRateUsDialogShown();
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.couldNotOpenStore),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [RateUsDialog] Error opening store: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.couldNotOpenStore),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: AppColors.black.withOpacity(0.5),
    builder: (dialogContext) => _RateUsDialogContent(
      l10n: l10n,
      theme: theme,
      prefsService: prefsService,
      onRate: openStore,
      onDismiss: () {
        Navigator.of(dialogContext).pop();
        prefsService.setRateUsDialogShown();
      },
    ),
  );
}

class _RateUsDialogContent extends StatefulWidget {
  const _RateUsDialogContent({
    required this.l10n,
    required this.theme,
    required this.prefsService,
    required this.onRate,
    required this.onDismiss,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final PreferencesService prefsService;
  final VoidCallback onRate;
  final VoidCallback onDismiss;

  @override
  State<_RateUsDialogContent> createState() => _RateUsDialogContentState();
}

class _RateUsDialogContentState extends State<_RateUsDialogContent> {
  int _selectedStars = 0;
  bool _hasRated = false;

  void _handleStarTap(int stars) {
    setState(() {
      _selectedStars = stars;
    });
    HapticFeedback.lightImpact();
  }

  void _handleSubmit() {
    if (_selectedStars == 0) {
      // Yıldız seçilmediyse kapat
      widget.onDismiss();
      return;
    }

    setState(() {
      _hasRated = true;
    });
    HapticFeedback.mediumImpact();

    // 4-5 yıldız ise store'a yönlendir
    if (_selectedStars >= 4) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onRate();
        }
      });
    } else {
      // Düşük yıldız ise teşekkür mesajı göster ve kapat
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onDismiss();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.theme.colorScheme.surface.withOpacity(0.95),
                widget.theme.colorScheme.surfaceContainerHighest.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.theme.colorScheme.outline.withOpacity(0.1),
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_hasRated) ...[
                  // Star icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.warning,
                          AppColors.warningLight,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warning.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Platform.isAndroid
                          ? Icons.star_rounded
                          : CupertinoIcons.star_fill,
                      color: AppColors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    widget.l10n.rateApp,
                    style: widget.theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Support message
                  Text(
                    widget.l10n.rateAppSupportMessage,
                    style: widget.theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Star rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      final isSelected = starIndex <= _selectedStars;
                      return GestureDetector(
                        onTap: () => _handleStarTap(starIndex),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: Icon(
                              Platform.isAndroid
                                  ? (isSelected
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded)
                                  : (isSelected
                                      ? CupertinoIcons.star_fill
                                      : CupertinoIcons.star),
                              color: isSelected
                                  ? AppColors.warning
                                  : widget.theme.colorScheme.onSurface
                                      .withOpacity(0.3),
                              size: 40,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  // Submit button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.warning.withOpacity(0.9),
                          AppColors.warningLight.withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warning.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: AppColors.transparent,
                      child: InkWell(
                        onTap: _handleSubmit,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 24,
                          ),
                          child: Text(
                            _selectedStars == 0
                                ? widget.l10n.maybeLater
                                : widget.l10n.done,
                            style: widget.theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.white,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Thank you message
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.secondary,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: AppColors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.l10n.thankYou,
                    style: widget.theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.l10n.thanksForFeedback,
                    style: widget.theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


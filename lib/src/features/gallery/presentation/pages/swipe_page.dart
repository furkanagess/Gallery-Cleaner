import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:lottie/lottie.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/services/preferences_service.dart';

import '../../application/gallery_providers.dart';
import '../../application/blur_detection_provider.dart';
import '../../application/duplicate_detection_provider.dart';
import '../../../onboarding/application/permissions_controller.dart';
import '../../../../core/models/blur_photo.dart';
import '../../../../core/models/duplicate_photo.dart';
import '../../../../core/services/rewarded_ads_service.dart';
import '../../../../core/services/interstitial_ads_service.dart';
import '../widgets/photo_swipe_deck.dart';
import '../../application/review_actions_controller.dart';
import '../../application/review_history_controller.dart';
import '../../application/gallery_stats_provider.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_decorations.dart';
import '../../../settings/presentation/settings_page.dart' as settings;
import '../../../settings/presentation/premium_after_ads_dialog.dart';
import '../../../settings/presentation/premium_success_dialog.dart';
import 'results_page_helpers.dart';

// Provider for tracking drag over "Change Album" zone
final _isDraggingOverChangeAlbumProvider = StateProvider<bool>((ref) => false);

// Shimmer widget for loading states
class _ShimmerWidget extends StatefulWidget {
  const _ShimmerWidget({
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final baseColor = brightness == Brightness.light
        ? Colors.grey[300]!
        : Colors.grey[800]!;
    final highlightColor = brightness == Brightness.light
        ? Colors.grey[100]!
        : Colors.grey[700]!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, 0.0),
              end: Alignment(1.0 - _controller.value * 2, 0.0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// Shimmer for photo cards (swipe tab)
class _PhotoCardShimmer extends StatelessWidget {
  const _PhotoCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: _ShimmerWidget(
            width: double.infinity,
            height: double.infinity,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// Shimmer for scan form (blur/duplicate tabs)
class _ScanFormShimmer extends StatelessWidget {
  const _ScanFormShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title shimmer
          _ShimmerWidget(
            width: 200,
            height: 24,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 24),
          // Description shimmer
          _ShimmerWidget(
            width: double.infinity,
            height: 16,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          _ShimmerWidget(
            width: double.infinity,
            height: 16,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 32),
          // Button shimmer
          _ShimmerWidget(
            width: double.infinity,
            height: 56,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(height: 16),
          // Estimated time shimmer
          _ShimmerWidget(
            width: 150,
            height: 40,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 12),
          // Warning shimmer
          _ShimmerWidget(
            width: double.infinity,
            height: 50,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }
}

// Helper function to check if a global position is over a widget's bounds
bool _isPositionOverWidget(GlobalKey key, Offset globalPosition) {
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
Offset? _getWidgetCenter(GlobalKey key) {
  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return null;

  final widgetPosition = renderBox.localToGlobal(Offset.zero);
  final widgetSize = renderBox.size;

  return Offset(
    widgetPosition.dx + widgetSize.width / 2,
    widgetPosition.dy + widgetSize.height / 2,
  );
}

Future<void> _presentAlbumPicker({
  required BuildContext context,
  required List<pm.AssetPathEntity> albums,
  required pm.AssetPathEntity? selectedAlbum,
  required ValueChanged<pm.AssetPathEntity?> onSelected,
}) async {
  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context)!;

  if (albums.isEmpty) {
    return;
  }

  final filteredAlbums = albums.where((album) => !album.isAll).toList();

  final selection = await showModalBottomSheet<pm.AssetPathEntity?>(
    context: context,
    backgroundColor: AppColors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              l10n.selectAlbumToView,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: Icon(
                    Icons.grid_view,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(l10n.allPhotos, overflow: TextOverflow.ellipsis),
                  trailing: selectedAlbum == null
                      ? Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(null),
                ),
                const Divider(height: 1),
                ...filteredAlbums.map((album) {
                  final isSelected = selectedAlbum?.id == album.id;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    leading: Icon(
                      Icons.folder,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    title: Text(album.name, overflow: TextOverflow.ellipsis),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(album),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  if (!context.mounted) return;
  onSelected(selection);
}

// ignore: unused_element
class _ChangeAlbumZone extends ConsumerWidget {
  const _ChangeAlbumZone({
    required this.onDragOver,
    required this.changeAlbumZoneKey,
  });

  final ValueChanged<bool> onDragOver;
  final GlobalKey changeAlbumZoneKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDraggingOver = ref.watch(_isDraggingOverChangeAlbumProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      key: changeAlbumZoneKey,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radial glow background when hovering
          AnimatedOpacity(
            opacity: isDraggingOver ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.95,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.12),
                    AppColors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          AnimatedScale(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            scale: isDraggingOver ? 1.03 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              // Container decoration kaldırıldı - sadece içerik gösteriliyor
              decoration: const BoxDecoration(
                color: AppColors.transparent, // Container arka planı kaldırıldı
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedRotation(
                    turns: isDraggingOver ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.photo_library_outlined,
                      size: 26,
                      color: isDraggingOver
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.changeAlbum,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isDraggingOver
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isDraggingOver
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface.withOpacity(0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.dragPhotoHere,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDraggingOver
                              ? theme.colorScheme.onPrimaryContainer
                                    .withOpacity(0.8)
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_upward,
                    size: 22,
                    color: isDraggingOver
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface.withOpacity(0.6),
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

class _AlbumSelectionSheet extends StatelessWidget {
  const _AlbumSelectionSheet({required this.albums});

  final List<pm.AssetPathEntity> albums;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              l10n.selectAlbum,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.folder,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(album.name, overflow: TextOverflow.ellipsis),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  onTap: () {
                    Navigator.of(context).pop(album);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeAreaContent extends ConsumerStatefulWidget {
  const _SwipeAreaContent({
    super.key,
    required this.assets,
    required this.changeAlbumZoneKey,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.onResetCallbackReady,
  });

  final List<pm.AssetEntity> assets;
  final GlobalKey changeAlbumZoneKey;
  final int initialIndex;
  final void Function(int index)? onIndexChanged;
  final void Function(VoidCallback resetCallback)? onResetCallbackReady;

  @override
  ConsumerState<_SwipeAreaContent> createState() => _SwipeAreaContentState();
}

class _SwipeAreaContentState extends ConsumerState<_SwipeAreaContent> {
  static const double _verticalActivationOffset = 16.0;
  static const double _verticalMaxTravel = 280.0;
  static const double _verticalMinScale = 0.58;
  static const double _verticalMinOpacity = 0.78;
  static const double _zoneMaxDistance = 400.0;
  static const double _zoneMinScale = 0.45;
  static const double _zoneMinOpacity = 0.65;

  double _dragScale = 1.0;
  double _dragOpacity = 1.0;
  Offset _dragOffset = Offset.zero;
  bool _isDraggingToAlbum = false;
  Offset? _dragStartPosition;
  bool _isDialogShowing = false;

  @override
  void didUpdateWidget(covariant _SwipeAreaContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldTopId = oldWidget.assets.isEmpty
        ? null
        : oldWidget.assets.first.id;
    final newTopId = widget.assets.isEmpty ? null : widget.assets.first.id;

    if (oldTopId != newTopId) {
      _resetVisuals();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Silme hakkı kontrolü - sadece limit değiştiğinde rebuild
    final canDelete = ref.watch(
      deleteLimitProvider.select(
        (asyncValue) => asyncValue.maybeWhen(
          data: (limit) => limit > 0,
          orElse: () =>
              true, // Loading veya error durumunda varsayılan olarak true
        ),
      ),
    );

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: AnimatedScale(
                scale: _dragScale,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                child: Transform.translate(
                  offset: _dragOffset,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PhotoSwipeDeck(
                        assets: widget.assets,
                        initialIndex: widget.initialIndex,
                        canDelete: canDelete,
                        isDraggingToAlbum: () => _isDraggingToAlbum,
                        onDragUpdate: _handleDragUpdate,
                        onDragEnd: (asset, pos) {
                          _handleDragEnd(asset, pos);
                        },
                        onDecision: (asset, decision) {
                          _handleDecision(asset, decision);
                        },
                        onNoRightsLeft: () {
                          _showNoRightsDialog(context);
                        },
                        onIndexChanged: widget.onIndexChanged,
                        onResetCallbackReady: widget.onResetCallbackReady,
                      ),
                      if (_dragOpacity < 1.0)
                        IgnorePointer(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            color: AppColors.black.withOpacity(
                              (1 - _dragOpacity) * 0.4,
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
      ),
    );
  }

  void _handleDragUpdate(Offset globalPos) {
    _dragStartPosition ??= globalPos;

    final changeAlbumZoneCenter = _getWidgetCenter(widget.changeAlbumZoneKey);
    final isOverChangeAlbumZone = _isPositionOverWidget(
      widget.changeAlbumZoneKey,
      globalPos,
    );

    double zoneScale = 1.0;
    double zoneOpacity = 1.0;
    Offset zoneOffset = Offset.zero;
    double distanceToZone = double.infinity;

    if (changeAlbumZoneCenter != null) {
      distanceToZone = (globalPos - changeAlbumZoneCenter).distance;

      if (isOverChangeAlbumZone) {
        zoneScale = _zoneMinScale;
        zoneOpacity = _zoneMinOpacity;

        final directionToCenter = changeAlbumZoneCenter - globalPos;
        zoneOffset = Offset(
          directionToCenter.dx * 0.1,
          directionToCenter.dy * 0.1,
        );
      } else if (distanceToZone < _zoneMaxDistance) {
        final normalizedDistance = (distanceToZone / _zoneMaxDistance).clamp(
          0.0,
          1.0,
        );
        final easedDistance = math.pow(normalizedDistance, 0.65).toDouble();

        zoneScale = _zoneMinScale + (easedDistance * (1.0 - _zoneMinScale));
        zoneScale = zoneScale.clamp(_zoneMinScale, 1.0);

        zoneOpacity =
            _zoneMinOpacity + (easedDistance * (1.0 - _zoneMinOpacity));
        zoneOpacity = zoneOpacity.clamp(_zoneMinOpacity, 1.0);

        final directionToCenter = changeAlbumZoneCenter - globalPos;
        final offsetIntensity = (1.0 - easedDistance) * 0.12;
        zoneOffset = Offset(
          directionToCenter.dx * offsetIntensity,
          directionToCenter.dy * offsetIntensity,
        );
      }
    }

    final upwardDragRaw = _dragStartPosition == null
        ? 0.0
        : (_dragStartPosition!.dy - globalPos.dy);
    final upwardDrag = math.max(0.0, upwardDragRaw);
    final effectiveDrag = math.max(0.0, upwardDrag - _verticalActivationOffset);
    final verticalRange = math.max(
      1.0,
      _verticalMaxTravel - _verticalActivationOffset,
    );
    final verticalProgress = (effectiveDrag / verticalRange).clamp(0.0, 1.0);
    final verticalFactor = math.pow(verticalProgress, 0.65).toDouble();

    final verticalScale = 1.0 - verticalFactor * (1.0 - _verticalMinScale);
    final verticalOpacity = 1.0 - verticalFactor * (1.0 - _verticalMinOpacity);

    ref.read(_isDraggingOverChangeAlbumProvider.notifier).state =
        isOverChangeAlbumZone;

    setState(() {
      _dragScale = math.min(zoneScale, verticalScale);
      _dragOpacity = math.min(zoneOpacity, verticalOpacity);
      _dragOffset = zoneOffset;
      _isDraggingToAlbum = isOverChangeAlbumZone;
    });
  }

  Future<void> _handleDragEnd(pm.AssetEntity asset, Offset pos) async {
    final isOverChangeAlbumZone = _isPositionOverWidget(
      widget.changeAlbumZoneKey,
      pos,
    );

    _resetVisuals();

    if (isOverChangeAlbumZone && mounted && widget.assets.isNotEmpty) {
      final soundService = SoundService();
      soundService.playKeepSound();

      await _showAlbumSelectionDialog(context, ref, asset, widget.assets);
    }
  }

  Future<void> _handleDecision(
    pm.AssetEntity asset,
    SwipeDecision decision,
  ) async {
    final actions = ref.read(reviewActionsControllerProvider.notifier);

    if (decision == SwipeDecision.keep) {
      await actions.onKeep(asset);
    } else {
      await actions.onDelete(asset);
    }

    _maybePrefetch(ref, widget.assets, asset);
    _resetVisuals();
  }

  void _resetVisuals() {
    if (!mounted) return;

    setState(() {
      _dragScale = 1.0;
      _dragOpacity = 1.0;
      _dragOffset = Offset.zero;
      _isDraggingToAlbum = false;
      _dragStartPosition = null;
    });

    ref.read(_isDraggingOverChangeAlbumProvider.notifier).state = false;
  }

  void _showNoRightsDialog(BuildContext context) {
    // Dialog zaten açıksa, yeni dialog açma
    if (_isDialogShowing) return;

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.black.withOpacity(0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (value * 0.2),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.25),
                  blurRadius: 32,
                  spreadRadius: 2,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.error,
                        theme.colorScheme.error.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.error.withOpacity(0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.block,
                    size: 40,
                    color: theme.colorScheme.onError,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  l10n.noDeleteRightsLeft,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  l10n.noDeleteRightsLeftMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Purchase button with gradient
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Material(
                      color: AppColors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          _isDialogShowing = false;
                          context.push('/paywall');
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Text(
                            l10n.unlockPremiumFeatures,
                            style: theme.textTheme.titleMedium?.copyWith(
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
                ),
                const SizedBox(height: 12),
                // Cancel button
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    l10n.maybeLater,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      // Dialog kapandığında flag'i sıfırla
      _isDialogShowing = false;
    });
  }
}

// Modern loading overlay widget

// Tab pages
class _SwipeTab extends ConsumerStatefulWidget {
  const _SwipeTab();

  @override
  ConsumerState<_SwipeTab> createState() => _SwipeTabState();
}

class _SwipeTabState extends ConsumerState<_SwipeTab>
    with AutomaticKeepAliveClientMixin {
  int _currentSwipeIndex = 0;
  int _previousAssetsLength = 0;
  bool _showResetToStartButton = false;
  String? _currentAlbumId;
  VoidCallback? _resetToStartCallback;
  bool _isDeleting = false;
  int? _pendingIndexAdjustment; // Reload sonrası index ayarlaması için

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSwipeIndex();
  }

  Future<void> _loadSwipeIndex() async {
    final selectedAlbum = ref.read(selectedAlbumProvider);
    final albumId = selectedAlbum?.id;
    _currentAlbumId = albumId;

    final prefsService = PreferencesService();
    final savedIndex = await prefsService.getSwipeIndex(albumId);

    if (savedIndex != null && savedIndex > 0) {
      setState(() {
        _currentSwipeIndex = savedIndex;
      });
    }
  }

  void _onSwipeIndexChanged(int index) {
    setState(() {
      _currentSwipeIndex = index;
      // Index 0 ise butonu gizle
      if (index == 0) {
        _showResetToStartButton = false;
      }
    });

    // Index'i kaydet (her değişiklikte)
    _saveSwipeIndex(index);
  }

  Future<void> _saveSwipeIndex(int index) async {
    final selectedAlbum = ref.read(selectedAlbumProvider);
    final albumId = selectedAlbum?.id;
    _currentAlbumId = albumId;

    final prefsService = PreferencesService();
    await prefsService.saveSwipeIndex(index, albumId);
  }

  void _resetToStart() {
    // Galeriyi yeniden yükle - silinen fotoğraflar artık listede olmayacak
    ref.read(galleryPagingControllerProvider.notifier).reload();

    _resetToStartCallback?.call();
    setState(() {
      _currentSwipeIndex = 0;
      _showResetToStartButton = false;
      _previousAssetsLength = 0; // Reset previous length
    });
    _saveSwipeIndex(0);
  }

  Widget _buildSwipeArea(
    List<pm.AssetEntity> assets,
    GlobalKey changeAlbumZoneKey,
    String? albumId,
  ) {
    // Yeni fotoğraf eklendi mi kontrol et (assets uzunluğu arttıysa)
    if (_previousAssetsLength > 0 && assets.length > _previousAssetsLength) {
      // Yeni fotoğraf eklendi - butonu göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentSwipeIndex > 0) {
          setState(() {
            _showResetToStartButton = true;
          });
        }
      });
    }
    _previousAssetsLength = assets.length;

    // Eğer pending index adjustment varsa, onu kullan
    int adjustedIndex = _pendingIndexAdjustment ?? _currentSwipeIndex;

    if (assets.isNotEmpty) {
      final maxIndex = assets.length - 1;
      adjustedIndex = adjustedIndex.clamp(0, maxIndex);
    } else {
      adjustedIndex = 0;
    }

    // Pending adjustment uygulandıysa temizle
    if (_pendingIndexAdjustment != null) {
      _pendingIndexAdjustment = null;
    }

    if (adjustedIndex != _currentSwipeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentSwipeIndex = adjustedIndex;
        });
        _saveSwipeIndex(adjustedIndex);
      });
    }

    final swipeAreaKey = albumId ?? 'all_photos';

    return RepaintBoundary(
      child: _SwipeAreaContent(
        key: ValueKey('swipe_area_$swipeAreaKey'),
        assets: assets,
        changeAlbumZoneKey: changeAlbumZoneKey,
        initialIndex: adjustedIndex,
        onIndexChanged: _onSwipeIndexChanged,
        onResetCallbackReady: (callback) {
          _resetToStartCallback = callback;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli

    // Geri al işlemlerini dinle - sadece gerekli durumlarda setState yap
    ref.listen<List<dynamic>>(reviewActionsControllerProvider, (
      previous,
      next,
    ) {
      if (previous != null &&
          previous.isNotEmpty &&
          next.isEmpty &&
          _currentSwipeIndex > 0 &&
          !_showResetToStartButton) {
        // Tüm geri al işlemleri yapıldı ve index > 0 ise buton göster
        // Sadece buton zaten gösterilmiyorsa setState yap
        if (mounted) {
          setState(() {
            _showResetToStartButton = true;
          });
        }
      }
    });

    final selectedAlbum = ref.watch(selectedAlbumProvider);

    // Album değiştiğinde index'i yükle
    if (selectedAlbum?.id != _currentAlbumId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadSwipeIndex();
        }
      });
    }

    // Assets listesini selector ile izle - sadece assets listesi gerçekten değiştiğinde rebuild
    // Loading state değişikliklerini ignore et - dialog/reklam gösterilirken rebuild'i engelle
    final state = ref.watch(galleryPagingControllerProvider);

    // Önceki assets listesini sakla - loading state'de kullanmak için
    final previousAssets = state.maybeWhen(
      data: (assets) => assets,
      orElse: () => <pm.AssetEntity>[],
    );

    // Sadece data state'inde ve assets listesi gerçekten değiştiğinde rebuild yap
    final currentAssets = ref.watch(
      galleryPagingControllerProvider.select((asyncState) {
        return asyncState.maybeWhen(
          data: (assets) => assets,
          orElse: () => null, // Loading/error state'lerinde null döndür
        );
      }),
    );

    // Assets listesi değişmediyse ve loading state'deyse, önceki build'i koru
    final effectiveAssets = currentAssets ?? previousAssets;

    return state.when(
      loading: () {
        // Loading state'de önceki widget'ı koru - dialog/reklam gösterilirken rebuild'i engelle
        // Eğer önceki assets varsa onu göster, yoksa loading göster
        if (effectiveAssets.isNotEmpty) {
          // Önceki assets'i kullan - rebuild'i engelle
          return _buildContentWithAssets(effectiveAssets, selectedAlbum);
        }
        // İlk yükleme ise photo card shimmer'ları göster
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 3,
          itemBuilder: (context, index) => const _PhotoCardShimmer(),
        );
      },
      error: (e, _) => Builder(
        builder: (ctx) {
          final l10n = AppLocalizations.of(ctx)!;
          return Center(
            child: Text(
              '${l10n.galleryInfoNotAvailable}: $e',
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
      data: (_) {
        // effectiveAssets kullan - loading state'de önceki assets'i koru
        return _buildContentWithAssets(effectiveAssets, selectedAlbum);
      },
    );
  }

  Widget _buildContentWithAssets(
    List<pm.AssetEntity> assetsToUse,
    pm.AssetPathEntity? selectedAlbum,
  ) {
    if (assetsToUse.isEmpty) {
      return Builder(
        builder: (ctx) {
          final l10n = AppLocalizations.of(ctx)!;
          final theme = Theme.of(ctx);
          final albumsAsync = ref.watch(albumsProvider);
          final albumsData = albumsAsync.asData?.value;
          final canOpenAlbumPicker =
              albumsData != null && albumsData.isNotEmpty;
          final selectedAlbum = ref.watch(selectedAlbumProvider);

          Future<void> openAlbumPicker() async {
            final availableAlbums = albumsData;
            if (availableAlbums == null || availableAlbums.isEmpty) return;
            await _presentAlbumPicker(
              context: ctx,
              albums: availableAlbums,
              selectedAlbum: selectedAlbum,
              onSelected: (album) {
                ref.read(selectedAlbumProvider.notifier).state = album;
              },
            );
          }

          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 48,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Modern icon container with gradient and animation
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.secondaryContainer,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.25),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.photo_library_outlined,
                        color: theme.colorScheme.primary,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Title with better styling
                    Text(
                      l10n.noPhotosToShow,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        letterSpacing: -0.5,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Description in a container
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        l10n.selectAlbumToView,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.75),
                          height: 1.5,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Modern button with gradient
                    if (canOpenAlbumPicker)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Material(
                          color: AppColors.transparent,
                          child: InkWell(
                            onTap: openAlbumPicker,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.folder_open_rounded,
                                    color: AppColors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.changeAlbum,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.white,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Material(
                          color: AppColors.transparent,
                          child: InkWell(
                            onTap: () {
                              ref.invalidate(galleryPagingControllerProvider);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    color: theme.colorScheme.onSurface,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.tryAgain,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: theme.colorScheme.onSurface,
                                          letterSpacing: 0.3,
                                        ),
                                  ),
                                ],
                              ),
                            ),
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
    final changeAlbumZoneKey = GlobalKey();
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _DeleteLimitInfo(),
        ),
        // Galeri Başına Dön butonu
        if (_showResetToStartButton && _currentSwipeIndex > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetToStart,
                icon: const Icon(Icons.restart_alt),
                label: Text(l10n.resetToStart),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        Expanded(
          child: _buildSwipeArea(
            assetsToUse,
            changeAlbumZoneKey,
            selectedAlbum?.id,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _AnimatedSwipeInstructions(),
        ),
        Consumer(
          builder: (context, ref, _) {
            final pending = ref.watch(reviewActionsControllerProvider);
            final pendingCount = pending.length;

            if (pendingCount == 0 && !_showResetToStartButton) {
              return const SizedBox.shrink();
            }

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (pendingCount > 0)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () {
                          while (ref
                              .read(reviewActionsControllerProvider)
                              .isNotEmpty) {
                            ref
                                .read(reviewActionsControllerProvider.notifier)
                                .undoLast();
                          }
                        },
                        child: Text(
                          l10n.undo,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary, // Daha belirgin renk
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary
                                .withOpacity(0.6), // Primary renkte border
                            width: 1.5,
                          ),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.outline,
                          backgroundColor: AppColors.transparent,
                        ),
                      ),
                    ),
                  if (pendingCount > 0) const SizedBox(width: 12),
                  if (pendingCount > 0)
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        onPressed: () async {
                          final l10n = AppLocalizations.of(context)!;
                          final theme = Theme.of(context);

                          setState(() {
                            _isDeleting = true;
                          });

                          // Delete limit'i kontrol et
                          final deleteLimitController = ref.read(
                            deleteLimitProvider.notifier,
                          );
                          final deleteLimit = await deleteLimitController
                              .currentLimit();
                          final pendingCount = ref
                              .read(reviewActionsControllerProvider)
                              .length;

                          // Delete limit'e göre maksimum silinebilecek fotoğraf sayısını belirle
                          final maxDeleteCount = deleteLimit < 999999999
                              ? math.min(deleteLimit, pendingCount)
                              : pendingCount;

                          debugPrint(
                            '📊 [SwipePage] Silme işlemi başlatılıyor: $maxDeleteCount/$pendingCount fotoğraf silinecek (limit: $deleteLimit)',
                          );

                          final deletedCount = await ref
                              .read(reviewActionsControllerProvider.notifier)
                              .applyPendingDeletes(
                                maxDeleteCount: maxDeleteCount,
                              );

                          debugPrint(
                            '📊 [SwipePage] Silme işlemi tamamlandı: $deletedCount fotoğraf silindi',
                          );

                          if (!context.mounted) {
                            debugPrint(
                              '⚠️ [SwipePage] Context mounted değil, işlem iptal edildi',
                            );
                            if (mounted) {
                              setState(() {
                                _isDeleting = false;
                              });
                            }
                            return;
                          }

                          // Silme işlemi başarılı olup olmadığını kontrol et
                          if (deletedCount > 0) {
                            debugPrint(
                              '✅ [SwipePage] $deletedCount fotoğraf başarıyla silindi, silme hakkı azaltılıyor...',
                            );

                            try {
                              final newLimit = await deleteLimitController
                                  .decrease(deletedCount);
                              debugPrint(
                                '💾 [SwipePage] Delete limit güncellendi, kalan: $newLimit (azaltılan: $deletedCount)',
                              );

                              // Mevcut swipe index'ini kaydet - silme sonrası kaldığı yerden devam etmek için
                              final currentIndexBeforeReload =
                                  _currentSwipeIndex;
                              debugPrint(
                                '💾 [SwipePage] Mevcut swipe index kaydedildi: $currentIndexBeforeReload',
                              );

                              // Başarı dialog'unu önce göster - reload'dan önce
                              // Böylece dialog gösterilirken TabView rebuild olmaz
                              debugPrint(
                                '🎯 [SwipePage] About to show delete success dialog - deletedCount: $deletedCount, context.mounted: ${context.mounted}',
                              );
                              if (context.mounted) {
                                debugPrint(
                                  '✅ [SwipePage] Context is mounted, calling _showDeleteSuccessDialog...',
                                );
                                await _showDeleteSuccessDialog(
                                  context,
                                  deletedCount,
                                );
                                debugPrint(
                                  '✅ [SwipePage] _showDeleteSuccessDialog completed',
                                );
                              } else {
                                debugPrint(
                                  '❌ [SwipePage] Context not mounted, cannot show dialog',
                                );
                              }

                              // Reload'u dialog kapandıktan sonra yap
                              // Böylece dialog gösterilirken TabView rebuild olmaz
                              if (mounted) {
                                ref
                                    .read(
                                      galleryPagingControllerProvider.notifier,
                                    )
                                    .reload();

                                // Reload sonrası, silinen fotoğraflar listeden çıktığı için
                                // index'i ayarla (silinen fotoğraflar kadar azalt)
                                // Ancak index 0'dan küçük olamaz
                                final adjustedIndex =
                                    (currentIndexBeforeReload - deletedCount)
                                        .clamp(0, 999999999);

                                // Index ayarlamasını işaretle - _buildSwipeArea'da uygulanacak
                                setState(() {
                                  _pendingIndexAdjustment = adjustedIndex;
                                  _currentSwipeIndex = adjustedIndex;
                                });
                                _saveSwipeIndex(adjustedIndex);
                                debugPrint(
                                  '💾 [SwipePage] Swipe index ayarlandı: $currentIndexBeforeReload -> $adjustedIndex (silinen: $deletedCount)',
                                );
                              }
                            } catch (e, stackTrace) {
                              debugPrint(
                                '❌ [SwipePage] Silme hakkı azaltılırken hata: $e',
                              );
                              debugPrint(
                                '❌ [SwipePage] Stack trace: $stackTrace',
                              );
                              await deleteLimitController.refresh();
                              // Hata olsa bile dialog'u göster
                              debugPrint(
                                '🎯 [SwipePage] Error case - About to show delete success dialog - deletedCount: $deletedCount, context.mounted: ${context.mounted}',
                              );
                              if (context.mounted) {
                                debugPrint(
                                  '✅ [SwipePage] Error case - Context is mounted, calling _showDeleteSuccessDialog...',
                                );
                                await _showDeleteSuccessDialog(
                                  context,
                                  deletedCount,
                                );
                                debugPrint(
                                  '✅ [SwipePage] Error case - _showDeleteSuccessDialog completed',
                                );
                              } else {
                                debugPrint(
                                  '❌ [SwipePage] Error case - Context not mounted, cannot show dialog',
                                );
                              }
                            }
                          } else {
                            debugPrint(
                              '⚠️ [SwipePage] Silme işlemi başarısız veya hiç fotoğraf silinmedi (deletedCount: $deletedCount)',
                            );
                            // Kullanıcıya bilgi ver
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.deleteOperationFailed),
                                  backgroundColor: theme.colorScheme.error,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                          // Animasyonu 1 saniye sonra durdur
                          Future.delayed(
                            const Duration(milliseconds: 1000),
                            () {
                              if (mounted) {
                                setState(() {
                                  _isDeleting = false;
                                });
                              }
                            },
                          );
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              Theme.of(
                                context,
                              ).extension<AppSemanticColors>()?.delete ??
                              Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onError,
                          side: BorderSide(
                            color: AppColors.error.withOpacity(
                              0.9,
                            ), // Kırmızı border
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  Theme.of(context).colorScheme.onError,
                                  BlendMode.srcATop,
                                ),
                                child: Lottie.asset(
                                  'assets/lottie/trash.json',
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                  repeat: _isDeleting,
                                  options: LottieOptions(
                                    enableMergePaths: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.deletePhotos(pendingCount)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BlurTab extends ConsumerStatefulWidget {
  const _BlurTab();

  @override
  ConsumerState<_BlurTab> createState() => _BlurTabState();
}

class _BlurTabState extends ConsumerState<_BlurTab> {
  double _blurThreshold = 0.5; // Default: Medium sensitivity
  final SoundService _soundService = SoundService();

  @override
  void dispose() {
    _soundService.stopScannerSound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedAlbum = ref.watch(selectedAlbumProvider);
    final albumsAsync = ref.watch(albumsProvider);
    final blurState = ref.watch(blurDetectionProvider);

    // Scanner durumu değiştiğinde ses kontrolü yap
    ref.listen<BlurDetectionState>(blurDetectionProvider, (previous, next) {
      // Scan durumu veya tamamlanma durumu değiştiğinde ses kontrolü yap
      final wasScanning = previous?.isScanning ?? false;
      final isScanning = next.isScanning;
      final hasCompleted = next.hasCompletedScan;

      // Scan başladıysa ses çal
      if (isScanning && !wasScanning) {
        _soundService.playScannerSound();
      }
      // Scan durduysa veya tamamlandıysa ses durdur
      else if ((!isScanning && wasScanning) || hasCompleted) {
        _soundService.stopScannerSound();
      }
    });

    final isScanning = blurState.isScanning;

    return PopScope(
      canPop: !isScanning,
      onPopInvoked: (didPop) {
        if (!didPop && isScanning) {
          // Kullanıcı scan sırasında geri tuşuna bastı, bilgilendirme göster
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.doNotLeaveScreenDuringScan),
              duration: const Duration(seconds: 3),
              backgroundColor: theme.colorScheme.errorContainer,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: albumsAsync.when(
        loading: () => const _ScanFormShimmer(),
        error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
        data: (albums) {
          if (albums.isEmpty) {
            return Center(child: Text(l10n.albumNotFound));
          }

          final selectedAlbums = selectedAlbum != null
              ? [selectedAlbum]
              : albums.where((a) => !a.isAll).toList();

          // Eğer tarama tamamlandıysa, sonuç olsun ya da olmasın results view göster
          // Böylece no results ekranı da gösterilebilir
          final hasResults =
              blurState.hasCompletedScan || blurState.totalBlurryPhotos > 0;

        // Tarama yapılırken full-screen overlay göster
        if (isScanning) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Lottie.asset(
                      'assets/lottie/gallery_loading.json',
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.scanningBlurPhotos,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.loadingMayTakeFewSeconds,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.7),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warning.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 28,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            l10n.doNotLeaveScreenDuringScan,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress bilgisi - scan başladığı andan itibaren göster
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(
                        0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      blurState.currentAlbum != null
                          ? '${blurState.currentAlbum} • ${(blurState.progress * 100).floor()}%'
                          : '${(blurState.progress * 100).floor()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Durdur butonu
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(blurDetectionProvider.notifier).cancel();
                    },
                    icon: const Icon(Icons.stop),
                    label: Text(l10n.stop),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: AppColors.error.withOpacity(
                          0.9,
                        ), // Kırmızı border
                        width: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 8,
                left: 16,
                right: 16,
                bottom: 80,
              ),
              child: hasResults
                  ? _buildResultsView(context, blurState, theme, l10n)
                  : _buildScanForm(context, theme, l10n),
            ),
            // Fixed bottom button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.colorScheme.background),
                child: SafeArea(
                  child: Consumer(
                    builder: (context, ref, _) {
                      // Check if there are actual photos to delete
                      final allPhotos = <BlurPhoto>[];
                      for (final entry
                          in blurState.blurryPhotosByAlbum.entries) {
                        allPhotos.addAll(entry.value);
                      }
                      final hasPhotosToDelete = allPhotos.isNotEmpty;

                      final blurScanLimitAsync = ref.watch(
                        blurScanLimitProvider,
                      );
                      final isPremiumAsync = ref.watch(isPremiumProvider);

                      return blurScanLimitAsync.when(
                        loading: () => hasPhotosToDelete
                            ? FilledButton.icon(
                                onPressed: () async {
                                  final allPhotos = <BlurPhoto>[];
                                  for (final entry
                                      in blurState
                                          .blurryPhotosByAlbum
                                          .entries) {
                                    allPhotos.addAll(entry.value);
                                  }

                                  final l10n = AppLocalizations.of(context)!;
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(l10n.deleteAllBlurryPhotos),
                                      content: Text(
                                        l10n.deleteAllBlurryPhotosMessage(
                                          allPhotos.length,
                                        ),
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
                                            backgroundColor:
                                                theme.colorScheme.error,
                                          ),
                                          child: Text(l10n.delete),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed != true || !mounted) return;

                                  // Delete limit kontrolü
                                  final deleteLimitController = ref.read(
                                    deleteLimitProvider.notifier,
                                  );
                                  final deleteLimit =
                                      await deleteLimitController
                                          .currentLimit();
                                  final isPremium = await PreferencesService()
                                      .isPremium();

                                  // Toplam silinecek fotoğraf sayısını kontrol et
                                  final totalPhotosToDelete = allPhotos.length;

                                  // Delete limit'e göre maksimum silinebilecek fotoğraf sayısını belirle
                                  final maxDeleteCount =
                                      isPremium || deleteLimit >= 999999999
                                      ? totalPhotosToDelete
                                      : math.min(
                                          deleteLimit,
                                          totalPhotosToDelete,
                                        );

                                  debugPrint(
                                    '📊 [SwipePage] Blur tab - Toplu silme: $maxDeleteCount/$totalPhotosToDelete fotoğraf silinecek (limit: $deleteLimit)',
                                  );

                                  // Eğer limit varsa, sadece limit kadar fotoğrafı sil
                                  int deletedCount = 0;
                                  if (maxDeleteCount > 0) {
                                    // Tüm fotoğrafları al ve limit kadarını sil
                                    final photosToDelete = allPhotos
                                        .take(maxDeleteCount)
                                        .toList();
                                    deletedCount = await ref
                                        .read(blurDetectionProvider.notifier)
                                        .deleteBlurryPhotos(photosToDelete);
                                  }

                                  if (!mounted) return;

                                  if (deletedCount > 0) {
                                    // Silme hakkını azalt
                                    await deleteLimitController.decrease(
                                      deletedCount,
                                    );

                                    debugPrint(
                                      '✅ [SwipePage] Blur tab - $deletedCount fotoğraf silindi',
                                    );

                                    // Cleanup complete dialogunu önce göster - reload'dan önce
                                    // Böylece dialog gösterilirken TabView rebuild olmaz
                                    debugPrint(
                                      '🎯 [SwipePage] Blur tab (post-scan) - About to show delete success dialog - deletedCount: $deletedCount, mounted: $mounted',
                                    );
                                    if (mounted) {
                                      debugPrint(
                                        '✅ [SwipePage] Blur tab (post-scan) - Mounted, calling _showDeleteSuccessDialog...',
                                      );
                                      await _showDeleteSuccessDialog(
                                        context,
                                        deletedCount,
                                      );
                                      debugPrint(
                                        '✅ [SwipePage] Blur tab (post-scan) - _showDeleteSuccessDialog completed',
                                      );
                                    } else {
                                      debugPrint(
                                        '❌ [SwipePage] Blur tab (post-scan) - Not mounted, cannot show dialog',
                                      );
                                    }

                                    // Reload'u dialog kapandıktan sonra yap
                                    // Böylece dialog gösterilirken TabView rebuild olmaz
                                    if (mounted) {
                                      ref
                                          .read(
                                            galleryPagingControllerProvider
                                                .notifier,
                                          )
                                          .reload();
                                    }
                                  } else {
                                    debugPrint(
                                      '⚠️ [SwipePage] Blur tab - Silme işlemi başarısız veya limit yok',
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: Text(l10n.deleteAllBlurryPhotos),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  minimumSize: const Size(double.infinity, 56),
                                  backgroundColor: AppColors.error.withOpacity(
                                    0.85,
                                  ), // Soluk iç renk
                                  foregroundColor: theme.colorScheme.onError,
                                  side: BorderSide(
                                    color: AppColors.error.withOpacity(
                                      0.9,
                                    ), // Kırmızı border
                                    width: 1.5,
                                  ),
                                ),
                              )
                            : _buildModernScanButton(
                                context: context,
                                theme: theme,
                                l10n: l10n,
                                onPressed: null,
                                icon: Icons.search_rounded,
                                label: l10n.startScan,
                                isEnabled: false,
                                isError: false,
                              ),
                        error: (_, __) => hasPhotosToDelete
                            ? FilledButton.icon(
                                onPressed: () async {
                                  final allPhotos = <BlurPhoto>[];
                                  for (final entry
                                      in blurState
                                          .blurryPhotosByAlbum
                                          .entries) {
                                    allPhotos.addAll(entry.value);
                                  }

                                  final l10n = AppLocalizations.of(context)!;
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(l10n.deleteAllBlurryPhotos),
                                      content: Text(
                                        l10n.deleteAllBlurryPhotosMessage(
                                          allPhotos.length,
                                        ),
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
                                            backgroundColor:
                                                theme.colorScheme.error,
                                          ),
                                          child: Text(l10n.delete),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed != true || !mounted) return;

                                  // Delete limit kontrolü
                                  final deleteLimitController = ref.read(
                                    deleteLimitProvider.notifier,
                                  );
                                  final deleteLimit =
                                      await deleteLimitController
                                          .currentLimit();
                                  final isPremium = await PreferencesService()
                                      .isPremium();

                                  // Toplam silinecek fotoğraf sayısını kontrol et
                                  final totalPhotosToDelete = allPhotos.length;

                                  // Delete limit'e göre maksimum silinebilecek fotoğraf sayısını belirle
                                  final maxDeleteCount =
                                      isPremium || deleteLimit >= 999999999
                                      ? totalPhotosToDelete
                                      : math.min(
                                          deleteLimit,
                                          totalPhotosToDelete,
                                        );

                                  debugPrint(
                                    '📊 [SwipePage] Blur tab - Toplu silme: $maxDeleteCount/$totalPhotosToDelete fotoğraf silinecek (limit: $deleteLimit)',
                                  );

                                  // Eğer limit varsa, sadece limit kadar fotoğrafı sil
                                  int deletedCount = 0;
                                  if (maxDeleteCount > 0) {
                                    // Tüm fotoğrafları al ve limit kadarını sil
                                    final photosToDelete = allPhotos
                                        .take(maxDeleteCount)
                                        .toList();
                                    deletedCount = await ref
                                        .read(blurDetectionProvider.notifier)
                                        .deleteBlurryPhotos(photosToDelete);
                                  }

                                  if (!mounted) return;

                                  if (deletedCount > 0) {
                                    // Silme hakkını azalt
                                    await deleteLimitController.decrease(
                                      deletedCount,
                                    );

                                    debugPrint(
                                      '✅ [SwipePage] Blur tab - $deletedCount fotoğraf silindi',
                                    );

                                    // Cleanup complete dialogunu önce göster - reload'dan önce
                                    // Böylece dialog gösterilirken TabView rebuild olmaz
                                    debugPrint(
                                      '🎯 [SwipePage] Blur tab (post-scan) - About to show delete success dialog - deletedCount: $deletedCount, mounted: $mounted',
                                    );
                                    if (mounted) {
                                      debugPrint(
                                        '✅ [SwipePage] Blur tab (post-scan) - Mounted, calling _showDeleteSuccessDialog...',
                                      );
                                      await _showDeleteSuccessDialog(
                                        context,
                                        deletedCount,
                                      );
                                      debugPrint(
                                        '✅ [SwipePage] Blur tab (post-scan) - _showDeleteSuccessDialog completed',
                                      );
                                    } else {
                                      debugPrint(
                                        '❌ [SwipePage] Blur tab (post-scan) - Not mounted, cannot show dialog',
                                      );
                                    }

                                    // Reload'u dialog kapandıktan sonra yap
                                    // Böylece dialog gösterilirken TabView rebuild olmaz
                                    if (mounted) {
                                      ref
                                          .read(
                                            galleryPagingControllerProvider
                                                .notifier,
                                          )
                                          .reload();
                                    }
                                  } else {
                                    debugPrint(
                                      '⚠️ [SwipePage] Blur tab - Silme işlemi başarısız veya limit yok',
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: Text(l10n.deleteAllBlurryPhotos),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  minimumSize: const Size(double.infinity, 56),
                                  backgroundColor: AppColors.error.withOpacity(
                                    0.85,
                                  ), // Soluk iç renk
                                  foregroundColor: theme.colorScheme.onError,
                                  side: BorderSide(
                                    color: AppColors.error.withOpacity(
                                      0.9,
                                    ), // Kırmızı border
                                    width: 1.5,
                                  ),
                                ),
                              )
                            : _buildModernScanButton(
                                context: context,
                                theme: theme,
                                l10n: l10n,
                                onPressed: null,
                                icon: Icons.search_rounded,
                                label: l10n.startScan,
                                isEnabled: false,
                                isError: false,
                              ),
                        data: (scanLimit) {
                          return isPremiumAsync.when(
                            loading: () => hasPhotosToDelete
                                ? FilledButton.icon(
                                    onPressed: () async {
                                      final allPhotos = <BlurPhoto>[];
                                      for (final entry
                                          in blurState
                                              .blurryPhotosByAlbum
                                              .entries) {
                                        allPhotos.addAll(entry.value);
                                      }

                                      final l10n = AppLocalizations.of(
                                        context,
                                      )!;
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(
                                            l10n.deleteAllBlurryPhotos,
                                          ),
                                          content: Text(
                                            l10n.deleteAllBlurryPhotosMessage(
                                              allPhotos.length,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: Text(l10n.cancel),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    theme.colorScheme.error,
                                              ),
                                              child: Text(l10n.delete),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed != true || !mounted) return;

                                      final deletedCount = await ref
                                          .read(blurDetectionProvider.notifier)
                                          .deleteAllBlurryPhotos();

                                      if (!mounted) return;

                                      await ref
                                          .read(deleteLimitProvider.notifier)
                                          .decrease(deletedCount);
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(l10n.deleteAllBlurryPhotos),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        56,
                                      ),
                                      backgroundColor: theme.colorScheme.error,
                                      foregroundColor:
                                          theme.colorScheme.onError,
                                      side: BorderSide(
                                        color: AppColors.error.withOpacity(
                                          0.9,
                                        ), // Kırmızı border
                                        width: 1.5,
                                      ),
                                    ),
                                  )
                                : _buildModernScanButton(
                                    context: context,
                                    theme: theme,
                                    l10n: l10n,
                                    onPressed: null,
                                    icon: Icons.search_rounded,
                                    label: l10n.startScan,
                                    isEnabled: false,
                                    isError: false,
                                  ),
                            error: (_, __) => hasPhotosToDelete
                                ? FilledButton.icon(
                                    onPressed: () async {
                                      final allPhotos = <BlurPhoto>[];
                                      for (final entry
                                          in blurState
                                              .blurryPhotosByAlbum
                                              .entries) {
                                        allPhotos.addAll(entry.value);
                                      }

                                      final l10n = AppLocalizations.of(
                                        context,
                                      )!;
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(
                                            l10n.deleteAllBlurryPhotos,
                                          ),
                                          content: Text(
                                            l10n.deleteAllBlurryPhotosMessage(
                                              allPhotos.length,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: Text(l10n.cancel),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    theme.colorScheme.error,
                                              ),
                                              child: Text(l10n.delete),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed != true || !mounted) return;

                                      final deletedCount = await ref
                                          .read(blurDetectionProvider.notifier)
                                          .deleteAllBlurryPhotos();

                                      if (!mounted) return;

                                      await ref
                                          .read(deleteLimitProvider.notifier)
                                          .decrease(deletedCount);
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(l10n.deleteAllBlurryPhotos),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        56,
                                      ),
                                      backgroundColor: theme.colorScheme.error,
                                      foregroundColor:
                                          theme.colorScheme.onError,
                                      side: BorderSide(
                                        color: AppColors.error.withOpacity(
                                          0.9,
                                        ), // Kırmızı border
                                        width: 1.5,
                                      ),
                                    ),
                                  )
                                : _buildModernScanButton(
                                    context: context,
                                    theme: theme,
                                    l10n: l10n,
                                    onPressed: null,
                                    icon: Icons.search_rounded,
                                    label: l10n.startScan,
                                    isEnabled: false,
                                    isError: false,
                                  ),
                            data: (isPremium) {
                              final hasNoScanRights =
                                  !isPremium && scanLimit <= 0;

                              // No blurry photos found durumunda hiçbir buton gösterilmez
                              if (hasResults && !hasPhotosToDelete) {
                                return const SizedBox.shrink();
                              }

                              return hasResults && hasPhotosToDelete
                                  ? FilledButton.icon(
                                      onPressed: () async {
                                        final allPhotos = <BlurPhoto>[];
                                        for (final entry
                                            in blurState
                                                .blurryPhotosByAlbum
                                                .entries) {
                                          allPhotos.addAll(entry.value);
                                        }

                                        final l10n = AppLocalizations.of(
                                          context,
                                        )!;
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                              l10n.deleteAllBlurryPhotos,
                                            ),
                                            content: Text(
                                              l10n.deleteAllBlurryPhotosMessage(
                                                allPhotos.length,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                                child: Text(l10n.cancel),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      theme.colorScheme.error,
                                                  side: BorderSide(
                                                    color: AppColors.error
                                                        .withOpacity(0.9),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Text(l10n.delete),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed != true || !mounted)
                                          return;

                                        final deletedCount = await ref
                                            .read(
                                              blurDetectionProvider.notifier,
                                            )
                                            .deleteAllBlurryPhotos();

                                        if (!mounted) return;

                                        await ref
                                            .read(deleteLimitProvider.notifier)
                                            .decrease(deletedCount);
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                      label: Text(l10n.deleteAllBlurryPhotos),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        minimumSize: const Size(
                                          double.infinity,
                                          56,
                                        ),
                                        backgroundColor:
                                            theme.colorScheme.error,
                                        foregroundColor:
                                            theme.colorScheme.onError,
                                        side: BorderSide(
                                          color: AppColors.error.withOpacity(
                                            0.9,
                                          ), // Kırmızı border
                                          width: 1.5,
                                        ),
                                      ),
                                    )
                                  : FutureBuilder<
                                      ({
                                        int estimatedSeconds,
                                        int totalPhotoCount,
                                        bool hasLimitWarning,
                                      })
                                    >(
                                      future: _estimateScanDuration(
                                        selectedAlbums,
                                        true,
                                      ),
                                      builder: (context, snapshot) {
                                        final estimatedTimeText =
                                            snapshot.hasData
                                            ? _formatEstimatedTime(
                                                snapshot.data!.estimatedSeconds,
                                                l10n,
                                              )
                                            : null;

                                        final hasLimitWarning =
                                            snapshot.hasData &&
                                            snapshot.data!.hasLimitWarning;
                                        final totalPhotoCount = snapshot.hasData
                                            ? snapshot.data!.totalPhotoCount
                                            : 0;

                                        return _buildModernScanButton(
                                          context: context,
                                          theme: theme,
                                          l10n: l10n,
                                          onPressed:
                                              isScanning || hasNoScanRights
                                              ? null
                                              : () async {
                                                  // Seçili albüm isimlerini hazırla
                                                  final albumNames =
                                                      selectedAlbums
                                                          .map((a) => a.name)
                                                          .join(', ');

                                                  // Onay dialogu göster
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (dialogContext) => AlertDialog(
                                                      title: Text(
                                                        l10n.confirmBlurScan,
                                                      ),
                                                      content: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            l10n.confirmBlurScanMessage,
                                                          ),
                                                          const SizedBox(
                                                            height: 12,
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  12,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: theme
                                                                  .colorScheme
                                                                  .primaryContainer
                                                                  .withOpacity(
                                                                    0.3,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                              border: Border.all(
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary
                                                                    .withOpacity(
                                                                      0.2,
                                                                    ),
                                                                width: 1,
                                                              ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .folder_rounded,
                                                                  size: 20,
                                                                  color: theme
                                                                      .colorScheme
                                                                      .primary,
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    albumNames,
                                                                    style: theme
                                                                        .textTheme
                                                                        .bodyMedium
                                                                        ?.copyWith(
                                                                          color: theme
                                                                              .colorScheme
                                                                              .primary,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                    maxLines: 3,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(false),
                                                          child: Text(
                                                            l10n.cancel,
                                                          ),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(true),
                                                          style: FilledButton.styleFrom(
                                                            backgroundColor:
                                                                theme
                                                                    .colorScheme
                                                                    .primary,
                                                          ),
                                                          child: Text(
                                                            l10n.scan,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  // Kullanıcı onaylamadıysa veya dialog kapatıldıysa çık
                                                  if (confirmed != true ||
                                                      !mounted)
                                                    return;

                                                  // Scan başlat
                                                  await ref
                                                      .read(
                                                        blurDetectionProvider
                                                            .notifier,
                                                      )
                                                      .scanAlbums(
                                                        selectedAlbums,
                                                        blurThreshold:
                                                            _blurThreshold,
                                                      );

                                                  if (!mounted) return;
                                                },
                                          icon: hasNoScanRights
                                              ? Icons.block
                                              : Icons.search_rounded,
                                          label: hasNoScanRights
                                              ? l10n.noScanRightsLeft
                                              : l10n.scanSelectedAlbums,
                                          isEnabled:
                                              !isScanning && !hasNoScanRights,
                                          isError: hasNoScanRights,
                                          estimatedTimeText: estimatedTimeText,
                                          hasLimitWarning: hasLimitWarning,
                                          totalPhotoCount: totalPhotoCount,
                                        );
                                      },
                                    );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
      ),
    );
  }

  Widget _buildScanForm(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kompakt info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppDecorations.floatingCard(
            borderRadius: 18,
            color: theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.blur_on_rounded,
                  size: 28,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.aiPowered,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.blurPhotoDetection,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.blurDetectionDescriptionFromAppBar,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        height: 1.3,
                        color: theme.colorScheme.onPrimaryContainer.withOpacity(
                          0.8,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Scan limit info
        _ScanLimitInfo(adUnitType: AdUnitType.blurScanLimit),
        const SizedBox(height: 8),
        // Kompakt sensitivity section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.sensitivity,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Sensitivity levels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSensitivityChip(
                    theme,
                    l10n.sensitivityLow,
                    Icons.visibility_outlined,
                    0.65, // Daha fazla sonuç, hafif blurlu fotoğraflar da dahil (yüksek threshold = daha fazla fotoğraf blur olarak işaretlenir)
                    _blurThreshold >= 0.57,
                    () => setState(() => _blurThreshold = 0.65),
                  ),
                  _buildSensitivityChip(
                    theme,
                    l10n.sensitivityMedium,
                    Icons.visibility,
                    0.5, // Dengeli, orta seviye blur tespiti
                    _blurThreshold > 0.42 && _blurThreshold < 0.57,
                    () => setState(() => _blurThreshold = 0.5),
                  ),
                  _buildSensitivityChip(
                    theme,
                    l10n.sensitivityHigh,
                    Icons.visibility_off_outlined,
                    0.35, // Sadece çok blurlu fotoğraflar (düşük threshold = sadece çok düşük score'ları yakalar)
                    _blurThreshold <= 0.42,
                    () => setState(() => _blurThreshold = 0.35),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Kompakt description
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.sensitivityLevelsDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        height: 1.3,
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tahmini scan süresini hesapla (saniye cinsinden)
  /// Estimated scan duration ve limit kontrolü
  /// Returns: ({estimatedSeconds: int, totalPhotoCount: int, hasLimitWarning: bool})
  Future<({int estimatedSeconds, int totalPhotoCount, bool hasLimitWarning})>
  _estimateScanDuration(
    List<pm.AssetPathEntity> albums,
    bool isBlurScan,
  ) async {
    try {
      int totalPhotoCount = 0;

      for (final album in albums) {
        try {
          final count = await album.assetCountAsync;
          totalPhotoCount += count;
        } catch (e) {
          // Hata durumunda tahmin et
          debugPrint(
            '⚠️ [SwipePage] Albüm sayısı alınamadı: ${album.name}, $e',
          );
          // Ortalama albüm boyutu tahmini
          totalPhotoCount += 500;
        }
      }

      // 1000 fotoğraf limit kontrolü
      const maxPhotos = 1000;
      final hasLimitWarning = totalPhotoCount > maxPhotos;

      // Limit varsa 1000 fotoğraf için hesapla
      final effectivePhotoCount = hasLimitWarning ? maxPhotos : totalPhotoCount;

      // Fotoğraf başına ortalama işleme süresi (saniye)
      // Blur detection: ~0.15 saniye/fotoğraf (400x400 thumbnail + çoklu analiz)
      // Duplicate detection: ~0.08 saniye/fotoğraf (hash hesaplama)
      final secondsPerPhoto = isBlurScan ? 0.15 : 0.08;

      // Toplam tahmini süre (saniye) - limit varsa 1000 fotoğraf için
      final estimatedSeconds = (effectivePhotoCount * secondsPerPhoto).round();

      // Minimum 5 saniye, maksimum 300 saniye (5 dakika)
      return (
        estimatedSeconds: estimatedSeconds.clamp(5, 300),
        totalPhotoCount: totalPhotoCount,
        hasLimitWarning: hasLimitWarning,
      );
    } catch (e) {
      debugPrint('⚠️ [SwipePage] Tahmini süre hesaplanamadı: $e');
      return (estimatedSeconds: 30, totalPhotoCount: 0, hasLimitWarning: false);
    }
  }

  /// Süreyi formatla (örn: "~30 saniye", "~2 dakika")
  String _formatEstimatedTime(int seconds, AppLocalizations l10n) {
    if (seconds < 60) {
      return l10n.estimatedTimeSeconds(seconds);
    } else {
      final minutes = (seconds / 60).round();
      return l10n.estimatedTimeMinutes(minutes);
    }
  }

  Widget _buildModernScanButton({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required bool isEnabled,
    required bool isError,
    String? estimatedTimeText,
    bool hasLimitWarning = false,
    int totalPhotoCount = 0,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (estimatedTimeText != null && isEnabled && !isError) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.estimatedScanTime(estimatedTimeText),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (hasLimitWarning && isEnabled && !isError) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warningLight.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warningLight.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.warningLight,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.maxPhotoLimitWarning(totalPhotoCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warningLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isEnabled ? onPressed : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: isError
                  ? AppColors
                        .error // Daha belirgin kırmızı
                  : isEnabled
                  ? AppColors.primary.withOpacity(0.85)
                  : theme.colorScheme.surfaceContainerHighest,
              disabledBackgroundColor: isError
                  ? AppColors
                        .error // Disabled durumda da kırmızı
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: isError
                  ? AppColors
                        .white // Kırmızı üzerinde beyaz text
                  : isEnabled
                  ? AppColors.white
                  : theme.colorScheme.onSurface.withOpacity(0.6),
              disabledForegroundColor: isError
                  ? AppColors
                        .white // Disabled durumda da beyaz text
                  : theme.colorScheme.onSurface.withOpacity(0.6),
              side: BorderSide(
                color: isError
                    ? AppColors
                          .error // Kırmızı border
                    : isEnabled
                    ? AppColors.primary.withOpacity(0.9)
                    : theme.colorScheme.onSurface.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSensitivityChip(
    ThemeData theme,
    String label,
    IconData icon,
    double value,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(
                        0.3,
                      ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.4)
                      : theme.colorScheme.outline.withOpacity(0.1),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsView(
    BuildContext context,
    BlurDetectionState state,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final allPhotos = <BlurPhoto>[];
    for (final entry in state.blurryPhotosByAlbum.entries) {
      allPhotos.addAll(entry.value);
    }
    allPhotos.sort((a, b) => a.blurScore.compareTo(b.blurScore));

    if (allPhotos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Modern illustration container
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.secondary.withOpacity(0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 8,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background pattern
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
                    // Main icon with decorative elements
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.1),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.image_not_supported_rounded,
                            size: 64,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Decorative dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.secondary.withOpacity(0.4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Main title
              Text(
                l10n.noBlurryPhotosFoundTitle,
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
              // Detailed description
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      l10n.scanCompletedSuccessfully,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                        height: 1.6,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.noBlurryPhotosFound,
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
              // Retry scan button with gradient
              Consumer(
                builder: (context, ref, _) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.primary.withOpacity(0.85), // Soluk iç renk
                          AppColors.accent.withOpacity(0.75), // Soluk iç renk
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(
                          0.9,
                        ), // Koyu border
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
                        ref.read(blurDetectionProvider.notifier).clear();
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

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kompakt Success Banner
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.scanCompleted,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      l10n.scanCompletedBlurMessage(allPhotos.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.8,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  ref.read(blurDetectionProvider.notifier).clear();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      l10n.startNewScan,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Compact Stats Cards
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _BlurTabState._buildCompactStatCard(
                  theme,
                  Icons.photo_library_rounded,
                  '${allPhotos.length}',
                  l10n.photo,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BlurTabState._buildCompactStatCard(
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
        const SizedBox(height: 8),
        // Kompakt Photos Grid - Expanded ile scroll edilebilir yap
        Expanded(child: _buildGridView(context, allPhotos, theme, l10n)),
      ],
    );
  }

  static Widget _buildCompactStatCard(
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

  Widget _buildGridView(
    BuildContext context,
    List<BlurPhoto> allPhotos,
    ThemeData theme,
    AppLocalizations l10n,
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
          child: _buildPhotoCard(context, photo, theme, l10n),
        );
      },
    );
  }

  String _getProblemTypeLabel(BlurPhoto photo, AppLocalizations l10n) {
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

  Widget _buildPhotoCard(
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
            onTap: () => _showPhotoDetail(context, photo, theme),
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
                            onTap: () => _deletePhoto(context, photo, theme),
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

  Future<void> _deletePhoto(
    BuildContext context,
    BlurPhoto photo,
    ThemeData theme,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final problemType = _getProblemTypeLabel(photo, l10n);
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

    final deletedCount = await ref
        .read(blurDetectionProvider.notifier)
        .deleteBlurryPhotos([photo]);

    if (!mounted) return;

    await ref.read(deleteLimitProvider.notifier).decrease(deletedCount);
  }

  Future<void> _showPhotoDetail(
    BuildContext context,
    BlurPhoto photo,
    ThemeData theme,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isPixelated = photo.isPixelated();
    final isBlurry = photo.isBlurry();
    final problemColor = isPixelated && isBlurry
        ? AppColors.secondary
        : isPixelated
        ? AppColors.blurTab
        : AppColors.error;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getProblemTypeLabel(photo, l10n),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (isBlurry)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    l10n.blurScoreLabel(
                                      photo.blurScore.toStringAsFixed(2),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              if (isPixelated)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.blurTab.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    l10n.pixelationScoreLabel(
                                      photo.pixelationScore.toStringAsFixed(2),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.blurTab,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: problemColor, width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: FutureBuilder(
                      future: photo.asset.thumbnailDataWithSize(
                        const pm.ThumbnailSize(800, 800),
                        quality: 90,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.contain,
                          );
                        }
                        return Container(
                          height: 200,
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
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.close),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _deletePhoto(context, photo, theme);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                        ),
                        child: Text(l10n.delete),
                      ),
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
}

class _DuplicateTab extends ConsumerStatefulWidget {
  const _DuplicateTab();

  @override
  ConsumerState<_DuplicateTab> createState() => _DuplicateTabState();
}

class _DuplicateTabState extends ConsumerState<_DuplicateTab> {
  final SoundService _soundService = SoundService();
  DuplicateDetectionMode _duplicateMode = DuplicateDetectionMode.balanced;

  @override
  void dispose() {
    _soundService.stopScannerSound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedAlbum = ref.watch(selectedAlbumProvider);
    final albumsAsync = ref.watch(albumsProvider);
    final duplicateState = ref.watch(duplicateDetectionProvider);

    // Scanner durumu değiştiğinde ses kontrolü yap
    ref.listen<DuplicateDetectionState>(duplicateDetectionProvider, (
      previous,
      next,
    ) {
      // Scan durumu veya tamamlanma durumu değiştiğinde ses kontrolü yap
      final wasScanning = previous?.isScanning ?? false;
      final isScanning = next.isScanning;
      final hasCompleted = next.hasCompletedScan;

      // Scan başladıysa ses çal
      if (isScanning && !wasScanning) {
        _soundService.playScannerSound();
      }
      // Scan durduysa veya tamamlandıysa ses durdur
      else if ((!isScanning && wasScanning) || hasCompleted) {
        _soundService.stopScannerSound();
      }
    });

    final isScanning = duplicateState.isScanning;

    return PopScope(
      canPop: !isScanning,
      onPopInvoked: (didPop) {
        if (!didPop && isScanning) {
          // Kullanıcı scan sırasında geri tuşuna bastı, bilgilendirme göster
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.doNotLeaveScreenDuringScan),
              duration: const Duration(seconds: 3),
              backgroundColor: theme.colorScheme.errorContainer,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: albumsAsync.when(
        loading: () => const _ScanFormShimmer(),
        error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
        data: (albums) {
          if (albums.isEmpty) {
            return Center(child: Text(l10n.albumNotFound));
          }

          final selectedAlbums = selectedAlbum != null
              ? [selectedAlbum]
              : albums.where((a) => !a.isAll).toList();

          // Eğer tarama tamamlandıysa, sonuç olsun ya da olmasın results view göster
          // Böylece no results ekranı da gösterilebilir
          final hasResults =
              duplicateState.hasCompletedScan || duplicateState.totalGroups > 0;

        // Tarama yapılırken full-screen overlay göster
        if (isScanning) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Lottie.asset(
                      'assets/lottie/gallery_loading.json',
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.scanningDuplicatePhotos,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.loadingMayTakeFewSeconds,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.7),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warning.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 28,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            l10n.doNotLeaveScreenDuringScan,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress bilgisi - scan başladığı andan itibaren göster
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(
                        0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      duplicateState.currentAlbum != null
                          ? '${duplicateState.currentAlbum} • ${(duplicateState.progress * 100).floor()}%'
                          : '${(duplicateState.progress * 100).floor()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Durdur butonu
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(duplicateDetectionProvider.notifier).cancel();
                    },
                    icon: const Icon(Icons.stop),
                    label: Text(l10n.stop),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: AppColors.error.withOpacity(
                          0.9,
                        ), // Kırmızı border
                        width: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 8,
                left: 16,
                right: 16,
                bottom: 80,
              ),
              child: hasResults
                  ? _buildResultsView(context, duplicateState, theme, l10n)
                  : _buildScanForm(context, theme, l10n),
            ),
            // Fixed bottom button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.colorScheme.background),
                child: SafeArea(
                  child: Consumer(
                    builder: (context, ref, _) {
                      // Check if there are actual duplicate groups to delete
                      final hasPhotosToDelete =
                          duplicateState.totalDuplicatePhotos > 0;

                      final duplicateScanLimitAsync = ref.watch(
                        duplicateScanLimitProvider,
                      );
                      final isPremiumAsync = ref.watch(isPremiumProvider);

                      return duplicateScanLimitAsync.when(
                        loading: () => hasPhotosToDelete
                            ? FilledButton.icon(
                                onPressed: () async {
                                  final l10n = AppLocalizations.of(context)!;
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(l10n.deleteAllDuplicates),
                                      content: Text(
                                        l10n.deleteAllDuplicatesMessage(
                                          duplicateState.totalDuplicatePhotos,
                                        ),
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
                                            backgroundColor:
                                                theme.colorScheme.error,
                                            side: BorderSide(
                                              color: AppColors.error
                                                  .withOpacity(
                                                    0.9,
                                                  ), // Kırmızı border
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(l10n.delete),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed != true || !mounted) return;

                                  final deletedCount = await ref
                                      .read(duplicateDetectionProvider.notifier)
                                      .deleteAllDuplicates();

                                  if (!mounted) return;

                                  await ref
                                      .read(deleteLimitProvider.notifier)
                                      .decrease(deletedCount);
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: Text(l10n.deleteAllDuplicates),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  minimumSize: const Size(double.infinity, 56),
                                  backgroundColor: AppColors.error.withOpacity(
                                    0.85,
                                  ), // Soluk iç renk
                                  foregroundColor: theme.colorScheme.onError,
                                  side: BorderSide(
                                    color: AppColors.error.withOpacity(
                                      0.9,
                                    ), // Kırmızı border
                                    width: 1.5,
                                  ),
                                ),
                              )
                            : _DuplicateTabState._buildModernScanButton(
                                context: context,
                                theme: theme,
                                l10n: l10n,
                                onPressed: null,
                                icon: Icons.search_rounded,
                                label: l10n.scanSelectedAlbums,
                                isEnabled: false,
                                isError: false,
                              ),
                        error: (_, __) => hasPhotosToDelete
                            ? FilledButton.icon(
                                onPressed: () async {
                                  final l10n = AppLocalizations.of(context)!;
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(l10n.deleteAllDuplicates),
                                      content: Text(
                                        l10n.deleteAllDuplicatesMessage(
                                          duplicateState.totalDuplicatePhotos,
                                        ),
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
                                            backgroundColor:
                                                theme.colorScheme.error,
                                            side: BorderSide(
                                              color: AppColors.error
                                                  .withOpacity(
                                                    0.9,
                                                  ), // Kırmızı border
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(l10n.delete),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed != true || !mounted) return;

                                  // Delete limit kontrolü
                                  final deleteLimitController = ref.read(
                                    deleteLimitProvider.notifier,
                                  );
                                  final deleteLimit =
                                      await deleteLimitController
                                          .currentLimit();
                                  final isPremium = await PreferencesService()
                                      .isPremium();

                                  // Toplam silinecek fotoğraf sayısını kontrol et
                                  final totalPhotosToDelete =
                                      duplicateState.totalDuplicatePhotos;

                                  // Delete limit'e göre maksimum silinebilecek fotoğraf sayısını belirle
                                  final maxDeleteCount =
                                      isPremium || deleteLimit >= 999999999
                                      ? totalPhotosToDelete
                                      : math.min(
                                          deleteLimit,
                                          totalPhotosToDelete,
                                        );

                                  debugPrint(
                                    '📊 [SwipePage] Duplicate tab - Toplu silme: $maxDeleteCount/$totalPhotosToDelete fotoğraf silinecek (limit: $deleteLimit)',
                                  );

                                  // Eğer limit varsa, sadece limit kadar fotoğrafı sil
                                  int deletedCount = 0;
                                  if (maxDeleteCount > 0) {
                                    deletedCount = await ref
                                        .read(
                                          duplicateDetectionProvider.notifier,
                                        )
                                        .deleteAllDuplicates(
                                          maxDeleteCount: maxDeleteCount,
                                        );
                                  }

                                  if (!mounted) return;

                                  if (deletedCount > 0) {
                                    // Silme hakkını azalt
                                    await deleteLimitController.decrease(
                                      deletedCount,
                                    );

                                    debugPrint(
                                      '✅ [SwipePage] Duplicate tab - $deletedCount fotoğraf silindi',
                                    );

                                    // Cleanup complete dialogunu önce göster - reload'dan önce
                                    // Böylece dialog gösterilirken TabView rebuild olmaz
                                    debugPrint(
                                      '🎯 [SwipePage] Duplicate tab - About to show delete success dialog - deletedCount: $deletedCount, mounted: $mounted',
                                    );
                                    if (mounted) {
                                      debugPrint(
                                        '✅ [SwipePage] Duplicate tab - Mounted, calling _showDeleteSuccessDialog...',
                                      );
                                      await _showDeleteSuccessDialog(
                                        context,
                                        deletedCount,
                                      );
                                      debugPrint(
                                        '✅ [SwipePage] Duplicate tab - _showDeleteSuccessDialog completed',
                                      );
                                    } else {
                                      debugPrint(
                                        '❌ [SwipePage] Duplicate tab - Not mounted, cannot show dialog',
                                      );
                                    }

                                    // Reload'u dialog kapandıktan sonra yap
                                    // Böylece dialog gösterilirken TabView rebuild olmaz
                                    if (mounted) {
                                      ref
                                          .read(
                                            galleryPagingControllerProvider
                                                .notifier,
                                          )
                                          .reload();
                                    }
                                  } else {
                                    debugPrint(
                                      '⚠️ [SwipePage] Duplicate tab - Silme işlemi başarısız veya limit yok',
                                    );
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: Text(l10n.deleteAllDuplicates),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  minimumSize: const Size(double.infinity, 56),
                                  backgroundColor: AppColors.error.withOpacity(
                                    0.85,
                                  ), // Soluk iç renk
                                  foregroundColor: theme.colorScheme.onError,
                                  side: BorderSide(
                                    color: AppColors.error.withOpacity(
                                      0.9,
                                    ), // Kırmızı border
                                    width: 1.5,
                                  ),
                                ),
                              )
                            : FilledButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.search),
                                label: Text(l10n.scanSelectedAlbums),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  minimumSize: const Size(double.infinity, 56),
                                ),
                              ),
                        data: (scanLimit) {
                          return isPremiumAsync.when(
                            loading: () => hasPhotosToDelete
                                ? FilledButton.icon(
                                    onPressed: () async {
                                      final l10n = AppLocalizations.of(
                                        context,
                                      )!;
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(l10n.deleteAllDuplicates),
                                          content: Text(
                                            l10n.deleteAllDuplicatesMessage(
                                              duplicateState
                                                  .totalDuplicatePhotos,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: Text(l10n.cancel),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    theme.colorScheme.error,
                                              ),
                                              child: Text(l10n.delete),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed != true || !mounted) return;

                                      final deletedCount = await ref
                                          .read(
                                            duplicateDetectionProvider.notifier,
                                          )
                                          .deleteAllDuplicates();

                                      if (!mounted) return;

                                      await ref
                                          .read(deleteLimitProvider.notifier)
                                          .decrease(deletedCount);
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(l10n.deleteAllDuplicates),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        56,
                                      ),
                                      backgroundColor: theme.colorScheme.error,
                                      foregroundColor:
                                          theme.colorScheme.onError,
                                    ),
                                  )
                                : _DuplicateTabState._buildModernScanButton(
                                    context: context,
                                    theme: theme,
                                    l10n: l10n,
                                    onPressed: null,
                                    icon: Icons.search_rounded,
                                    label: l10n.scanSelectedAlbums,
                                    isEnabled: false,
                                    isError: false,
                                  ),
                            error: (_, __) => hasPhotosToDelete
                                ? FilledButton.icon(
                                    onPressed: () async {
                                      final l10n = AppLocalizations.of(
                                        context,
                                      )!;
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(l10n.deleteAllDuplicates),
                                          content: Text(
                                            l10n.deleteAllDuplicatesMessage(
                                              duplicateState
                                                  .totalDuplicatePhotos,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: Text(l10n.cancel),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    theme.colorScheme.error,
                                                side: BorderSide(
                                                  color: AppColors.error
                                                      .withOpacity(0.9),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Text(l10n.delete),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed != true || !mounted) return;

                                      final deletedCount = await ref
                                          .read(
                                            duplicateDetectionProvider.notifier,
                                          )
                                          .deleteAllDuplicates();

                                      if (!mounted) return;

                                      await ref
                                          .read(deleteLimitProvider.notifier)
                                          .decrease(deletedCount);
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(l10n.deleteAllDuplicates),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        56,
                                      ),
                                      backgroundColor: theme.colorScheme.error,
                                      foregroundColor:
                                          theme.colorScheme.onError,
                                      side: BorderSide(
                                        color: AppColors.error.withOpacity(
                                          0.9,
                                        ), // Kırmızı border
                                        width: 1.5,
                                      ),
                                    ),
                                  )
                                : _DuplicateTabState._buildModernScanButton(
                                    context: context,
                                    theme: theme,
                                    l10n: l10n,
                                    onPressed: null,
                                    icon: Icons.search_rounded,
                                    label: l10n.scanSelectedAlbums,
                                    isEnabled: false,
                                    isError: false,
                                  ),
                            data: (isPremium) {
                              final hasNoScanRights =
                                  !isPremium && scanLimit <= 0;

                              // No duplicates found durumunda hiçbir buton gösterilmez
                              if (hasResults && !hasPhotosToDelete) {
                                return const SizedBox.shrink();
                              }

                              return hasResults && hasPhotosToDelete
                                  ? FilledButton.icon(
                                      onPressed: () async {
                                        final l10n = AppLocalizations.of(
                                          context,
                                        )!;
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                              l10n.deleteAllDuplicates,
                                            ),
                                            content: Text(
                                              l10n.deleteAllDuplicatesMessage(
                                                duplicateState
                                                    .totalDuplicatePhotos,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                                child: Text(l10n.cancel),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      theme.colorScheme.error,
                                                  side: BorderSide(
                                                    color: AppColors.error
                                                        .withOpacity(0.9),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Text(l10n.delete),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed != true || !mounted)
                                          return;

                                        final deletedCount = await ref
                                            .read(
                                              duplicateDetectionProvider
                                                  .notifier,
                                            )
                                            .deleteAllDuplicates();

                                        if (!mounted) return;

                                        await ref
                                            .read(deleteLimitProvider.notifier)
                                            .decrease(deletedCount);
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                      label: Text(l10n.deleteAllDuplicates),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        minimumSize: const Size(
                                          double.infinity,
                                          56,
                                        ),
                                        backgroundColor:
                                            theme.colorScheme.error,
                                        foregroundColor:
                                            theme.colorScheme.onError,
                                        side: BorderSide(
                                          color: AppColors.error.withOpacity(
                                            0.9,
                                          ), // Kırmızı border
                                          width: 1.5,
                                        ),
                                      ),
                                    )
                                  : FutureBuilder<
                                      ({
                                        int estimatedSeconds,
                                        int totalPhotoCount,
                                        bool hasLimitWarning,
                                      })
                                    >(
                                      future:
                                          _DuplicateTabState._estimateScanDurationStatic(
                                            selectedAlbums,
                                            false,
                                          ),
                                      builder: (context, snapshot) {
                                        final estimatedTimeText =
                                            snapshot.hasData
                                            ? _DuplicateTabState._formatEstimatedTimeStatic(
                                                snapshot.data!.estimatedSeconds,
                                                l10n,
                                              )
                                            : null;

                                        final hasLimitWarning =
                                            snapshot.hasData &&
                                            snapshot.data!.hasLimitWarning;
                                        final totalPhotoCount = snapshot.hasData
                                            ? snapshot.data!.totalPhotoCount
                                            : 0;

                                        return _DuplicateTabState._buildModernScanButton(
                                          context: context,
                                          theme: theme,
                                          l10n: l10n,
                                          onPressed:
                                              isScanning || hasNoScanRights
                                              ? null
                                              : () async {
                                                  // Seçili albüm isimlerini hazırla
                                                  final albumNames =
                                                      selectedAlbums
                                                          .map((a) => a.name)
                                                          .join(', ');

                                                  // Onay dialogu göster
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (dialogContext) => AlertDialog(
                                                      title: Text(
                                                        l10n.confirmDuplicateScan,
                                                      ),
                                                      content: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            l10n.confirmDuplicateScanMessage,
                                                          ),
                                                          const SizedBox(
                                                            height: 12,
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  12,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: theme
                                                                  .colorScheme
                                                                  .primaryContainer
                                                                  .withOpacity(
                                                                    0.3,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                              border: Border.all(
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary
                                                                    .withOpacity(
                                                                      0.2,
                                                                    ),
                                                                width: 1,
                                                              ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .folder_rounded,
                                                                  size: 20,
                                                                  color: theme
                                                                      .colorScheme
                                                                      .primary,
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    albumNames,
                                                                    style: theme
                                                                        .textTheme
                                                                        .bodyMedium
                                                                        ?.copyWith(
                                                                          color: theme
                                                                              .colorScheme
                                                                              .primary,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                    maxLines: 3,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(false),
                                                          child: Text(
                                                            l10n.cancel,
                                                          ),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(true),
                                                          style: FilledButton.styleFrom(
                                                            backgroundColor:
                                                                theme
                                                                    .colorScheme
                                                                    .primary,
                                                          ),
                                                          child: Text(
                                                            l10n.scan,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  // Kullanıcı onaylamadıysa veya dialog kapatıldıysa çık
                                                  if (confirmed != true ||
                                                      !mounted)
                                                    return;

                                                  // Scan başlat
                                                  await ref
                                                      .read(
                                                        duplicateDetectionProvider
                                                            .notifier,
                                                      )
                                                      .scanAlbums(
                                                        selectedAlbums,
                                                        mode: _duplicateMode,
                                                      );

                                                  if (!mounted) return;
                                                },
                                          icon: hasNoScanRights
                                              ? Icons.block
                                              : Icons.search_rounded,
                                          label: hasNoScanRights
                                              ? l10n.noScanRightsLeft
                                              : l10n.scanSelectedAlbums,
                                          isEnabled:
                                              !isScanning && !hasNoScanRights,
                                          isError: hasNoScanRights,
                                          estimatedTimeText: estimatedTimeText,
                                          hasLimitWarning: hasLimitWarning,
                                          totalPhotoCount: totalPhotoCount,
                                        );
                                      },
                                    );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
      ),
    );
  }

  Widget _buildScanForm(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kompakt info card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.secondaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.content_copy_rounded,
                  size: 28,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.aiPowered,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.duplicatePhotoDetection,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.duplicateDetectionDescriptionFromAppBar,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        height: 1.3,
                        color: theme.colorScheme.onPrimaryContainer.withOpacity(
                          0.8,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Scan limit info
        _ScanLimitInfo(adUnitType: AdUnitType.duplicateScanLimit),
        const SizedBox(height: 8),
        // Kompakt mode section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.duplicateMode,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Mode levels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDuplicateModeChip(
                    theme,
                    l10n.duplicateModeLowSpeedHighAccuracy,
                    Icons.precision_manufacturing_rounded,
                    DuplicateDetectionMode.lowSpeedHighAccuracy,
                    _duplicateMode ==
                        DuplicateDetectionMode.lowSpeedHighAccuracy,
                    () => setState(
                      () => _duplicateMode =
                          DuplicateDetectionMode.lowSpeedHighAccuracy,
                    ),
                  ),
                  _buildDuplicateModeChip(
                    theme,
                    l10n.duplicateModeBalanced,
                    Icons.balance_rounded,
                    DuplicateDetectionMode.balanced,
                    _duplicateMode == DuplicateDetectionMode.balanced,
                    () => setState(
                      () => _duplicateMode = DuplicateDetectionMode.balanced,
                    ),
                  ),
                  _buildDuplicateModeChip(
                    theme,
                    l10n.duplicateModeHighSpeedLowAccuracy,
                    Icons.speed_rounded,
                    DuplicateDetectionMode.highSpeedLowAccuracy,
                    _duplicateMode ==
                        DuplicateDetectionMode.highSpeedLowAccuracy,
                    () => setState(
                      () => _duplicateMode =
                          DuplicateDetectionMode.highSpeedLowAccuracy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Kompakt description
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.duplicateModeLevelsDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        height: 1.3,
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicateModeChip(
    ThemeData theme,
    String label,
    IconData icon,
    DuplicateDetectionMode mode,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(
                        0.3,
                      ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.4)
                      : theme.colorScheme.outline.withOpacity(0.1),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tahmini scan süresini hesapla (saniye cinsinden) - Static versiyon
  /// Estimated scan duration ve limit kontrolü
  /// Returns: ({estimatedSeconds: int, totalPhotoCount: int, hasLimitWarning: bool})
  static Future<
    ({int estimatedSeconds, int totalPhotoCount, bool hasLimitWarning})
  >
  _estimateScanDurationStatic(
    List<pm.AssetPathEntity> albums,
    bool isBlurScan,
  ) async {
    try {
      int totalPhotoCount = 0;

      for (final album in albums) {
        try {
          final count = await album.assetCountAsync;
          totalPhotoCount += count;
        } catch (e) {
          // Hata durumunda tahmin et
          debugPrint(
            '⚠️ [SwipePage] Albüm sayısı alınamadı: ${album.name}, $e',
          );
          // Ortalama albüm boyutu tahmini
          totalPhotoCount += 500;
        }
      }

      // 1000 fotoğraf limit kontrolü
      const maxPhotos = 1000;
      final hasLimitWarning = totalPhotoCount > maxPhotos;

      // Limit varsa 1000 fotoğraf için hesapla
      final effectivePhotoCount = hasLimitWarning ? maxPhotos : totalPhotoCount;

      // Fotoğraf başına ortalama işleme süresi (saniye)
      // Blur detection: ~0.15 saniye/fotoğraf (400x400 thumbnail + çoklu analiz)
      // Duplicate detection: ~0.08 saniye/fotoğraf (hash hesaplama)
      final secondsPerPhoto = isBlurScan ? 0.15 : 0.08;

      // Toplam tahmini süre (saniye) - limit varsa 1000 fotoğraf için
      final estimatedSeconds = (effectivePhotoCount * secondsPerPhoto).round();

      // Minimum 5 saniye, maksimum 300 saniye (5 dakika)
      return (
        estimatedSeconds: estimatedSeconds.clamp(5, 300),
        totalPhotoCount: totalPhotoCount,
        hasLimitWarning: hasLimitWarning,
      );
    } catch (e) {
      debugPrint('⚠️ [SwipePage] Tahmini süre hesaplanamadı: $e');
      return (estimatedSeconds: 30, totalPhotoCount: 0, hasLimitWarning: false);
    }
  }

  /// Süreyi formatla (örn: "~30 saniye", "~2 dakika") - Static versiyon
  static String _formatEstimatedTimeStatic(int seconds, AppLocalizations l10n) {
    if (seconds < 60) {
      return l10n.estimatedTimeSeconds(seconds);
    } else {
      final minutes = (seconds / 60).round();
      return l10n.estimatedTimeMinutes(minutes);
    }
  }

  static Widget _buildModernScanButton({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required bool isEnabled,
    required bool isError,
    String? estimatedTimeText,
    bool hasLimitWarning = false,
    int totalPhotoCount = 0,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (estimatedTimeText != null && isEnabled && !isError) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.estimatedScanTime(estimatedTimeText),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (hasLimitWarning && isEnabled && !isError) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warningLight.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warningLight.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.warningLight,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.maxPhotoLimitWarning(totalPhotoCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warningLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isEnabled ? onPressed : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: isError
                  ? AppColors
                        .error // Daha belirgin kırmızı
                  : isEnabled
                  ? AppColors.primary.withOpacity(0.85)
                  : theme.colorScheme.surfaceContainerHighest,
              disabledBackgroundColor: isError
                  ? AppColors
                        .error // Disabled durumda da kırmızı
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: isError
                  ? AppColors
                        .white // Kırmızı üzerinde beyaz text
                  : isEnabled
                  ? AppColors.white
                  : theme.colorScheme.onSurface.withOpacity(0.6),
              disabledForegroundColor: isError
                  ? AppColors
                        .white // Disabled durumda da beyaz text
                  : theme.colorScheme.onSurface.withOpacity(0.6),
              side: BorderSide(
                color: isError
                    ? AppColors
                          .error // Kırmızı border
                    : isEnabled
                    ? AppColors.primary.withOpacity(0.9)
                    : theme.colorScheme.onSurface.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsView(
    BuildContext context,
    DuplicateDetectionState state,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final albumEntries = state.duplicatesByAlbum.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    if (albumEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Modern illustration container
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.secondary.withOpacity(0.15),
                      AppColors.primary.withOpacity(0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 8,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background pattern
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: RadialGradient(
                            center: Alignment.topLeft,
                            radius: 1.5,
                            colors: [
                              AppColors.accent.withOpacity(0.1),
                              AppColors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Main icon with decorative elements
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.secondary.withOpacity(0.1),
                            border: Border.all(
                              color: AppColors.secondary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.collections_rounded,
                            size: 64,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Decorative elements - overlapping circles
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.secondary.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Main title
              Text(
                l10n.noDuplicatesFoundTitle,
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
              // Detailed description
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      l10n.scanCompletedSuccessfullyDuplicate,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                        height: 1.6,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.noDuplicatePhotosFound,
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
              // Retry scan button with gradient
              Consumer(
                builder: (context, ref, _) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.primary.withOpacity(0.85), // Soluk iç renk
                          AppColors.accent.withOpacity(0.75), // Soluk iç renk
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(
                          0.9,
                        ), // Koyu border
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
                        ref.read(duplicateDetectionProvider.notifier).clear();
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

    return Column(
      children: [
        // Kompakt Success Banner
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.scanCompleted,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      l10n.scanCompletedDuplicateMessage(state.totalGroups),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.8,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  ref.read(duplicateDetectionProvider.notifier).clear();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      l10n.startNewScan,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Modern Stats Cards with gradient
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
        // Modern Duplicate Grid
        Expanded(child: buildDuplicateGrid(context, state, theme, l10n, ref)),
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

  Future<void> _deleteGroup(
    BuildContext context,
    DuplicatePhotoGroup group,
    AppLocalizations l10n,
    ThemeData theme,
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

    if (confirmed != true || !mounted) return;

    final deletedCount = await ref
        .read(duplicateDetectionProvider.notifier)
        .deleteDuplicates([group]);

    if (!mounted) return;

    await ref.read(deleteLimitProvider.notifier).decrease(deletedCount);
  }

  Future<void> _showDuplicateGroupDetail(
    BuildContext context,
    DuplicatePhotoGroup group,
    AppLocalizations l10n,
    ThemeData theme,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => _DuplicateGroupDetailSheet(
        group: group,
        onDelete: () {
          Navigator.of(context).pop();
          _deleteGroup(context, group, l10n, theme);
        },
      ),
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  const _DuplicateGroupCard({
    required this.group,
    required this.onDelete,
    required this.onTap,
  });

  final DuplicatePhotoGroup group;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final toDelete = group.duplicatesToDelete;

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
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Main thumbnail as background
                      if (group.assets.isNotEmpty)
                        FutureBuilder(
                          future: group.assets[0].thumbnailDataWithSize(
                            const pm.ThumbnailSize(400, 400),
                            quality: 85,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                  );
                                },
                              );
                            }
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
                          },
                        ),
                      // Gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.transparent,
                                AppColors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Count badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${group.assets.length}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Delete button
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: AppColors.black.withValues(alpha: 0.5),
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: onDelete,
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
                      // Info at bottom
                      Positioned(
                        bottom: 8,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${toDelete.length} ${l10n.photo}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${group.spaceToSaveMB.toStringAsFixed(1)} MB',
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
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
    );
  }
}

class _ScanLimitInfo extends ConsumerStatefulWidget {
  const _ScanLimitInfo({required this.adUnitType});

  final AdUnitType adUnitType;

  @override
  ConsumerState<_ScanLimitInfo> createState() => _ScanLimitInfoState();
}

class _ScanLimitInfoState extends ConsumerState<_ScanLimitInfo>
    with SingleTickerProviderStateMixin {
  final RewardedAdsService _adsService = RewardedAdsService.instance;
  bool _isLoadingAd = false;
  bool _isAdReady = false;
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _breathingAnimation = CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    );
    // Reklam yüklemesi artık dialog açıldığında yapılacak
    // initState'te yükleme yapılmıyor
  }

  @override
  void dispose() {
    _breathingController.dispose();
    // Don't dispose the service, it's a singleton
    super.dispose();
  }

  void _updateBreathingState() {
    if (!mounted) return;
    final bool isEnabled = !_isLoadingAd && _isAdReady;
    if (isEnabled) {
      if (!_breathingController.isAnimating) {
        _breathingController
          ..reset()
          ..repeat(reverse: true);
      }
    } else {
      if (_breathingController.isAnimating) {
        _breathingController.stop();
      }
      _breathingController.reset();
    }
  }

  void _loadAd() {
    // Reklam zaten yüklenmişse veya yükleniyorsa, tekrar yükleme isteği yapma
    if (!_adsService.isAdReadyOrLoading(widget.adUnitType)) {
      _adsService.loadRewardedAd(widget.adUnitType);
    }
    _checkAdReady();
  }

  void _checkAdReady() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final isReady = _adsService.isAdReady(widget.adUnitType);
        if (_isAdReady != isReady) {
          setState(() {
            _isAdReady = isReady;
          });
          _updateBreathingState();
        }
        if (!isReady) {
          _checkAdReady();
        }
      }
    });
  }

  Future<void> _watchAd() async {
    if (_isLoadingAd || !_isAdReady || !mounted) return;

    setState(() {
      _isLoadingAd = true;
    });
    _updateBreathingState();

    try {
      final success = await _adsService.showRewardedAd(
        type: widget.adUnitType,
        onRewarded: () async {
          if (!mounted) return;

          try {
            // Increase scan limit by 100 based on ad unit type
            final prefsService = PreferencesService();
            if (widget.adUnitType == AdUnitType.blurScanLimit) {
              await prefsService.increaseBlurScanLimit(100);
              if (mounted) {
                ref.invalidate(blurScanLimitProvider);
              }
            } else if (widget.adUnitType == AdUnitType.duplicateScanLimit) {
              await prefsService.increaseDuplicateScanLimit(100);
              if (mounted) {
                ref.invalidate(duplicateScanLimitProvider);
              }
            } else {
              // Fallback to old scan limit for backward compatibility
              await prefsService.increaseScanLimit(100);
              if (mounted) {
                ref.invalidate(scanLimitProvider);
              }
            }
          } catch (e) {
            debugPrint('❌ [ScanLimitInfo] Error in onRewarded callback: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ [ScanLimitInfo] Ad error: $error');
        },
      );

      if (success && mounted) {
        // Ad was shown successfully, check if new ad is ready
        _checkAdReady();
      } else if (mounted) {
        // Ad was not ready, update state
        setState(() {
          _isAdReady = false;
        });
        _updateBreathingState();
        _checkAdReady();
      }
    } catch (e) {
      debugPrint('❌ [ScanLimitInfo] Error showing ad: $e');
      if (mounted) {
        setState(() {
          _isAdReady = false;
        });
        _updateBreathingState();
        _checkAdReady();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAd = false;
        });
        _updateBreathingState();
      }
    }
  }

  void _showAddRightsDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isBlur = widget.adUnitType == AdUnitType.blurScanLimit;

    // Dialog açıldığında reklam yüklemesi başlat
    _loadAd();

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.black.withOpacity(0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.9 + (value * 0.1),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.2),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  l10n.increaseScanRights,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Watch Ad button - sadece reklam hazırsa tıklanabilir
                Material(
                  color: AppColors.transparent,
                  child: InkWell(
                    onTap: _isAdReady && !_isLoadingAd
                        ? () async {
                            Navigator.of(dialogContext).pop();
                            await _watchAd();
                          }
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Opacity(
                      opacity: _isAdReady && !_isLoadingAd ? 1.0 : 0.5,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.secondaryContainer,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isAdReady && !_isLoadingAd
                                  ? l10n.watchAdToGetScanLimit(100)
                                  : l10n.adNotReady,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Premium purchase button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      settings.SettingsPage.showPurchaseDialog(context);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isBlur
                          ? l10n.buyUnlimitedBlurRights
                          : l10n.buyUnlimitedDuplicateRights,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Cancel button
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface.withOpacity(
                      0.7,
                    ),
                  ),
                  child: Text(
                    l10n.cancel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Use appropriate provider based on ad unit type
    final scanLimitAsync = widget.adUnitType == AdUnitType.blurScanLimit
        ? ref.watch(blurScanLimitProvider)
        : widget.adUnitType == AdUnitType.duplicateScanLimit
        ? ref.watch(duplicateScanLimitProvider)
        : ref.watch(scanLimitProvider);

    final isPremiumAsync = ref.watch(isPremiumProvider);

    return scanLimitAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (scanLimit) {
        return isPremiumAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (isPremium) {
            if (isPremium) {
              // Premium kullanıcılar için şaşalı container - sonsuzluk işareti ve premium ikon
              // Container decoration kaldırıldı
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premium scan rights container - şaşalı tasarım
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Premium scan rights badge - sonsuzluk işareti ile
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primaryContainer,
                                  theme.colorScheme.primaryContainer
                                      .withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.3,
                                ),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.4,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 3,
                                ),
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.25,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.15,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 1),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.search_rounded,
                                            size: 13,
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer
                                                .withOpacity(0.9),
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              l10n.remainingScanRights,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 10,
                                                    color: theme
                                                        .colorScheme
                                                        .onPrimaryContainer
                                                        .withOpacity(0.9),
                                                    letterSpacing: 0.4,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '∞',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 26,
                                              color: theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                              letterSpacing: -1.5,
                                              height: 1,
                                              shadows: [
                                                Shadow(
                                                  color: theme
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.5),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 2),
                                                ),
                                                Shadow(
                                                  color: theme
                                                      .colorScheme
                                                      .onPrimaryContainer
                                                      .withOpacity(0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Premium icon button
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.primaryContainer,
                                        theme.colorScheme.primaryContainer
                                            .withOpacity(0.7),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.5),
                                        blurRadius: 12,
                                        offset: const Offset(0, 2),
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 22,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Album selection dropdown button
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: Consumer(
                            builder: (context, ref, _) {
                              final albumsAsync = ref.watch(albumsProvider);
                              final selectedAlbum = ref.watch(
                                selectedAlbumProvider,
                              );
                              final albumsData = albumsAsync.asData?.value;
                              final canOpenAlbumPicker =
                                  albumsData != null && albumsData.isNotEmpty;
                              final displayAlbumName =
                                  selectedAlbum?.name ?? l10n.allPhotos;

                              Future<void> openAlbumPicker() async {
                                final availableAlbums = albumsData;
                                if (availableAlbums == null ||
                                    availableAlbums.isEmpty)
                                  return;
                                await _presentAlbumPicker(
                                  context: context,
                                  albums: availableAlbums,
                                  selectedAlbum: selectedAlbum,
                                  onSelected: (album) {
                                    ref
                                            .read(
                                              selectedAlbumProvider.notifier,
                                            )
                                            .state =
                                        album;
                                  },
                                );
                              }

                              return Material(
                                color: AppColors.transparent,
                                child: InkWell(
                                  onTap: canOpenAlbumPicker
                                      ? openAlbumPicker
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.colorScheme.outline
                                            .withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.photo_library_outlined,
                                          size: 16,
                                          color: canOpenAlbumPicker
                                              ? theme.colorScheme.onSurface
                                              : theme.colorScheme.onSurface
                                                    .withOpacity(0.3),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            displayAlbumName,
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                  color: canOpenAlbumPicker
                                                      ? theme
                                                            .colorScheme
                                                            .onSurface
                                                      : theme
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.3),
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          size: 20,
                                          color: canOpenAlbumPicker
                                              ? theme.colorScheme.onSurface
                                                    .withOpacity(0.7)
                                              : theme.colorScheme.onSurface
                                                    .withOpacity(0.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Premium olmayan kullanıcılar için delete limit gibi yapı
            // Container decoration kaldırıldı
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Scan rights badge and Album selection
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Scan rights badge - Daha geniş, primary renk
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primaryContainer,
                                theme.colorScheme.primaryContainer.withOpacity(
                                  0.8,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.15,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.search_rounded,
                                          size: 13,
                                          color: theme
                                              .colorScheme
                                              .onPrimaryContainer
                                              .withOpacity(0.9),
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            l10n.remainingScanRights,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 10,
                                                  color: theme
                                                      .colorScheme
                                                      .onPrimaryContainer
                                                      .withOpacity(0.9),
                                                  letterSpacing: 0.3,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$scanLimit',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20,
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                            letterSpacing: -1.2,
                                            height: 1,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // + Button - her zaman tıklanabilir
                              Material(
                                color: AppColors.transparent,
                                child: InkWell(
                                  onTap: () => _showAddRightsDialog(context),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .onPrimaryContainer
                                          .withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Album selection dropdown button
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final albumsAsync = ref.watch(albumsProvider);
                            final selectedAlbum = ref.watch(
                              selectedAlbumProvider,
                            );
                            final albumsData = albumsAsync.asData?.value;
                            final canOpenAlbumPicker =
                                albumsData != null && albumsData.isNotEmpty;
                            final displayAlbumName =
                                selectedAlbum?.name ?? l10n.allPhotos;

                            Future<void> openAlbumPicker() async {
                              final availableAlbums = albumsData;
                              if (availableAlbums == null ||
                                  availableAlbums.isEmpty)
                                return;
                              await _presentAlbumPicker(
                                context: context,
                                albums: availableAlbums,
                                selectedAlbum: selectedAlbum,
                                onSelected: (album) {
                                  ref
                                          .read(selectedAlbumProvider.notifier)
                                          .state =
                                      album;
                                },
                              );
                            }

                            return Material(
                              color: AppColors.transparent,
                              child: InkWell(
                                onTap: canOpenAlbumPicker
                                    ? openAlbumPicker
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  height: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.photo_library_outlined,
                                        size: 16,
                                        color: canOpenAlbumPicker
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface
                                                  .withOpacity(0.3),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          displayAlbumName,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: canOpenAlbumPicker
                                                    ? theme
                                                          .colorScheme
                                                          .onSurface
                                                    : theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withOpacity(0.3),
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        size: 20,
                                        color: canOpenAlbumPicker
                                            ? theme.colorScheme.onSurface
                                                  .withOpacity(0.7)
                                            : theme.colorScheme.onSurface
                                                  .withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DuplicateGroupDetailSheet extends StatelessWidget {
  const _DuplicateGroupDetailSheet({
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.duplicatePhotos,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.photosInGroup(group.assets.length)} • ${l10n.totalDuplicates}: ${toDelete.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.keepOldest,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Text(
                  '${group.spaceToSaveMB.toStringAsFixed(1)} MB',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: sortedAssets.length,
              itemBuilder: (context, index) {
                final asset = sortedAssets[index];
                final isKeep = asset.id == keepAsset.id;
                final isToDelete = toDelete.any((a) => a.id == asset.id);

                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isKeep
                              ? AppColors.success
                              : isToDelete
                              ? theme.colorScheme.error
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.2,
                                ),
                          width: isKeep || isToDelete ? 3 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: FutureBuilder(
                          future: asset.thumbnailDataWithSize(
                            const pm.ThumbnailSize(300, 300),
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
                            return Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Icon(
                                  Icons.photo,
                                  size: 40,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isKeep
                              ? AppColors.success
                              : theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isKeep ? l10n.keepOldest : l10n.deleteDuplicates,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${asset.width}x${asset.height}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
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

class SwipePage extends ConsumerStatefulWidget {
  const SwipePage({super.key});

  @override
  ConsumerState<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends ConsumerState<SwipePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late AnimationController _historyPulseController;
  late AnimationController _blurTabPulseController;
  late AnimationController _duplicateTabPulseController;
  final SoundService _soundService = SoundService();

  int? _previousTabIndex; // Scan sırasında tab değişimini engellemek için
  bool _tabListenerAdded = false; // Listener'ın eklenip eklenmediğini takip et

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _previousTabIndex = _tabController.index;
    
    _historyPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _blurTabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _duplicateTabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Interstisial ad servisine premium dialog callback'i ayarla
    InterstitialAdsService.instance.onPremiumDialogTrigger = () {
      if (mounted) {
        _showPremiumDialog();
      }
    };

    // Lifecycle observer'ı ekle (arka plan/ön plan kontrolü için)
    WidgetsBinding.instance.addObserver(this);

    // İzin durumunu hemen kontrol et - böylece izin varsa hiç izin ekranı gösterilmez
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // İzin durumunu refresh et (güncel durumu almak için)
      await ref.read(permissionsControllerProvider.notifier).refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Arka plana geçildiğinde scanner sesini durdur
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _soundService.stopScannerSound();
    }
    // Ön plana döndüğünde, eğer scan devam ediyorsa sesi tekrar başlat
    else if (state == AppLifecycleState.resumed) {
      final blurState = ref.read(blurDetectionProvider);
      final duplicateState = ref.read(duplicateDetectionProvider);

      // Eğer blur veya duplicate scan devam ediyorsa sesi başlat
      if (blurState.isScanning || duplicateState.isScanning) {
        _soundService.playScannerSound();
      }
    }
  }

  void _showPremiumDialog() {
    if (!mounted) return;
    debugPrint(
      '💰 [SwipePage] Showing premium dialog after 3 interstitial ads',
    );
    // PremiumAfterAdsDialog'u göster
    PremiumAfterAdsDialog.show(context);
  }

  /// Scan tamamlandığında interstitial ad göster ve sonra results sayfasına yönlendir
  Future<void> _showInterstitialAdAndNavigate(String route) async {
    if (!mounted) return;

    debugPrint('📱 [SwipePage] Scan completed, showing interstitial ad before navigating to $route');

    // Premium kontrolü
    final prefsService = PreferencesService();
    final isPremium = await prefsService.isPremium();

    if (!isPremium) {
      debugPrint('📱 [SwipePage] Non-premium user, showing interstitial ad...');
      try {
        final adService = InterstitialAdsService.instance;

        // Ad göster ve kapatılmasını bekle
        try {
          debugPrint('📱 [SwipePage] Attempting to show interstitial ad...');
          final adShown = await adService
              .showAd()
              .timeout(
                const Duration(seconds: 35),
                onTimeout: () {
                  debugPrint(
                    '⚠️ [SwipePage] Ad showing timeout, continuing to navigate',
                  );
                  return false;
                },
              )
              .catchError((e) {
                debugPrint(
                  '⚠️ [SwipePage] Ad showing error: $e, continuing to navigate',
                );
                return false;
              });

          debugPrint('📱 [SwipePage] Ad shown result: $adShown');

          if (adShown == true) {
            // Ad kapatıldı, kısa bir bekleme sonra navigate et
            debugPrint(
              '📱 [SwipePage] Ad was shown, waiting 500ms before navigation...',
            );
            await Future.delayed(const Duration(milliseconds: 500));
          } else {
            debugPrint(
              '📱 [SwipePage] Ad was not shown, proceeding to navigation...',
            );
          }
        } catch (e) {
          debugPrint(
            '⚠️ [SwipePage] Error showing ad: $e, continuing to navigate',
          );
          // Hata olsa bile devam et
        }
      } catch (e) {
        debugPrint(
          '⚠️ [SwipePage] Error in ad flow: $e, continuing to navigate',
        );
        // Hata olsa bile navigate et
      }
    } else {
      debugPrint('💰 [SwipePage] Premium user, skipping ad...');
    }

    // Ad gösterildikten sonra (veya premium kullanıcı ise) results sayfasına yönlendir
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          context.push(route);
        }
      });
    }
  }

  @override
  void dispose() {
    // Lifecycle observer'ı kaldır
    WidgetsBinding.instance.removeObserver(this);

    // Callback'i temizle
    InterstitialAdsService.instance.onPremiumDialogTrigger = null;

    _tabController.dispose();
    _historyPulseController.dispose();
    _blurTabPulseController.dispose();
    _duplicateTabPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final permission = ref.watch(permissionsControllerProvider);
    final selectedAlbum = ref.watch(selectedAlbumProvider);
    final blurState = ref.watch(blurDetectionProvider);
    final duplicateState = ref.watch(duplicateDetectionProvider);
    final isScanning = blurState.isScanning || duplicateState.isScanning;

    // TabController listener - scan sırasında tab değişimini engelle
    // Listener'ı sadece bir kez ekle
    if (!_tabListenerAdded) {
      _tabController.addListener(() {
        if (!mounted) return;
        final blurState = ref.read(blurDetectionProvider);
        final duplicateState = ref.read(duplicateDetectionProvider);
        final isScanning = blurState.isScanning || duplicateState.isScanning;
        
        if (isScanning && _previousTabIndex != null) {
          // Scan sırasında tab değişimini geri al
          if (_tabController.index != _previousTabIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _tabController.index != _previousTabIndex) {
                _tabController.animateTo(_previousTabIndex!);
              }
            });
          }
        } else {
          // Normal durumda önceki index'i güncelle
          _previousTabIndex = _tabController.index;
        }
      });
      _tabListenerAdded = true;
    } else if (!isScanning) {
      // Listener zaten var, sadece önceki index'i güncelle
      _previousTabIndex = _tabController.index;
    }

    // İzin durumu değiştiğinde dinle - otomatik analiz yapılmıyor
    // Analiz sadece permission_request_page'de izin verildiğinde (ilk defa) başlatılıyor
    // veya kullanıcı galeri istatistikleri sayfasından "Tekrardan Analiz Et" butonuna basarak başlatıyor
    ref.listen<GalleryPermissionStatus>(permissionsControllerProvider, (
      previous,
      next,
    ) {
      // İzin durumu değişikliği sadece UI güncellemesi için kullanılıyor
      // Otomatik analiz başlatılmıyor
    });

    // Blur tarama durumunu dinle - tarama bittiğinde pulse başlat ve results sayfasına yönlendir
    ref.listen<BlurDetectionState>(blurDetectionProvider, (previous, next) {
      if (!mounted) return;

      final wasScanning = previous?.isScanning ?? false;
      final isNowScanning = next.isScanning;
      final hasCompleted = next.hasCompletedScan && !next.isScanning;

      // Tarama bittiğinde ve tamamlandıysa interstitial ad göster ve results sayfasına yönlendir
      if (wasScanning && !isNowScanning && hasCompleted) {
        // Önce interstitial ad göster, sonra results sayfasına yönlendir
        _showInterstitialAdAndNavigate('/results/blur');
      }
    });

    // Duplicate tarama durumunu dinle - tarama bittiğinde pulse başlat ve results sayfasına yönlendir
    ref.listen<DuplicateDetectionState>(duplicateDetectionProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;

      final wasScanning = previous?.isScanning ?? false;
      final isNowScanning = next.isScanning;
      final hasCompleted = next.hasCompletedScan && !next.isScanning;

      // Tarama bittiğinde ve tamamlandıysa interstitial ad göster ve results sayfasına yönlendir
      if (wasScanning && !isNowScanning && hasCompleted) {
        // Önce interstitial ad göster, sonra results sayfasına yönlendir
        _showInterstitialAdAndNavigate('/results/duplicate');
      }
    });

    // İzin durumu unknown ise lottie'li splash loading göster (izin kontrolü yapılıyor)
    // Böylece izin varsa hiç izin ekranı gösterilmez
    if (permission == GalleryPermissionStatus.unknown) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withOpacity(0.1),
                theme.colorScheme.secondary.withOpacity(0.05),
                AppColors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lottie animasyonu
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Lottie.asset(
                    'assets/lottie/loading.json',
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
                const SizedBox(height: 32),
                // App ismi
                Text(
                  'Gallery Cleaner',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // İzin yoksa izin ekranı göster
    if (permission != GalleryPermissionStatus.authorized) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: AppColors.transparent,
          elevation: 0,
          title: Text(l10n.appTitle, overflow: TextOverflow.ellipsis),
        ),
        body: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 120,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      l10n.galleryPermissionRequired,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.galleryPermissionDescription,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PermissionFeature(
                            icon: Icons.swipe,
                            title: l10n.quickCleanupTitle,
                            description: l10n.quickCleanupDescription,
                          ),
                          const SizedBox(height: 16),
                          _PermissionFeature(
                            icon: Icons.folder,
                            title: l10n.organizeTitle,
                            description: l10n.organizeDescription,
                          ),
                          const SizedBox(height: 16),
                          _PermissionFeature(
                            icon: Icons.delete_outline,
                            title: l10n.safeDeleteTitle,
                            description: l10n.safeDeleteDescription,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.lock_open),
                          label: Text(l10n.grantPermission),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () async {
                            await ref
                                .read(permissionsControllerProvider.notifier)
                                .request();
                            // İzin verildiğinde otomatik analiz başlatılmıyor
                            // Analiz sadece permission_request_page'de izin verildiğinde (ilk defa) başlatılıyor
                            // veya kullanıcı galeri istatistikleri sayfasından "Tekrardan Analiz Et" butonuna basarak başlatıyor
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // Premium badge - en solda (leading)
        leading: Consumer(
          builder: (context, ref, _) {
            final isPremiumAsync = ref.watch(isPremiumProvider);
            return isPremiumAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (isPremium) {
                // Premium kullanıcıda buton görünür, tıklanabilir ve sarı renkte
                // Tıklandığında premium success dialog gösterilir
                // Premium olmayan kullanıcıda paywall page'e yönlendir
                return IconButton(
                  onPressed: isScanning
                      ? null // Scan sırasında tıklanamaz
                      : isPremium
                          ? () async {
                              // Premium kullanıcıda premium success dialog göster
                              await PremiumSuccessDialog.show(context);
                            }
                          : () {
                              context.push('/paywall');
                            },
                  icon: Icon(
                    Icons.workspace_premium_rounded,
                    color: isScanning
                        ? theme.colorScheme.onSurface.withOpacity(0.38)
                        : isPremium
                            ? AppColors
                                  .warningLight // Premium kullanıcıda sarı renk
                            : theme.colorScheme.primary,
                  ),
                  tooltip: isScanning
                      ? l10n.doNotLeaveScreenDuringScan
                      : isPremium
                          ? 'Premium Aktif'
                          : l10n.unlockPremiumFeatures,
                );
              },
            );
          },
        ),
        centerTitle: false,
        backgroundColor: theme.colorScheme.background,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: AppDecorations.glassSurface(
              borderRadius: 20,
              tint: theme.colorScheme.surface,
              opacity: theme.brightness == Brightness.light ? 0.7 : 0.32,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: IgnorePointer(
              ignoring: isScanning, // Scan sırasında tüm TabBar'ı devre dışı bırak
              child: Opacity(
                opacity: isScanning ? 0.5 : 1.0, // Scan sırasında görsel olarak da belirt
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    // Scan sırasında tab değişimini engelle
                    if (isScanning) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.doNotLeaveScreenDuringScan),
                          duration: const Duration(seconds: 2),
                          backgroundColor: theme.colorScheme.errorContainer,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    HapticFeedback.lightImpact();
                    _previousTabIndex = index; // Önceki index'i güncelle
                    // Tab değiştiğinde pulse animasyonlarını durdur
                    if (_blurTabPulseController.isAnimating) {
                      _blurTabPulseController.stop();
                      _blurTabPulseController.reset();
                    }
                    if (_duplicateTabPulseController.isAnimating) {
                      _duplicateTabPulseController.stop();
                      _duplicateTabPulseController.reset();
                    }
                  },
              indicator: AppDecorations.pill(
                color: theme.colorScheme.primary,
                borderRadius: 16,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: AppColors.transparent,
              labelColor: theme.colorScheme.onPrimary,
              unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(
                0.7,
              ),
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
              tabs: [
                Tab(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swipe_rounded, size: 20),
                      const SizedBox(width: 6),
                      Text(l10n.swipeTab),
                    ],
                  ),
                ),
                Tab(height: 56, child: const _BlurTabIndicator()),
                Tab(height: 56, child: const _DuplicateTabIndicator()),
              ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          _HistoryButton(
            pulseController: _historyPulseController,
            isScanning: isScanning,
          ),
          IconButton(
            icon: Icon(
              Icons.settings,
              color: isScanning
                  ? theme.colorScheme.onSurface.withOpacity(0.38)
                  : null,
            ),
            tooltip: isScanning ? l10n.doNotLeaveScreenDuringScan : l10n.settings,
            onPressed: isScanning
                ? null // Scan sırasında tıklanamaz
                : () {
                    context.push('/settings');
                  },
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [_SwipeTab(), _BlurTab(), _DuplicateTab()],
        ),
      ),
    );
  }
}

int _topIndexHint(List<pm.AssetEntity> list, pm.AssetEntity current) {
  return list.indexWhere((e) => e.id == current.id);
}

// History button with pulse animation when gallery stats scan completes
class _HistoryButton extends ConsumerStatefulWidget {
  const _HistoryButton({
    required this.pulseController,
    required this.isScanning,
  });
  final AnimationController pulseController;
  final bool isScanning;

  @override
  ConsumerState<_HistoryButton> createState() => _HistoryButtonState();
}

class _HistoryButtonState extends ConsumerState<_HistoryButton> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statsState = ref.watch(galleryStatsProvider);
    final isScanning = statsState.isScanning;
    final hasNewData =
        statsState.stats != null &&
        statsState.previousStats != null &&
        !statsState.isFromCache &&
        !statsState.isScanning;

    // Galeri analizi tamamlandığında animasyonu başlat
    ref.listen<GalleryStatsState>(galleryStatsProvider, (previous, next) {
      if (!mounted) return;

      final wasScanning = previous?.isScanning ?? false;
      final isNowScanning = next.isScanning;
      final hasNewData =
          next.stats != null &&
          next.previousStats != null &&
          !next.isFromCache &&
          !next.isScanning;

      // Tarama bittiğinde ve yeni veri varsa pulse başlat
      if (wasScanning && !isNowScanning && hasNewData) {
        if (!widget.pulseController.isAnimating) {
          widget.pulseController.repeat(reverse: true);
        }
      } else if (!hasNewData || isNowScanning) {
        if (widget.pulseController.isAnimating) {
          widget.pulseController.stop();
          widget.pulseController.reset();
        }
      }
    });

    // Tarama bittiğinde ve yeni veri varsa pulse yap
    final shouldPulse = !isScanning && hasNewData;

    return AnimatedBuilder(
      animation: widget.pulseController,
      builder: (context, child) {
        final scale = shouldPulse
            ? 1.0 + (widget.pulseController.value * 0.15)
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: IconButton(
            icon: Icon(
              Icons.history,
              color: widget.isScanning
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.38)
                  : shouldPulse
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: widget.isScanning ? l10n.doNotLeaveScreenDuringScan : l10n.history,
            onPressed: widget.isScanning
                ? null // Scan sırasında tıklanamaz
                : () {
                    // İstatistikler sayfasına git
                    if (context.mounted) {
                      context.push('/gallery/stats');
                      // Pulse'u durdur
                      if (widget.pulseController.isAnimating) {
                        widget.pulseController.stop();
                        widget.pulseController.reset();
                      }
                    }
                  },
          ),
        );
      },
    );
  }
}

void _maybePrefetch(
  WidgetRef ref,
  List<pm.AssetEntity> assets,
  pm.AssetEntity current,
) {
  if (assets.length - _topIndexHint(assets, current) < 6) {
    ref.read(galleryPagingControllerProvider.notifier).loadMore();
  }
}

Future<void> _showAlbumSelectionDialog(
  BuildContext context,
  WidgetRef ref,
  pm.AssetEntity asset,
  List<pm.AssetEntity> assets,
) async {
  debugPrint('📁 [SwipePage] Albüm seçim dialogu açılıyor');

  final albumsAsync = ref.read(albumsProvider);

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
    builder: (context) => _AlbumSelectionSheet(albums: albums),
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
      ok = await ref
          .read(mediaLibraryServiceProvider)
          .moveAssetToAlbum(asset: asset, album: selectedAlbum);
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

      // Dosya boyutunu al
      final file = await asset.file;
      final fileSize = file != null ? await file.length() : 0;

      ref
          .read(reviewHistoryControllerProvider.notifier)
          .addMove(asset.id, selectedAlbum.id, fileSizeBytes: fileSize);

      // Başarı haptic feedback
      HapticFeedback.lightImpact();

      _maybePrefetch(ref, assets, asset);
    } else if (context.mounted) {
      debugPrint(
        '❌ [SwipePage] Albüme taşıma BAŞARISIZ: ${asset.id} → ${selectedAlbum.id}',
      );
      // Hata haptic feedback
      HapticFeedback.heavyImpact();
    }
  }
}

class _DeleteLimitInfo extends ConsumerStatefulWidget {
  const _DeleteLimitInfo();

  @override
  ConsumerState<_DeleteLimitInfo> createState() => _DeleteLimitInfoState();
}

class _DeleteLimitInfoState extends ConsumerState<_DeleteLimitInfo>
    with SingleTickerProviderStateMixin {
  final RewardedAdsService _adsService = RewardedAdsService.instance;
  bool _isLoadingAd = false;
  bool _isAdReady = false;
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _breathingAnimation = CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    );
    // Reklam yüklemesi artık dialog açıldığında yapılacak
    // initState'te yükleme yapılmıyor
  }

  void _checkAdReady() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final isReady = _adsService.isAdReady(AdUnitType.deleteLimit);
        if (_isAdReady != isReady) {
          setState(() {
            _isAdReady = isReady;
          });
          _updateBreathingState();
        }
        if (!isReady) {
          _checkAdReady();
        }
      }
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    // Don't dispose the service, it's a singleton
    super.dispose();
  }

  void _updateBreathingState() {
    if (!mounted) return;
    final bool isEnabled = !_isLoadingAd && _isAdReady;
    if (isEnabled) {
      if (!_breathingController.isAnimating) {
        _breathingController
          ..reset()
          ..repeat(reverse: true);
      }
    } else {
      if (_breathingController.isAnimating) {
        _breathingController.stop();
      }
      _breathingController.reset();
    }
  }

  Future<void> _watchAd() async {
    if (_isLoadingAd || !_isAdReady || !mounted) return;

    setState(() {
      _isLoadingAd = true;
    });
    _updateBreathingState();

    try {
      final success = await _adsService.showRewardedAd(
        type: AdUnitType.deleteLimit,
        onRewarded: () async {
          if (!mounted) return;

          try {
            // Increase delete limit by 20
            await ref.read(deleteLimitProvider.notifier).increase(20);
          } catch (e) {
            debugPrint('❌ [SwipePage] Error in onRewarded callback: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ [SwipePage] Ad error: $error');
        },
      );

      if (success && mounted) {
        // Ad was shown successfully, check if new ad is ready
        _checkAdReady();
      } else if (mounted) {
        // Ad was not ready, update state
        setState(() {
          _isAdReady = false;
        });
        _updateBreathingState();
        _checkAdReady();
      }
    } catch (e) {
      debugPrint('❌ [SwipePage] Error showing ad: $e');
      if (mounted) {
        setState(() {
          _isAdReady = false;
        });
        _updateBreathingState();
        _checkAdReady();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAd = false;
        });
        _updateBreathingState();
      }
    }
  }

  void _showAddRightsDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Reklam zaten uygulama açılışında yüklenmiş olmalı, sadece durumu kontrol et
    _checkAdReady();

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.black.withOpacity(0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.9 + (value * 0.1),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.2),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  l10n.increaseDeletionRights,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Watch Ad button - sadece reklam hazırsa tıklanabilir
                Material(
                  color: AppColors.transparent,
                  child: InkWell(
                    onTap: _isAdReady && !_isLoadingAd
                        ? () async {
                            Navigator.of(dialogContext).pop();
                            await _watchAd();
                          }
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Opacity(
                      opacity: _isAdReady && !_isLoadingAd ? 1.0 : 0.5,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.secondaryContainer,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isAdReady && !_isLoadingAd
                                  ? '${l10n.watchAdToEarn} +20'
                                  : l10n.adNotReady,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Premium purchase button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      settings.SettingsPage.showPurchaseDialog(context);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.buyUnlimitedRights,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Cancel button
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface.withOpacity(
                      0.7,
                    ),
                  ),
                  child: Text(
                    l10n.cancel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final deleteLimitAsync = ref.watch(deleteLimitProvider);
    final isPremiumAsync = ref.watch(isPremiumProvider);

    return deleteLimitAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (deleteLimit) {
        return isPremiumAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (isPremium) {
            // Container decoration kaldırıldı
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Deletion rights badge and Album selection
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Deletion rights badge - Premium için parlak tasarım
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primaryContainer,
                                theme.colorScheme.primaryContainer.withOpacity(
                                  0.8,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isPremium
                                  ? theme.colorScheme.primary.withOpacity(0.3)
                                  : theme.colorScheme.primary.withOpacity(0.2),
                              width: isPremium ? 2 : 1,
                            ),
                            boxShadow: isPremium
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                      spreadRadius: 3,
                                    ),
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                      spreadRadius: 1,
                                    ),
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 1),
                                      spreadRadius: 0,
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                      spreadRadius: 0,
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: ColorFiltered(
                                            colorFilter: ColorFilter.mode(
                                              theme
                                                  .colorScheme
                                                  .onPrimaryContainer
                                                  .withOpacity(0.9),
                                              BlendMode.srcATop,
                                            ),
                                            child: Lottie.asset(
                                              'assets/lottie/trash.json',
                                              width: 13,
                                              height: 13,
                                              fit: BoxFit.contain,
                                              repeat: true,
                                              options: LottieOptions(
                                                enableMergePaths: true,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            l10n.remainingDeletionRights,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontWeight: isPremium
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  fontSize: 10,
                                                  color: theme
                                                      .colorScheme
                                                      .onPrimaryContainer
                                                      .withOpacity(0.9),
                                                  letterSpacing: isPremium
                                                      ? 0.4
                                                      : 0.3,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPremium ? '∞' : '$deleteLimit',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            fontSize: isPremium ? 26 : 20,
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                            letterSpacing: isPremium
                                                ? -1.5
                                                : -1.2,
                                            height: 1,
                                            shadows: isPremium
                                                ? [
                                                    Shadow(
                                                      color: theme
                                                          .colorScheme
                                                          .primary
                                                          .withOpacity(0.5),
                                                      blurRadius: 10,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                    Shadow(
                                                      color: theme
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                          .withOpacity(0.3),
                                                      blurRadius: 6,
                                                      offset: const Offset(
                                                        0,
                                                        1,
                                                      ),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Premium icon veya + Button
                              if (isPremium)
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.primaryContainer,
                                        theme.colorScheme.primaryContainer
                                            .withOpacity(0.7),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.5),
                                        blurRadius: 12,
                                        offset: const Offset(0, 2),
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 22,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                )
                              else
                                Material(
                                  color: AppColors.transparent,
                                  child: InkWell(
                                    onTap: () => _showAddRightsDialog(context),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme
                                              .colorScheme
                                              .onPrimaryContainer
                                              .withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Album selection dropdown button
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final albumsAsync = ref.watch(albumsProvider);
                            final selectedAlbum = ref.watch(
                              selectedAlbumProvider,
                            );
                            final albumsData = albumsAsync.asData?.value;
                            final canOpenAlbumPicker =
                                albumsData != null && albumsData.isNotEmpty;
                            final displayAlbumName =
                                selectedAlbum?.name ?? l10n.allPhotos;

                            Future<void> openAlbumPicker() async {
                              final availableAlbums = albumsData;
                              if (availableAlbums == null ||
                                  availableAlbums.isEmpty)
                                return;
                              await _presentAlbumPicker(
                                context: context,
                                albums: availableAlbums,
                                selectedAlbum: selectedAlbum,
                                onSelected: (album) {
                                  ref
                                          .read(selectedAlbumProvider.notifier)
                                          .state =
                                      album;
                                },
                              );
                            }

                            return Material(
                              color: AppColors.transparent,
                              child: InkWell(
                                onTap: canOpenAlbumPicker
                                    ? openAlbumPicker
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  height: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.photo_library_outlined,
                                        size: 16,
                                        color: canOpenAlbumPicker
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface
                                                  .withOpacity(0.3),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          displayAlbumName,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: canOpenAlbumPicker
                                                    ? theme
                                                          .colorScheme
                                                          .onSurface
                                                    : theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withOpacity(0.3),
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        size: 20,
                                        color: canOpenAlbumPicker
                                            ? theme.colorScheme.onSurface
                                                  .withOpacity(0.7)
                                            : theme.colorScheme.onSurface
                                                  .withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AnimatedSwipeInstructions extends StatefulWidget {
  const _AnimatedSwipeInstructions();

  @override
  State<_AnimatedSwipeInstructions> createState() =>
      _AnimatedSwipeInstructionsState();
}

class _AnimatedSwipeInstructionsState extends State<_AnimatedSwipeInstructions>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Delete action - animated
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sem.delete.withOpacity(0.1 * _pulseAnimation.value),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sem.delete.withOpacity(0.4 * _pulseAnimation.value),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: sem.delete.withOpacity(0.2 * _pulseAnimation.value),
                    blurRadius: 8 * _pulseAnimation.value,
                    spreadRadius: 1 * _pulseAnimation.value,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        sem.delete,
                        BlendMode.srcATop,
                      ),
                      child: Lottie.asset(
                        'assets/lottie/left.json',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.delete,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: sem.delete,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: 1,
                height: 16,
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            // Keep action - animated
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sem.keep.withOpacity(0.1 * _pulseAnimation.value),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sem.keep.withOpacity(0.4 * _pulseAnimation.value),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: sem.keep.withOpacity(0.2 * _pulseAnimation.value),
                    blurRadius: 8 * _pulseAnimation.value,
                    spreadRadius: 1 * _pulseAnimation.value,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.keep,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: sem.keep,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        sem.keep,
                        BlendMode.srcATop,
                      ),
                      child: Lottie.asset(
                        'assets/lottie/right.json',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PurchaseFeatureItem extends StatelessWidget {
  const _PurchaseFeatureItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Blur tab indicator (nefes alma animasyonu kaldırıldı)
class _BlurTabIndicator extends ConsumerStatefulWidget {
  const _BlurTabIndicator();

  @override
  ConsumerState<_BlurTabIndicator> createState() => _BlurTabIndicatorState();
}

class _BlurTabIndicatorState extends ConsumerState<_BlurTabIndicator> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final blurState = ref.watch(blurDetectionProvider);
    final isScanning = blurState.isScanning;
    final hasCompleted = blurState.hasCompletedScan && !isScanning;

    // Nefes alma animasyonu kaldırıldı - sadece statik gösterim
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.blur_on_rounded,
          size: 20,
          color: hasCompleted ? theme.colorScheme.primary : null,
        ),
        const SizedBox(width: 6),
        Text(l10n.blurTab),
        if (hasCompleted) ...[
          const SizedBox(width: 4),
          Icon(Icons.check_circle, size: 14, color: theme.colorScheme.primary),
        ],
      ],
    );
  }
}

// Duplicate tab indicator (nefes alma animasyonu kaldırıldı)
class _DuplicateTabIndicator extends ConsumerStatefulWidget {
  const _DuplicateTabIndicator();

  @override
  ConsumerState<_DuplicateTabIndicator> createState() =>
      _DuplicateTabIndicatorState();
}

class _DuplicateTabIndicatorState
    extends ConsumerState<_DuplicateTabIndicator> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final duplicateState = ref.watch(duplicateDetectionProvider);
    final isScanning = duplicateState.isScanning;
    final hasCompleted = duplicateState.hasCompletedScan && !isScanning;

    // Nefes alma animasyonu kaldırıldı - sadece statik gösterim
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.content_copy_rounded,
          size: 20,
          color: hasCompleted ? theme.colorScheme.primary : null,
        ),
        const SizedBox(width: 6),
        Text(l10n.duplicateTab),
        if (hasCompleted) ...[
          const SizedBox(width: 4),
          Icon(Icons.check_circle, size: 14, color: theme.colorScheme.primary),
        ],
      ],
    );
  }
}

// Permission feature widget for permission request screen
class _PermissionFeature extends StatelessWidget {
  const _PermissionFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _showDeleteSuccessDialog(
  BuildContext context,
  int deletedCount,
) async {
  debugPrint(
    '🎯 [SwipePage] _showDeleteSuccessDialog çağrıldı - deletedCount: $deletedCount',
  );

  if (!context.mounted) {
    debugPrint(
      '❌ [SwipePage] Context not mounted at start, cannot show dialog',
    );
    return;
  }

  // Root context'i başta sakla - reklam akışından sonra kullanmak için
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final rootContext = rootNavigator.context;
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  // Premium kontrolü - premium kullanıcılar reklam görmesin
  debugPrint('🔍 [SwipePage] Checking premium status...');
  final prefsService = PreferencesService();
  final isPremium = await prefsService.isPremium();
  debugPrint('💰 [SwipePage] Premium status: $isPremium');

  // Premium değilse interstitial ad göster (önce ad, sonra dialog)
  // Ad başarısız olsa bile dialog mutlaka gösterilecek
  // Reklam zaten uygulama açılışında yüklenmiş olmalı
  if (!isPremium) {
    debugPrint('📱 [SwipePage] Non-premium user, showing interstitial ad...');
    try {
      final adService = InterstitialAdsService.instance;

      // Ad göster ve kapatılmasını bekle (timeout ile - maksimum 35 saniye bekle)
      // showAd zaten 30 saniye timeout'a sahip, ekstra 5 saniye buffer
      try {
        debugPrint('📱 [SwipePage] Attempting to show preloaded ad...');
        final adShown = await adService
            .showAd()
            .timeout(
              const Duration(seconds: 35),
              onTimeout: () {
                debugPrint(
                  '⚠️ [SwipePage] Ad showing timeout, continuing to show dialog',
                );
                return false;
              },
            )
            .catchError((e) {
              debugPrint(
                '⚠️ [SwipePage] Ad showing error: $e, continuing to show dialog',
              );
              return false;
            });

        debugPrint('📱 [SwipePage] Ad shown result: $adShown');

        if (adShown == true) {
          // Ad kapatıldı, kısa bir bekleme sonra dialog göster
          debugPrint(
            '📱 [SwipePage] Ad was shown, waiting 500ms before dialog...',
          );
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          debugPrint(
            '📱 [SwipePage] Ad was not shown, proceeding to dialog...',
          );
        }
      } catch (e) {
        debugPrint(
          '⚠️ [SwipePage] Error showing ad: $e, continuing to show dialog',
        );
        // Hata olsa bile devam et
      }
    } catch (e) {
      debugPrint(
        '⚠️ [SwipePage] Error in ad flow: $e, continuing to show dialog',
      );
      // Hata olsa bile dialog göster
    }
  } else {
    debugPrint('💰 [SwipePage] Premium user, skipping ad...');
  }

  // Context kontrolü - ad gösterildikten sonra
  // Root context'i kullan - başta sakladığımız root context'i kullan
  BuildContext dialogContext;
  if (context.mounted) {
    dialogContext = context;
  } else {
    // Context unmount olduysa başta sakladığımız root context'i kullan
    dialogContext = rootContext;
    debugPrint(
      '✅ [SwipePage] Using root navigator context for dialog (original context unmounted)',
    );
  }

  // Dialog'u göster (ad gösterilmiş olsun veya olmasın - HER KOŞULDA)
  // Root navigator kullanarak context unmount olsa bile dialog göster
  debugPrint(
    '✅ [SwipePage] Showing cleanup complete dialog - deletedCount: $deletedCount',
  );

  try {
    debugPrint('🎬 [SwipePage] Calling showDialog...');
    await Future.delayed(const Duration(milliseconds: 100)); // Kısa bir bekleme
    await showDialog(
      context: dialogContext,
      useRootNavigator: true, // Root navigator kullan
      barrierDismissible: true,
      barrierColor: AppColors.black.withOpacity(0.5),
      builder: (dialogContext) {
        debugPrint('🎬 [SwipePage] Dialog builder called');
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
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withOpacity(0.15),
                    blurRadius: 24,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lottie animation
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Lottie.asset(
                      'assets/lottie/wipe.json',
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    l10n.cleanupComplete,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Description with deleted count
                  Text(
                    l10n.cleanupCompleteMessageWithCount(deletedCount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Done button - uygulamadaki buton yapısına uygun
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: AppColors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(dialogContext).pop(),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                            child: Text(
                              l10n.done,
                              style: theme.textTheme.titleMedium?.copyWith(
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    debugPrint('✅ [SwipePage] showDialog completed successfully');
  } catch (e, stackTrace) {
    debugPrint('❌ [SwipePage] Error showing dialog: $e');
    debugPrint('❌ [SwipePage] Stack trace: $stackTrace');
  }
}

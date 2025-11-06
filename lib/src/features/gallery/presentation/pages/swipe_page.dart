import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../../../../core/services/sound_service.dart';
import '../../../../../l10n/app_localizations.dart';

import '../../application/gallery_providers.dart';
import '../../../onboarding/application/permissions_controller.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/services/rewarded_ads_service.dart';
import '../widgets/photo_swipe_deck.dart';
import '../../application/review_actions_controller.dart';
import '../../application/review_history_controller.dart';
import '../../../../app/theme/app_theme.dart';
import 'history_page.dart';

// Provider for tracking drag over "Change Album" zone
final _isDraggingOverChangeAlbumProvider = StateProvider<bool>((ref) => false);

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

class _AlbumSelector extends ConsumerWidget {
  const _AlbumSelector({
    required this.selectedAlbum,
    required this.albumsAsync,
    required this.onAlbumSelected,
  });

  final pm.AssetPathEntity? selectedAlbum;
  final AsyncValue<List<pm.AssetPathEntity>> albumsAsync;
  final ValueChanged<pm.AssetPathEntity?> onAlbumSelected;

  Future<void> _showAlbumPicker(
    BuildContext context,
    List<pm.AssetPathEntity> albums,
    pm.AssetPathEntity? currentSelection,
    ValueChanged<pm.AssetPathEntity?> onSelected,
  ) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<pm.AssetPathEntity?>(
      context: context,
      backgroundColor: Colors.transparent,
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  // "All Photos" option
                  _AlbumOption(
                    label: l10n.allPhotos,
                    icon: Icons.grid_view,
                    isSelected: currentSelection == null,
                    onTap: () {
                      Navigator.of(context).pop(null);
                      onSelected(null);
                    },
                  ),
                  const Divider(height: 1),
                  // Albums
                  ...albums.where((a) => !a.isAll).map((album) {
                    final isSelected = currentSelection?.id == album.id;
                    return _AlbumOption(
                      label: album.name,
                      icon: Icons.folder,
                      isSelected: isSelected,
                      onTap: () {
                        Navigator.of(context).pop(album);
                        onSelected(album);
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return albumsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (albums) {
        if (albums.isEmpty) return const SizedBox.shrink();

        final displayText = selectedAlbum == null
            ? l10n.allPhotos
            : selectedAlbum!.name;

        return InkWell(
          onTap: () =>
              _showAlbumPicker(context, albums, selectedAlbum, onAlbumSelected),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).appBarTheme.backgroundColor ??
                  Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(
                  selectedAlbum == null ? Icons.grid_view : Icons.folder,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlbumOption extends StatelessWidget {
  const _AlbumOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 20,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

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
                    Colors.transparent,
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
              decoration: BoxDecoration(
                color: isDraggingOver
                    ? theme.colorScheme.primaryContainer.withOpacity(0.95)
                    : theme.appBarTheme.backgroundColor ??
                          theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDraggingOver
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.4),
                  width: isDraggingOver ? 3 : 2,
                ),
                boxShadow: isDraggingOver
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.45),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
    required this.assets,
    required this.changeAlbumZoneKey,
  });

  final List<pm.AssetEntity> assets;
  final GlobalKey changeAlbumZoneKey;

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: AnimatedOpacity(
              opacity: _dragOpacity,
              duration: const Duration(milliseconds: 200),
              child: AnimatedScale(
                scale: _dragScale,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                child: Transform.translate(
                  offset: _dragOffset,
                  child: PhotoSwipeDeck(
                    assets: widget.assets,
                    isDraggingToAlbum: () => _isDraggingToAlbum,
                    onDragUpdate: _handleDragUpdate,
                    onDragEnd: (asset, pos) {
                      _handleDragEnd(asset, pos);
                    },
                    onDecision: (asset, decision) {
                      _handleDecision(asset, decision);
                    },
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
}

class SwipePage extends ConsumerWidget {
  const SwipePage({super.key});

  Widget _buildSwipeArea(
    WidgetRef _,
    List<pm.AssetEntity> assets,
    GlobalKey changeAlbumZoneKey,
  ) {
    return _SwipeAreaContent(
      assets: assets,
      changeAlbumZoneKey: changeAlbumZoneKey,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final permission = ref.watch(permissionsControllerProvider);
    final state = ref.watch(galleryPagingControllerProvider);

    // Debug summary for current build
    debugPrint('🧭 [SwipePage] build: permission=$permission');

    if (permission != GalleryPermissionStatus.authorized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle, overflow: TextOverflow.ellipsis),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.galleryPermissionRequired,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.read(permissionsControllerProvider.notifier).request(),
                child: Text(
                  l10n.grantPermission,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selectedAlbum = ref.watch(selectedAlbumProvider);
    final albumsAsync = ref.watch(albumsProvider);
    debugPrint('🧭 [SwipePage] selectedAlbum=${selectedAlbum?.name ?? "All"}');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.history,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.06),
                Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withOpacity(0.04),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            children: [
              // 1. Albüm seçme yapısı (hangi albümden swipe edileceği)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _AlbumSelector(
                  selectedAlbum: selectedAlbum,
                  albumsAsync: albumsAsync,
                  onAlbumSelected: (album) {
                    ref.read(selectedAlbumProvider.notifier).state = album;
                  },
                ),
              ),
              // state.when ile hem Change Album Zone hem de Swipe Area'yı birlikte yönet
              Expanded(
                child: state.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
                  data: (assets) {
                    if (assets.isEmpty) {
                      return Builder(
                        builder: (ctx) {
                          final l10n = AppLocalizations.of(ctx)!;
                          return Center(
                            child: Text(
                              l10n.noPhotosToShow,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      );
                    }
                    // GlobalKey for Change Album Zone - hem zone hem de swipe area için aynı key
                    final changeAlbumZoneKey = GlobalKey();

                    return Column(
                      children: [
                        // 2. Üzerine fotoğraf sürüklenip albüm değiştirmeye yarayan alan
                        // Padding(
                        //   padding: const EdgeInsets.symmetric(
                        //     horizontal: 16,
                        //     vertical: 8,
                        //   ),
                        //   child: _ChangeAlbumZone(
                        //     changeAlbumZoneKey: changeAlbumZoneKey,
                        //     onDragOver: (isOver) {
                        //       ref
                        //               .read(
                        //                 _isDraggingOverChangeAlbumProvider
                        //                     .notifier,
                        //               )
                        //               .state =
                        //           isOver;
                        //     },
                        //   ),
                        // ),
                        // 2. Kullanıcının 100 görsel silme hakkı bilgilendirmesi
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: _DeleteLimitInfo(),
                        ),
                        // 3. Swipe fotoğraf alanı
                        Expanded(
                          child: _buildSwipeArea(
                            ref,
                            assets,
                            changeAlbumZoneKey,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // 4. Sola kaydır sil sağa kaydır tut bilgilendirmesi
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: _AnimatedSwipeInstructions(),
              ),
              // Delete button - below swipe area
              Consumer(
                builder: (context, ref, _) {
                  final pending = ref.watch(reviewActionsControllerProvider);
                  final pendingCount = pending.length;

                  if (pendingCount == 0) return const SizedBox.shrink();

                  final l10n = AppLocalizations.of(context)!;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: () {
                              // Clear all pending deletions by undoing until empty
                              while (ref
                                  .read(reviewActionsControllerProvider)
                                  .isNotEmpty) {
                                ref
                                    .read(
                                      reviewActionsControllerProvider.notifier,
                                    )
                                    .undoLast();
                              }
                            },
                            child: Text(
                              l10n.undo,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                                width: 1.5,
                              ),
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.outline,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final deletedCount = await ref
                                  .read(
                                    reviewActionsControllerProvider.notifier,
                                  )
                                  .applyPendingDeletes();
                              if (context.mounted && deletedCount > 0) {
                                // Silme hakkını azalt
                                final prefsService = PreferencesService();
                                await prefsService.decreaseDeleteLimit(
                                  deletedCount,
                                );
                                // Provider'ı yeniden yükle
                                ref.invalidate(deleteLimitProvider);

                                _showDeleteSuccessDialog(context, deletedCount);
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: Text(l10n.deletePhotos(pendingCount)),
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
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _topIndexHint(List<pm.AssetEntity> list, pm.AssetEntity current) {
  return list.indexWhere((e) => e.id == current.id);
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

  final l10n = AppLocalizations.of(context)!;

  if (albums.isEmpty) {
    debugPrint('📁 [SwipePage] Albüm bulunamadı');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.albumNotFound, overflow: TextOverflow.ellipsis),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  debugPrint('📁 [SwipePage] Albüm seçim dialogu gösteriliyor...');

  // Albüm seçim dialogunu göster
  final selectedAlbum = await showModalBottomSheet<pm.AssetPathEntity>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AlbumSelectionSheet(albums: albums),
  );

  debugPrint('📁 [SwipePage] Seçilen albüm: ${selectedAlbum?.name ?? "null"}');

  if (selectedAlbum != null && context.mounted) {
    debugPrint(
      '📁 [SwipePage] Albüme taşıma işlemi başlatılıyor: ${asset.id} -> ${selectedAlbum.name}',
    );
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Loading göstergesi göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                l10n.movingToAlbum(selectedAlbum.name),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

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

    // Loading mesajını kapat
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
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

      // Başarı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.movedToAlbum(selectedAlbum.name),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      _maybePrefetch(ref, assets, asset);
    } else if (context.mounted) {
      debugPrint(
        '❌ [SwipePage] Albüme taşıma BAŞARISIZ: ${asset.id} → ${selectedAlbum.id}',
      );
      // Hata haptic feedback
      HapticFeedback.heavyImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onError,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.moveToAlbumFailed,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

class _DeleteLimitInfo extends ConsumerStatefulWidget {
  const _DeleteLimitInfo();

  @override
  ConsumerState<_DeleteLimitInfo> createState() => _DeleteLimitInfoState();
}

class _DeleteLimitInfoState extends ConsumerState<_DeleteLimitInfo> {
  final RewardedAdsService _adsService = RewardedAdsService();
  bool _isLoadingAd = false;
  bool _isAdReady = false;

  @override
  void initState() {
    super.initState();
    // Preload ad when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          _adsService.loadRewardedAd();
          // Check ad readiness periodically
          _checkAdReady();
        } catch (e) {
          debugPrint('❌ [SwipePage] Error loading ad in initState: $e');
        }
      }
    });
  }

  void _checkAdReady() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final isReady = _adsService.isAdReady;
        if (_isAdReady != isReady) {
          setState(() {
            _isAdReady = isReady;
          });
        }
        if (!isReady) {
          _checkAdReady();
        }
      }
    });
  }

  @override
  void dispose() {
    _adsService.dispose();
    super.dispose();
  }

  Future<void> _watchAd() async {
    if (_isLoadingAd || !_isAdReady || !mounted) return;

    setState(() {
      _isLoadingAd = true;
    });

    try {
      final success = await _adsService.showRewardedAd(
        onRewarded: () async {
          if (!mounted) return;

          try {
            // Increase delete limit by 20
            final prefsService = PreferencesService();
            await prefsService.increaseDeleteLimit(20);

            // Refresh the provider
            if (mounted) {
              ref.invalidate(deleteLimitProvider);
            }
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
        _checkAdReady();
      }
    } catch (e) {
      debugPrint('❌ [SwipePage] Error showing ad: $e');
      if (mounted) {
        setState(() {
          _isAdReady = false;
        });
        _checkAdReady();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAd = false;
        });
      }
    }
  }

  void _showPurchaseDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
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
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.all_inclusive_rounded,
                    size: 40,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  l10n.buyUnlimitedRights,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Subtitle - One-time payment for lifetime
                Text(
                  '${l10n.oneTimePayment} • ${l10n.lifetimeAccess}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // One-time payment badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    l10n.oneTimePayment,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 24),
                // Features
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _PurchaseFeatureItem(
                        icon: Icons.all_inclusive,
                        text:
                            '${l10n.unlimitedDeletions} • ${l10n.lifetimeAccess}',
                      ),
                      const SizedBox(height: 16),
                      _PurchaseFeatureItem(
                        icon: Icons.block,
                        text: l10n.noMoreAds,
                      ),
                      const SizedBox(height: 16),
                      _PurchaseFeatureItem(
                        icon: Icons.verified,
                        text: l10n.oneTimePayment,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Purchase button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // TODO: Implement actual purchase logic
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Purchase functionality will be implemented',
                          ),
                          backgroundColor: theme.colorScheme.primaryContainer,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.purchaseNow,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Cancel button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
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
                    overflow: TextOverflow.ellipsis,
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

    return deleteLimitAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (deleteLimit) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: Deletion rights badge and Watch Ad button
              Row(
                children: [
                  // Deletion rights badge - Daha geniş, primary renk
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.primaryContainer.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 13,
                                color: theme.colorScheme.onPrimaryContainer
                                    .withOpacity(0.9),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  l10n.remainingDeletionRights,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: theme.colorScheme.onPrimaryContainer
                                        .withOpacity(0.9),
                                    letterSpacing: 0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$deleteLimit',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: theme.colorScheme.onPrimaryContainer,
                              letterSpacing: -1.2,
                              height: 1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Watch Ad button - Daha küçük, amber/orange renk
                  Expanded(
                    flex: 2,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: (_isLoadingAd || !_isAdReady) ? null : _watchAd,
                        borderRadius: BorderRadius.circular(14),
                        child: Opacity(
                          opacity: (_isLoadingAd || !_isAdReady) ? 0.5 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.teal.shade400,
                                  Colors.cyan.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.teal.shade300.withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isLoadingAd)
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.play_circle_outline,
                                        size: 11,
                                        color: Colors.white.withOpacity(0.95),
                                      ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        l10n.watchAdToEarn,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 9,
                                              color: Colors.white.withOpacity(
                                                0.95,
                                              ),
                                              letterSpacing: 0.2,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.earnDeletionRights,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: Colors.white,
                                        letterSpacing: -0.8,
                                        height: 1,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Unlimited deletion rights button - Premium solid color
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _showPurchaseDialog(context);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onPrimary.withOpacity(
                                0.15,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.all_inclusive_rounded,
                              size: 20,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.buyUnlimitedRights,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: theme.colorScheme.onPrimary,
                                    letterSpacing: -0.4,
                                    height: 1.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 12,
                                      color: theme.colorScheme.onPrimary
                                          .withOpacity(0.9),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        l10n.oneTimePayment,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          color: theme.colorScheme.onPrimary
                                              .withOpacity(0.9),
                                          letterSpacing: 0.3,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: theme.colorScheme.onPrimary.withOpacity(0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
  late Animation<double> _arrowLeftAnimation;
  late Animation<double> _arrowRightAnimation;

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

    _arrowLeftAnimation = Tween<double>(
      begin: -3.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _arrowRightAnimation = Tween<double>(
      begin: 0.0,
      end: 3.0,
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
                  Transform.translate(
                    offset: Offset(_arrowLeftAnimation.value, 0),
                    child: Icon(Icons.arrow_back, size: 18, color: sem.delete),
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
                  Transform.translate(
                    offset: Offset(_arrowRightAnimation.value, 0),
                    child: Icon(Icons.arrow_forward, size: 18, color: sem.keep),
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

void _showDeleteSuccessDialog(BuildContext context, int deletedCount) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
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
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon with animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green.shade200.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.15),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 48,
                        color: Colors.green.shade600,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Success title
              Text(
                l10n.success,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Deleted count message
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        l10n.deletedSuccessfully(deletedCount),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // OK button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.ok,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
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

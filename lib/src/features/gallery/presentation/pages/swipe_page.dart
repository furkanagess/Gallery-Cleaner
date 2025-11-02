import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import '../../../../core/services/sound_service.dart';

import '../../application/gallery_providers.dart';
import '../../../onboarding/application/permissions_controller.dart';
import '../widgets/photo_swipe_deck.dart';
import '../../application/review_actions_controller.dart';
import '../../application/folder_targets_provider.dart';
import '../widgets/top_folder_targets.dart';
import '../../application/review_history_controller.dart';
import '../../../../app/theme/app_theme.dart';
import '../widgets/folder_target_selector.dart';
import 'history_page.dart';

class _AlbumSelectionSheet extends StatelessWidget {
  const _AlbumSelectionSheet({required this.albums});

  final List<pm.AssetPathEntity> albums;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
              'Albüm Seç',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                  title: Text(album.name),
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

class SwipePage extends ConsumerWidget {
  const SwipePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(permissionsControllerProvider);
    final state = ref.watch(galleryPagingControllerProvider);

    if (permission != GalleryPermissionStatus.authorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gallery Cleaner')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Galeri izni gerekli.'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.read(permissionsControllerProvider.notifier).request(),
                child: const Text('İzin Ver'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Gallery Cleaner'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Klasör Hedefleri',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => const FolderTargetSelectorSheet(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Geçmiş',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryPage()));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient and soft shapes
          Positioned.fill(
            child: Builder(builder: (context) {
              final scheme = Theme.of(context).colorScheme;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withOpacity(0.06),
                      scheme.secondaryContainer.withOpacity(0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            }),
          ),
          Positioned(
            top: kToolbarHeight - 30,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(child: Text('Gösterilecek fotoğraf yok.'));
          }
          // Ensure targets are initialized by activating init effect provider
          ref.watch(folderTargetsInitEffectProvider);
          final targets = ref.watch(targetAlbumsProvider);

          int? hoverIndex;
          const double targetsHeight = 96;
          const double targetsTop = 84; // place targets lower, just above photo area
          final double deckTopPadding = targetsTop + targetsHeight + 16;

          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, deckTopPadding, 16, 24),
                  child: StatefulBuilder(
                    builder: (context, setLocal) {
                      double dragScale = 1.0;
                      bool isDraggingToAlbum = false;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: AspectRatio(
                                aspectRatio: 3 / 4,
                                child: Stack(
                                  children: [
                                    AnimatedScale(
                                      scale: dragScale,
                                      duration: const Duration(milliseconds: 120),
                                      curve: Curves.easeOut,
                                      child: PhotoSwipeDeck(
                                        assets: assets,
                                        isDraggingToAlbum: () => isDraggingToAlbum,
                                        onDragUpdate: (pos) {
                                          // pos global pozisyon (ekran koordinatları)
                                          final dy = pos.dy; // global y pozisyonu
                                          
                                          // Üstteki albüm hedeflerinin yüksekliği ve konumu
                                          final threshold = targetsTop;
                                          final dragThreshold = threshold + targetsHeight;
                                          
                                          // Yukarı sürükleniyor mu kontrol et (yukarı = daha küçük y değeri)
                                          // Albüm hedefleri ekranın üst kısmında, eğer dy threshold'tan küçükse yukarı sürükleniyor
                                          final isUpwardDrag = dy < dragThreshold;
                                          
                                          debugPrint('🔄 [SwipePage] onDragUpdate: dy=$dy, threshold=$dragThreshold, isUpwardDrag=$isUpwardDrag');
                                          
                                          if (isUpwardDrag) {
                                            // Yukarı sürükleniyor - albüm taşıma modu
                                            setLocal(() {
                                              if (!isDraggingToAlbum) {
                                                isDraggingToAlbum = true;
                                              }
                                              
                                              if (targets.isNotEmpty) {
                                                final screenWidth = MediaQuery.of(context).size.width;
                                                final slotWidth = screenWidth / targets.length;
                                                final dx = pos.dx;
                                                final idx = (dx / slotWidth).clamp(0, targets.length - 1).toInt();
                                                hoverIndex = idx;
                                              }
                                              
                                              // shrink proportionally as it approaches top targets
                                              final proximity = (dragThreshold - dy).clamp(0, 150);
                                              final factor = 1.0 - (proximity / 150) * 0.2; // shrink up to 20%
                                              dragScale = factor;
                                            });
                                          } else {
                                            // Yukarı sürüklenmiyor - normal swipe modu
                                            setLocal(() {
                                              if (isDraggingToAlbum) {
                                                isDraggingToAlbum = false;
                                              }
                                              hoverIndex = null;
                                              dragScale = 1.0;
                                            });
                                          }
                                        },
                                        onDragEnd: (pos) async {
                                          // ÖNEMLİ: wasDragging değerini setLocal'dan ÖNCE al
                                          final wasDragging = isDraggingToAlbum;
                                          final currentHoverIndex = hoverIndex;
                                          
                                          // Threshold değerlerini hesapla
                                          final threshold = targetsTop;
                                          final dragThreshold = threshold + targetsHeight;
                                          
                                          debugPrint('🔄 [SwipePage] onDragEnd çağrıldı: pos=$pos, wasDragging=$wasDragging, hoverIndex=$currentHoverIndex');
                                          debugPrint('🔄 [SwipePage] threshold=$threshold, targetsHeight=$targetsHeight, dragThreshold=$dragThreshold');
                                          
                                          // Ek kontrol: Global pozisyon kontrolü de yap
                                          final isUpwardDragByPos = pos.dy < dragThreshold;
                                          
                                          debugPrint('🔄 [SwipePage] isUpwardDragByPos=$isUpwardDragByPos (pos.dy=${pos.dy}, dragThreshold=$dragThreshold)');
                                          
                                          setLocal(() {
                                            hoverIndex = null;
                                            dragScale = 1.0;
                                            isDraggingToAlbum = false;
                                          });
                                          
                                          // Eğer yukarıya sürüklenmişse albüm seçim dialogunu aç
                                          if ((wasDragging || isUpwardDragByPos) && context.mounted) {
                                            debugPrint('🔄 [SwipePage] Yukarı sürükleme tespit edildi, albüm seçim dialogu açılıyor');
                                            
                                            // Tutma ses efektini çal (yukarı kaydırma = tutma)
                                            final soundService = SoundService();
                                            soundService.playKeepSound();
                                            
                                            final asset = assets.first;
                                            await _showAlbumSelectionDialog(context, ref, asset, assets);
                                          } else {
                                            debugPrint('🔄 [SwipePage] Yukarı sürükleme tespit edilmedi: wasDragging=$wasDragging, isUpwardDragByPos=$isUpwardDragByPos');
                                          }
                                        },
                                        onDecision: (asset, decision) async {
                                          final actions = ref.read(reviewActionsControllerProvider.notifier);
                                          if (decision == SwipeDecision.keep) {
                                            await actions.onKeep(asset);
                                            _maybePrefetch(ref, assets, asset);
                                            return;
                                          }
                                          await actions.onDelete(asset);
                                          _maybePrefetch(ref, assets, asset);
                                        },
                                      ),
                                    ),
                                    // Drag to album indicator
                                    if (isDraggingToAlbum && hoverIndex != null && hoverIndex! >= 0 && hoverIndex! < targets.length)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                                                width: 3,
                                              ),
                                            ),
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.95),
                                                  borderRadius: BorderRadius.circular(16),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.2),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.folder,
                                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                      size: 24,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      targets[hoverIndex!].name,
                                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      Icons.arrow_forward,
                                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                      size: 20,
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
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Builder(builder: (context) {
                            final sem = Theme.of(context).extension<AppSemanticColors>()!;
                            return Opacity(
                              opacity: 0.9,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.swipe_left, size: 18, color: sem.delete),
                                  const SizedBox(width: 6),
                                  const Text('Sola kaydır: Sil'),
                                  const SizedBox(width: 20),
                                  Icon(Icons.swipe_right, size: 18, color: sem.keep),
                                  const SizedBox(width: 6),
                                  const Text('Sağa kaydır: Tut'),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ),
              // Put targets last so they overlay above the photo
              Positioned(
                left: 0,
                right: 0,
                top: targetsTop,
                child: TopFolderTargets(albums: targets, hoverIndex: hoverIndex),
              ),
            ],
          );
        },
            ),
          ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final pending = ref.watch(reviewActionsControllerProvider);
          final pendingCount = pending.length;
          if (pendingCount == 0) return const SizedBox.shrink();
          
          return FloatingActionButton.extended(
            onPressed: () async {
              final deletedCount = await ref.read(reviewActionsControllerProvider.notifier).applyPendingDeletes();
              if (context.mounted && deletedCount > 0) {
                _showDeleteSuccessDialog(context, deletedCount);
              }
            },
            icon: const Icon(Icons.check),
            label: Text('$pendingCount Sil'),
            backgroundColor: Theme.of(context).extension<AppSemanticColors>()?.delete ?? Theme.of(context).colorScheme.error,
          );
        },
      ),
    );
  }
}

int _topIndexHint(List<pm.AssetEntity> list, pm.AssetEntity current) {
  return list.indexWhere((e) => e.id == current.id);
}

void _maybePrefetch(WidgetRef ref, List<pm.AssetEntity> assets, pm.AssetEntity current) {
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
  final albums = await albumsAsync.when(
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Albüm bulunamadı'),
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
    debugPrint('📁 [SwipePage] Albüme taşıma işlemi başlatılıyor: ${asset.id} -> ${selectedAlbum.name}');
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
            Text(
              '${selectedAlbum.name} albümüne taşınıyor...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
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
    final ok = await ref.read(mediaLibraryServiceProvider).addAssetToAlbum(
      asset: asset,
      album: selectedAlbum,
    );
    
    // Loading mesajını kapat
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
    
    if (ok && context.mounted) {
      ref.read(reviewHistoryControllerProvider.notifier).addMove(asset.id, selectedAlbum.id);
      
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
                  '${selectedAlbum.name} albümüne taşındı',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      
      _maybePrefetch(ref, assets, asset);
    } else if (context.mounted) {
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
                  'Albüme taşıma başarısız oldu. Lütfen tekrar deneyin.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onError),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

void _showDeleteSuccessDialog(BuildContext context, int deletedCount) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (Theme.of(context).extension<AppSemanticColors>()?.delete ?? Theme.of(context).colorScheme.error).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 48,
                color: Theme.of(context).extension<AppSemanticColors>()?.delete ??
                    Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Başarılı!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '$deletedCount fotoğraf başarıyla silindi.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Tamam'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}




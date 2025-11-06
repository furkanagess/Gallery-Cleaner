import 'dart:io';
import 'dart:typed_data';
// import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
// import '../../application/review_actions_controller.dart';
import '../../application/review_history_controller.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../../l10n/app_localizations.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final history = ref.watch(reviewHistoryControllerProvider);
    // final pending = ref.watch(reviewActionsControllerProvider);
    final semanticColors = Theme.of(context).extension<AppSemanticColors>();

    // Sadece onaylanan silme işlemleri ve tutma işlemlerini göster
    final visibleHistory = history.where((e) {
      // Keep işlemleri her zaman göster
      if (e.type == ReviewActionType.keep) return true;
      // Delete işlemleri sadece applied ise göster
      if (e.type == ReviewActionType.delete) {
        return e.status == ReviewActionStatus.applied;
      }
      // Move işlemleri gösterme
      return false;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          l10n.historyAndQueue,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        leading: Platform.isIOS
            ? IconButton(
                icon: const Icon(CupertinoIcons.back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              )
            : null,
        automaticallyImplyLeading: !Platform.isIOS,
        actions: const [],
      ),
      body: visibleHistory.isEmpty
          ? _buildEmptyState(context, l10n)
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Keep/Delete/Move stats at top
                  if (visibleHistory.isNotEmpty)
                    _buildStatsHeader(
                      context,
                      l10n,
                      visibleHistory,
                      semanticColors,
                    ),
                  // Space Saved metric card
                  _buildLifetimeStatsCard(
                    context,
                    l10n,
                    visibleHistory,
                    semanticColors,
                  ),
                  // Son silinen fotoğraflar bölümü
                  _buildRecentlyDeletedSection(
                    context,
                    l10n,
                    visibleHistory,
                    semanticColors,
                    ref,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: null,
    );
  }
}

// Lifetime Stats Card
Widget _buildLifetimeStatsCard(
  BuildContext context,
  AppLocalizations l10n,
  List<ReviewActionItem> history,
  AppSemanticColors? semanticColors,
) {
  // Sadece applied olan delete işlemlerini say
  final appliedDeletes = history
      .where(
        (e) =>
            e.type == ReviewActionType.delete &&
            e.status == ReviewActionStatus.applied,
      )
      .toList();

  // final totalDeletedCount = appliedDeletes.length;
  final totalBytesFreed = appliedDeletes.fold<int>(
    0,
    (sum, item) => sum + item.fileSizeBytes,
  );

  // Byte'ı okunabilir formata çevir
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // final totalReviewed = history
  //     .where(
  //       (e) =>
  //           e.type == ReviewActionType.keep ||
  //           (e.type == ReviewActionType.delete &&
  //               e.status == ReviewActionStatus.applied),
  //     )
  //     .length;

  // Removed Files Deleted card; formatting helper not needed now

  return Column(
    children: [
      _MetricCard(
        icon: Icons.data_saver_on_outlined,
        iconColor: semanticColors?.keep ?? Colors.green,
        label: AppLocalizations.of(context)!.totalSize,
        value: formatBytes(totalBytesFreed),
      ),
    ],
  );
}

// (Old _LifetimeStatBox removed in favor of simpler compact pills)

// Son silinen fotoğraflar bölümü
Widget _buildRecentlyDeletedSection(
  BuildContext context,
  AppLocalizations l10n,
  List<ReviewActionItem> history,
  AppSemanticColors? semanticColors,
  WidgetRef ref,
) {
  // Son silinen fotoğrafları al (en yeni 10 tanesi)
  final deletedItems =
      history
          .where(
            (e) =>
                e.type == ReviewActionType.delete &&
                e.status == ReviewActionStatus.applied,
          )
          .toList()
        ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));

  if (deletedItems.isEmpty) {
    return const SizedBox.shrink();
  }

  final recentDeleted = deletedItems.take(10).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Row(
          children: [
            Icon(
              Icons.delete_outline,
              color: semanticColors?.delete ?? Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.recentlyDeleted,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: recentDeleted.length,
          itemBuilder: (context, index) {
            final item = recentDeleted[index];
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _DeletedPhotoCard(
                item: item,
                semanticColors: semanticColors,
                onRestore: () {
                  _restoreDeletedPhoto(context, l10n, item, ref);
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

// Silinen fotoğraf kartı
class _DeletedPhotoCard extends StatelessWidget {
  const _DeletedPhotoCard({
    required this.item,
    required this.semanticColors,
    required this.onRestore,
  });

  final ReviewActionItem item;
  final AppSemanticColors? semanticColors;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _DeletedPhotoThumbnail(
              assetId: item.assetId,
              thumbnailBytes: item.thumbnailBytes,
            ),
          ),
        ),
        // Geri al butonu
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRestore,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.undo, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.undo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Geri alma işlemi
Future<void> _restoreDeletedPhoto(
  BuildContext context,
  AppLocalizations l10n,
  ReviewActionItem item,
  WidgetRef ref,
) async {
  // Kullanıcıya bilgi ver
  final shouldRestore = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.restorePhoto, overflow: TextOverflow.ellipsis),
      content: Text(l10n.restorePhotoMessage, overflow: TextOverflow.ellipsis),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel, overflow: TextOverflow.ellipsis),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.restore, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );

  if (shouldRestore == true) {
    // History'den kaldır veya status'ü değiştir
    ref.read(reviewHistoryControllerProvider.notifier).undoDelete(item.assetId);

    // Başarı mesajı göster
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.photoRestored, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// Empty state widget
Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.history,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.noHistoryYet,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          'Start reviewing photos to see your activity',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

// Stats header widget
Widget _buildStatsHeader(
  BuildContext context,
  AppLocalizations l10n,
  List<ReviewActionItem> history,
  AppSemanticColors? semanticColors,
) {
  final keepCount = history
      .where((e) => e.type == ReviewActionType.keep)
      .length;
  final deleteCount = history
      .where((e) => e.type == ReviewActionType.delete)
      .length;
  // final moveCount = history
  //     .where((e) => e.type == ReviewActionType.move)
  //     .length;

  return Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
    child: Row(
      children: [
        Expanded(
          child: _KDMStatCard(
            icon: Icons.check_circle_outline,
            color: semanticColors?.keep ?? Colors.green,
            label: l10n.keep,
            count: keepCount,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KDMStatCard(
            icon: Icons.delete_outline,
            color: semanticColors?.delete ?? Colors.red,
            label: l10n.delete,
            count: deleteCount,
          ),
        ),
        // const SizedBox(width: 10),
        // Expanded(
        //   child: _KDMStatCard(
        //     icon: Icons.drive_file_move_outline,
        //     color: Colors.blue,
        //     label: l10n.move,
        //     count: moveCount,
        //   ),
        // ),
      ],
    ),
  );
}

// (Old _StatItem removed in favor of _KDMStatCard)

class _KDMStatCard extends StatelessWidget {
  const _KDMStatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.75),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// History card widget
// (Old list card removed; replaced by grid items)

class _HistoryGridItem extends StatelessWidget {
  const _HistoryGridItem({required this.item, required this.semanticColors});

  final ReviewActionItem item;
  final AppSemanticColors? semanticColors;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.type) {
      ReviewActionType.keep => semanticColors?.keep ?? Colors.green,
      ReviewActionType.delete => semanticColors?.delete ?? Colors.red,
      ReviewActionType.move => Colors.blue,
    };

    final l10n = AppLocalizations.of(context)!;
    final statusLabel = switch (item.status) {
      ReviewActionStatus.pending => l10n.pending,
      ReviewActionStatus.applied => l10n.applied,
      ReviewActionStatus.undone => l10n.undone,
    };

    final action = switch (item.type) {
      ReviewActionType.keep => (
        l10n.keep,
        Icons.check_circle,
        semanticColors?.keep ?? Colors.green,
      ),
      ReviewActionType.delete => (
        l10n.delete,
        Icons.delete,
        semanticColors?.delete ?? Colors.red,
      ),
      ReviewActionType.move => (l10n.move, Icons.drive_file_move, Colors.blue),
    };

    final timestamp = DateTime.fromMillisecondsSinceEpoch(item.timestampMs);
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    String timeAgo;
    if (difference.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (difference.inMinutes < 60) {
      timeAgo = '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      timeAgo = '${difference.inHours}h ago';
    } else {
      timeAgo = '${difference.inDays}d ago';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _GridThumbnail(
              assetId: item.assetId,
              thumbnailBytes: item.thumbnailBytes,
            ),
            // Top-left action badge
            Positioned(
              top: 8,
              left: 8,
              child: _ActionPill(
                text: action.$1,
                icon: action.$2,
                color: action.$3,
              ),
            ),
            // Top-right status
            Positioned(
              top: 8,
              right: 8,
              child: _StatusPill(text: statusLabel, color: color),
            ),
            // Bottom gradient and time
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color.fromARGB(160, 0, 0, 0),
                      Color.fromARGB(0, 0, 0, 0),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridThumbnail extends StatelessWidget {
  const _GridThumbnail({required this.assetId, this.thumbnailBytes});
  final String assetId;
  final Uint8List? thumbnailBytes;

  @override
  Widget build(BuildContext context) {
    // Eğer kaydedilmiş thumbnail varsa, onu göster
    if (thumbnailBytes != null && thumbnailBytes!.isNotEmpty) {
      return Image.memory(thumbnailBytes!, fit: BoxFit.cover);
    }

    // Yoksa asset'ten thumbnail al
    return FutureBuilder<pm.AssetEntity?>(
      future: pm.AssetEntity.fromId(assetId),
      builder: (context, snapshot) {
        final asset = snapshot.data;
        if (asset == null) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 28),
            ),
          );
        }
        return FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(
            const pm.ThumbnailSize(600, 600),
            quality: 80,
          ),
          builder: (context, thumbSnapshot) {
            final bytes = thumbSnapshot.data;
            if (bytes == null || bytes.isEmpty) {
              return Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: const Center(
                  child: Icon(Icons.image, color: Colors.grey, size: 28),
                ),
              );
            }
            return Image.memory(bytes, fit: BoxFit.cover);
          },
        );
      },
    );
  }
}

// Silinen fotoğraf thumbnail widget'ı
class _DeletedPhotoThumbnail extends StatelessWidget {
  const _DeletedPhotoThumbnail({required this.assetId, this.thumbnailBytes});
  final String assetId;
  final Uint8List? thumbnailBytes;

  @override
  Widget build(BuildContext context) {
    // Eğer kaydedilmiş thumbnail varsa, onu göster
    if (thumbnailBytes != null && thumbnailBytes!.isNotEmpty) {
      return Image.memory(
        thumbnailBytes!,
        fit: BoxFit.cover,
        width: 100,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
            ),
          );
        },
      );
    }

    // Yoksa asset'ten thumbnail almaya çalış (silinmiş olsa bile bazı durumlarda çalışabilir)
    return FutureBuilder<pm.AssetEntity?>(
      future: pm.AssetEntity.fromId(assetId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final asset = snapshot.data;
        if (asset == null) {
          // Asset bulunamadı (silinmiş), placeholder göster
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error.withOpacity(0.6),
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deleted',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Asset bulundu, thumbnail al
        return FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(
            const pm.ThumbnailSize(200, 240),
            quality: 80,
          ),
          builder: (context, thumbSnapshot) {
            if (thumbSnapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final bytes = thumbSnapshot.data;
            if (bytes == null || bytes.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.image, color: Colors.grey, size: 32),
                ),
              );
            }
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: 100,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 32,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _HistoryPreviewGrid extends StatefulWidget {
  const _HistoryPreviewGrid({
    required this.items,
    required this.semanticColors,
  });

  final List<ReviewActionItem> items;
  final AppSemanticColors? semanticColors;

  @override
  State<_HistoryPreviewGrid> createState() => _HistoryPreviewGridState();
}

class _HistoryPreviewGridState extends State<_HistoryPreviewGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _offsetAnim = Tween<double>(
      begin: 0,
      end: -6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: widget.items.length,
          itemBuilder: (ctx, i) {
            return _HistoryGridItem(
              item: widget.items[i],
              semanticColors: widget.semanticColors,
            );
          },
        ),
        // Bottom fade + chevron hint
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surface.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _offsetAnim.value),
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.expand_more, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)!.continueButton,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FullHistoryPage extends ConsumerWidget {
  const FullHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(reviewHistoryControllerProvider);
    final semanticColors = Theme.of(context).extension<AppSemanticColors>();
    final l10n = AppLocalizations.of(context)!;

    // Sadece onaylanan silme işlemleri ve tutma işlemlerini göster
    final visibleHistory = history.where((e) {
      // Keep işlemleri her zaman göster
      if (e.type == ReviewActionType.keep) return true;
      // Delete işlemleri sadece applied ise göster
      if (e.type == ReviewActionType.delete) {
        return e.status == ReviewActionStatus.applied;
      }
      // Move işlemleri gösterme
      return false;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyAndQueue, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: visibleHistory.length,
              itemBuilder: (context, index) {
                return _HistoryGridItem(
                  item: visibleHistory[index],
                  semanticColors: semanticColors,
                );
              },
            ),
          ),
          // Animated continue button at bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: _AnimatedContinueButton(
              onPressed: () {
                context.go('/swipe');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedContinueButton extends StatefulWidget {
  const _AnimatedContinueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_AnimatedContinueButton> createState() =>
      _AnimatedContinueButtonState();
}

class _AnimatedContinueButtonState extends State<_AnimatedContinueButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
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
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.onPressed,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(
                      _glowAnimation.value,
                    ),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.continueButton,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onPrimary,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: _glowAnimation.value * 0.1,
                        duration: const Duration(milliseconds: 2000),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.text,
    required this.icon,
    required this.color,
  });
  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// (Old compact pill widget no longer used)

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// (Old small thumbnail widget removed; grid uses _GridThumbnail)

// _showDeleteSuccessDialog removed (no longer used)

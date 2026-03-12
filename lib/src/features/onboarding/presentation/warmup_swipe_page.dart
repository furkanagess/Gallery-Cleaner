import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_three_d_button.dart';
import '../../../core/services/media_library_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../gallery/application/asset_size_helper.dart';
import '../../gallery/application/gallery_providers.dart';
import '../../gallery/presentation/widgets/photo_swipe_deck.dart';
import '../../gallery/presentation/pages/review_delete_photos_page.dart'
    show showDeleteSummaryBottomSheet;
import 'package:flutter_bloc/flutter_bloc.dart';

/// Warm-up screen after permission: user swipes to "delete" 5 photos (oldest from gallery).
/// No real deletion; after 5 swipes the button becomes tappable to enter the app.
class WarmupSwipePage extends StatefulWidget {
  const WarmupSwipePage({super.key});

  @override
  State<WarmupSwipePage> createState() => _WarmupSwipePageState();
}

class _WarmupSwipePageState extends State<WarmupSwipePage>
    with TickerProviderStateMixin {
  static const int _targetDeleteCount = 5;
  static const int _warmupDeckSize = 30;

  List<pm.AssetEntity> _assets = [];
  bool _loading = true;
  String? _error;
  int _deletedCount = 0;
  final List<String> _idsToDelete = [];

  double _animatedDeleteOpacity = 0.0;
  double _animatedKeepOpacity = 0.0;
  double _cachedDeleteOverlayWidth = 0.0;
  double _cachedKeepOverlayWidth = 0.0;
  Offset? _pendingDragOffset;
  bool _hasPendingOffsetUpdate = false;

  late AnimationController _fillController;
  late Animation<double> _fillAnimation;
  double _fillTargetProgress = 0.0;

  int get _targetCount => _assets.isEmpty
      ? _targetDeleteCount
      : _targetDeleteCount.clamp(0, _assets.length);

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fillAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _fillController, curve: Curves.easeOutCubic),
    );
    _loadOldestPhotos();
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  void _animateFillTo(double targetProgress) {
    _fillTargetProgress = targetProgress.clamp(0.0, 1.0);
    _fillAnimation =
        Tween<double>(
          begin: _fillAnimation.value,
          end: _fillTargetProgress,
        ).animate(
          CurvedAnimation(parent: _fillController, curve: Curves.easeOutCubic),
        );
    _fillController.forward(from: 0);
  }

  Future<void> _loadOldestPhotos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final paths = await pm.PhotoManager.getAssetPathList(
        type: pm.RequestType.image,
        hasAll: true,
        onlyAll: true,
      );
      if (paths.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No album';
        });
        return;
      }
      final album = paths.first;
      final list = await album.getAssetListPaged(page: 0, size: 80);
      final sorted = List<pm.AssetEntity>.from(list)
        ..sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      final candidates = sorted.take(_warmupDeckSize).toList();
      if (!mounted) return;
      setState(() {
        _assets = candidates;
        _loading = false;
        _error = candidates.isEmpty ? 'No photos' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onDragOffsetChanged(Offset offset) {
    if (!mounted) return;
    _pendingDragOffset = offset;
    if (!_hasPendingOffsetUpdate) {
      _hasPendingOffsetUpdate = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pendingDragOffset == null) {
          if (mounted) _hasPendingOffsetUpdate = false;
          return;
        }
        final offsetToApply = _pendingDragOffset!;
        _pendingDragOffset = null;
        _hasPendingOffsetUpdate = false;

        final dragDx = offsetToApply.dx;
        final deleteOffsetAbsCalc = dragDx < 0 ? dragDx.abs() : 0.0;
        final deleteProgressCalc = deleteOffsetAbsCalc >= 10.0
            ? ((deleteOffsetAbsCalc - 10.0) / 100.0).clamp(0.0, 1.0)
            : 0.0;
        final targetDeleteOpacity = deleteProgressCalc > 0.0
            ? (0.3 + (deleteProgressCalc * 0.7)).clamp(0.3, 1.0)
            : 0.0;

        final keepOffsetCalc = dragDx > 0 ? dragDx : 0.0;
        final keepProgressCalc = keepOffsetCalc >= 10.0
            ? ((keepOffsetCalc - 10.0) / 100.0).clamp(0.0, 1.0)
            : 0.0;
        final targetKeepOpacity = keepProgressCalc > 0.0
            ? (0.3 + (keepProgressCalc * 0.7)).clamp(0.3, 1.0)
            : 0.0;

        final screenWidth = MediaQuery.of(context).size.width;
        // Overlay'ler ekranın en solundan / en sağından başlasın, tam genişliğe kadar (swipe page gibi)
        final newDeleteOverlayWidth = deleteProgressCalc * screenWidth;
        final newKeepOverlayWidth = keepProgressCalc * screenWidth;

        final deleteOpacityDelta =
            (targetDeleteOpacity - _animatedDeleteOpacity).abs();
        final keepOpacityDelta = (targetKeepOpacity - _animatedKeepOpacity)
            .abs();
        final deleteWidthDelta =
            (newDeleteOverlayWidth - _cachedDeleteOverlayWidth).abs();
        final keepWidthDelta = (newKeepOverlayWidth - _cachedKeepOverlayWidth)
            .abs();

        if (deleteOpacityDelta > 0.05 ||
            keepOpacityDelta > 0.05 ||
            deleteWidthDelta > 2.0 ||
            keepWidthDelta > 2.0 ||
            (targetDeleteOpacity == 0.0 && _animatedDeleteOpacity > 0.0) ||
            (targetKeepOpacity == 0.0 && _animatedKeepOpacity > 0.0)) {
          setState(() {
            _animatedDeleteOpacity = targetDeleteOpacity;
            _animatedKeepOpacity = targetKeepOpacity;
            _cachedDeleteOverlayWidth = newDeleteOverlayWidth;
            _cachedKeepOverlayWidth = newKeepOverlayWidth;
          });
        }
      });
    }
  }

  void _onDecision(pm.AssetEntity asset, SwipeDecision decision) {
    if (decision == SwipeDecision.delete) {
      HapticFeedback.lightImpact();
      setState(() {
        _deletedCount++;
        _idsToDelete.add(asset.id);
      });
      if (mounted) {
        final p = _targetCount > 0
            ? (_deletedCount / _targetCount).clamp(0.0, 1.0)
            : 0.0;
        _animateFillTo(p);
      }
    }
  }

  Future<void> _onContinue() async {
    if (_deletedCount < _targetCount || _idsToDelete.isEmpty) return;
    if (!mounted) return;
    final media = context.read<MediaLibraryService>();
    final deleteLimitCubit = context.read<DeleteLimitCubit>();
    final deletedIds = await media.deleteBatch(_idsToDelete);
    if (deletedIds.isNotEmpty) {
      await deleteLimitCubit.decrease(deletedIds.length);
    }
    if (!mounted) return;
    // Kullanıcı "silmeye izin verme" derse ekran kapanmasın; sadece silme başarılıysa dialog göster
    if (deletedIds.isEmpty) return;

    // Silinen fotoğrafların toplam boyutunu hesapla (MB)
    final deletedAssets = _assets
        .where((a) => deletedIds.contains(a.id))
        .toList();
    int totalBytes = 0;
    for (final a in deletedAssets) {
      totalBytes += await estimateAssetSize(a);
    }
    final sizeMB = totalBytes > 0
        ? (totalBytes / (1024 * 1024)).toStringAsFixed(1)
        : '0';
    if (!mounted) return;

    await showDeleteSummaryBottomSheet(
      context,
      deletedCount: deletedIds.length,
      deletedSizeMB: double.tryParse(sizeMB) ?? 0,
      onDone: () {
        if (!mounted) return;
        context.go('/swipe');
      },
    );
    return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(l10n.warmupLoading, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null || _assets.isEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.warmupNoPhotos,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loadOldestPhotos,
                    child: Text(l10n.warmupRetry),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/swipe'),
                    child: Text(l10n.warmupSkip),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final canContinue = _deletedCount >= _targetCount;

    final screenSize = MediaQuery.of(context).size;
    const buttonSize = 80.0;
    const buttonIconSize = 32.0;
    final buttonCenterY = screenSize.height / 2 - 120;
    final leftButtonCenterX = screenSize.width / 2 - 70;
    final rightButtonCenterX = screenSize.width / 2 + 70;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Material(
                  color: AppColors.transparent,
                  child: InkWell(
                    onTap: () => context.go('/swipe'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!canContinue) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.warmupTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: AspectRatio(
                  aspectRatio: 5 / 7,
                  child: RepaintBoundary(
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          ignoring: canContinue,
                          child: PhotoSwipeDeck(
                            key: ValueKey(
                              'warmup_${_assets.length}_${_assets.isNotEmpty ? _assets.map((a) => a.id).join("_") : "empty"}',
                            ),
                            assets: _assets,
                            initialIndex: 0,
                            canDelete: !canContinue,
                            isCompleted: canContinue,
                            onDecision: _onDecision,
                            onDragOffsetChanged: _onDragOffsetChanged,
                            completedTitle: l10n.warmupCompletionTitle(
                              _targetDeleteCount,
                            ),
                            completedDescription:
                                l10n.warmupCompletionDescription,
                          ),
                        ),
                        // Sol overlay - Sil (kırmızı)
                        if (_animatedDeleteOpacity > 0.0)
                          Positioned(
                            left: 0,
                            top: buttonCenterY - (buttonSize / 2),
                            height: buttonSize,
                            width: _cachedDeleteOverlayWidth,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: _animatedDeleteOpacity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        AppColors.error.withValues(alpha: 0.6),
                                        AppColors.error.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_animatedKeepOpacity > 0.0)
                          Positioned(
                            right: 0,
                            top: buttonCenterY - (buttonSize / 2),
                            height: buttonSize,
                            width: _cachedKeepOverlayWidth,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: _animatedKeepOpacity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerRight,
                                      end: Alignment.centerLeft,
                                      colors: [
                                        AppColors.success.withValues(
                                          alpha: 0.6,
                                        ),
                                        AppColors.success.withValues(
                                          alpha: 0.0,
                                        ),
                                      ],
                                      stops: const [0.0, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_animatedDeleteOpacity > 0.0)
                          Positioned(
                            left: leftButtonCenterX - (buttonSize / 2),
                            top: buttonCenterY - (buttonSize / 2),
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: _animatedDeleteOpacity,
                                child: Container(
                                  width: buttonSize,
                                  height: buttonSize,
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.delete_forever_rounded,
                                    size: buttonIconSize,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_animatedKeepOpacity > 0.0)
                          Positioned(
                            left: rightButtonCenterX - (buttonSize / 2),
                            top: buttonCenterY - (buttonSize / 2),
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: _animatedKeepOpacity,
                                child: Container(
                                  width: buttonSize,
                                  height: buttonSize,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    size: buttonIconSize,
                                    color: AppColors.white,
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
            ),
            const SizedBox(height: 16),
            // Swipe sayfasındaki sil butonu ile aynı UI; soldan sağa kırmızı dolum; tamamlanınca "Fotoğrafları Sil (5)"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: canContinue
                  ? AppThreeDButton(
                      label: l10n.deletePhotos(_targetCount),
                      icon: Icons.delete_outline_rounded,
                      onPressed: _onContinue,
                      baseColor: theme.colorScheme.error,
                      textColor: AppColors.white,
                      fullWidth: true,
                      height: 56,
                      fontSize: 14,
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final fullWidth = constraints.maxWidth;
                        const borderRadius = 18.0;
                        final grayBase = theme.colorScheme.onSurface.withValues(
                          alpha: 0.15,
                        );
                        return AnimatedBuilder(
                          animation: _fillAnimation,
                          builder: (context, _) {
                            final fillValue = _fillAnimation.value;
                            final fillWidth =
                                fullWidth * fillValue.clamp(0.0, 1.0);
                            return IgnorePointer(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: grayBase,
                                  borderRadius: BorderRadius.circular(
                                    borderRadius,
                                  ),
                                  border: Border.all(
                                    color:
                                        Color.lerp(
                                          grayBase,
                                          AppColors.white,
                                          0.2,
                                        ) ??
                                        grayBase,
                                    width: 1.8,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    borderRadius,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      if (fillValue > 0)
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          bottom: 0,
                                          width: fillWidth,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: () {
                                                  final f = fillValue.clamp(
                                                    0.0,
                                                    1.0,
                                                  );
                                                  final paleRed = Color.lerp(
                                                    AppColors.white,
                                                    AppColors.error,
                                                    0.32,
                                                  )!;
                                                  final baseRed = Color.lerp(
                                                    paleRed,
                                                    AppColors.error,
                                                    f,
                                                  )!;
                                                  final whiteMix =
                                                      0.14 * (1.0 - f) + 0.04;
                                                  return [
                                                    Color.lerp(
                                                          baseRed,
                                                          AppColors.white,
                                                          whiteMix,
                                                        ) ??
                                                        baseRed,
                                                    Color.lerp(
                                                          baseRed,
                                                          AppColors.white,
                                                          whiteMix * 0.4,
                                                        ) ??
                                                        baseRed,
                                                  ];
                                                }(),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    borderRadius,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      // Sağ taraf gri; yalnızca kırmızı alan radiuslu
                                      Positioned(
                                        left: fillWidth,
                                        top: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          decoration: BoxDecoration(),
                                        ),
                                      ),
                                      // İkon + metin; her zaman beyaz
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: AppColors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.warmupCountProgress(
                                                _deletedCount,
                                                _targetCount,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  (theme
                                                              .textTheme
                                                              .titleMedium ??
                                                          const TextStyle(
                                                            fontSize: 16,
                                                          ))
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                        letterSpacing: 0.3,
                                                        color: AppColors.white,
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
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

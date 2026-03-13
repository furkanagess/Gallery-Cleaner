part of 'swipe_page.dart';

/// Modern and subtle shimmer widget used for loading states.
class _ShimmerWidget extends StatefulWidget {
  const _ShimmerWidget({required this.width, required this.height});

  final double width;
  final double height;

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
      duration: const Duration(milliseconds: 1800),
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
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2);
    final highlightColor = brightness == Brightness.light
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final animationValue = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: baseColor,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + (animationValue * 2.0), 0.0),
                        end: Alignment(1.0 + (animationValue * 2.0), 0.0),
                        colors: [baseColor, highlightColor, baseColor],
                        stops: const [0.0, 0.5, 1.0],
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

/// History button with pulse animation when gallery stats scan completes.
class _HistoryButton extends StatefulWidget {
  const _HistoryButton({
    required this.pulseController,
    required this.isScanning,
  });

  final AnimationController pulseController;
  final bool isScanning;

  @override
  State<_HistoryButton> createState() => _HistoryButtonState();
}

class _HistoryButtonState extends State<_HistoryButton> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statsState = context.watch<GalleryStatsCubit>().state;
    final isScanning = statsState.isScanning;
    final hasNewData =
        statsState.stats != null &&
        statsState.previousStats != null &&
        !statsState.isFromCache &&
        !statsState.isScanning;

    final galleryStatsCubit = context.read<GalleryStatsCubit>();
    galleryStatsCubit.stream.listen((next) {
      final previous = galleryStatsCubit.state;
      if (!mounted) return;

      final wasScanning = previous.isScanning;
      final isNowScanning = next.isScanning;
      final hasNewDataNext =
          next.stats != null &&
          next.previousStats != null &&
          !next.isFromCache &&
          !next.isScanning;

      if (wasScanning && !isNowScanning && hasNewDataNext) {
        if (!widget.pulseController.isAnimating) {
          widget.pulseController.repeat(reverse: true);
        }
      } else if (!hasNewDataNext || isNowScanning) {
        if (widget.pulseController.isAnimating) {
          widget.pulseController.stop();
          widget.pulseController.reset();
        }
      }
    });

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
                  ? Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38)
                  : shouldPulse
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: widget.isScanning
                ? l10n.doNotLeaveScreenDuringScan
                : l10n.history,
            onPressed: widget.isScanning
                ? null
                : () {
                    if (context.mounted) {
                      context.push('/gallery/stats');
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

/// Modern Top Info Bar - Delete limit, Scan limit, Album selection.
class _ModernTopInfoBar extends StatefulWidget {
  const _ModernTopInfoBar({
    required this.tabController,
    required this.isScanning,
  });

  final TabController tabController;
  final bool isScanning;

  @override
  State<_ModernTopInfoBar> createState() => _ModernTopInfoBarState();
}

class _ModernTopInfoBarState extends State<_ModernTopInfoBar>
    with CubitStateMixin<_ModernTopInfoBar> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      final currentIndex = widget.tabController.index;
      context.read<TabSelectionCubit>().selectTab(currentIndex);
      cubitSetState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final currentTab = context.watch<TabSelectionCubit>().state;

    return IgnorePointer(
      ignoring: widget.isScanning,
      child: Opacity(
        opacity: widget.isScanning ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildTabSpecificContent(context, currentTab),
        ),
      ),
    );
  }

  Widget _buildTabSpecificContent(BuildContext context, int currentTab) {
    switch (currentTab) {
      case 0:
        return Row(
          key: const ValueKey<String>('swipe_delete_album'),
          children: [
            const Expanded(flex: 2, child: _ModernDeleteLimitBadge()),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _ModernAlbumSelectionButton()),
          ],
        );
      case 1:
        return Row(
          key: const ValueKey<String>('blur_scan'),
          children: [
            Expanded(
              flex: 2,
              child: _ModernScanLimitBadge(
                adUnitType: AdUnitType.blurScanLimit,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _ModernAlbumSelectionButton()),
          ],
        );
      case 2:
        return Row(
          key: const ValueKey<String>('duplicate_scan'),
          children: [
            Expanded(
              flex: 2,
              child: _ModernScanLimitBadge(
                adUnitType: AdUnitType.duplicateScanLimit,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _ModernAlbumSelectionButton()),
          ],
        );
      default:
        return const SizedBox.shrink(key: ValueKey<int>(-1));
    }
  }
}

/// Modern Delete Limit Badge.
class _ModernDeleteLimitBadge extends StatelessWidget {
  const _ModernDeleteLimitBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final deleteLimitAsync = context.watch<DeleteLimitCubit>().state;
    final isPremiumAsync = context.watch<PremiumCubit>().state;

    return deleteLimitAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (deleteLimit) {
        return isPremiumAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (isPremium) {
            final displayValue = isPremium ? '∞' : '$deleteLimit';

            return Stack(
              children: [
                Container(
                  padding: const EdgeInsets.only(
                    left: 14,
                    top: 10,
                    bottom: 10,
                    right: 4,
                  ),
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.error.withValues(alpha: 0.15),
                        AppColors.error.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.remainingDeletionRights,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                color: AppColors.error.withValues(alpha: 0.9),
                                letterSpacing: 0.3,
                                shadows: null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayValue,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: AppColors.error,
                                letterSpacing: -0.5,
                                height: 1,
                                shadows: isPremium
                                    ? [
                                        Shadow(
                                          color: AppColors.error.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : [
                                        Shadow(
                                          color: AppColors.error.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!isPremium) ...[
                        Material(
                          color: AppColors.transparent,
                          child: InkWell(
                            onTap: () => context.push('/paywall'),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.error.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: AppColors.error.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
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

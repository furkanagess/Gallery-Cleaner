import 'package:flutter/material.dart';

// Shimmer widget for swipe tab
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
        ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.2);
    final highlightColor = brightness == Brightness.light
        ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.6)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final animationValue = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            color: baseColor,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius:
                      widget.borderRadius ?? BorderRadius.circular(12),
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

// Comprehensive shimmer for swipe tab covering all components
class SwipeTabShimmer extends StatelessWidget {
  const SwipeTabShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _ShimmerWidget(
                  width: double.infinity,
                  height: 48,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _ShimmerWidget(
                  width: double.infinity,
                  height: 48,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: _ShimmerWidget(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ShimmerWidget(
                width: 80,
                height: 32,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 16),
              _ShimmerWidget(
                width: 80,
                height: 32,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 16),
              _ShimmerWidget(
                width: 80,
                height: 32,
                borderRadius: BorderRadius.circular(12),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _ShimmerWidget(
                  width: double.infinity,
                  height: 48,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _ShimmerWidget(
                  width: double.infinity,
                  height: 48,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


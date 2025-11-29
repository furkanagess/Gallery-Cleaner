import 'package:flutter/material.dart';

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

    // More subtle colors for a modern look
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
              // Subtle shimmer effect
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

// Shimmer for scan form (duplicate tab)
class ScanFormShimmer extends StatelessWidget {
  const ScanFormShimmer();

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


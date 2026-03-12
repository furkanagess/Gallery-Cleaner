import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../application/blur_detection_provider.dart';

// Blur tab indicator
class BlurTabIndicator extends StatefulWidget {
  const BlurTabIndicator({super.key, required this.isSelected});

  final bool isSelected;

  @override
  State<BlurTabIndicator> createState() => BlurTabIndicatorState();
}

class BlurTabIndicatorState extends State<BlurTabIndicator> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blurState = context.watch<BlurDetectionCubit>().state;
    final isScanning = blurState.isScanning;
    final hasCompleted = blurState.hasCompletedScan && !isScanning;

    // Seçili item ikon rengi: ekranın arka plan rengiyle aynı
    final selectedIconColor = theme.colorScheme.surface;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.blur_on_rounded,
              size: widget.isSelected ? 22 : 20,
              color: widget.isSelected
                  ? selectedIconColor
                  : hasCompleted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            if (hasCompleted && !widget.isSelected)
              Positioned(
                top: -2,
                right: -4,
                child: Icon(
                  Icons.check_circle,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

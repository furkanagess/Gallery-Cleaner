import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../application/duplicate_detection_provider.dart';

class DuplicateTabIndicator extends StatefulWidget {
  const DuplicateTabIndicator({super.key, required this.isSelected});

  final bool isSelected;

  @override
  State<DuplicateTabIndicator> createState() => _DuplicateTabIndicatorState();
}

class _DuplicateTabIndicatorState extends State<DuplicateTabIndicator> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duplicateState = context.watch<DuplicateDetectionCubit>().state;
    final isScanning = duplicateState.isScanning;
    final hasCompleted = duplicateState.hasCompletedScan && !isScanning;

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
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                widget.isSelected
                    ? selectedIconColor
                    : hasCompleted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                BlendMode.srcIn,
              ),
              child: Image.asset(
                'assets/icon/document.png',
                width: widget.isSelected ? 22 : 20,
                height: widget.isSelected ? 22 : 20,
                fit: BoxFit.contain,
              ),
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

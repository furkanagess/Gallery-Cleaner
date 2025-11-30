import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../application/blur_detection_provider.dart';
import '../../../../../../../../l10n/app_localizations.dart';

// Blur tab indicator
class BlurTabIndicator extends StatefulWidget {
  const BlurTabIndicator({required this.isSelected});

  final bool isSelected;

  @override
  State<BlurTabIndicator> createState() => BlurTabIndicatorState();
}

class BlurTabIndicatorState extends State<BlurTabIndicator> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final blurState = context.watch<BlurDetectionCubit>().state;
    final isScanning = blurState.isScanning;
    final hasCompleted = blurState.hasCompletedScan && !isScanning;

    // Seçili tab'da sadece icon göster (text yok)
    if (widget.isSelected) {
      // Seçili item ikon rengi: ekranın arka plan rengiyle aynı
      final selectedIconColor = theme.colorScheme.background;
      
      return Icon(
        Icons.blur_on_rounded,
        size: 24,
        color: selectedIconColor,
      );
    }

    // Seçili değilse icon + text göster
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.blur_on_rounded,
          size: 22,
          color: hasCompleted ? theme.colorScheme.primary : null,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                l10n.blurTab,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(height: 1.2),
              ),
            ),
            if (hasCompleted) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.check_circle,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ],
    );
  }
}


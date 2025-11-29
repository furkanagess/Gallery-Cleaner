import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../application/duplicate_detection_provider.dart';
import '../../../../../../../../../l10n/app_localizations.dart';

class DuplicateTabIndicator extends StatefulWidget {
  const DuplicateTabIndicator({required this.isSelected});

  final bool isSelected;

  @override
  State<DuplicateTabIndicator> createState() => _DuplicateTabIndicatorState();
}

class _DuplicateTabIndicatorState extends State<DuplicateTabIndicator> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final duplicateState = context.watch<DuplicateDetectionCubit>().state;
    final isScanning = duplicateState.isScanning;
    final hasCompleted = duplicateState.hasCompletedScan && !isScanning;

    if (widget.isSelected) {
      return Icon(
        Icons.content_copy_rounded,
        size: 24,
        color: theme.colorScheme.onPrimary,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.content_copy_rounded,
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
                l10n.duplicateTab,
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


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

    // Seçili item ikon rengi: ekranın arka plan rengiyle aynı
    final selectedIconColor = theme.colorScheme.background;
    
    // Her zaman aynı yapıyı kullan, seçili olanlarda text'i görünmez yap
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Seçili item'ın ikonu için üstte padding ekle
        SizedBox(height: widget.isSelected ? 4 : 0),
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            widget.isSelected
                ? selectedIconColor
                : hasCompleted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.7),
            BlendMode.srcIn,
          ),
          child: Image.asset(
            'assets/icon/document.png',
            width: widget.isSelected ? 20 : 18,
            height: widget.isSelected ? 20 : 18,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 13, // Text yüksekliğini sabit tut (check icon da dahil)
          child: Opacity(
            opacity: widget.isSelected ? 0.0 : 1.0,
            child: Row(
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
                    style: const TextStyle(
                      height: 1.1,
                      fontSize: 11,
                    ),
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
          ),
        ),
      ],
    );
  }
}


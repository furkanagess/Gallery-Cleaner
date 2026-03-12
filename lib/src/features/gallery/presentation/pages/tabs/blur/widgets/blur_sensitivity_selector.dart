import 'package:flutter/material.dart';
import '../../../../../../../app/theme/app_colors.dart';
import '../../../../../../../../l10n/app_localizations.dart';

enum BlurSensitivity {
  low, // Higher threshold (0.6) - detects more photos
  medium, // Medium threshold (0.5) - balanced
  high, // Lower threshold (0.4) - only very blurry photos
}

extension BlurSensitivityExtension on BlurSensitivity {
  double get threshold {
    switch (this) {
      case BlurSensitivity.low:
        return 0.6;
      case BlurSensitivity.medium:
        return 0.5;
      case BlurSensitivity.high:
        return 0.4;
    }
  }

  String getLabel(AppLocalizations l10n) {
    switch (this) {
      case BlurSensitivity.low:
        return l10n.sensitivityLow;
      case BlurSensitivity.medium:
        return l10n.sensitivityMedium;
      case BlurSensitivity.high:
        return l10n.sensitivityHigh;
    }
  }

  IconData get icon {
    switch (this) {
      case BlurSensitivity.low:
        return Icons.visibility_rounded;
      case BlurSensitivity.medium:
        return Icons.balance_rounded;
      case BlurSensitivity.high:
        return Icons.filter_alt_rounded;
    }
  }
}

class BlurSensitivitySelector extends StatefulWidget {
  final double currentThreshold;
  final ValueChanged<double> onThresholdChanged;

  const BlurSensitivitySelector({
    super.key,
    required this.currentThreshold,
    required this.onThresholdChanged,
  });

  @override
  State<BlurSensitivitySelector> createState() =>
      _BlurSensitivitySelectorState();
}

class _BlurSensitivitySelectorState extends State<BlurSensitivitySelector>
    with SingleTickerProviderStateMixin {
  late BlurSensitivity _currentSensitivity;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _currentSensitivity = _getSensitivityFromThreshold(widget.currentThreshold);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(BlurSensitivitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentThreshold != widget.currentThreshold) {
      _currentSensitivity = _getSensitivityFromThreshold(
        widget.currentThreshold,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  BlurSensitivity _getSensitivityFromThreshold(double threshold) {
    if (threshold >= 0.55) {
      return BlurSensitivity.low;
    } else if (threshold >= 0.45) {
      return BlurSensitivity.medium;
    } else {
      return BlurSensitivity.high;
    }
  }

  void _handleSensitivityChange(BlurSensitivity newSensitivity) {
    if (_currentSensitivity == newSensitivity) return;

    // Anında state'i güncelle
    setState(() {
      _currentSensitivity = newSensitivity;
    });

    // Animasyon başlat
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Callback'i çağır - anında mod değişimi
    widget.onThresholdChanged(newSensitivity.threshold);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.8,
    );

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.15),
                  theme.colorScheme.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: containerColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.sensitivity,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.8,
                    ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.sensitivity,
                      onPressed: () => _showSensitivityInfoDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Sensitivity levels with improved design
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSensitivityChip(
                      context,
                      theme,
                      BlurSensitivity.low.getLabel(l10n),
                      BlurSensitivity.low.icon,
                      BlurSensitivity.low,
                      _currentSensitivity == BlurSensitivity.low,
                      () => _handleSensitivityChange(BlurSensitivity.low),
                    ),
                    const SizedBox(width: 6),
                    _buildSensitivityChip(
                      context,
                      theme,
                      BlurSensitivity.medium.getLabel(l10n),
                      BlurSensitivity.medium.icon,
                      BlurSensitivity.medium,
                      _currentSensitivity == BlurSensitivity.medium,
                      () => _handleSensitivityChange(BlurSensitivity.medium),
                    ),
                    const SizedBox(width: 6),
                    _buildSensitivityChip(
                      context,
                      theme,
                      BlurSensitivity.high.getLabel(l10n),
                      BlurSensitivity.high.icon,
                      BlurSensitivity.high,
                      _currentSensitivity == BlurSensitivity.high,
                      () => _handleSensitivityChange(BlurSensitivity.high),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSensitivityInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final l10n = AppLocalizations.of(dialogContext)!;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l10n.sensitivity,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: _buildSensitivityDescriptionContent(dialogContext),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                MaterialLocalizations.of(dialogContext).okButtonLabel,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSensitivityDescriptionContent(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final bulletColor = theme.colorScheme.primary.withValues(alpha: 0.8);

    final lines = _parseSensitivityDescription(
      l10n.sensitivityLevelsDescription,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6, color: bulletColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lines[i],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i != lines.length - 1)
            Divider(
              height: 8,
              thickness: 0.6,
              color: theme.dividerColor.withValues(alpha: 0.6),
            ),
        ],
      ],
    );
  }

  List<String> _parseSensitivityDescription(String description) {
    return description
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim())
        .toList();
  }

  Widget _buildSensitivityChip(
    BuildContext context,
    ThemeData theme,
    String label,
    IconData icon,
    BlurSensitivity sensitivity,
    bool isSelected,
    VoidCallback onTap,
  ) {
    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.8,
    );

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? containerColor
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? containerColor
                      : theme.colorScheme.outline.withValues(alpha: 0.15),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: containerColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                  ? AppColors.surface.withValues(alpha: 0.2)
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: isSelected
                          ? AppColors.surface
                          : containerColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label.replaceAll('\n', ' '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected
                          ? AppColors.surface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 10.5,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../../app/theme/app_colors.dart';
import '../../../../../../../../l10n/app_localizations.dart';
import '../../../../../application/gallery_providers.dart' show PremiumCubit;

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

    // Premium durumunu kontrol et
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    final isPremium = isPremiumAsync.maybeWhen(
      data: (premium) => premium,
      orElse: () => false,
    );

    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(
      0.8,
    );

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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
                        color: theme.colorScheme.primaryContainer.withOpacity(
                          0.3,
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
                        color: theme.colorScheme.onSurface,
                      ),
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
                const SizedBox(height: 12),
                // Sensitivity descriptions with bullet points
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._parseSensitivityDescription(
                        l10n.sensitivityLevelsDescription,
                      ).map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6, right: 8),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: containerColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  line,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.75),
                                    height: 1.5,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    // Premium durumunu kontrol et
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    final isPremium = isPremiumAsync.maybeWhen(
      data: (premium) => premium,
      orElse: () => false,
    );

    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(
      0.8,
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
            splashColor: theme.colorScheme.primary.withOpacity(0.1),
            highlightColor: theme.colorScheme.primary.withOpacity(0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? containerColor
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(
                        0.4,
                      ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? containerColor
                      : theme.colorScheme.outline.withOpacity(0.15),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: containerColor.withOpacity(0.35),
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
                          ? AppColors.white.withOpacity(0.2)
                          : theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: isSelected
                          ? AppColors.white
                          : containerColor.withOpacity(0.6),
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
                          ? AppColors.white
                          : theme.colorScheme.onSurface.withOpacity(0.7),
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

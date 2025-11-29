import 'package:flutter/material.dart';
import '../../../../../../../app/theme/app_colors.dart';
import '../../../../../application/duplicate_detection_provider.dart';
import '../../../../../../../../l10n/app_localizations.dart';

class DuplicateModeSelector extends StatefulWidget {
  final DuplicateDetectionMode currentMode;
  final ValueChanged<DuplicateDetectionMode> onModeChanged;

  const DuplicateModeSelector({
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  State<DuplicateModeSelector> createState() => _DuplicateModeSelectorState();
}

class _DuplicateModeSelectorState extends State<DuplicateModeSelector>
    with SingleTickerProviderStateMixin {
  late DuplicateDetectionMode _currentMode;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.currentMode;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(DuplicateModeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMode != widget.currentMode) {
      _currentMode = widget.currentMode;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleModeChange(DuplicateDetectionMode newMode) {
    if (_currentMode == newMode) return;

    // Anında state'i güncelle
    setState(() {
      _currentMode = newMode;
    });

    // Animasyon başlat
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Callback'i çağır - anında mod değişimi
    widget.onModeChanged(newMode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
                        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                Icons.tune_rounded,
                        size: 18,
                color: theme.colorScheme.primary,
              ),
                    ),
                    const SizedBox(width: 10),
              Text(
                l10n.duplicateMode,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
                const SizedBox(height: 14),
                // Mode levels with improved design
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildModeChip(
                theme,
                _getShortModeLabel(
                  l10n,
                  DuplicateDetectionMode.lowSpeedHighAccuracy,
                ),
                Icons.verified_rounded,
                DuplicateDetectionMode.lowSpeedHighAccuracy,
                      _currentMode == DuplicateDetectionMode.lowSpeedHighAccuracy,
                      () => _handleModeChange(DuplicateDetectionMode.lowSpeedHighAccuracy),
              ),
                    const SizedBox(width: 6),
              _buildModeChip(
                theme,
                l10n.duplicateModeBalanced,
                Icons.balance_rounded,
                DuplicateDetectionMode.balanced,
                      _currentMode == DuplicateDetectionMode.balanced,
                      () => _handleModeChange(DuplicateDetectionMode.balanced),
              ),
                    const SizedBox(width: 6),
              _buildModeChip(
                theme,
                _getShortModeLabel(
                  l10n,
                  DuplicateDetectionMode.highSpeedLowAccuracy,
                ),
                Icons.speed_rounded,
                DuplicateDetectionMode.highSpeedLowAccuracy,
                      _currentMode == DuplicateDetectionMode.highSpeedLowAccuracy,
                      () => _handleModeChange(DuplicateDetectionMode.highSpeedLowAccuracy),
              ),
            ],
          ),
                const SizedBox(height: 12),
          // Mode descriptions with bullet points
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._parseModeDescription(l10n.duplicateModeLevelsDescription).map(
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
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.75),
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

  List<String> _parseModeDescription(String description) {
    return description
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim())
        .toList();
  }

  String _getShortModeLabel(
    AppLocalizations l10n,
    DuplicateDetectionMode mode,
  ) {
    final fullLabel = mode == DuplicateDetectionMode.lowSpeedHighAccuracy
        ? l10n.duplicateModeLowSpeedHighAccuracy
        : l10n.duplicateModeHighSpeedLowAccuracy;
    // Take first line or first word before newline
    return fullLabel.split('\n').first.split('/').first.trim();
  }

  Widget _buildModeChip(
    ThemeData theme,
    String label,
    IconData icon,
    DuplicateDetectionMode mode,
    bool isSelected,
    VoidCallback onTap,
  ) {
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
                    ? theme.colorScheme.primaryContainer.withOpacity(0.6)
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.5)
                      : theme.colorScheme.outline.withOpacity(0.15),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.2),
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
                          ? theme.colorScheme.primary.withOpacity(0.15)
                          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                    icon,
                      size: 18,
                    color: isSelected
                          ? theme.colorScheme.onPrimaryContainer.withOpacity(0.8)
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label.replaceAll('\n', ' '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer.withOpacity(0.8)
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

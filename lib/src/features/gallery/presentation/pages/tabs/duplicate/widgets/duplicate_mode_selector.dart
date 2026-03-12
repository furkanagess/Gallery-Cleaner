import 'package:flutter/material.dart';
import '../../../../../../../app/theme/app_colors.dart';
import '../../../../../application/duplicate_detection_provider.dart';
import '../../../../../../../../l10n/app_localizations.dart';

class DuplicateModeSelector extends StatefulWidget {
  final DuplicateDetectionMode currentMode;
  final ValueChanged<DuplicateDetectionMode> onModeChanged;

  const DuplicateModeSelector({
    super.key,
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
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
                      onPressed: () => _showModeInfoDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Sensitivity levels (same structure as blur tab)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildModeChip(
                      context,
                      theme,
                      l10n.sensitivityLow,
                      Icons.visibility_rounded,
                      DuplicateDetectionMode.lowSensitivity,
                      _currentMode == DuplicateDetectionMode.lowSensitivity,
                      () => _handleModeChange(
                        DuplicateDetectionMode.lowSensitivity,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildModeChip(
                      context,
                      theme,
                      l10n.sensitivityMedium,
                      Icons.balance_rounded,
                      DuplicateDetectionMode.mediumSensitivity,
                      _currentMode == DuplicateDetectionMode.mediumSensitivity,
                      () => _handleModeChange(
                        DuplicateDetectionMode.mediumSensitivity,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildModeChip(
                      context,
                      theme,
                      l10n.sensitivityHigh,
                      Icons.filter_alt_rounded,
                      DuplicateDetectionMode.highSensitivity,
                      _currentMode == DuplicateDetectionMode.highSensitivity,
                      () => _handleModeChange(
                        DuplicateDetectionMode.highSensitivity,
                      ),
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

  void _showModeInfoDialog(BuildContext context) {
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
            child: _buildModeDescriptionContent(dialogContext),
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

  Widget _buildModeDescriptionContent(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final bulletColor = theme.colorScheme.primary.withValues(alpha: 0.8);

    final lines = _parseModeDescription(
      l10n.duplicateSensitivityLevelsDescription,
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

  List<String> _parseModeDescription(String description) {
    return description
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim())
        .toList();
  }

  Widget _buildModeChip(
    BuildContext context,
    ThemeData theme,
    String label,
    IconData icon,
    DuplicateDetectionMode mode,
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

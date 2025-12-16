import 'dart:math' as math;
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
                      context,
                      theme,
                      _getShortModeLabel(
                        l10n,
                        DuplicateDetectionMode.lowSpeedHighAccuracy,
                      ),
                      Icons.verified_rounded,
                      DuplicateDetectionMode.lowSpeedHighAccuracy,
                      _currentMode ==
                          DuplicateDetectionMode.lowSpeedHighAccuracy,
                      () => _handleModeChange(
                        DuplicateDetectionMode.lowSpeedHighAccuracy,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildModeChip(
                      context,
                      theme,
                      l10n.duplicateModeBalanced,
                      Icons.balance_rounded,
                      DuplicateDetectionMode.balanced,
                      _currentMode == DuplicateDetectionMode.balanced,
                      () => _handleModeChange(DuplicateDetectionMode.balanced),
                    ),
                    const SizedBox(width: 6),
                    _buildModeChip(
                      context,
                      theme,
                      _getShortModeLabel(
                        l10n,
                        DuplicateDetectionMode.highSpeedLowAccuracy,
                      ),
                      Icons.speed_rounded,
                      DuplicateDetectionMode.highSpeedLowAccuracy,
                      _currentMode ==
                          DuplicateDetectionMode.highSpeedLowAccuracy,
                      () => _handleModeChange(
                        DuplicateDetectionMode.highSpeedLowAccuracy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Mode descriptions with bullet points
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.12),
                        theme.colorScheme.secondary.withOpacity(0.10),
                        theme.colorScheme.surface.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.18),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _SnowyBackground(
                          tint: containerColor,
                          accent: theme.colorScheme.secondary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._parseModeDescription(
                        l10n.duplicateModeLevelsDescription,
                      ).map(
                        (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                      margin:
                                          const EdgeInsets.only(top: 6, right: 8),
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
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                              .withOpacity(0.78),
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
    BuildContext context,
    ThemeData theme,
    String label,
    IconData icon,
    DuplicateDetectionMode mode,
    bool isSelected,
    VoidCallback onTap,
  ) {
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

class _SnowyBackground extends StatelessWidget {
  const _SnowyBackground({
    required this.tint,
    required this.accent,
  });

  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark
        ? [
            Colors.white.withOpacity(0.75),
            tint.withOpacity(0.82),
            accent.withOpacity(0.68),
          ]
        : [
            tint.withOpacity(0.72),
            accent.withOpacity(0.65),
            Colors.white.withOpacity(0.6),
          ];

    final flakes = List.generate(16, (index) {
      final top = (index * 41 + 15 * (index % 3)) % 200;
      final left = (index * 53 + 19 * (index % 5)) % 240;
      final opacity = (isDark ? 0.16 : 0.12) + (index % 5) * 0.05;
      final size = 12.0 + (index % 5) * 5.0;
      final rotationDeg = (index * 19 + 7 * (index % 4)) % 360;
      final color = palette[index % palette.length];

      return Positioned(
        top: top.toDouble(),
        left: left.toDouble(),
        child: Opacity(
          opacity: opacity.clamp(0.12, 0.8),
          child: Transform.rotate(
            angle: rotationDeg * math.pi / 180,
            child: Image.asset(
              'assets/new_year/snowflake.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              color: color,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        ),
      );
    });

    final sparkles = List.generate(6, (i) {
      final size = 3.5 + (i % 3) * 1.4;
      final dx = (i * 52 + 11 * (i % 4)) % 200;
      final dy = (i * 67 + 17 * (i % 5)) % 150;
      return Positioned(
        left: dx.toDouble(),
        top: dy.toDouble(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.52),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.42),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    });

    return Stack(
      children: [
        ...flakes,
        ...sparkles,
      ],
    );
  }
}

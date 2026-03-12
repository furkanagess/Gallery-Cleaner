import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../../../../../src/app/theme/app_theme.dart'
    show AppSemanticColors;
import '../../../../../../../../l10n/app_localizations.dart'
    show AppLocalizations;

class AnimatedSwipeInstructions extends StatefulWidget {
  const AnimatedSwipeInstructions({super.key});

  @override
  State<AnimatedSwipeInstructions> createState() =>
      _AnimatedSwipeInstructionsState();
}

class _AnimatedSwipeInstructionsState extends State<AnimatedSwipeInstructions>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Delete action - animated
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sem.delete.withValues(
                  alpha: 0.1 * _pulseAnimation.value,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sem.delete.withValues(
                    alpha: 0.4 * _pulseAnimation.value,
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: sem.delete.withValues(
                      alpha: 0.2 * _pulseAnimation.value,
                    ),
                    blurRadius: 8 * _pulseAnimation.value,
                    spreadRadius: 1 * _pulseAnimation.value,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        sem.delete,
                        BlendMode.srcATop,
                      ),
                      child: Lottie.asset(
                        'assets/lottie/left.json',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.delete,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: sem.delete,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: 1,
                height: 16,
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            // Keep action - animated
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sem.keep.withValues(alpha: 0.1 * _pulseAnimation.value),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sem.keep.withValues(
                    alpha: 0.4 * _pulseAnimation.value,
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: sem.keep.withValues(
                      alpha: 0.2 * _pulseAnimation.value,
                    ),
                    blurRadius: 8 * _pulseAnimation.value,
                    spreadRadius: 1 * _pulseAnimation.value,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.keep,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: sem.keep,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        sem.keep,
                        BlendMode.srcATop,
                      ),
                      child: Lottie.asset(
                        'assets/lottie/right.json',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        repeat: true,
                        options: LottieOptions(enableMergePaths: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

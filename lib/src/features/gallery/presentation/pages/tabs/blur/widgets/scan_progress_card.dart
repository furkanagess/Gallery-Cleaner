import 'dart:math' as math;
import 'package:flutter/material.dart';

class ScanProgressCard extends StatelessWidget {
  const ScanProgressCard({
    required this.title,
    required this.processed,
    required this.total,
    required this.fallbackLabel,
  });

  final String title;
  final int processed;
  final int total;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(
      0.8,
    );

    final hasTotal = total > 0;
    final progressValue = hasTotal ? (processed / total).clamp(0.0, 1.0) : null;
    final primaryLabel = title.isEmpty ? fallbackLabel : title;
    // Sayısal ilerleme gösterimi (0/500, 100/500 gibi)
    final statusText = hasTotal ? '$processed/$total' : '$processed';
    final helperText = hasTotal ? 'photos scanned' : 'photos analyzed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.16),
            theme.colorScheme.secondary.withOpacity(0.14),
            theme.colorScheme.surface.withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.18),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _NewYearBackground(
              tint: containerColor,
              accent: theme.colorScheme.secondary,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
            primaryLabel,
            style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
            ),
          ),
                  const SizedBox(width: 8),
                  Opacity(
                    opacity: 0.85,
                    child: Image.asset(
                      'assets/new_year/gift-box.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
          ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
          ),
              const SizedBox(height: 10),
          Text(
            statusText,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
            ),
          ),
              const SizedBox(height: 4),
          Text(
            helperText,
            style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                ),
            ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewYearBackground extends StatelessWidget {
  const _NewYearBackground({
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
            Colors.white.withOpacity(0.62),
          ];

    final flakes = List.generate(18, (index) {
      final top = (index * 43 + 17 * (index % 3)) % 200;
      final left = (index * 57 + 21 * (index % 5)) % 260;
      final opacity = (isDark ? 0.16 : 0.12) + (index % 5) * 0.05;
      final size = 14.0 + (index % 5) * 5.0;
      final rotationDeg = (index * 23 + 9 * (index % 4)) % 360;
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

    // Hafif yıldız/sparkle dokunuşu
    final sparkles = List.generate(6, (i) {
      final size = 3.5 + (i % 3) * 1.5;
      final dx = (i * 58 + 13 * (i % 4)) % 220;
      final dy = (i * 71 + 19 * (i % 5)) % 160;
      return Positioned(
        left: dx.toDouble(),
        top: dy.toDouble(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.55),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.45),
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

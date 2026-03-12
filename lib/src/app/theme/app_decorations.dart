// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralised elevation and decoration tokens for a more dimensional UI.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft(Color color) => [
    BoxShadow(
      color: color.withValues(alpha:0.18),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: AppColors.black.withValues(alpha:0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> focus(Color color) => [
    BoxShadow(
      color: color.withValues(alpha:0.32),
      blurRadius: 36,
      spreadRadius: 4,
      offset: const Offset(0, 14),
    ),
  ];

  static List<BoxShadow> subtle() => [
    BoxShadow(
      color: AppColors.black.withValues(alpha:0.08),
      blurRadius: 18,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: AppColors.black.withValues(alpha:0.04),
      blurRadius: 32,
      offset: const Offset(0, 18),
    ),
  ];
}

class AppDecorations {
  AppDecorations._();

  static BoxDecoration glassSurface({
    double borderRadius = 18,
    Color? tint,
    double? opacity,
  }) {
    final base = tint ?? AppColors.white;
    final resolvedOpacity = opacity ?? 0.65;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.white.withValues(alpha:0.12)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          base.withValues(alpha:resolvedOpacity),
          base.withValues(alpha:resolvedOpacity * 0.8),
        ],
      ),
      boxShadow: AppShadows.subtle(),
    );
  }

  static BoxDecoration floatingCard({double borderRadius = 20, Color? color}) {
    final surface = color ?? AppColors.cardDark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [surface.withValues(alpha:0.96), surface.withValues(alpha:0.88)],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.white.withValues(alpha:0.1)),
      boxShadow: AppShadows.soft(
        surface == AppColors.cardDark
            ? AppColors.primary
            : AppColors.secondary,
      ),
    );
  }

  static BoxDecoration pill({Color? color, double borderRadius = 40}) =>
      BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            (color ?? AppColors.primary).withValues(alpha:0.92),
            (color ?? AppColors.primary).withValues(alpha:0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppShadows.focus(color ?? AppColors.primary),
      );
}

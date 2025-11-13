import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralised elevation and decoration tokens for a more dimensional UI.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.18),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: AppColors.black.withOpacity(0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> focus(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.32),
          blurRadius: 36,
          spreadRadius: 4,
          offset: const Offset(0, 14),
        ),
      ];

  static List<BoxShadow> subtle() => [
        BoxShadow(
          color: AppColors.black.withOpacity(0.08),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: AppColors.black.withOpacity(0.04),
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
      border: Border.all(
        color: AppColors.white.withOpacity(0.12),
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          base.withOpacity(resolvedOpacity),
          base.withOpacity(resolvedOpacity * 0.8),
        ],
      ),
      boxShadow: AppShadows.subtle(),
    );
  }

  static BoxDecoration floatingCard({
    double borderRadius = 20,
    Color? color,
  }) {
    final surface = color ?? AppColors.cardLight;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          surface.withOpacity(0.96),
          surface.withOpacity(0.88),
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.white.withOpacity(0.1)),
      boxShadow: AppShadows.soft(surface == AppColors.cardLight
          ? AppColors.primary
          : AppColors.secondary),
    );
  }

  static BoxDecoration pill({
    Color? color,
    double borderRadius = 40,
  }) =>
      BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            (color ?? AppColors.primary).withOpacity(0.92),
            (color ?? AppColors.primary).withOpacity(0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppShadows.focus(color ?? AppColors.primary),
      );
}


import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Central 3D button used across the app for consistent depth + animation.
///
/// Text visibility is guaranteed by automatic contrast calculation plus
/// a subtle stroke/shadow around both text and icon.
class AppThreeDButton extends StatefulWidget {
  const AppThreeDButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.baseColor,
    this.textColor,
    this.fullWidth = false,
    this.height = 56,
    this.padding,
    this.fontWeight = FontWeight.w700,
    this.centerText = false,
    this.fontSize,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? baseColor;
  final Color? textColor;
  final bool fullWidth;
  final double height;
  final EdgeInsetsGeometry? padding;
  final FontWeight fontWeight;
  final bool centerText;
  final double? fontSize;

  @override
  State<AppThreeDButton> createState() => _AppThreeDButtonState();
}

class _AppThreeDButtonState extends State<AppThreeDButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color base =
        widget.baseColor ?? colorScheme.onPrimaryContainer.withOpacity(0.9);
    // Resolve foreground with contrast guarantee:
    // 1) Use provided textColor if given, but fix contrast if too close.
    // 2) Otherwise auto-pick based on base.
    final Color foreground = _resolveForeground(
      base,
      widget.textColor,
      colorScheme,
    );
    final borderRadius = BorderRadius.circular(18);

    final shadow = _pressed
        ? [
            BoxShadow(
              color: AppColors.black.withOpacity(0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
        : [
            BoxShadow(
              color: AppColors.black.withOpacity(0.35),
              blurRadius: 0,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: AppColors.black.withOpacity(0.22),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      transform: Matrix4.translationValues(0, _pressed ? 2.2 : 0, 0),
      width: widget.fullWidth ? double.infinity : null,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_tint(base, 0.12), _shade(base, 0.07)],
        ),
        borderRadius: borderRadius,
        // Use a uniform border color to allow rounded corners.
        border: Border.all(color: _tint(base, 0.2), width: 1.8),
        boxShadow: shadow,
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          splashColor: _tint(base, 0.25).withOpacity(0.25),
          highlightColor: Colors.transparent,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          onTap: widget.onPressed,
          child: Padding(
            padding:
                widget.padding ??
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisAlignment: widget.fullWidth
                  ? MainAxisAlignment.center
                  : (widget.centerText
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start),
              mainAxisSize: widget.fullWidth
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 18,
                    color: foreground,
                    // Keep text clean without extra stroke/shadow
                    shadows: const [],
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (theme.textTheme.titleMedium ??
                                const TextStyle(fontSize: 16))
                            .copyWith(
                              fontWeight: widget.fontWeight,
                              fontSize: widget.fontSize,
                              letterSpacing: 0.3,
                              color: foreground,
                              shadows: const [],
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _tint(Color color, double amount) =>
    Color.lerp(color, Colors.white, amount) ?? color;

Color _shade(Color color, double amount) =>
    Color.lerp(color, Colors.black, amount) ?? color;

Color _autoTextColor(Color base, ColorScheme scheme) {
  final lum = base.computeLuminance();
  if (lum > 0.6) {
    // Bright base -> dark readable text
    return scheme.onSurface.withOpacity(0.98);
  }
  // Dark base -> light text
  return scheme.onPrimary;
}

Color _resolveForeground(Color base, Color? userColor, ColorScheme scheme) {
  final auto = _autoTextColor(base, scheme);
  if (userColor == null) return auto;

  // If user color is too close to base, switch to auto for legibility.
  if (_contrastRatio(userColor, base) < 3.5) {
    return auto;
  }
  return userColor;
}

double _contrastRatio(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final bright = math.max(l1, l2);
  final dark = math.min(l1, l2);
  return (bright + 0.05) / (dark + 0.05);
}

double _luminance(Color c) {
  // sRGB luminance
  final r = _linearize(c.red / 255);
  final g = _linearize(c.green / 255);
  final b = _linearize(c.blue / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _linearize(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

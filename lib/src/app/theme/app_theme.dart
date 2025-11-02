import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppThemeData {
  final ThemeData light;
  final ThemeData dark;

  const AppThemeData({required this.light, required this.dark});
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color keep;
  final Color delete;
  final Color targetHover;

  const AppSemanticColors({
    required this.keep,
    required this.delete,
    required this.targetHover,
  });

  @override
  AppSemanticColors copyWith({Color? keep, Color? delete, Color? targetHover}) {
    return AppSemanticColors(
      keep: keep ?? this.keep,
      delete: delete ?? this.delete,
      targetHover: targetHover ?? this.targetHover,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      keep: Color.lerp(keep, other.keep, t)!,
      delete: Color.lerp(delete, other.delete, t)!,
      targetHover: Color.lerp(targetHover, other.targetHover, t)!,
    );
  }
}

final appThemeProvider = Provider<AppThemeData>((ref) {
  const seed = Color(0xFF334155); // slate/indigo blend for a clean look
  const keep = Color(0xFF22C55E); // emerald
  const del = Color(0xFFEF4444); // red-500
  const hover = Color(0xFF38BDF8); // sky-400

  ThemeData themed(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: const ChipThemeData(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        side: BorderSide(color: Colors.transparent),
      ),
      extensions: const [
        AppSemanticColors(keep: keep, delete: del, targetHover: hover),
      ],
    );
  }

  final light = themed(Brightness.light);
  final dark = themed(Brightness.dark);
  return AppThemeData(light: light, dark: dark);
});


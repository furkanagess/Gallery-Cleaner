// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'app_colors.dart';

class AppThemeData {
  final ThemeData dark;

  const AppThemeData({required this.dark});
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color keep;
  final Color delete;
  final Color targetHover;
  final Color blurTab;
  final Color duplicateTab;
  final Color accent;

  const AppSemanticColors({
    required this.keep,
    required this.delete,
    required this.targetHover,
    required this.blurTab,
    required this.duplicateTab,
    required this.accent,
  });

  @override
  AppSemanticColors copyWith({
    Color? keep,
    Color? delete,
    Color? targetHover,
    Color? blurTab,
    Color? duplicateTab,
    Color? accent,
  }) {
    return AppSemanticColors(
      keep: keep ?? this.keep,
      delete: delete ?? this.delete,
      targetHover: targetHover ?? this.targetHover,
      blurTab: blurTab ?? this.blurTab,
      duplicateTab: duplicateTab ?? this.duplicateTab,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      keep: Color.lerp(keep, other.keep, t)!,
      delete: Color.lerp(delete, other.delete, t)!,
      targetHover: Color.lerp(targetHover, other.targetHover, t)!,
      blurTab: Color.lerp(blurTab, other.blurTab, t)!,
      duplicateTab: Color.lerp(duplicateTab, other.duplicateTab, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

/// Extension to easily access semantic colors from theme
extension AppSemanticColorsExtension on ThemeData {
  AppSemanticColors get semanticColors =>
      extension<AppSemanticColors>() ??
      const AppSemanticColors(
        keep: AppColors.success,
        delete: AppColors.error,
        targetHover: AppColors.primary,
        blurTab: AppColors.blurTab,
        duplicateTab: AppColors.duplicateTab,
        accent: AppColors.accent,
      );
}

AppThemeData buildAppTheme() {
  ThemeData themedDark() {
    const brightness = Brightness.dark;

    // Create ColorScheme with new color palette
    final colorScheme = ColorScheme(
      brightness: brightness,
      // Primary colors
      primary: AppColors.primary,
      onPrimary: AppColors.textPrimaryDark,
      primaryContainer: AppColors.primary.withValues(alpha: 0.2),
      onPrimaryContainer: AppColors.accent,
      // Secondary colors
      secondary: AppColors.secondary,
      onSecondary: AppColors.textPrimaryDark,
      secondaryContainer: AppColors.secondary.withValues(alpha: 0.2),
      onSecondaryContainer: AppColors.accent,
      // Tertiary/Accent
      tertiary: AppColors.accent,
      onTertiary: AppColors.textPrimaryDark,
      tertiaryContainer: AppColors.accent.withValues(alpha: 0.2),
      onTertiaryContainer: AppColors.accent,
      // Error
      error: AppColors.error,
      onError: AppColors.white,
      errorContainer: AppColors.error.withValues(alpha: 0.2),
      onErrorContainer: AppColors.error,
      // Surface
      // Requested: all surface backgrounds = #0E0E0E
      surface: AppColors.surface,
      onSurface: AppColors.textPrimaryDark,
      surfaceContainerHighest: AppColors.cardDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
      // Outline
      outline: AppColors.borderDark,
      outlineVariant: AppColors.borderDark.withValues(alpha: 0.5),
      // Shadow
      shadow: AppColors.shadowDark,
      scrim: AppColors.black.withValues(alpha:0.3),
      inverseSurface: AppColors.textPrimaryDark,
      onInverseSurface: AppColors.backgroundDark,
      inversePrimary: AppColors.primary,
      surfaceTint: AppColors.primary,
    );

    // Base text theme with Poppins
    final baseTextTheme = ThemeData(
      brightness: brightness,
    ).textTheme.apply(fontFamily: 'Poppins');

    final baseButtonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    ButtonStyle filledButtonStyle() {
      return ButtonStyle(
        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        ),
        shape: MaterialStateProperty.all(baseButtonShape),
        elevation: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) return 2;
          if (states.contains(MaterialState.disabled)) return 0;
          return 4;
        }),
        shadowColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return AppColors.black.withValues(alpha:0.0);
          }
          return AppColors.black.withValues(alpha:0.15);
        }),
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return AppColors.primary.withValues(alpha:0.28);
          }
          // İç rengi daha soluk yap
          return AppColors.primary.withValues(alpha:0.85);
        }),
        foregroundColor: MaterialStateProperty.all(AppColors.white),
        overlayColor: MaterialStateProperty.all(AppColors.transparent),
        // Border ekle - daha koyu renk
        side: MaterialStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(MaterialState.disabled)
                ? AppColors.primary.withValues(alpha:0.2)
                : AppColors.primary.withValues(alpha:0.9), // Koyu border
            width: 1.5,
          ),
        ),
      );
    }

    ButtonStyle outlinedButtonStyle() {
      return ButtonStyle(
        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        ),
        shape: MaterialStateProperty.all(baseButtonShape),
        side: MaterialStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(MaterialState.disabled)
                ? AppColors.primary.withValues(alpha:0.2)
                : states.contains(MaterialState.pressed)
                ? AppColors.primary.withValues(alpha:0.9) // Koyu border
                : AppColors.primary.withValues(alpha:0.8), // Koyu border
            width: 1.5,
          ),
        ),
        foregroundColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.disabled)
              ? AppColors.primary.withValues(alpha:0.35)
              : AppColors.primary,
        ),
        overlayColor: MaterialStateProperty.all(AppColors.transparent),
        elevation: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) return 2;
          if (states.contains(MaterialState.disabled)) return 0;
          return 3;
        }),
        shadowColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return AppColors.black.withValues(alpha:0.0);
          }
          return AppColors.black.withValues(alpha:0.1);
        }),
        // İç rengi daha soluk yap
        backgroundColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.disabled)
              ? AppColors.transparent
              : AppColors.primary.withValues(alpha:0.08), // Çok soluk iç renk
        ),
      );
    }

    ButtonStyle textButtonStyle() {
      return ButtonStyle(
        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        shape: MaterialStateProperty.all(baseButtonShape),
        foregroundColor: MaterialStateProperty.all(AppColors.primary),
        overlayColor: MaterialStateProperty.all(AppColors.transparent),
        // Border ekle - daha koyu renk
        side: MaterialStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(MaterialState.disabled)
                ? AppColors.primary.withValues(alpha:0.2)
                : AppColors.primary.withValues(alpha:0.7), // Koyu border
            width: 1.5,
          ),
        ),
        // İç rengi daha soluk yap
        backgroundColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.disabled)
              ? AppColors.transparent
              : AppColors.primary.withValues(alpha:0.06), // Çok soluk iç renk
        ),
        elevation: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) return 1;
          if (states.contains(MaterialState.disabled)) return 0;
          return 2;
        }),
        shadowColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return AppColors.black.withValues(alpha:0.0);
          }
          return AppColors.black.withValues(alpha:0.08);
        }),
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Poppins',
      textTheme: baseTextTheme,
      primaryTextTheme: baseTextTheme,
      typography: Typography.material2021(platform: defaultTargetPlatform),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: AppColors.surface,
      // Disable ripple/splash effects globally
      splashFactory: NoSplash.splashFactory,
      splashColor: AppColors.transparent,
      highlightColor: AppColors.transparent,
      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        surfaceTintColor: AppColors.transparent,
      ),
      // Button Themes
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle()),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledButtonStyle()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: outlinedButtonStyle(),
      ),
      textButtonTheme: TextButtonThemeData(style: textButtonStyle()),
      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 2,
        shadowColor: AppColors.black.withValues(alpha:0.25),
        surfaceTintColor: AppColors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 6,
        highlightElevation: 8,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
        overlayColor: MaterialStateProperty.all(AppColors.transparent),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardDark.withValues(alpha:0.94),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 12,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: AppColors.border(brightness)),
          ),
        ),
      ),
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardDark,
        selectedColor: AppColors.primary.withValues(alpha:0.1),
        labelStyle: TextStyle(
          color: AppColors.textPrimaryDark,
        ),
        secondaryLabelStyle: TextStyle(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        side: BorderSide(color: AppColors.border(brightness)),
      ),
      // Divider Theme
      dividerTheme: DividerThemeData(
        color: AppColors.border(brightness),
        thickness: 1,
        space: 1,
      ),
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      // Extensions
      extensions: [
        AppSemanticColors(
          keep: AppColors.success,
          delete: AppColors.error,
          targetHover: AppColors.primary,
          blurTab: AppColors.blurTab,
          duplicateTab: AppColors.duplicateTab,
          accent: AppColors.accent,
        ),
      ],
    );
  }

  final dark = themedDark();
  return AppThemeData(dark: dark);
}

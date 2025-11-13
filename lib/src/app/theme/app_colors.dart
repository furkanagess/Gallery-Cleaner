import 'package:flutter/material.dart';

/// Modern and professional color palette for Gallery Cleaner app
/// Based on the design system with light and dark mode support
class AppColors {
  AppColors._();

  // ==================== PRIMARY COLORS ====================
  /// Primary Color: #5D9CEC
  /// Usage: Buttons, active tabs, titles
  /// Meaning: Cleanliness, technology, freshness
  static const Color primary = Color(0xFF5D9CEC);

  /// Secondary Color: #B39DDB
  /// Usage: Background transitions, card highlights
  /// Meaning: Elegant, modern, calm
  static const Color secondary = Color(0xFFB39DDB);

  /// Accent Color: #A5F1E9
  /// Usage: Swipe effects, icon highlights, paywall
  /// Meaning: Smart technology, vibrancy
  static const Color accent = Color(0xFFA5F1E9);

  // ==================== SEMANTIC COLORS ====================
  /// Success (Keep - Right Swipe): #22C55E
  /// Usage: "Swipe right - keep" overlay, confirmation buttons
  static const Color success = Color(0xFF22C55E);

  /// Error (Delete - Left Swipe): #EF4444
  /// Usage: "Swipe left - delete" overlay, error messages
  static const Color error = Color(0xFFEF4444);

  /// Warning / Attention: #FF9800
  /// Usage: Limited offers, alerts, highlights
  static const Color warning = Color(0xFFFF9800);

  /// Warning Light Variant: #FFB74D (orange-400)
  static const Color warningLight = Color(0xFFFFB74D);

  /// Warning Dark Variant: #F57C00 (orange-700)
  static const Color warningDark = Color(0xFFF57C00);

  /// Blur Tab Color: #5D9CEC (Blue tones)
  static const Color blurTab = Color(0xFF5D9CEC);

  /// Duplicate Tab Color: #A5F1E9 (Mint tones)
  static const Color duplicateTab = Color(0xFFA5F1E9);

  // ==================== NEUTRAL COLORS ====================
  /// Background Light: #F8FAFC
  static const Color backgroundLight = Color(0xFFF8FAFC);

  /// Background Dark: #191C24
  static const Color backgroundDark = Color(0xFF191C24);

  /// Pure White
  static const Color white = Color(0xFFFFFFFF);

  /// Pure Black
  static const Color black = Color(0xFF000000);

  /// Black with 54% opacity (for shadows, overlays)
  static const Color black54 = Color(0x8A000000);

  /// Black with 38% opacity
  static const Color black38 = Color(0x61000000);

  /// Transparent
  static const Color transparent = Color(0x00000000);

  /// Card Background Light: #FFFFFF
  static const Color cardLight = white;

  /// Card Background Dark: #1E293B
  static const Color cardDark = Color(0xFF1E293B);

  /// Text Primary Light: #1E293B
  static const Color textPrimaryLight = Color(0xFF1E293B);

  /// Text Primary Dark: #E2E8F0
  static const Color textPrimaryDark = Color(0xFFE2E8F0);

  /// Text Secondary Light: #64748B
  static const Color textSecondaryLight = Color(0xFF64748B);

  /// Text Secondary Dark: #94A3B8
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  /// Border/Divider Light: #E2E8F0
  static const Color borderLight = Color(0xFFE2E8F0);

  /// Border/Divider Dark: #334155
  static const Color borderDark = Color(0xFF334155);

  // ==================== SHADOWS ====================
  /// Shadow Light: rgba(0, 0, 0, 0.05)
  static const Color shadowLight = Color.fromRGBO(0, 0, 0, 0.05);

  /// Shadow Dark: rgba(0, 0, 0, 0.25)
  static const Color shadowDark = Color.fromRGBO(0, 0, 0, 0.25);

  // ==================== GRADIENTS ====================
  /// Main Background Gradient (Splash / Home)
  /// linear-gradient(135deg, #5D9CEC 0%, #B39DDB 100%)
  static const LinearGradient mainBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  /// Premium Banner / Paywall Gradient
  /// linear-gradient(135deg, #B39DDB 0%, #A5F1E9 100%)
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, accent],
  );

  /// CTA Button Gradient (Upgrade / Clean Now)
  /// linear-gradient(90deg, #5D9CEC 0%, #A5F1E9 100%)
  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, accent],
  );

  /// Swipe Overlay Gradient (Delete / Keep)
  /// linear-gradient(90deg, #EF4444 0%, #22C55E 100%)
  static const LinearGradient swipeOverlayGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [error, success],
  );

  // ==================== HELPER METHODS ====================
  /// Get background color based on brightness
  static Color background(Brightness brightness) {
    return brightness == Brightness.light ? backgroundLight : backgroundDark;
  }

  /// Get card color based on brightness
  static Color card(Brightness brightness) {
    return brightness == Brightness.light ? cardLight : cardDark;
  }

  /// Get text primary color based on brightness
  static Color textPrimary(Brightness brightness) {
    return brightness == Brightness.light ? textPrimaryLight : textPrimaryDark;
  }

  /// Get text secondary color based on brightness
  static Color textSecondary(Brightness brightness) {
    return brightness == Brightness.light ? textSecondaryLight : textSecondaryDark;
  }

  /// Get border color based on brightness
  static Color border(Brightness brightness) {
    return brightness == Brightness.light ? borderLight : borderDark;
  }

  /// Get shadow color based on brightness
  static Color shadow(Brightness brightness) {
    return brightness == Brightness.light ? shadowLight : shadowDark;
  }
}


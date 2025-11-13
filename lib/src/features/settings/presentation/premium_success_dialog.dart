import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app/theme/app_colors.dart';

/// Premium başarı dialog'u - kullanıcı premium olduğunda gösterilir
class PremiumSuccessDialog extends StatelessWidget {
  const PremiumSuccessDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PremiumSuccessDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 28),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withOpacity(isDark ? 0.85 : 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(isDark ? 0.25 : 0.18),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(isDark ? 0.35 : 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 24),
                  spreadRadius: -12,
                ),
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(isDark ? 0.4 : 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Premium Aktif!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tebrikler! Premium üyeliğiniz aktif. Artık tüm özelliklere erişebilirsiniz.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.85),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withOpacity(isDark ? 0.35 : 0.25),
                        theme.colorScheme.secondary.withOpacity(isDark ? 0.2 : 0.18),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(isDark ? 0.4 : 0.25),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(isDark ? 0.3 : 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.onPrimary.withOpacity(0.12),
                          border: Border.all(
                            color:
                                theme.colorScheme.onPrimary.withOpacity(isDark ? 0.3 : 0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.all_inclusive_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          l10n.lifetimeAccessMessage,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh
                        .withOpacity(isDark ? 0.7 : 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      _FeatureItem(
                        icon: Icons.all_inclusive,
                        text: l10n.unlimitedDeletions,
                        theme: theme,
                      ),
                      const SizedBox(height: 10),
                      _FeatureItem(
                        icon: Icons.blur_on,
                        text: l10n.unlimitedBlurScans,
                        theme: theme,
                      ),
                      const SizedBox(height: 10),
                      _FeatureItem(
                        icon: Icons.photo_library,
                        text: l10n.unlimitedDuplicateScans,
                        theme: theme,
                      ),
                      const SizedBox(height: 10),
                      _FeatureItem(
                        icon: Icons.block,
                        text: l10n.noAds,
                        theme: theme,
                      ),
                      const SizedBox(height: 10),
                      _FeatureItem(
                        icon: Icons.verified,
                        text: l10n.prioritySupport,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.85),
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.92),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Kullanmaya Başla',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -36,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.45),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Lottie.asset(
                    'assets/lottie/succes.json',
                    fit: BoxFit.contain,
                    repeat: false,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.text,
    required this.theme,
  });

  final IconData icon;
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withOpacity(0.25),
                theme.colorScheme.secondary.withOpacity(0.20),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.35),
              width: 1.1,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(
          Icons.check_circle,
          size: 20,
          color: AppColors.success.withOpacity(0.9),
        ),
      ],
    );
  }
}


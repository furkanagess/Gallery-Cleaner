import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app/theme/app_colors.dart';
import '../../gallery/application/gallery_providers.dart' show PremiumCubit;

/// Premium başarı dialog'u - kullanıcı premium olduğunda gösterilir
class PremiumSuccessDialog extends StatelessWidget {
  const PremiumSuccessDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PremiumSuccessDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Dinamik container rengi (premium durumuna göre)
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    isPremiumAsync.maybeWhen(data: (premium) => premium, orElse: () => false);
    final containerColor = AppColors.accent.withValues(alpha: 0.8);

    return Dialog(
      backgroundColor: AppColors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 28),
            decoration: BoxDecoration(
              color: AppColors.cardDark.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: containerColor.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: containerColor.withValues(alpha: 0.35),
                  blurRadius: 40,
                  offset: const Offset(0, 24),
                  spreadRadius: -12,
                ),
                BoxShadow(
                  color: AppColors.shadowDark.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.premiumActive,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryDark,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        containerColor.withValues(alpha: 0.35),
                        containerColor.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: containerColor.withValues(
                        alpha: 0.4,
                      ),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: containerColor.withValues(
                          alpha: 0.3,
                        ),
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
                          color: AppColors.white.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppColors.white.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Icon(
                          Icons.all_inclusive_rounded,
                          color: AppColors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          l10n.lifetimeAccessMessage,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.borderDark.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      _FeatureItem(
                        icon: Icons.all_inclusive,
                        text: l10n.unlimitedDeletions,
                        theme: theme,
                        containerColor: containerColor,
                      ),
                      const SizedBox(height: 10),
                      _FeatureItem(
                        icon: Icons.blur_on,
                        text: l10n.unlimitedBlurScans,
                        theme: theme,
                        containerColor: containerColor,
                      ),
                      const SizedBox(height: 10),
                      _FeatureItem(
                        icon: Icons.photo_library,
                        text: l10n.unlimitedDuplicateScans,
                        theme: theme,
                        containerColor: containerColor,
                      ),
                      const SizedBox(height: 10),
                      _FeatureItem(
                        icon: Icons.block,
                        text: l10n.noAds,
                        theme: theme,
                        containerColor: containerColor,
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
                      backgroundColor: containerColor.withValues(alpha: 0.85),
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      side: BorderSide(
                        color: containerColor.withValues(alpha: 0.92),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      l10n.startUsing,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
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
                      containerColor,
                      containerColor.withValues(alpha: 0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: containerColor.withValues(alpha: 0.45),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 74,
                  color: AppColors.white,
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
    required this.containerColor,
  });

  final IconData icon;
  final String text;
  final ThemeData theme;
  final Color containerColor;

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
                containerColor.withValues(alpha: 0.25),
                containerColor.withValues(alpha: 0.20),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: containerColor.withValues(alpha: 0.35),
              width: 1.1,
            ),
          ),
          child: Icon(icon, size: 20, color: AppColors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimaryDark.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(
          Icons.check_circle,
          size: 20,
          color: AppColors.success.withValues(alpha: 0.9),
        ),
      ],
    );
  }
}

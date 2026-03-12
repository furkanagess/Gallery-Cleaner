import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../../../../../src/app/theme/app_colors.dart' show AppColors;
import '../../../../../../../../l10n/app_localizations.dart'
    show AppLocalizations;
import '../../../../../application/gallery_providers.dart' show PremiumCubit;

class ModernScanButton extends StatelessWidget {
  const ModernScanButton({
    super.key,
    required this.context,
    required this.theme,
    required this.l10n,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.isEnabled,
    required this.isError,
    this.estimatedTimeText,
    this.hasLimitWarning = false,
    this.totalPhotoCount = 0,
    this.onErrorPressed,
  });

  final BuildContext context;
  final ThemeData theme;
  final AppLocalizations l10n;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isEnabled;
  final bool isError;
  final String? estimatedTimeText;
  final bool hasLimitWarning;
  final int totalPhotoCount;
  final VoidCallback? onErrorPressed;

  @override
  Widget build(BuildContext context) {
    // Premium durumunu kontrol et
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    isPremiumAsync.maybeWhen(data: (premium) => premium, orElse: () => false);

    // Bottom navigation bar'daki seçili item container rengiyle aynı renk
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.8,
    );

    // isError durumunda premium butonu göster
    if (isError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.error.withValues(alpha: 0.2),
                  AppColors.error.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 20,
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.getUnlimitedDeletions,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onErrorPressed ?? () => context.push('/paywall'),
              icon: Icon(
                Icons.workspace_premium_rounded,
                size: 20,
                color: theme.colorScheme.surface,
              ),
              label: Text(
                l10n.getUnlimitedScans,
                style: TextStyle(color: theme.colorScheme.surface),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: AppColors.warningLight,
                foregroundColor: theme.colorScheme.surface,
                side: BorderSide(
                  color: AppColors.warningLight.withValues(alpha: 0.9),
                  width: 1.5,
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasLimitWarning && isEnabled && !isError) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.warningLight.withValues(alpha: 0.2),
                  AppColors.warningLight.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warningLight.withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.warningLight.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.warningLight,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.maxPhotoLimitWarning(totalPhotoCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warningLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isEnabled ? onPressed : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: isEnabled
                  ? containerColor
                  : theme.colorScheme.surfaceContainerHighest,
              disabledBackgroundColor:
                  theme.colorScheme.surfaceContainerHighest,
              foregroundColor: isEnabled
                  ? AppColors.surface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              disabledForegroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.6,
              ),
              side: BorderSide(
                color: isEnabled
                    ? containerColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    estimatedTimeText != null && isEnabled && !isError
                        ? '$label ($estimatedTimeText)'
                        : label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.surface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

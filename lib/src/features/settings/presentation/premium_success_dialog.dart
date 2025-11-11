import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../l10n/app_localizations.dart';

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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.secondaryContainer,
            ],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success animation
              SizedBox(
                width: 120,
                height: 120,
                child: Lottie.asset(
                  'assets/lottie/succes.json',
                  fit: BoxFit.contain,
                  repeat: false,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                'Premium Aktif!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'Tebrikler! Premium üyeliğiniz aktif. Artık tüm özelliklere erişebilirsiniz.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.9),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Lifetime access message
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.all_inclusive_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        l10n.lifetimeAccessMessage,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Features list
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _FeatureItem(
                      icon: Icons.all_inclusive,
                      text: l10n.unlimitedDeletions,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _FeatureItem(
                      icon: Icons.blur_on,
                      text: l10n.unlimitedBlurScans,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _FeatureItem(
                      icon: Icons.photo_library,
                      text: l10n.unlimitedDuplicateScans,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _FeatureItem(
                      icon: Icons.block,
                      text: l10n.noAds,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _FeatureItem(
                      icon: Icons.verified,
                      text: l10n.prioritySupport,
                      theme: theme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Close button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Kullanmaya Başla'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(
          Icons.check_circle,
          size: 20,
          color: Colors.green.shade400,
        ),
      ],
    );
  }
}


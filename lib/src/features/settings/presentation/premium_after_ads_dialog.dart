import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../gallery/application/gallery_providers.dart';
import 'premium_success_dialog.dart';
import '../../../app/theme/app_colors.dart';

/// Premium dialog shown after 3 interstitial ads
class PremiumAfterAdsDialog extends ConsumerStatefulWidget {
  const PremiumAfterAdsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: AppColors.black.withOpacity(0.7), // Transparan değil
      builder: (dialogContext) => const PremiumAfterAdsDialog(),
    );
  }

  @override
  ConsumerState<PremiumAfterAdsDialog> createState() =>
      _PremiumAfterAdsDialogState();
}

class _PremiumAfterAdsDialogState
    extends ConsumerState<PremiumAfterAdsDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
  String? _productPrice;
  String? _originalPrice;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _loadProductPrice();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadProductPrice() async {
    try {
      final rc = RevenueCatService.instance;
      await rc.initialize();
      final product = await rc.fetchLifetimeProduct();
      if (product == null) {
        if (mounted) {
          setState(() {
            _productPrice = 'N/A';
            _originalPrice = null;
          });
        }
        return;
      }

      final priceString = product.priceString;
      final priceValue = _parsePrice(priceString);
      if (priceValue != null) {
        final increasedPrice = priceValue * 1.25;
        final currencySymbol = _extractCurrencySymbol(priceString);
        if (mounted) {
          setState(() {
            _originalPrice =
                '$currencySymbol${increasedPrice.toStringAsFixed(2)}';
            _productPrice = priceString;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _originalPrice = null;
            _productPrice = priceString;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [PremiumAfterAdsDialog] Error loading product price: $e');
      if (mounted) {
        setState(() {
          _productPrice = 'N/A';
          _originalPrice = null;
        });
      }
    }
  }

  double? _parsePrice(String price) {
    final cleaned =
        price.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  String _extractCurrencySymbol(String price) {
    final match = RegExp(r'[^\d.,\s]').firstMatch(price);
    return match?.group(0) ?? '';
  }


  Future<void> _handlePurchase() async {
    if (_isLoading) return;

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rc = RevenueCatService.instance;
      await rc.initialize();

      if (await rc.isPremium()) {
        await _handlePremiumUnlocked();
        return;
      }

      final success = await rc.purchaseLifetime();

      if (!mounted) return;

      if (success) {
        await _handlePremiumUnlocked();
      } else {
        final premiumNow = await rc.isPremium();
        if (premiumNow) {
          await _handlePremiumUnlocked();
        } else {
          setState(() {
            _errorMessage = l10n.failedToInitiatePurchase;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${l10n.purchaseError}: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePremiumUnlocked() async {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = null;
    });

    ref.invalidate(isPremiumProvider);
    ref.invalidate(scanLimitProvider);
    await ref.read(deleteLimitProvider.notifier).refresh();

    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final rootContext = navigator.context;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await PremiumSuccessDialog.show(rootContext);
      } catch (e) {
        debugPrint('⚠️ [PremiumAfterAdsDialog] Dialog gösterilirken hata: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPremiumAsync = ref.watch(isPremiumProvider);
    final isPremium = isPremiumAsync.asData?.value ?? false;

    return Dialog(
      backgroundColor: AppColors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (value * 0.2),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.25),
                blurRadius: 32,
                spreadRadius: 2,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium Icon with pulse
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: AppColors.ctaGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 50,
                        color: AppColors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                l10n.removeAdsAndUnlimitedDeletions,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                l10n.removeAdsAndUnlimitedDeletionsDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Features
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh
                      .withOpacity(isDark ? 0.5 : 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _FeatureRow(
                      icon: Icons.block_rounded,
                      text: l10n.noAds,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.delete_outline_rounded,
                      text: l10n.unlimitedDeletions,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.verified_rounded,
                      text: l10n.lifetimeAccess,
                      theme: theme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!isPremium) ...[
                // Package Price Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        theme.colorScheme.surface.withOpacity(0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              color: AppColors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.discount25Short,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 0.98 + (_pulseAnimation.value - 1) * 0.02,
                            child: Text(
                              _productPrice ?? '--',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                                color: theme.colorScheme.primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          );
                        },
                      ),
                      if (_originalPrice != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _originalPrice!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.oneTimePayment,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.lifetimeAccess,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handlePurchase,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(AppColors.white),
                            ),
                          )
                        : Text(
                            l10n.purchaseNow,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.youArePremium,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.premiumAccessDescription,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      l10n.startCleaningButton,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Cancel Button
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                child: Text(
                  l10n.maybeLater,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
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
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gallery_cleaner/src/features/gallery/application/gallery_providers.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/services/revenuecat_service.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../settings/presentation/premium_success_dialog.dart';
import '../../../../core/services/delete_limit_tracker_service.dart';
import '../../application/gallery_stats_provider.dart';

/// Public paywall dialog widget extracted from SwipePage.
class FirstPaywallDialog extends StatefulWidget {
  const FirstPaywallDialog({required this.onPurchaseComplete, super.key});

  final VoidCallback onPurchaseComplete;

  @override
  State<FirstPaywallDialog> createState() => _FirstPaywallDialogState();
}

class _FirstPaywallDialogState extends State<FirstPaywallDialog>
    with TickerProviderStateMixin {
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

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadProductInfo();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadProductInfo() async {
    try {
      final rc = RevenueCatService.instance;
      await rc.initialize();

      final package = await rc.fetchLifetimePackage();
      if (package != null) {
        final product = package.storeProduct;
        final priceString = product.priceString;
        final priceValue = _parsePrice(priceString);

        if (mounted) {
          setState(() {
            if (priceValue != null) {
              final increasedPrice = priceValue * 1.25;
              final currencySymbol = _extractCurrencySymbol(priceString);
              _originalPrice =
                  '$currencySymbol${increasedPrice.toStringAsFixed(2)}';
              _productPrice = priceString;
            } else {
              _productPrice = priceString;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load product information';
        });
      }
    }
  }

  double? _parsePrice(String price) {
    final cleaned = price
        .replaceAll(RegExp(r'[^\d.,]'), '')
        .replaceAll(',', '.');
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

    context.read<PremiumCubit>().refresh();
    context.read<GeneralScanLimitCubit>().refresh();
    await context.read<DeleteLimitCubit>().refresh();

    if (!mounted) return;
    Navigator.of(context).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        try {
          await PremiumSuccessDialog.show(context);
          widget.onPurchaseComplete();
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final pricePrimaryTextColor = AppColors.textPrimary(theme.brightness);
    final priceSecondaryTextColor = AppColors.textSecondary(theme.brightness);
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.8,
    );

    return Dialog(
      backgroundColor: AppColors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      containerColor.withValues(alpha: 0.15),
                      containerColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.12),
                      AppColors.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: 20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.1),
                      AppColors.secondary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                        color: theme.colorScheme.onSurface,
                        padding: EdgeInsets.zero,
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
                // ... (keep remaining UI identical to existing implementation) ...
              ],
            ),
          ],
        ),
      ),
    );
  }
}

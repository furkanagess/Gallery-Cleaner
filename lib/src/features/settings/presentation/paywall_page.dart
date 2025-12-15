import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../gallery/application/gallery_providers.dart';
import 'premium_success_dialog.dart';
import '../../../app/theme/app_colors.dart';
import 'package:gallery_cleaner/src/core/utils/view_refresh_cubit.dart';

/// Full-screen paywall page for in-app purchases
class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage>
    with TickerProviderStateMixin, CubitStateMixin<PaywallPage> {
  bool _isLoading = false;
  bool _isRestoring = false;
  String? _errorMessage;
  String? _successMessage;
  String? _productPrice;
  String? _originalPrice;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _sparkleController;

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

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _loadProductPrice();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  Future<void> _loadProductPrice() async {
    try {
      final rc = RevenueCatService.instance;
      await rc.initialize();
      final product = await rc.fetchLifetimeProduct();
      if (product == null) {
        debugPrint('⚠️ [Paywall] Lifetime product not available');
        if (mounted) {
          cubitSetState(() {
            _productPrice = 'N/A';
            _originalPrice = null;
          });
        }
        return;
      }
      final priceString = product.priceString;
      final priceValue = _parsePrice(priceString);
      if (priceValue != null) {
        // Show as if there is a 25% discount: original price = +25% of current,
        // displayed price = current RevenueCat price.
        final increasedPrice = priceValue * 1.25;
        final currencySymbol = _extractCurrencySymbol(priceString);
        if (mounted) {
          cubitSetState(() {
            _originalPrice =
                '$currencySymbol${increasedPrice.toStringAsFixed(2)}';
            _productPrice = priceString;
          });
        }
      } else {
        // Fallback: show only current price without strikethrough section
        if (mounted) {
          cubitSetState(() {
            _originalPrice = null;
            _productPrice = priceString;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [Paywall] Error loading product price: $e');
      if (mounted) {
        cubitSetState(() {
          _productPrice = 'N/A';
          _originalPrice = null;
        });
      }
    }
  }

  double? _parsePrice(String price) {
    // Remove currency symbols and parse number
    final cleaned = price
        .replaceAll(RegExp(r'[^\d.,]'), '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  String _extractCurrencySymbol(String price) {
    // Extract currency symbol (first non-digit character)
    final match = RegExp(r'[^\d.,\s]').firstMatch(price);
    return match?.group(0) ?? '';
  }

  Future<void> _handlePurchase() async {
    if (_isLoading) return;

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    cubitSetState(() {
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
          cubitSetState(() {
            _errorMessage = l10n.failedToInitiatePurchase;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      cubitSetState(() {
        _errorMessage = '${l10n.purchaseError}: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRestorePurchases() async {
    if (_isLoading || _isRestoring) return;

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    cubitSetState(() {
      _isRestoring = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final rc = RevenueCatService.instance;
      await rc.initialize();
      final ok = await rc.restore();
      if (!mounted) return;
      final contextL10n = AppLocalizations.of(context)!;
      if (ok) {
        await _handlePremiumUnlocked(isFromRestore: true);
      } else {
        final premiumNow = await rc.isPremium();
        if (premiumNow) {
          await _handlePremiumUnlocked(isFromRestore: true);
        } else {
          cubitSetState(() {
            _errorMessage = contextL10n.noPreviousPurchases;
            _isRestoring = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      cubitSetState(() {
        _errorMessage = '${l10n.restoreError}: $e';
        _isRestoring = false;
      });
    }
  }

  Future<void> _handlePremiumUnlocked({bool isFromRestore = false}) async {
    if (!mounted) return;
    cubitSetState(() {
      _isLoading = false;
      if (isFromRestore) {
        _isRestoring = false;
      }
      _errorMessage = null;
      _successMessage = null;
    });

    context.read<PremiumCubit>().refresh();
    context.read<GeneralScanLimitCubit>().refresh();
    await context.read<DeleteLimitCubit>().refresh();

    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final rootContext = navigator.context;

    if (Navigator.of(context).canPop()) {
      context.pop();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await PremiumSuccessDialog.show(rootContext);
      } catch (e) {
        debugPrint('⚠️ [PaywallPage] Dialog gösterilirken hata: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pricePrimaryTextColor = AppColors.textPrimary(theme.brightness);
    final priceSecondaryTextColor = AppColors.textSecondary(theme.brightness);
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    final isPremium = isPremiumAsync.valueOrNull ?? false;
    // Dinamik container rengi (premium durumuna göre)
    final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(
      0.8,
    );

    return buildWithCubit(
      () => Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: SafeArea(
          child: Stack(
            children: [
              // New Year snowing background
              Positioned.fill(
                child: Opacity(
                  opacity: 0.4,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      AppColors.white,
                      BlendMode.srcATop,
                    ),
                    child: Lottie.asset(
                      'assets/new_year/Snowing.json',
                      fit: BoxFit.cover,
                      repeat: true,
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  // Header with close and restore buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, size: 22),
                          onPressed: () => context.pop(),
                          color: theme.colorScheme.onSurface,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        TextButton(
                          onPressed: (_isLoading || _isRestoring)
                              ? null
                              : _handleRestorePurchases,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: Colors.transparent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Builder(
                            builder: (buttonContext) {
                              final isPremiumButtonAsync = buttonContext
                                  .watch<PremiumCubit>()
                                  .state;
                              final isPremiumButton =
                                  isPremiumButtonAsync.valueOrNull ?? false;
                              final containerColorButton = theme
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity(0.8);
                              return _isRestoring
                                  ? SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              containerColorButton,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      l10n.restorePurchases,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: containerColorButton,
                                      ),
                                    );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // New Year themed header card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primary.withOpacity(0.18),
                                theme.colorScheme.error.withOpacity(0.16),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(
                                0.35,
                              ),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.shadow.withOpacity(
                                  0.25,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.background
                                          .withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Image.asset(
                                      'assets/new_year/santa-claus.png',
                                      width: 26,
                                      height: 26,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      l10n.paywallTitle,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.4,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.paywallSubtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.86),
                                  height: 1.3,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: -10,
                          child: Opacity(
                            opacity: 0.35,
                            child: Image.asset(
                              'assets/new_year/gift-box.png',
                              width: 72,
                              height: 72,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Features - Vertical List (Compact)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _PaywallFeatureItem(
                              icon: Icons.all_inclusive_rounded,
                              title: l10n.featureUnlimitedDeletions,
                              description: l10n.featureUnlimitedDeletionsDesc,
                              isCompact: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            flex: 1,
                            child: _PaywallFeatureItem(
                              icon: Icons.grid_view_rounded,
                              title: l10n.featureAIDetection,
                              description: l10n.featureAIDetectionDesc,
                              isCompact: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            flex: 1,
                            child: _PaywallFeatureItem(
                              icon: Icons.auto_awesome_rounded,
                              title: l10n.featureAutoClean,
                              description: l10n.featureAutoCleanDesc,
                              isCompact: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            flex: 1,
                            child: _PaywallFeatureItem(
                              icon: Icons.block_rounded,
                              title: l10n.featureAdFree,
                              description: l10n.featureAdFreeDesc,
                              isCompact: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!isPremium) ...[
                    // One-time Offer Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        l10n.oneTimeOffer,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.background,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Price section
                    if (_productPrice != null && _originalPrice != null) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? theme.colorScheme.primaryContainer.withOpacity(
                                  0.3,
                                )
                              : theme.colorScheme.primaryContainer.withOpacity(
                                  0.8,
                                ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: containerColor.withOpacity(
                              isDark ? 0.3 : 0.5,
                            ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: containerColor.withOpacity(
                                isDark ? 0.15 : 0.3,
                              ),
                              blurRadius: 15,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l10n.payOnceOwnForever,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: pricePrimaryTextColor,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 120,
                                        ),
                                        child: Text(
                                          _originalPrice!,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                decorationThickness: 2,
                                                decorationColor:
                                                    priceSecondaryTextColor
                                                        .withOpacity(
                                                          isDark ? 0.8 : 0.7,
                                                        ),
                                                color: priceSecondaryTextColor
                                                    .withOpacity(
                                                      isDark ? 0.85 : 0.65,
                                                    ),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withOpacity(
                                            0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: AppColors.success
                                                .withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          l10n.discount25Short,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 9,
                                                color: AppColors.success,
                                                letterSpacing: 0.3,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              flex: 1,
                              fit: FlexFit.loose,
                              child: AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale:
                                        0.98 +
                                        (_pulseAnimation.value - 1) * 0.02,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        _productPrice!,
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 32,
                                              color: pricePrimaryTextColor,
                                              letterSpacing: -0.8,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Upgrade button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [containerColor, AppColors.accent],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: containerColor.withOpacity(0.9),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: containerColor.withOpacity(
                                      (isDark ? 0.3 : 0.5) *
                                          _pulseAnimation.value,
                                    ),
                                    blurRadius: 25 * _pulseAnimation.value,
                                    spreadRadius: 2 * _pulseAnimation.value,
                                    offset: Offset(
                                      0,
                                      10 * _pulseAnimation.value,
                                    ),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: AppColors.transparent,
                                child: InkWell(
                                  onTap: _isLoading ? null : _handlePurchase,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: _isLoading
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                height: 18,
                                                width: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(
                                                        theme
                                                            .colorScheme
                                                            .onPrimary,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                l10n.processing,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: theme
                                                      .colorScheme
                                                      .background,
                                                  letterSpacing: 0.3,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          )
                                        : Text(
                                            l10n.upgradeToPremium,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color:
                                                  theme.colorScheme.background,
                                              letterSpacing: 0.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Continue with free version
                    TextButton(
                      onPressed: () => context.pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: Colors.transparent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.continueWithFree,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Footer text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.noSubscriptionsNoFees,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: containerColor.withOpacity(0.2),
                          width: 1.5,
                        ),
                        color: theme.colorScheme.surface,
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
                          const SizedBox(width: 16),
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
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: FilledButton(
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            context.pop();
                          }
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          l10n.startCleaningButton,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Error/Success messages
                  if (_errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.colorScheme.onErrorContainer,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (_successMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.success.withOpacity(0.2)
                              : AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.success.withOpacity(
                              isDark ? 0.3 : 0.2,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: AppColors.success,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.success,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaywallFeatureItem extends StatelessWidget {
  const _PaywallFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    this.isCompact = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    final isPremium = isPremiumAsync.valueOrNull ?? false;
    final color = theme.colorScheme.onPrimaryContainer.withOpacity(0.8);

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                ]
              : [
                  theme.colorScheme.surface.withOpacity(0.95),
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                ],
        ),
        borderRadius: BorderRadius.circular(isCompact ? 14 : 18),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.25 : 0.18),
          width: isCompact ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.15 : 0.12),
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.shadow(
              theme.brightness,
            ).withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: isCompact ? 42 : 52,
            height: isCompact ? 42 : 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.25), color.withOpacity(0.12)],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.35),
                width: isCompact ? 1.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: isCompact ? 22 : 26, color: color),
          ),
          SizedBox(width: isCompact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: isCompact ? 14 : 16,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 6 : 8,
                        vertical: isCompact ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: color.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: isCompact ? 12 : 14,
                        color: color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 4 : 6),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: isCompact ? 11 : 12.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.72),
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaywallFeatureCard extends StatefulWidget {
  const _PaywallFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  State<_PaywallFeatureCard> createState() => _PaywallFeatureCardState();
}

class _PaywallFeatureCardState extends State<_PaywallFeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    final isPremium = isPremiumAsync.valueOrNull ?? false;
    final color = theme.colorScheme.onPrimaryContainer.withOpacity(0.8);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.2, 0),
          end: Offset.zero,
        ).animate(_fadeAnimation),
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.4)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(isDark ? 0.3 : 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isDark ? 0.15 : 0.1),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.25), color.withOpacity(0.15)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.4), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(widget.icon, size: 28, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Text(
                widget.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

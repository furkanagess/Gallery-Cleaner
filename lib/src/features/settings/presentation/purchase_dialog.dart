import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../gallery/application/gallery_providers.dart';
import 'premium_success_dialog.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_decorations.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Purchase dialog widget for in-app purchases
class PurchaseDialog extends ConsumerStatefulWidget {
  const PurchaseDialog({super.key});

  @override
  ConsumerState<PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends ConsumerState<PurchaseDialog>
    with TickerProviderStateMixin {
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
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
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
      // Load RevenueCat offerings and read lifetime package price
      final rc = RevenueCatService.instance;
      await rc.initialize();
      final offerings = await rc.getOfferings();
      if (offerings == null || offerings.current == null) {
        debugPrint('⚠️ [PurchaseDialog] Offerings not available');
        if (mounted) {
          setState(() {
            _productPrice = 'N/A';
            _originalPrice = null;
          });
        }
        return;
      }
      final current = offerings.current!;
      final target = (current.identifier == RevenueCatService.offeringId)
          ? current
          : offerings.all[RevenueCatService.offeringId] ?? current;
      final base = target;
      Package? package = base.lifetime;
      if (package == null) {
        final list = base.availablePackages;
        final byType = list.where((p) => p.packageType == PackageType.lifetime);
        package = byType.isNotEmpty ? byType.first : (list.isNotEmpty ? list.first : null);
      }
      final product = package?.storeProduct;
      if (product == null || !mounted) {
        if (mounted) {
          setState(() {
            _productPrice = 'N/A';
            _originalPrice = null;
          });
        }
        return;
      }
      // Optional promo calc (25%)
      final priceString = product.priceString;
      final priceValue = _parsePrice(priceString);
      if (priceValue != null) {
        final discountedPrice = priceValue * 0.75;
        final currencySymbol = _extractCurrencySymbol(priceString);
        if (mounted) {
          setState(() {
            _originalPrice = priceString;
            _productPrice = '$currencySymbol${discountedPrice.toStringAsFixed(2)}';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _productPrice = priceString;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [PurchaseDialog] Error loading product price: $e');
      if (mounted) {
        setState(() {
          _productPrice = 'N/A';
          _originalPrice = null;
        });
      }
    }
  }

  double? _parsePrice(String price) {
    // Remove currency symbols and parse number
    final cleaned = price.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rc = RevenueCatService.instance;
      await rc.initialize();

      // Önce premium durumunu kontrol et
      if (await rc.isPremium()) {
        await _handlePremiumUnlocked();
        return;
      }

      // Satın alma işlemini başlat
      final success = await rc.purchaseLifetime();
      
      if (!mounted) return;

      if (success) {
        await _handlePremiumUnlocked();
      } else {
        // Başarısız olursa tekrar premium durumunu kontrol et
        // (Simülatörde bazen false negative olabiliyor)
        await Future.delayed(const Duration(milliseconds: 500));
        final premiumNow = await rc.isPremium();
        if (premiumNow) {
          debugPrint('✅ [PurchaseDialog] Premium activated after retry check.');
          await _handlePremiumUnlocked();
        } else {
          setState(() {
            _errorMessage = l10n.failedToInitiatePurchase;
            _isLoading = false;
          });
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      
      // Platform exception'ları yakalayıp daha detaylı loglama yap
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('⚠️ [PurchaseDialog] Platform exception: $errorCode | ${e.message}');
      
      // User cancelled durumunda bile bir kez daha premium kontrolü yap
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        await Future.delayed(const Duration(milliseconds: 500));
        final rc = RevenueCatService.instance;
        final premiumNow = await rc.isPremium();
        if (premiumNow) {
          debugPrint('✅ [PurchaseDialog] Premium activated despite cancellation error.');
          await _handlePremiumUnlocked();
          return;
        }
      }
      
      setState(() {
        _errorMessage = l10n.failedToInitiatePurchase;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      debugPrint('❌ [PurchaseDialog] Purchase error: $e');
      
      // Genel hata durumunda da premium kontrolü yap
      final rc = RevenueCatService.instance;
      final premiumNow = await rc.isPremium();
      if (premiumNow) {
        debugPrint('✅ [PurchaseDialog] Premium activated despite error.');
        await _handlePremiumUnlocked();
        return;
      }
      
      setState(() {
        _errorMessage = '${l10n.purchaseError}: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRestorePurchases() async {
    if (_isLoading || _isRestoring) return;

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
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
          setState(() {
            _errorMessage = contextL10n.noPreviousPurchases;
            _isRestoring = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${l10n.restoreError}: $e';
        _isRestoring = false;
      });
    }
  }

  Future<void> _handlePremiumUnlocked({bool isFromRestore = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (isFromRestore) {
        _isRestoring = false;
      }
      _errorMessage = null;
      _successMessage = null;
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
        debugPrint('⚠️ [PurchaseDialog] Dialog gösterilirken hata: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.secondaryContainer,
              ],
            ),
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
              // Animated Icon with pulse
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.4 * _pulseAnimation.value),
                            blurRadius: 20 * _pulseAnimation.value,
                            spreadRadius: 3 * _pulseAnimation.value,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.all_inclusive_rounded,
                        size: 45,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              // Discount Badge with animation
              AnimatedBuilder(
                animation: _sparkleController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _sparkleController.value * 0.1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: AppDecorations.pill(
                        color: AppColors.error,
                        borderRadius: 28,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: AppColors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.discount25,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Limited Time Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: AppDecorations.glassSurface(
                  borderRadius: 18,
                  tint: AppColors.warningLight,
                  opacity: 0.35,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: AppColors.warningDark,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.limitedTimeOffer,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.warningDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Features - Horizontal Scroll
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    const SizedBox(width: 4),
                    _PurchaseFeatureCard(
                      icon: Icons.delete_outline_rounded,
                      iconColor: AppColors.error,
                      text: l10n.unlimitedDeletions,
                      subtitle: l10n.lifetimeAccess,
                    ),
                    const SizedBox(width: 12),
                    _PurchaseFeatureCard(
                      icon: Icons.blur_on_rounded,
                      iconColor: AppColors.primary,
                      text: l10n.unlimitedBlurScans,
                    ),
                    const SizedBox(width: 12),
                    _PurchaseFeatureCard(
                      icon: Icons.photo_library_outlined,
                      iconColor: AppColors.secondary,
                      text: l10n.unlimitedDuplicateScans,
                    ),
                    const SizedBox(width: 12),
                    _PurchaseFeatureCard(
                      icon: Icons.block_rounded,
                      iconColor: AppColors.warning,
                      text: l10n.noMoreAds,
                    ),
                    const SizedBox(width: 12),
                    _PurchaseFeatureCard(
                      icon: Icons.verified_rounded,
                      iconColor: theme.colorScheme.primary,
                      text: l10n.oneTimePayment,
                      subtitle: l10n.lifetimeAccess,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
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
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (!isPremium) ...[
                // Price section with discount
                if (_productPrice != null && _originalPrice != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.originalPrice,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _originalPrice!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                decorationThickness: 2,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 0.98 + (_pulseAnimation.value - 1) * 0.02,
                              child: Text(
                                _productPrice!,
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
                        const SizedBox(height: 4),
                        Text(
                          l10n.saveNow,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Purchase button with gradient and animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.5 * _pulseAnimation.value),
                              blurRadius: 25 * _pulseAnimation.value,
                              spreadRadius: 3 * _pulseAnimation.value,
                              offset: Offset(0, 10 * _pulseAnimation.value),
                            ),
                          ],
                        ),
                        child: Material(
                          color: AppColors.transparent,
                          child: InkWell(
                            onTap: _isLoading ? null : _handlePurchase,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 22),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          theme.colorScheme.onPrimary,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color: theme.colorScheme.onPrimary,
                                          size: 26,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          l10n.purchaseNow,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20,
                                            color: theme.colorScheme.onPrimary,
                                            letterSpacing: 0.8,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: (_isLoading || _isRestoring)
                      ? null
                      : _handleRestorePurchases,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  child: _isRestoring
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.restoring,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          l10n.restorePurchases,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: (_isLoading || _isRestoring)
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  child: Text(
                    l10n.cancel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
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
                FilledButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    l10n.startCleaningButton,
                    style: const TextStyle(fontWeight: FontWeight.bold),
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

class _PurchaseFeatureCard extends StatefulWidget {
  const _PurchaseFeatureCard({
    required this.icon,
    required this.text,
    this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final String text;
  final String? subtitle;
  final Color? iconColor;

  @override
  State<_PurchaseFeatureCard> createState() => _PurchaseFeatureCardState();
}

class _PurchaseFeatureCardState extends State<_PurchaseFeatureCard>
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
    final color = widget.iconColor ?? theme.colorScheme.primary;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.2, 0),
          end: Offset.zero,
        ).animate(_fadeAnimation),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface.withOpacity(0.9),
                theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.25),
                      color.withOpacity(0.15),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.4),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: theme.colorScheme.onSurface,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

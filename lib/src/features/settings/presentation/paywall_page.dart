import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/services/in_app_purchase_service.dart';
import '../../gallery/application/gallery_providers.dart';
import 'premium_success_dialog.dart';

/// Full-screen paywall page for in-app purchases
class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage>
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
    final iapService = InAppPurchaseService.instance;
    await iapService.loadProducts();
    final product = iapService.getPremiumProduct();
    if (product != null && mounted) {
      // Calculate 25% discount
      final priceValue = _parsePrice(product.price);
      if (priceValue != null) {
        final discountedPrice = priceValue * 0.75;
        final currencySymbol = _extractCurrencySymbol(product.price);
        setState(() {
          _originalPrice = product.price;
          _productPrice = '$currencySymbol${discountedPrice.toStringAsFixed(2)}';
        });
      } else {
        setState(() {
          _productPrice = product.price;
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
      final iapService = InAppPurchaseService.instance;
      
      if (!iapService.isAvailable) {
        if (!mounted) return;
        setState(() {
          _errorMessage = l10n.storeNotAvailable;
          _isLoading = false;
        });
        return;
      }

      final success = await iapService.purchasePremium(
        onComplete: (purchaseSuccess) async {
          if (!mounted) return;
          final contextL10n = AppLocalizations.of(context)!;
          
          if (purchaseSuccess) {
            // Invalidate premium provider to refresh UI
            ref.invalidate(isPremiumProvider);
            ref.invalidate(scanLimitProvider);
            await ref.read(deleteLimitProvider.notifier).refresh();
            
            if (mounted) {
              context.pop();
              // Show premium success dialog
              await PremiumSuccessDialog.show(context);
            }
          } else {
            if (!mounted) return;
            setState(() {
              _errorMessage = contextL10n.purchaseFailed;
              _isLoading = false;
            });
          }
        },
      );
      
      if (!mounted) return;

      if (!success) {
        setState(() {
          _errorMessage = l10n.failedToInitiatePurchase;
          _isLoading = false;
        });
      }
      // If success, wait for callback
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${l10n.purchaseError}: $e';
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
      final iapService = InAppPurchaseService.instance;
      
      if (!iapService.isAvailable) {
        if (!mounted) return;
        setState(() {
          _errorMessage = l10n.storeNotAvailable;
          _isRestoring = false;
        });
        return;
      }

      await iapService.restorePurchases(
        onComplete: (success, hasRestored) async {
          if (!mounted) return;
          final contextL10n = AppLocalizations.of(context)!;
          
          if (success && hasRestored) {
            // Invalidate premium provider to refresh UI
            ref.invalidate(isPremiumProvider);
            ref.invalidate(scanLimitProvider);
            await ref.read(deleteLimitProvider.notifier).refresh();
            
            if (!mounted) return;
            setState(() {
              _successMessage = contextL10n.purchasesRestoredSuccessfully;
              _isRestoring = false;
            });
            
            // Close page after a short delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                context.pop();
              }
            });
          } else {
            if (!mounted) return;
            setState(() {
              _errorMessage = contextL10n.noPreviousPurchases;
              _isRestoring = false;
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${l10n.restoreError}: $e';
        _isRestoring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primaryContainer.withOpacity(0.3),
                      theme.colorScheme.secondaryContainer.withOpacity(0.2),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Column(
              children: [
                // Header with close and restore buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: _isRestoring
                            ? SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary,
                                  ),
                                ),
                              )
                            : Text(
                                l10n.restorePurchases,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Unlock a Smarter, Cleaner Gallery',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onSurface,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'AI-powered photo cleanup. One-time payment. Lifetime access.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.75),
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                            iconColor: Colors.blue,
                            title: 'Unlimited Deletions',
                            description: 'Clean your gallery without any limits.',
                            isCompact: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          flex: 1,
                          child: _PaywallFeatureItem(
                            icon: Icons.grid_view_rounded,
                            iconColor: Colors.blue,
                            title: 'AI Blur & Duplicate Detection',
                            description: 'Find and remove unwanted photos.',
                            isCompact: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          flex: 1,
                          child: _PaywallFeatureItem(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: Colors.blue,
                            title: 'Smart Auto-Clean Suggestions',
                            description: 'Let our AI find photos to delete for you.',
                            isCompact: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          flex: 1,
                          child: _PaywallFeatureItem(
                            icon: Icons.block_rounded,
                            iconColor: Colors.blue,
                            title: 'Ad-Free Experience',
                            description: 'Enjoy a seamless, ad-free interface.',
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Most Popular Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'MOST POPULAR',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Price section
                if (_productPrice != null && _originalPrice != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'One-time purchase',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  _originalPrice!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    decorationThickness: 2,
                                    decorationColor: theme.colorScheme.onPrimaryContainer.withOpacity(0.6),
                                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '25% OFF',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                      color: Colors.green.shade700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 0.98 + (_pulseAnimation.value - 1) * 0.02,
                              child: Text(
                                _productPrice!,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 32,
                                  color: theme.colorScheme.onPrimaryContainer,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            );
                          },
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
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.5 * _pulseAnimation.value),
                                blurRadius: 25 * _pulseAnimation.value,
                                spreadRadius: 2 * _pulseAnimation.value,
                                offset: Offset(0, 10 * _pulseAnimation.value),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _handlePurchase,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: _isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            theme.colorScheme.onPrimary,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        'Upgrade to Premium',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: theme.colorScheme.onPrimary,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Continue with Free Version',
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
                        'No subscriptions. No hidden fees.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
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
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green,
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
    );
  }
}

class _PaywallFeatureItem extends StatelessWidget {
  const _PaywallFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
    this.isCompact = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color? iconColor;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;
    
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: isCompact ? 1 : 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isCompact ? 40 : 56,
            height: isCompact ? 40 : 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.3),
                width: isCompact ? 1.5 : 2,
              ),
            ),
            child: Icon(
              icon,
              size: isCompact ? 20 : 28,
              color: color,
            ),
          ),
          SizedBox(width: isCompact ? 12 : 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: isCompact ? 14 : 18,
                    color: theme.colorScheme.onSurface,
                    height: 1.2,
                  ),
                  maxLines: isCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isCompact ? 4 : 8),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: isCompact ? 11 : 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.3,
                  ),
                  maxLines: isCompact ? 1 : 2,
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
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color? iconColor;

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
    final color = widget.iconColor ?? theme.colorScheme.primary;
    
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
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
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
                      color: color.withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  size: 28,
                  color: color,
                ),
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

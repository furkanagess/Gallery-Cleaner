import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/services/in_app_review_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../application/locale_controller.dart';
import '../../gallery/application/gallery_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/revenuecat_service.dart';
import 'premium_success_dialog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = context.watch<LocaleCubit>().state;

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: Text(l10n.settings), centerTitle: true),
      body: Builder(
        builder: (builderContext) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                // Premium Section - En üstte
                _PremiumSection(),
                const SizedBox(height: 12),
                // Rate App Section (shows only when user hasn't rated yet)
                const _RateAppSection(),
                const SizedBox(height: 12),
                // Language Selection
                _SettingsCard(
                  theme: theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.language,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CompactLanguageSelector(
                        locale: locale,
                        onLocaleChanged: (loc) {
                          context.read<LocaleCubit>().setAppLocale(loc);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Try swipe (warmup) - opens warmup screen

                // Gallery stats (en altta)
                _SettingsCard(
                  theme: theme,
                  child: Material(
                    color: AppColors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/gallery/stats'),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.bar_chart_rounded,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                l10n.galleryStatsTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Version info - Modern
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        final version = snapshot.data?.version;
                        final buildNumber = snapshot.data?.buildNumber;
                        final text = (version != null && buildNumber != null)
                            ? 'v$version'
                            : 'v--';

                        return Text(
                          text,

                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          );
        },
      ),
    );
  }

  static void showPurchaseDialog(BuildContext context) {
    context.push('/paywall');
  }
}

/// Modern settings card - surfaceContainerHighest, subtle border
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.theme, required this.child});

  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PremiumSection extends StatefulWidget {
  const _PremiumSection();

  @override
  State<_PremiumSection> createState() => _PremiumSectionState();
}

class _PremiumSectionState extends State<_PremiumSection>
    with SingleTickerProviderStateMixin {
  String? _productPrice;
  String? _originalPrice;
  bool _isLoading = false;
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
    _loadProductPrice();
  }

  Future<void> _loadProductPrice() async {
    try {
      final rc = RevenueCatService.instance;
      await rc.initialize();
      final product = await rc.fetchLifetimeProduct();
      if (product == null) {
        if (mounted)
          setState(() {
            _productPrice = 'N/A';
            _originalPrice = null;
          });
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
        if (mounted)
          setState(() {
            _originalPrice = null;
            _productPrice = priceString;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _productPrice = 'N/A';
          _originalPrice = null;
        });
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
    });

    try {
      final rc = RevenueCatService.instance;
      await rc.initialize();

      if (await rc.isPremium()) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        context.read<PremiumCubit>().refresh();
        await PremiumSuccessDialog.show(context);
        return;
      }

      final success = await rc.purchaseLifetime();
      if (!mounted) return;

      if (success) {
        setState(() => _isLoading = false);
        context.read<PremiumCubit>().refresh();
        await PremiumSuccessDialog.show(context);
      } else {
        final premiumNow = await rc.isPremium();
        if (premiumNow) {
          setState(() => _isLoading = false);
          context.read<PremiumCubit>().refresh();
          await PremiumSuccessDialog.show(context);
        } else {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.failedToInitiatePurchase)),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.purchaseError}: $e')));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.9,
    );
    final pricePrimaryTextColor = AppColors.textPrimary(theme.brightness);
    final priceSecondaryTextColor = AppColors.textSecondary(theme.brightness);

    return isPremiumAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
      data: (isPremium) {
        if (isPremium) return const SizedBox.shrink();

        return _SettingsCard(
          theme: theme,
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _handlePurchase,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sınırsız Silme Edin',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_productPrice != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.3,
                                )
                              : theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.8,
                                ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: containerColor.withValues(
                              alpha: isDark ? 0.3 : 0.5,
                            ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: containerColor.withValues(
                                alpha: isDark ? 0.15 : 0.3,
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
                                  if (_originalPrice != null) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          _originalPrice!,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                decorationThickness: 2,
                                                decorationColor:
                                                    priceSecondaryTextColor
                                                        .withValues(
                                                          alpha: isDark
                                                              ? 0.8
                                                              : 0.7,
                                                        ),
                                                color: priceSecondaryTextColor
                                                    .withValues(
                                                      alpha: isDark
                                                          ? 0.85
                                                          : 0.65,
                                                    ),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: AppColors.success
                                                  .withValues(alpha: 0.4),
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
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              flex: 1,
                              fit: FlexFit.loose,
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
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [containerColor, AppColors.accent],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: containerColor.withValues(alpha: 0.9),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: containerColor.withValues(
                                      alpha:
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
                                    alignment: Alignment.center,
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
                                                            .surface,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                l10n.processing,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color:
                                                      theme.colorScheme.surface,
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
                                              color: theme.colorScheme.surface,
                                              letterSpacing: 0.5,
                                            ),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompactLanguageSelector extends StatelessWidget {
  const _CompactLanguageSelector({
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<AppLocale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.8,
    );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: containerColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModernLanguageChip(
            flag: '🇹🇷',
            label: l10n.turkish,
            isSelected: locale.languageCode == 'tr',
            onTap: () => onLocaleChanged(AppLocale.tr),
            containerColor: containerColor,
          ),
          _ModernLanguageChip(
            flag: '🇬🇧',
            label: l10n.english,
            isSelected: locale.languageCode == 'en',
            onTap: () => onLocaleChanged(AppLocale.en),
            containerColor: containerColor,
          ),
          _ModernLanguageChip(
            flag: '🇪🇸',
            label: l10n.spanish,
            isSelected: locale.languageCode == 'es',
            onTap: () => onLocaleChanged(AppLocale.es),
            containerColor: containerColor,
          ),
        ],
      ),
    );
  }
}

class _ModernLanguageChip extends StatelessWidget {
  const _ModernLanguageChip({
    required this.flag,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.containerColor,
  });

  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      containerColor.withValues(alpha: 0.2),
                      containerColor.withValues(alpha: 0.15),
                    ],
                  )
                : null,
            color: isSelected ? null : AppColors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: containerColor.withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: containerColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 11,
                  color: isSelected
                      ? containerColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateAppSection extends StatefulWidget {
  const _RateAppSection();

  @override
  State<_RateAppSection> createState() => _RateAppSectionState();
}

class _RateAppSectionState extends State<_RateAppSection> {
  final PreferencesService _preferencesService = PreferencesService();
  bool _hasUserRated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRateStatus();
  }

  Future<void> _loadRateStatus() async {
    final hasShown = await _preferencesService.hasShownRateUsDialog();
    if (!mounted) return;
    setState(() {
      _hasUserRated = hasShown;
      _isLoading = false;
    });
  }

  Future<void> _handleTap() async {
    await openStoreForReview();
    if (!mounted) return;
    setState(() {
      _hasUserRated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _hasUserRated) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        const SizedBox(height: 12),
        _SettingsCard(
          theme: theme,
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: _handleTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Platform.isAndroid
                            ? Icons.star_rounded
                            : CupertinoIcons.star_fill,
                        color: AppColors.warning,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.rateApp,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.rateAppDescription,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

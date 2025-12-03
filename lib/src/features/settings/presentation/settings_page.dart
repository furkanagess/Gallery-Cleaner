import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../l10n/app_localizations.dart';
import '../application/theme_controller.dart';
import '../application/locale_controller.dart';
import '../../gallery/application/gallery_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/services/preferences_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = context.watch<ThemeCubit>().state;
    final locale = context.watch<LocaleCubit>().state;

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          l10n.settings,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        leading: Platform.isIOS
            ? IconButton(
                icon: Icon(
                  CupertinoIcons.chevron_left,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/swipe');
                  }
                },
              )
            : null,
        automaticallyImplyLeading: !Platform.isIOS,
      ),
      body: Builder(
        builder: (builderContext) {
          // Premium durumunu kontrol et
          final isPremiumAsync = builderContext.watch<PremiumCubit>().state;
          final isPremium = isPremiumAsync.maybeWhen(
            data: (premium) => premium,
            orElse: () => false,
          );

          // Bottom navigation bar'daki container rengiyle aynı
          final containerColor = theme.colorScheme.onPrimaryContainer
              .withOpacity(0.8);

          return Stack(
            children: [
              // Dekoratif arka plan desenleri
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        containerColor.withOpacity(0.1),
                        containerColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.08),
                        AppColors.accent.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Ana içerik - Scroll edilebilir
              SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Premium Section - En üstte, dikkat çekici
                    _PremiumSection(),
                    const SizedBox(height: 12),
                    // Theme Selection Container - Ayrı
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.4),
                            theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: containerColor.withOpacity(0.15),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withOpacity(0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Theme Selection - Modern
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: containerColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.palette_rounded,
                                  size: 16,
                                  color: containerColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.theme,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _CompactThemeSelector(
                            themeMode: themeMode,
                            onThemeChanged: (mode) {
                              context.read<ThemeCubit>().setThemeMode(mode);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Language Selection Container - Ayrı
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.4),
                            theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: containerColor.withOpacity(0.15),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withOpacity(0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Language Selection - Modern
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: containerColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.language_rounded,
                                  size: 16,
                                  color: containerColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.language,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
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
                    // Sound Volume Control Container
                    _SoundVolumeControl(),
                    const SizedBox(height: 12),
                    // Rate App Section
                    _RateAppSection(),
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
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'v1.0.0',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static void showPurchaseDialog(BuildContext context) {
    context.push('/paywall');
  }
}

class _PremiumSection extends StatelessWidget {
  const _PremiumSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isPremiumAsync = context.watch<PremiumCubit>().state;

    return isPremiumAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (isPremium) {
        // Premium kullanıcı için hiçbir şey gösterme
        if (isPremium) {
          return const SizedBox.shrink();
        }

        // Bottom navigation bar'daki container rengiyle aynı
        final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(
          0.8,
        );

        // Premium olmayan kullanıcı için dikkat çekici "Go Premium" bölümü - Rate App gibi
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                containerColor.withOpacity(0.15),
                containerColor.withOpacity(0.1),
                containerColor.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: containerColor.withOpacity(0.25),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: containerColor.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: AppColors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: () => SettingsPage.showPurchaseDialog(context),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Premium Icon Container - Daha büyük ve vurgulu
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                containerColor,
                                containerColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: containerColor.withOpacity(0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: AppColors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Title and Description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.goPremium,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -0.4,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.premiumDescription,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface.withOpacity(
                                    0.75,
                                  ),
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Feature Pills - kompakt
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FeaturePill(
                          icon: Icons.all_inclusive_rounded,
                          label: l10n.unlimited,
                          theme: theme,
                          containerColor: containerColor,
                        ),
                        _FeaturePill(
                          icon: Icons.block_rounded,
                          label: l10n.adFree,
                          theme: theme,
                          containerColor: containerColor,
                        ),
                        _FeaturePill(
                          icon: Icons.verified_rounded,
                          label: l10n.priority,
                          theme: theme,
                          containerColor: containerColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Call to Action Button - Modern ve dikkat çekici
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            containerColor.withOpacity(0.9),
                            containerColor.withOpacity(0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: containerColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: AppColors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.upgradeToPremium,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
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

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.theme,
    required this.containerColor,
  });

  final IconData icon;
  final String label;
  final ThemeData theme;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: containerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: containerColor.withOpacity(0.18), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: containerColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactThemeSelector extends StatelessWidget {
  const _CompactThemeSelector({
    required this.themeMode,
    required this.onThemeChanged,
  });

  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Premium durumunu kontrol et
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    final isPremium = isPremiumAsync.maybeWhen(
      data: (premium) => premium,
      orElse: () => false,
    );

    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(
      0.8,
    );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: containerColor.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModernThemeChip(
            icon: Icons.light_mode_rounded,
            label: l10n.light,
            isSelected: themeMode == AppThemeMode.light,
            onTap: () => onThemeChanged(AppThemeMode.light),
            containerColor: containerColor,
          ),
          _ModernThemeChip(
            icon: Icons.dark_mode_rounded,
            label: l10n.dark,
            isSelected: themeMode == AppThemeMode.dark,
            onTap: () => onThemeChanged(AppThemeMode.dark),
            containerColor: containerColor,
          ),
          _ModernThemeChip(
            icon: Icons.brightness_auto_rounded,
            label: l10n.system,
            isSelected: themeMode == AppThemeMode.system,
            onTap: () => onThemeChanged(AppThemeMode.system),
            containerColor: containerColor,
          ),
        ],
      ),
    );
  }
}

class _ModernThemeChip extends StatelessWidget {
  const _ModernThemeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.containerColor,
  });

  final IconData icon;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      containerColor.withOpacity(0.2),
                      containerColor.withOpacity(0.15),
                    ],
                  )
                : null,
            color: isSelected ? null : AppColors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: containerColor.withOpacity(0.4), width: 1.5)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: containerColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? containerColor
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 11,
                  color: isSelected
                      ? containerColor
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
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

    // Premium durumunu kontrol et
    final isPremiumAsync = context.watch<PremiumCubit>().state;
    final isPremium = isPremiumAsync.maybeWhen(
      data: (premium) => premium,
      orElse: () => false,
    );

    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(
      0.8,
    );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: containerColor.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
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
                      containerColor.withOpacity(0.2),
                      containerColor.withOpacity(0.15),
                    ],
                  )
                : null,
            color: isSelected ? null : AppColors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: containerColor.withOpacity(0.4), width: 1.5)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: containerColor.withOpacity(0.2),
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
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateAppSection extends StatelessWidget {
  const _RateAppSection();

  // Store URLs
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.furkanages.gallerycleaner';
  static const String _appStoreUrl =
      'https://apps.apple.com/us/app/gallery-cleaner-swipe-photo/id6754893118';

  Future<void> _openStore(BuildContext context) async {
    final url = Platform.isAndroid ? _playStoreUrl : _appStoreUrl;
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.couldNotOpenStore),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [RateApp] Error opening store: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.couldNotOpenStore),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.warning.withOpacity(0.15),
            AppColors.warningLight.withOpacity(0.1),
            AppColors.primary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.25),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppColors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () => _openStore(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Star Icon Container - Daha büyük ve vurgulu
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.warning, AppColors.warningLight],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.warning.withOpacity(0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Platform.isAndroid
                            ? Icons.star_rounded
                            : CupertinoIcons.star_fill,
                        color: AppColors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title and Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.rateApp,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.rateAppDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.75,
                              ),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Call to Action Button - Modern ve dikkat çekici
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.warning.withOpacity(0.9),
                        AppColors.warningLight.withOpacity(0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warning.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Platform.isAndroid
                            ? Icons.star_rounded
                            : CupertinoIcons.star_fill,
                        color: AppColors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.rateApp,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundVolumeControl extends StatefulWidget {
  const _SoundVolumeControl();

  @override
  State<_SoundVolumeControl> createState() => _SoundVolumeControlState();
}

class _SoundVolumeControlState extends State<_SoundVolumeControl> {
  final SoundService _soundService = SoundService();
  final PreferencesService _prefsService = PreferencesService();
  double _volume = 1.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVolume();
  }

  Future<void> _loadVolume() async {
    final volume = await _prefsService.getSoundVolume();
    if (mounted) {
      setState(() {
        _volume = volume;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateVolume(double newVolume) async {
    setState(() {
      _volume = newVolume;
    });
    await _soundService.setSoundVolume(newVolume);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Bottom navigation bar'daki container rengiyle aynı
    final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(0.8);

    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: containerColor.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sound Volume Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: containerColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.volume_up_rounded,
                  size: 16,
                  color: containerColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Sound Volume',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Volume Slider
          Row(
            children: [
              Icon(
                Icons.volume_mute_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  activeColor: containerColor,
                  inactiveColor: containerColor.withOpacity(0.3),
                  onChanged: _updateVolume,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.volume_up_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              // Volume percentage text
              SizedBox(
                width: 45,
                child: Text(
                  '${(_volume * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: containerColor,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

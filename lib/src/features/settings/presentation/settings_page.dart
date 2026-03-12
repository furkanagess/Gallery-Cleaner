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
import '../../../core/services/sound_service.dart';
import '../../../core/services/preferences_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = context.watch<LocaleCubit>().state;

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.settings),
        centerTitle: true,
      ),
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
                          color: theme.colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.8,
                          ),
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
                _SoundVolumeControl(),
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

class _PremiumSection extends StatelessWidget {
  const _PremiumSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isPremiumAsync = context.watch<PremiumCubit>().state;

    return isPremiumAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
      data: (isPremium) {
        // Premium kullanıcı için hiçbir şey gösterme
        if (isPremium) {
          return const SizedBox.shrink();
        }

        // Bottom navigation bar'daki container rengiyle aynı
        final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
          alpha: 0.8,
        );

        return _SettingsCard(
          theme: theme,
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: () => SettingsPage.showPurchaseDialog(context),
              borderRadius: BorderRadius.circular(16),
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
                                containerColor.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: containerColor.withValues(alpha: 0.5),
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
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.75,
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            SettingsPage.showPurchaseDialog(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: containerColor,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.workspace_premium_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l10n.upgradeToPremium,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
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
        color: containerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: containerColor.withValues(alpha: 0.18),
          width: 1,
        ),
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
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
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
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.8,
    );

    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return _SettingsCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sound Volume',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.volume_mute_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  activeColor: containerColor,
                  inactiveColor: containerColor.withValues(alpha: 0.3),
                  onChanged: _updateVolume,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.volume_up_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
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

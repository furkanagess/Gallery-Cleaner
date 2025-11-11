import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../application/theme_controller.dart';
import '../application/locale_controller.dart';
import '../../gallery/application/gallery_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        leading: Platform.isIOS
            ? IconButton(
                icon: const Icon(CupertinoIcons.chevron_left),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tema Seçimi
            _SettingsSection(
              title: l10n.theme,
              children: [
                _ThemeOption(
                  icon: Icons.light_mode,
                  title: l10n.light,
                  isSelected: themeMode == AppThemeMode.light,
                  onTap: () {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(AppThemeMode.light);
                  },
                ),
                _ThemeOption(
                  icon: Icons.dark_mode,
                  title: l10n.dark,
                  isSelected: themeMode == AppThemeMode.dark,
                  onTap: () {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(AppThemeMode.dark);
                  },
                ),
                _ThemeOption(
                  icon: Icons.brightness_auto,
                  title: l10n.system,
                  isSelected: themeMode == AppThemeMode.system,
                  onTap: () {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(AppThemeMode.system);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Dil Seçimi
            _SettingsSection(
              title: l10n.language,
              children: [
                _LocaleOption(
                  flag: '🇹🇷',
                  title: l10n.turkish,
                  isSelected: locale.languageCode == 'tr',
                  onTap: () {
                    ref
                        .read(localeProvider.notifier)
                        .setAppLocale(AppLocale.tr);
                  },
                ),
                _LocaleOption(
                  flag: '🇬🇧',
                  title: l10n.english,
                  isSelected: locale.languageCode == 'en',
                  onTap: () {
                    ref
                        .read(localeProvider.notifier)
                        .setAppLocale(AppLocale.en);
                  },
                ),
                _LocaleOption(
                  flag: '🇪🇸',
                  title: l10n.spanish,
                  isSelected: locale.languageCode == 'es',
                  onTap: () {
                    ref
                        .read(localeProvider.notifier)
                        .setAppLocale(AppLocale.es);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Premium Section - Dil seçiminin altında
            _PremiumSection(),
            const SizedBox(height: 32),
            // Version info
            Center(
              child: Text(
                'v1.0.0',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static void showPurchaseDialog(BuildContext context) {
    context.push('/paywall');
  }
}

class _PremiumSection extends ConsumerStatefulWidget {
  const _PremiumSection();

  @override
  ConsumerState<_PremiumSection> createState() => _PremiumSectionState();
}

class _PremiumSectionState extends ConsumerState<_PremiumSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isPremiumAsync = ref.watch(isPremiumProvider);

    return isPremiumAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (isPremium) {
        // Premium kullanıcı için modern bilgi kartı
        if (isPremium) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer.withOpacity(0.6),
                  theme.colorScheme.primaryContainer.withOpacity(0.8),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.25),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Icon + Title + Badge
                Row(
                  children: [
                    // Premium Icon Container with glow
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.onPrimaryContainer.withOpacity(0.2),
                            theme.colorScheme.onPrimaryContainer.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.onPrimaryContainer.withOpacity(0.3),
                          width: 1.5,
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
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        size: 32,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title and Badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.youArePremium,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    letterSpacing: -0.8,
                                    height: 1.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.green.shade400,
                                      Colors.green.shade600,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      l10n.active,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Description
                Text(
                  l10n.premiumAccessDescription,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    height: 1.6,
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                // Features row with improved design
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _PremiumFeatureChip(
                      icon: Icons.all_inclusive_rounded,
                      label: l10n.unlimited,
                      theme: theme,
                    ),
                    _PremiumFeatureChip(
                      icon: Icons.block_rounded,
                      label: l10n.adFree,
                      theme: theme,
                    ),
                    _PremiumFeatureChip(
                      icon: Icons.verified_rounded,
                      label: l10n.priority,
                      theme: theme,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // Premium olmayan kullanıcı için "Premium Ol" butonu
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.secondaryContainer,
                      theme.colorScheme.tertiaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(
                        _glowAnimation.value,
                      ),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => SettingsPage.showPurchaseDialog(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          // Animated Icon Container
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withOpacity(0.7),
                                  theme.colorScheme.secondary,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glow effect
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        theme.colorScheme.primary.withOpacity(
                                          _glowAnimation.value,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                // Icon
                                Icon(
                                  Icons.all_inclusive_rounded,
                                  color: theme.colorScheme.onPrimary,
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      l10n.goPremium,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22,
                                        color: theme.colorScheme.onSurface,
                                        letterSpacing: -0.8,
                                        height: 1.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            theme.colorScheme.primary,
                                            theme.colorScheme.secondary,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'PRO',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                          color: theme.colorScheme.onPrimary,
                                          letterSpacing: 1,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.premiumDescription,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface.withOpacity(
                                      0.75,
                                    ),
                                    height: 1.4,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                // Features preview
                                Row(
                                  children: [
                                    _FeatureBadge(
                                      icon: Icons.all_inclusive,
                                      theme: theme,
                                    ),
                                    const SizedBox(width: 8),
                                    _FeatureBadge(icon: Icons.block, theme: theme),
                                    const SizedBox(width: 8),
                                    _FeatureBadge(
                                      icon: Icons.verified,
                                      theme: theme,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Arrow with gradient
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({
    required this.icon,
    required this.theme,
  });

  final IconData icon;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        size: 16,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _PremiumFeatureChip extends StatelessWidget {
  const _PremiumFeatureChip({
    required this.icon,
    required this.label,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.onPrimaryContainer.withOpacity(0.18),
            theme.colorScheme.onPrimaryContainer.withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onPrimaryContainer.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: theme.colorScheme.onPrimaryContainer,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.08),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocaleOption extends StatelessWidget {
  const _LocaleOption({
    required this.flag,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String flag;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.08),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(flag, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../../l10n/app_localizations.dart';

import '../application/onboarding_controller.dart';
import '../../../app/theme/app_colors.dart';
import 'package:gallery_cleaner/src/core/utils/view_refresh_cubit.dart';
import '../../gallery/application/gallery_providers.dart' show PremiumCubit;

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with CubitStateMixin<OnboardingPage> {
  static const int _totalPages = 3;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    await context.read<OnboardingController>().completeOnboarding();
    if (mounted) {
      context.go('/permission');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return buildWithCubit(
      () => Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: SafeArea(
          child: Column(
            children: [
              // Skip button
              if (_currentPage < _totalPages - 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Builder(
                      builder: (ctx) {
                        final l10n = AppLocalizations.of(ctx)!;
                        return _ModernSkipButton(
                          onPressed: _completeOnboarding,
                          theme: theme,
                          l10n: l10n,
                        );
                      },
                    ),
                  ),
                ),

              // Page View
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    cubitSetState(() {
                      _currentPage = index;
                    });
                  },
                  children: const [
                    _OnboardingSlide1(),
                    _OnboardingSlide4(), // Blur tespit
                    _OnboardingSlide5(), // Duplicate tespit
                  ],
                ),
              ),

              // Page Indicators
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalPages, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentPage == index
                            ? (() {
                                final isPremiumAsync = context
                                    .watch<PremiumCubit>()
                                    .state;
                                final isPremium = isPremiumAsync.maybeWhen(
                                  data: (premium) => premium,
                                  orElse: () => false,
                                );
                                return isPremium
                                    ? theme.colorScheme.primary.withOpacity(0.9)
                                    : theme.colorScheme.onPrimaryContainer
                                          .withOpacity(0.8);
                              })()
                            : theme.colorScheme.primary.withOpacity(0.3),
                      ),
                    );
                  }),
                ),
              ),

              // Next/Start button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Builder(
                  builder: (ctx) {
                    final l10n = AppLocalizations.of(ctx)!;
                    return _ModernActionButton(
                      onPressed: _nextPage,
                      isLastPage: _currentPage == _totalPages - 1,
                      theme: theme,
                      l10n: l10n,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide1 extends StatelessWidget {
  const _OnboardingSlide1();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Swipe animation placeholder
          Container(
            width: 200,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.primaryContainer,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Photo card
                Container(
                  width: 180,
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Builder(
                    builder: (iconContext) {
                      final isPremiumAsync = iconContext
                          .watch<PremiumCubit>()
                          .state;
                      final isPremium = isPremiumAsync.maybeWhen(
                        data: (premium) => premium,
                        orElse: () => false,
                      );
                      final containerColor = theme
                          .colorScheme
                          .onPrimaryContainer
                          .withOpacity(0.8);
                      return Icon(Icons.photo, size: 80, color: containerColor);
                    },
                  ),
                ),
                // Swipe indicators
                Positioned(
                  left: -30,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.white,
                      size: 24,
                    ),
                  ),
                ),
                Positioned(
                  right: -30,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppColors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return Text(
                l10n.swipeLeftToDeleteTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return Text(
                l10n.swipeLeftToDeleteDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModernSkipButton extends StatelessWidget {
  const _ModernSkipButton({
    required this.onPressed,
    required this.theme,
    required this.l10n,
  });

  final VoidCallback onPressed;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final brightness = theme.brightness;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card(brightness).withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow(brightness),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: AppColors.textSecondary(brightness),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.skip,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Blur tespit sayfası
class _OnboardingSlide4 extends StatelessWidget {
  const _OnboardingSlide4();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Blur detection illustration
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.errorContainer.withOpacity(0.3),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Blurred photo example
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Blurred background
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              (() {
                                final isPremiumAsync = context
                                    .watch<PremiumCubit>()
                                    .state;
                                final isPremium = isPremiumAsync.maybeWhen(
                                  data: (premium) => premium,
                                  orElse: () => false,
                                );
                                final containerColor = theme
                                    .colorScheme
                                    .onPrimaryContainer
                                    .withOpacity(0.8);
                                return containerColor.withOpacity(0.3);
                              })(),
                              theme.colorScheme.secondary.withOpacity(0.2),
                            ],
                          ),
                        ),
                      ),
                      // Blur icon
                      Icon(
                        Icons.blur_on,
                        size: 60,
                        color: theme.colorScheme.error,
                      ),
                      // Warning badge
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning,
                            color: AppColors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return Text(
                l10n.blurDetectionOnboardingTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return Text(
                l10n.blurDetectionOnboardingDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Duplicate tespit sayfası
class _OnboardingSlide5 extends StatelessWidget {
  const _OnboardingSlide5();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Duplicate detection illustration
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Duplicate photos stack
                Positioned(
                  left: 30,
                  top: 40,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(2, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.photo,
                      size: 50,
                      color: (() {
                        final isPremiumAsync = context
                            .watch<PremiumCubit>()
                            .state;
                        final isPremium = isPremiumAsync.maybeWhen(
                          data: (premium) => premium,
                          orElse: () => false,
                        );
                        final containerColor = theme
                            .colorScheme
                            .onPrimaryContainer
                            .withOpacity(0.8);
                        return containerColor.withOpacity(0.6);
                      })(),
                    ),
                  ),
                ),
                Positioned(
                  left: 50,
                  top: 60,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.colorScheme.tertiary,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(2, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.photo,
                      size: 50,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
                // Link icon
                Positioned(
                  right: 20,
                  top: 80,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.link,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
                // Count badge
                Positioned(
                  bottom: 20,
                  right: 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.copy,
                          color: AppColors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '2x',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return Text(
                l10n.duplicateDetectionOnboardingTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx)!;
              return Text(
                l10n.duplicateDetectionOnboardingDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModernActionButton extends StatelessWidget {
  const _ModernActionButton({
    required this.onPressed,
    required this.isLastPage,
    required this.theme,
    required this.l10n,
  });

  final VoidCallback onPressed;
  final bool isLastPage;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        final isPremiumAsync = buttonContext.watch<PremiumCubit>().state;
        final isPremium = isPremiumAsync.maybeWhen(
          data: (premium) => premium,
          orElse: () => false,
        );
        final containerColor = theme.colorScheme.onPrimaryContainer.withOpacity(
          0.8,
        );

        return SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: containerColor,
              foregroundColor: AppColors.white,
              side: BorderSide(color: containerColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              isLastPage ? l10n.startButton : l10n.continueButton,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

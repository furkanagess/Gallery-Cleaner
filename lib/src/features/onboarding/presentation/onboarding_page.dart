import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../../../l10n/app_localizations.dart';

import '../application/onboarding_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_three_d_button.dart';
import 'package:gallery_cleaner/src/core/utils/view_refresh_cubit.dart';
import '../../gallery/application/gallery_providers.dart' show PremiumCubit;

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with CubitStateMixin<OnboardingPage> {
  static const int _totalPages = 4;
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
    final isLight = theme.brightness == Brightness.light;
    // Splash ekranındaki ren geyiği Lottie tint'i ile aynı mantığı kullan
    final snowTintColor = isLight
        ? theme.colorScheme.primary.withOpacity(0.9)
        : Colors.white;

    return buildWithCubit(
      () => Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: Stack(
          children: [
            // Snowing animation background - tint splash ekranındaki ren geyiği ile aynı
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.4,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      snowTintColor,
                      BlendMode.srcATop,
                    ),
                    child: Lottie.asset(
                      'assets/new_year/Snowing.json',
                      fit: BoxFit.cover,
                      repeat: true,
                      animate: true,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Skip button (aligned top-right with padding)
                  if (_currentPage < _totalPages - 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: AppThreeDButton(
                          label: AppLocalizations.of(context)!.skip,
                          onPressed: _completeOnboarding,
                          baseColor: theme.colorScheme.onPrimaryContainer
                              .withOpacity(0.9),
                          textColor: theme.colorScheme.background,
                          fullWidth: false,
                          height: 36,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          fontWeight: FontWeight.w700,
                          centerText: true,
                          fontSize: 13,
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
                      children: [
                        _OnboardingSlide1(isActive: _currentPage == 0),
                        _OnboardingSlide4(
                          isActive: _currentPage == 1,
                        ), // Blur tespit
                        _OnboardingSlide5(
                          isActive: _currentPage == 2,
                        ), // Duplicate tespit
                        _OnboardingSlide6(
                          isActive: _currentPage == 3,
                        ), // Storage cleanup
                      ],
                    ),
                  ),

                  // Page Indicators
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 16),
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
                                        ? theme.colorScheme.primary.withOpacity(
                                            0.9,
                                          )
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
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Builder(
                      builder: (ctx) {
                        final l10n = AppLocalizations.of(ctx)!;
                        final isLast = _currentPage == _totalPages - 1;
                        final isPremiumAsync = ctx.watch<PremiumCubit>().state;
                        final isPremium = isPremiumAsync.maybeWhen(
                          data: (premium) => premium,
                          orElse: () => false,
                        );
                        final baseColor = isPremium
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onPrimaryContainer.withOpacity(
                                0.92,
                              );
                        return AppThreeDButton(
                          label: isLast
                              ? l10n.startButton
                              : l10n.continueButton,
                          onPressed: _nextPage,
                          baseColor: baseColor,
                          textColor: theme.colorScheme.background,
                          fullWidth: true,
                          height: 56,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide1 extends StatefulWidget {
  const _OnboardingSlide1({required this.isActive});

  final bool isActive;

  @override
  State<_OnboardingSlide1> createState() => _OnboardingSlide1State();
}

class _OnboardingSlide1State extends State<_OnboardingSlide1>
    with TickerProviderStateMixin {
  late AnimationController _swipeController;
  late AnimationController _cardController;
  late AnimationController _fadeController;
  late Animation<double> _swipeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _fadeInAnimation;
  bool _isSwipingLeft = false;
  bool _isSwipingRight = false;
  int _currentForegroundIndex = 0; // 0 = example2, 1 = example3

  final String _backgroundImage = 'assets/image/example1.jpeg';
  final List<String> _foregroundImages = [
    'assets/image/example2.jpeg',
    'assets/image/example3.jpeg',
  ];
  bool _loopStarted = false;

  @override
  void initState() {
    super.initState();

    // Swipe animation controller
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Card transition controller
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Fade in controller for smooth transitions
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Swipe animation (translation)
    _swipeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeInOutCubic),
    );

    // Rotation animation
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.2).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeInOutCubic),
    );

    // Opacity animation (fade out during swipe - starts later for smoother transition)
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _swipeController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    // Fade in animation for new card
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Start animation loop
    if (widget.isActive) {
      _startAnimationLoop();
    }
  }

  @override
  void didUpdateWidget(covariant _OnboardingSlide1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _resetStateForActivation();
      _startAnimationLoop();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopAllAnimations();
    }
  }

  void _startAnimationLoop() {
    if (_loopStarted || !widget.isActive) return;
    _loopStarted = true;
    // Start with fade in animation
    _fadeController.forward().then((_) {
      if (mounted && widget.isActive) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted && widget.isActive) {
            // Start with example2 swiping right
            _currentForegroundIndex = 0;
            _swipeRight();
          }
        });
      }
    });
  }

  void _swipeRight() {
    if (!mounted) return;
    setState(() {
      _isSwipingRight = true;
      _isSwipingLeft = false;
    });

    _swipeController.forward().then((_) {
      if (mounted) {
        _resetAndContinue();
      }
    });
  }

  void _swipeLeft() {
    if (!mounted) return;
    setState(() {
      _isSwipingLeft = true;
      _isSwipingRight = false;
    });

    _swipeController.forward().then((_) {
      if (mounted) {
        _resetAndContinue();
      }
    });
  }

  void _resetAndContinue() {
    // Reset swipe state immediately
    setState(() {
      _isSwipingLeft = false;
      _isSwipingRight = false;
    });

    // Reset controllers smoothly
    _swipeController.reset();
    _cardController.reset();
    _fadeController.reset();

    // Switch to next image
    if (_currentForegroundIndex == 0) {
      // After example2 swipes right, show example3 and swipe left
      setState(() {
        _currentForegroundIndex = 1;
      });
    } else {
      // After example3 swipes left, show example2 and swipe right
      setState(() {
        _currentForegroundIndex = 0;
      });
    }

    // Fade in new image smoothly, then start next swipe
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && widget.isActive) {
        _fadeController.forward().then((_) {
          if (mounted && widget.isActive) {
            // Wait a bit before starting next swipe animation for smooth transition
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted && widget.isActive) {
                if (_currentForegroundIndex == 0) {
                  _swipeRight();
                } else {
                  _swipeLeft();
                }
              }
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _cardController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _stopAllAnimations() {
    _swipeController.stop();
    _cardController.stop();
    _fadeController.stop();
    _swipeController.reset();
    _cardController.reset();
    _fadeController.reset();
    _isSwipingLeft = false;
    _isSwipingRight = false;
    _loopStarted = false;
  }

  void _resetStateForActivation() {
    _isSwipingLeft = false;
    _isSwipingRight = false;
    _currentForegroundIndex = 0;
    _swipeController.reset();
    _cardController.reset();
    _fadeController.reset();
    _loopStarted = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Phone mockup frame with animated swipe demonstration
          Container(
            width: 240,
            height: 480,
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                width: 6,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 3,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: theme.colorScheme.background,
                child: Stack(
                  children: [
                    // Phone notch
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 90,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Screen content area
                    Positioned.fill(
                      top: 24,
                      bottom: 0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background image (fixed)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  _backgroundImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: theme.colorScheme.surface,
                                      child: Icon(
                                        Icons.photo,
                                        size: 80,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withOpacity(0.8),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // Foreground animated card
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                _swipeController,
                                _fadeController,
                              ]),
                              builder: (context, child) {
                                final swipeValue = _swipeAnimation.value;
                                final rotation = _rotationAnimation.value;
                                final swipeOpacity = _opacityAnimation.value;
                                final fadeIn = _fadeInAnimation.value;

                                // Combine fade in with swipe opacity for smooth transitions
                                final finalOpacity = fadeIn * swipeOpacity;

                                double translateX = 0;
                                double rotateZ = 0;

                                if (_isSwipingRight) {
                                  translateX = swipeValue * 400;
                                  rotateZ = rotation;
                                } else if (_isSwipingLeft) {
                                  translateX = -swipeValue * 400;
                                  rotateZ = -rotation;
                                }

                                return Positioned.fill(
                                  child: Transform.translate(
                                    offset: Offset(translateX, 0),
                                    child: Transform.rotate(
                                      angle: rotateZ,
                                      child: Opacity(
                                        opacity: finalOpacity,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.asset(
                                            _foregroundImages[_currentForegroundIndex],
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    color: theme
                                                        .colorScheme
                                                        .surface,
                                                    child: Icon(
                                                      Icons.photo,
                                                      size: 80,
                                                      color: theme
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                          .withOpacity(0.8),
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Swipe indicators (inside phone frame)
                            Positioned(
                              left: 12,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: AnimatedOpacity(
                                  opacity: _isSwipingLeft ? 1.0 : 0.4,
                                  duration: const Duration(milliseconds: 200),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.9),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.error.withOpacity(
                                            0.6,
                                          ),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: AppColors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 12,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: AnimatedOpacity(
                                  opacity: _isSwipingRight ? 1.0 : 0.4,
                                  duration: const Duration(milliseconds: 200),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.9),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.success.withOpacity(
                                            0.6,
                                          ),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: AppColors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom notch
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 90,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
        ],
      ),
    );
  }
}

// Blur tespit sayfası
class _OnboardingSlide4 extends StatefulWidget {
  const _OnboardingSlide4({required this.isActive});

  final bool isActive;

  @override
  State<_OnboardingSlide4> createState() => _OnboardingSlide4State();
}

class _OnboardingSlide4State extends State<_OnboardingSlide4>
    with TickerProviderStateMixin {
  late AnimationController _detectionController;
  late AnimationController _deleteController;
  late AnimationController _fadeInController;
  late AnimationController _storageMessageController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _storageMessageAnimation;
  late Animation<double> _translateYAnimation;
  bool _isDeleting = false;
  bool _showStorageMessage = false;
  bool _showRedOverlay = false;
  bool _showConfetti = false;
  int _deletedCount = 0;
  bool _loopStarted = false;

  final List<String> _blurImages = [
    'assets/image/blur1.jpeg',
    'assets/image/blur2.jpeg',
    'assets/image/blur3.jpeg',
    'assets/image/blur4.jpeg',
    'assets/image/blur6.jpeg',
  ];

  @override
  void initState() {
    super.initState();

    // Detection pulse animation controller
    _detectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Delete animation controller
    _deleteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Fade in controller for images
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Storage message animation controller
    _storageMessageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Pulse animation for blur detection
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _detectionController, curve: Curves.easeInOut),
    );

    // Scale and fade animation for deletion
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _deleteController, curve: Curves.easeInOut),
    );

    // Opacity animation for deletion
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _deleteController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    // Rotation animation for deletion
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _deleteController, curve: Curves.easeInOut),
    );

    // Fade in animation for images
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeOut),
    );

    // Storage message animation
    _storageMessageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _storageMessageController,
        curve: Curves.easeOutBack,
      ),
    );

    // Translate Y animation for moving to delete button
    _translateYAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _deleteController, curve: Curves.easeInOut),
    );

    // Start animation loop
    if (widget.isActive) {
      _startAnimationLoop();
      _detectionController.repeat(reverse: true);
    }
  }

  void _startAnimationLoop() {
    // Start with fade in for all images
    if (_loopStarted || !widget.isActive) return;
    _loopStarted = true;
    _fadeInController.forward().then((_) {
      if (mounted && widget.isActive) {
        // Wait a bit, then show red overlay
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && widget.isActive) {
            setState(() {
              _showRedOverlay = true;
            });
            // Wait a bit more, then start deletion
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && widget.isActive) {
                _deleteAllImages();
              }
            });
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _OnboardingSlide4 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _resetStateForActivation();
      _detectionController.repeat(reverse: true);
      _startAnimationLoop();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopAllAnimations();
    }
  }

  void _deleteAllImages() {
    if (!mounted || !widget.isActive) return;
    setState(() {
      _isDeleting = true;
    });

    _deleteController.forward().then((_) {
      if (mounted && widget.isActive) {
        setState(() {
          _deletedCount = 12; // 12 photos deleted (3x4 grid)
          _isDeleting = false;
          _showRedOverlay = false;
        });
        _deleteController.reset();
        _fadeInController.reset();

        // Show storage saved message
        _showStorageSavedMessage();
      }
    });
  }

  void _showStorageSavedMessage() {
    if (!mounted || !widget.isActive) return;
    setState(() {
      _showStorageMessage = true;
    });
    _storageMessageController.forward().then((_) {
      if (mounted && widget.isActive) {
        // Start confetti animation when storage message animation completes
        setState(() {
          _showConfetti = true;
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && widget.isActive) {
            _storageMessageController.reverse().then((_) {
              if (mounted && widget.isActive) {
                setState(() {
                  _showStorageMessage = false;
                  _showConfetti = false; // Hide confetti when restarting
                });
                // Restart animation loop
                _loopStarted = false;
                _startAnimationLoop();
              }
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _detectionController.dispose();
    _deleteController.dispose();
    _fadeInController.dispose();
    _storageMessageController.dispose();
    super.dispose();
  }

  void _stopAllAnimations() {
    _detectionController.stop();
    _deleteController.stop();
    _fadeInController.stop();
    _storageMessageController.stop();
    _deleteController.reset();
    _fadeInController.reset();
    _storageMessageController.reset();
    _showRedOverlay = false;
    _isDeleting = false;
    _showStorageMessage = false;
    _showConfetti = false;
    _loopStarted = false;
  }

  void _resetStateForActivation() {
    _stopAllAnimations();
    _deletedCount = 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Phone mockup frame with blur detection and deletion animation
          Container(
            width: 240,
            height: 480,
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                width: 6,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 3,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: theme.colorScheme.background,
                child: Stack(
                  children: [
                    // Phone notch
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 90,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Screen content area
                    Positioned.fill(
                      top: 24,
                      bottom: 0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 2x2 Grid of blurred photos
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                _detectionController,
                                _deleteController,
                                _fadeInController,
                              ]),
                              builder: (context, child) {
                                final pulse = _pulseAnimation.value;
                                final scale = _scaleAnimation.value;
                                final opacity = _opacityAnimation.value;
                                final rotation = _rotationAnimation.value;
                                final fadeIn = _fadeInAnimation.value;

                                final finalOpacity = _isDeleting
                                    ? opacity.clamp(0.0, 1.0)
                                    : fadeIn.clamp(0.0, 1.0);

                                return Opacity(
                                  opacity: finalOpacity,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: SizedBox(
                                      height: 420,
                                      child: ClipRect(
                                        clipBehavior: Clip.antiAlias,
                                        child: GridView.builder(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          padding: EdgeInsets.zero,
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 3,
                                                crossAxisSpacing: 3,
                                                mainAxisSpacing: 3,
                                                childAspectRatio: 0.7,
                                              ),
                                          itemCount: 12, // 3x4 grid
                                          itemBuilder: (context, index) {
                                            final imageIndex =
                                                index % _blurImages.length;
                                            final translateY = _isDeleting
                                                ? _translateYAnimation.value *
                                                      300
                                                : 0.0;

                                            return Transform.translate(
                                              offset: Offset(0, translateY),
                                              child: Transform.scale(
                                                scale: _isDeleting
                                                    ? scale.clamp(0.0, 1.0)
                                                    : pulse.clamp(0.95, 1.05),
                                                child: Transform.rotate(
                                                  angle: _isDeleting
                                                      ? rotation.clamp(0.0, 0.5)
                                                      : 0,
                                                  child: Opacity(
                                                    opacity: _isDeleting
                                                        ? (1.0 -
                                                                  _translateYAnimation
                                                                      .value)
                                                              .clamp(0.0, 1.0)
                                                        : 1.0,
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      clipBehavior:
                                                          Clip.antiAlias,
                                                      child: Stack(
                                                        clipBehavior:
                                                            Clip.antiAlias,
                                                        children: [
                                                          // Blurred image
                                                          Image.asset(
                                                            _blurImages[imageIndex],
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) {
                                                                  return Container(
                                                                    color: theme
                                                                        .colorScheme
                                                                        .surface,
                                                                    child: Icon(
                                                                      Icons
                                                                          .photo,
                                                                      size: 40,
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onPrimaryContainer
                                                                          .withOpacity(
                                                                            0.8,
                                                                          ),
                                                                    ),
                                                                  );
                                                                },
                                                          ),
                                                          // Blur overlay effect (only when red overlay is shown)
                                                          if (_showRedOverlay)
                                                            Container(
                                                              decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                gradient: LinearGradient(
                                                                  begin: Alignment
                                                                      .topLeft,
                                                                  end: Alignment
                                                                      .bottomRight,
                                                                  colors: [
                                                                    theme
                                                                        .colorScheme
                                                                        .error
                                                                        .withOpacity(
                                                                          0.4,
                                                                        ),
                                                                    theme
                                                                        .colorScheme
                                                                        .error
                                                                        .withOpacity(
                                                                          0.1,
                                                                        ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          // Blur detection pulse ring (only when red overlay is shown)
                                                          if (!_isDeleting &&
                                                              _showRedOverlay)
                                                            Center(
                                                              child: Container(
                                                                width:
                                                                    25 * pulse,
                                                                height:
                                                                    25 * pulse,
                                                                decoration: BoxDecoration(
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  border: Border.all(
                                                                    color: theme
                                                                        .colorScheme
                                                                        .error
                                                                        .withOpacity(
                                                                          0.6 /
                                                                              pulse,
                                                                        ),
                                                                    width: 1.5,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          // Blur icon (only when red overlay is shown)
                                                          if (_showRedOverlay)
                                                            Center(
                                                              child: Icon(
                                                                Icons.blur_on,
                                                                size: 20,
                                                                color: theme
                                                                    .colorScheme
                                                                    .error,
                                                              ),
                                                            ),
                                                          // Warning badge (only when red overlay is shown)
                                                          if (_showRedOverlay)
                                                            Positioned(
                                                              top: 4,
                                                              right: 4,
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      3,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: theme
                                                                      .colorScheme
                                                                      .error,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .error
                                                                          .withOpacity(
                                                                            0.5,
                                                                          ),
                                                                      blurRadius:
                                                                          4,
                                                                      spreadRadius:
                                                                          1,
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: const Icon(
                                                                  Icons.warning,
                                                                  color:
                                                                      AppColors
                                                                          .white,
                                                                  size: 10,
                                                                ),
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
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom delete button (shown when deleting)
                    if (_isDeleting)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _deleteController,
                            builder: (context, child) {
                              final deleteProgress = _deleteController.value;
                              return Transform.scale(
                                scale: 0.8 + (deleteProgress * 0.2),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.error.withOpacity(0.6),
                                        blurRadius: 20,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: AppColors.white,
                                    size: 28,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      // Bottom notch (when not deleting)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.black,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 90,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppColors.black,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Confetti animation
                    if (_showConfetti)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Lottie.asset(
                            'assets/lottie/Confeti.json',
                            fit: BoxFit.cover,
                            repeat: false,
                          ),
                        ),
                      ),
                    // Storage saved message
                    if (_showStorageMessage)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _storageMessageController,
                              builder: (context, child) {
                                final scale = _storageMessageAnimation.value
                                    .clamp(0.0, 1.0);
                                final opacity = _storageMessageAnimation.value
                                    .clamp(0.0, 1.0);

                                return Transform.scale(
                                  scale: scale,
                                  child: Opacity(
                                    opacity: opacity,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withOpacity(
                                          0.95,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.success
                                                .withOpacity(0.45),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: AppColors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Builder(
                                                builder: (ctx) {
                                                  final l10n =
                                                      AppLocalizations.of(ctx)!;
                                                  final mbValue =
                                                      (_deletedCount * 2.5)
                                                          .toStringAsFixed(1);
                                                  return Text(
                                                    l10n.mbFreed(mbValue),
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          color:
                                                              AppColors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                  );
                                                },
                                              ),
                                              Builder(
                                                builder: (ctx) {
                                                  final l10n =
                                                      AppLocalizations.of(ctx)!;
                                                  return Text(
                                                    l10n.spaceSaved,
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color:
                                                              AppColors.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 12,
                                                        ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
        ],
      ),
    );
  }
}

// Duplicate tespit sayfası
class _OnboardingSlide5 extends StatefulWidget {
  const _OnboardingSlide5({required this.isActive});

  final bool isActive;

  @override
  State<_OnboardingSlide5> createState() => _OnboardingSlide5State();
}

class _OnboardingSlide5State extends State<_OnboardingSlide5>
    with TickerProviderStateMixin {
  late AnimationController _collapseController;
  late Animation<double> _progress;
  late Animation<double> _fadeMerged;
  late AnimationController _savedController;
  late Animation<double> _savedAnimation;
  bool _loopStarted = false;
  bool _showSaved = false;
  bool _showConfetti = false;
  int _deletedCount = 0;

  final List<String> _duplicateImages = [
    'assets/image/duplicate1.jpeg',
    'assets/image/duplicate2.jpeg',
  ];

  @override
  void initState() {
    super.initState();
    _collapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progress = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOut,
    );
    _fadeMerged = CurvedAnimation(
      parent: _collapseController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );
    _savedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _savedAnimation = CurvedAnimation(
      parent: _savedController,
      curve: Curves.easeOutBack,
    );

    if (widget.isActive) {
      _startLoop();
    }
  }

  @override
  void didUpdateWidget(covariant _OnboardingSlide5 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _resetAndStart();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopAnimations();
    }
  }

  void _startLoop() {
    if (_loopStarted || !widget.isActive) return;
    _loopStarted = true;
    _collapseController.forward().then((_) {
      if (!mounted || !widget.isActive) return;
      _showSavedMessage();
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted || !widget.isActive) return;
        _resetAndStart();
      });
    });
  }

  void _resetAndStart() {
    _stopAnimations(resetOnly: true);
    _loopStarted = false;
    _startLoop();
  }

  void _stopAnimations({bool resetOnly = false}) {
    _collapseController.stop();
    _savedController.stop();
    if (resetOnly) {
      _collapseController.reset();
      _savedController.reset();
    } else {
      _collapseController.reset();
      _savedController.reset();
      _loopStarted = false;
      _showSaved = false;
      _showConfetti = false;
    }
  }

  @override
  void dispose() {
    _collapseController.dispose();
    _savedController.dispose();
    super.dispose();
  }

  void _showSavedMessage() {
    if (!mounted || !widget.isActive) return;
    setState(() {
      _showSaved = true;
      _deletedCount = 8; // 8 duplicates merged (4 per image, 2 images)
    });
    _savedController.forward().then((_) {
      if (!mounted || !widget.isActive) return;
      // Show confetti when saved message animation completes
      setState(() {
        _showConfetti = true;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted || !widget.isActive) return;
        _savedController.reverse().then((_) {
          if (mounted && widget.isActive) {
            setState(() {
              _showSaved = false;
              _showConfetti = false; // Hide confetti when restarting
            });
          }
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Phone mockup frame with duplicate merge animation
          Container(
            width: 240,
            height: 480,
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                width: 6,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 3,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: theme.colorScheme.background,
                child: Stack(
                  children: [
                    // Phone notch
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 90,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Screen content area
                    Positioned.fill(
                      top: 24,
                      bottom: 0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: AnimatedBuilder(
                          animation: _collapseController,
                          builder: (context, child) {
                            final p = _progress.value; // 0->scatter,1->merge

                            Widget buildGroup({
                              required String image,
                              required Offset baseOffset,
                            }) {
                              final offsets = [
                                const Offset(-40, -40),
                                const Offset(40, -32),
                                const Offset(-30, 32),
                                const Offset(36, 40),
                              ];

                              Widget buildThumb(int i) {
                                final offset =
                                    (offsets[i] * (1 - p)) + baseOffset;
                                final scale = 1 - (0.25 * p);
                                final opacity = (1 - p).clamp(0.0, 1.0);
                                return Transform.translate(
                                  offset: offset,
                                  child: Transform.scale(
                                    scale: scale,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.asset(
                                          image,
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  for (int i = 0; i < 4; i++) buildThumb(i),
                                  Opacity(
                                    opacity: _fadeMerged.value,
                                    child: Transform.translate(
                                      offset:
                                          baseOffset +
                                          (baseOffset.dy < 0
                                              ? const Offset(-40, -20)
                                              : const Offset(40, 20)),
                                      child: Transform.scale(
                                        scale: 0.8 + 0.2 * _fadeMerged.value,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Image.asset(
                                            image,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                buildGroup(
                                  image: _duplicateImages[0],
                                  baseOffset: const Offset(0, -50),
                                ),
                                buildGroup(
                                  image: _duplicateImages[1],
                                  baseOffset: const Offset(0, 70),
                                ),
                                // Confetti animation
                                if (_showConfetti)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Lottie.asset(
                                        'assets/lottie/Confeti.json',
                                        fit: BoxFit.cover,
                                        repeat: false,
                                      ),
                                    ),
                                  ),
                                if (_showSaved)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Center(
                                        child: AnimatedBuilder(
                                          animation: _savedController,
                                          builder: (context, child) {
                                            final scale = _savedAnimation.value
                                                .clamp(0.0, 1.0);
                                            final opacity = _savedAnimation
                                                .value
                                                .clamp(0.0, 1.0);
                                            return Transform.scale(
                                              scale: scale,
                                              child: Opacity(
                                                opacity: opacity,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 10,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.success
                                                        .withOpacity(0.95),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppColors.success
                                                            .withOpacity(0.45),
                                                        blurRadius: 12,
                                                        spreadRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.check_circle,
                                                        color: AppColors.white,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Builder(
                                                            builder: (ctx) {
                                                              final l10n =
                                                                  AppLocalizations.of(
                                                                    ctx,
                                                                  )!;
                                                              final mbValue =
                                                                  (_deletedCount *
                                                                          2.5)
                                                                      .toStringAsFixed(
                                                                        1,
                                                                      );
                                                              return Text(
                                                                l10n.mbFreed(
                                                                  mbValue,
                                                                ),
                                                                style: theme
                                                                    .textTheme
                                                                    .titleSmall
                                                                    ?.copyWith(
                                                                      color: AppColors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                              );
                                                            },
                                                          ),
                                                          Builder(
                                                            builder: (ctx) {
                                                              final l10n =
                                                                  AppLocalizations.of(
                                                                    ctx,
                                                                  )!;
                                                              return Text(
                                                                l10n.spaceSaved,
                                                                style: theme
                                                                    .textTheme
                                                                    .labelSmall
                                                                    ?.copyWith(
                                                                      color: AppColors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                // Bottom notch
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.black,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 90,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: AppColors.black,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
        ],
      ),
    );
  }
}

// Storage cleanup onboarding slide
class _OnboardingSlide6 extends StatefulWidget {
  const _OnboardingSlide6({required this.isActive});

  final bool isActive;

  @override
  State<_OnboardingSlide6> createState() => _OnboardingSlide6State();
}

class _OnboardingSlide6State extends State<_OnboardingSlide6>
    with TickerProviderStateMixin {
  late AnimationController _storageController;
  late AnimationController _cleanupController;
  late AnimationController _detectionController;
  late AnimationController _deleteController;
  late AnimationController _fadeInController;
  late Animation<double> _storageFillAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _translateYAnimation;
  late Animation<double> _cardPositionAnimation;
  late AnimationController _savedController;
  late Animation<double> _savedAnimation;
  bool _loopStarted = false;
  bool _isDeleting = false;
  bool _showRedOverlay = false;
  bool _showSaved = false;
  bool _showConfetti = false;
  int _deletedCount = 0;
  final List<String> _storageImages = const [
    'assets/image/blur1.jpeg',
    'assets/image/blur2.jpeg',
    'assets/image/blur3.jpeg',
    'assets/image/blur4.jpeg',
    'assets/image/duplicate1.jpeg',
    'assets/image/duplicate2.jpeg',
    'assets/image/example1.jpeg',
    'assets/image/example2.jpeg',
    'assets/image/example3.jpeg',
  ];

  @override
  void initState() {
    super.initState();
    _storageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _cleanupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _detectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _deleteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _storageFillAnimation = Tween<double>(begin: 0.75, end: 0.25).animate(
      CurvedAnimation(parent: _cleanupController, curve: Curves.easeInOut),
    );

    // Pulse animation for detection
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _detectionController, curve: Curves.easeInOut),
    );

    // Scale and fade animation for deletion
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _deleteController, curve: Curves.easeInOut),
    );

    // Opacity animation for deletion
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _deleteController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    // Rotation animation for deletion
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _deleteController, curve: Curves.easeInOut),
    );

    // Fade in animation for images
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeOut),
    );

    // Translate Y animation for moving to delete button
    _translateYAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _deleteController, curve: Curves.easeInOut),
    );

    // Card position animation (moves down after deletion)
    _cardPositionAnimation = Tween<double>(begin: 0.0, end: 90.0).animate(
      CurvedAnimation(parent: _cleanupController, curve: Curves.easeOut),
    );

    _savedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _savedAnimation = CurvedAnimation(
      parent: _savedController,
      curve: Curves.easeOutBack,
    );

    if (widget.isActive) {
      _startLoop();
    }
  }

  @override
  void didUpdateWidget(covariant _OnboardingSlide6 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _resetStateForActivation();
      _detectionController.repeat(reverse: true);
      _startLoop();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopAnimations();
    }
  }

  void _startLoop() {
    if (_loopStarted || !widget.isActive) return;
    _loopStarted = true;

    // Start with fade in for all images
    _fadeInController.forward().then((_) {
      if (mounted && widget.isActive) {
        // Start detection pulse
        _detectionController.repeat(reverse: true);
        // Wait a bit, then show red overlay
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && widget.isActive) {
            setState(() {
              _showRedOverlay = true;
            });
            // Wait a bit more, then start deletion
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && widget.isActive) {
                _deleteAllImages();
              }
            });
          }
        });
      }
    });
  }

  void _deleteAllImages() {
    if (!mounted || !widget.isActive) return;
    setState(() {
      _isDeleting = true;
      _detectionController.stop();
    });

    _deleteController.forward().then((_) {
      if (mounted && widget.isActive) {
        setState(() {
          _isDeleting = false;
          _showRedOverlay = false;
        });
        _deleteController.reset();
        _fadeInController.reset();
        // Start storage cleanup animation
        _cleanupController.forward().then((_) {
          if (!mounted || !widget.isActive) return;
          // Show saved message
          setState(() {
            _showSaved = true;
            _deletedCount = 9; // 9 photos deleted
          });
          _savedController.forward().then((_) {
            if (!mounted || !widget.isActive) return;
            // Show confetti when saved message animation completes
            setState(() {
              _showConfetti = true;
            });
            Future.delayed(const Duration(milliseconds: 800), () {
              if (!mounted || !widget.isActive) return;
              _savedController.reverse().then((_) {
                if (!mounted || !widget.isActive) return;
                setState(() {
                  _showSaved = false;
                  _showConfetti = false; // Hide confetti when restarting
                });
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (!mounted || !widget.isActive) return;
                  _resetAndStart();
                });
              });
            });
          });
        });
      }
    });
  }

  void _resetAndStart() {
    _resetStateForActivation();
    _startLoop();
  }

  void _resetStateForActivation() {
    _stopAnimations(resetOnly: true);
    _loopStarted = false;
    _isDeleting = false;
    _showRedOverlay = false;
    _showSaved = false;
    _showConfetti = false;
    _deletedCount = 0;
  }

  void _stopAnimations({bool resetOnly = false}) {
    _storageController.stop();
    _cleanupController.stop();
    _detectionController.stop();
    _deleteController.stop();
    _fadeInController.stop();
    _savedController.stop();
    if (resetOnly) {
      _storageController.reset();
      _cleanupController.reset();
      _deleteController.reset();
      _fadeInController.reset();
      _savedController.reset();
    } else {
      _storageController.reset();
      _cleanupController.reset();
      _deleteController.reset();
      _fadeInController.reset();
      _savedController.reset();
      _loopStarted = false;
      _isDeleting = false;
      _showRedOverlay = false;
      _showSaved = false;
      _deletedCount = 0;
    }
  }

  @override
  void dispose() {
    _storageController.dispose();
    _cleanupController.dispose();
    _detectionController.dispose();
    _deleteController.dispose();
    _fadeInController.dispose();
    _savedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Phone mockup frame with storage cleanup animation
          Container(
            width: 240,
            height: 480,
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                width: 6,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 3,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: theme.colorScheme.background,
                child: Stack(
                  children: [
                    // Phone notch
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 90,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Screen content area
                    Positioned.fill(
                      top: 24,
                      bottom: 0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _storageController,
                            _cleanupController,
                            _detectionController,
                            _deleteController,
                            _fadeInController,
                          ]),
                          builder: (context, child) {
                            final storageFill = _storageFillAnimation.value;
                            final pulse = _pulseAnimation.value;
                            final scale = _scaleAnimation.value;
                            final opacity = _opacityAnimation.value;
                            final rotation = _rotationAnimation.value;
                            final fadeIn = _fadeInAnimation.value;

                            // Calculate GB values
                            final usedGB = (256 * storageFill).round();

                            final finalOpacity = _isDeleting
                                ? opacity.clamp(0.0, 1.0)
                                : fadeIn.clamp(0.0, 1.0);

                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 40),
                                    // Storage container (smaller, like iOS Settings)
                                    Transform.translate(
                                      offset: Offset(
                                        0,
                                        _cardPositionAnimation.value,
                                      ),
                                      child: Container(
                                        width: 180,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Storage label and GB info in same row
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  l10n.storage,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: theme
                                                            .colorScheme
                                                            .background,
                                                        fontSize: 13,
                                                      ),
                                                ),
                                                Text(
                                                  '$usedGB GB',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .error,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 12,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            // Storage progress bar
                                            Container(
                                              width: double.infinity,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color:
                                                    theme.colorScheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                              child: Stack(
                                                children: [
                                                  // Used storage (always red, like before)
                                                  Container(
                                                    width: 180 * storageFill,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: theme
                                                          .colorScheme
                                                          .error,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            3,
                                                          ),
                                                    ),
                                                  ),
                                                  // Available storage (green)
                                                  Positioned(
                                                    right: 0,
                                                    child: Container(
                                                      width:
                                                          180 *
                                                          (1 - storageFill),
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            AppColors.success,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              3,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Photos grid (like blur onboarding)
                                    Opacity(
                                      opacity: finalOpacity,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: SizedBox(
                                          height: 280,
                                          child: ClipRect(
                                            clipBehavior: Clip.antiAlias,
                                            child: GridView.builder(
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              padding: EdgeInsets.zero,
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 3,
                                                    crossAxisSpacing: 3,
                                                    mainAxisSpacing: 3,
                                                    childAspectRatio: 0.75,
                                                  ),
                                              itemCount: 9,
                                              itemBuilder: (context, index) {
                                                final imageIndex =
                                                    index %
                                                    _storageImages.length;
                                                final translateY = _isDeleting
                                                    ? _translateYAnimation
                                                              .value *
                                                          200
                                                    : 0.0;

                                                return Transform.translate(
                                                  offset: Offset(0, translateY),
                                                  child: Transform.scale(
                                                    scale: _isDeleting
                                                        ? scale.clamp(0.0, 1.0)
                                                        : pulse.clamp(
                                                            0.95,
                                                            1.05,
                                                          ),
                                                    child: Transform.rotate(
                                                      angle: _isDeleting
                                                          ? rotation.clamp(
                                                              0.0,
                                                              0.5,
                                                            )
                                                          : 0,
                                                      child: Opacity(
                                                        opacity: _isDeleting
                                                            ? (1.0 -
                                                                      _translateYAnimation
                                                                          .value)
                                                                  .clamp(
                                                                    0.0,
                                                                    1.0,
                                                                  )
                                                            : 1.0,
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          clipBehavior:
                                                              Clip.antiAlias,
                                                          child: Stack(
                                                            clipBehavior:
                                                                Clip.antiAlias,
                                                            children: [
                                                              // Image
                                                              Image.asset(
                                                                _storageImages[imageIndex],
                                                                fit: BoxFit
                                                                    .cover,
                                                                errorBuilder:
                                                                    (
                                                                      context,
                                                                      error,
                                                                      stackTrace,
                                                                    ) {
                                                                      return Container(
                                                                        color: theme
                                                                            .colorScheme
                                                                            .surface,
                                                                        child: Icon(
                                                                          Icons
                                                                              .photo,
                                                                          size:
                                                                              30,
                                                                          color: theme
                                                                              .colorScheme
                                                                              .onPrimaryContainer
                                                                              .withOpacity(
                                                                                0.8,
                                                                              ),
                                                                        ),
                                                                      );
                                                                    },
                                                              ),
                                                              // Red overlay effect (only when red overlay is shown)
                                                              if (_showRedOverlay)
                                                                Container(
                                                                  decoration: BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                    gradient: LinearGradient(
                                                                      begin: Alignment
                                                                          .topLeft,
                                                                      end: Alignment
                                                                          .bottomRight,
                                                                      colors: [
                                                                        theme
                                                                            .colorScheme
                                                                            .error
                                                                            .withOpacity(
                                                                              0.4,
                                                                            ),
                                                                        theme
                                                                            .colorScheme
                                                                            .error
                                                                            .withOpacity(
                                                                              0.1,
                                                                            ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              // Detection pulse ring (only when red overlay is shown)
                                                              if (!_isDeleting &&
                                                                  _showRedOverlay)
                                                                Center(
                                                                  child: Container(
                                                                    width:
                                                                        20 *
                                                                        pulse,
                                                                    height:
                                                                        20 *
                                                                        pulse,
                                                                    decoration: BoxDecoration(
                                                                      shape: BoxShape
                                                                          .circle,
                                                                      border: Border.all(
                                                                        color: theme.colorScheme.error.withOpacity(
                                                                          (0.6 /
                                                                                  pulse.clamp(
                                                                                    0.95,
                                                                                    1.05,
                                                                                  ))
                                                                              .clamp(
                                                                                0.0,
                                                                                1.0,
                                                                              ),
                                                                        ),
                                                                        width:
                                                                            1.5,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              // Warning icon (only when red overlay is shown)
                                                              if (_showRedOverlay)
                                                                Center(
                                                                  child: Icon(
                                                                    Icons
                                                                        .warning,
                                                                    size: 16,
                                                                    color: theme
                                                                        .colorScheme
                                                                        .error,
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
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                                // Delete button at the bottom of the phone frame
                                if (_isDeleting)
                                  Positioned(
                                    bottom: 12,
                                    child: AnimatedBuilder(
                                      animation: _deleteController,
                                      builder: (context, child) {
                                        final deleteProgress =
                                            _deleteController.value;
                                        return Transform.scale(
                                          scale: (0.8 + (deleteProgress * 0.2))
                                              .clamp(0.0, 1.0),
                                          child: Opacity(
                                            opacity: (1.0 - deleteProgress)
                                                .clamp(0.0, 1.0),
                                            child: Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: AppColors.error
                                                    .withOpacity(0.9),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.error
                                                        .withOpacity(0.6),
                                                    blurRadius: 15,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.delete,
                                                color: AppColors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                else
                                  // Bottom notch (when not deleting)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AppColors.black,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          topRight: Radius.circular(16),
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 90,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: AppColors.black,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                // Confetti animation
                                if (_showConfetti)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Lottie.asset(
                                        'assets/lottie/Confeti.json',
                                        fit: BoxFit.cover,
                                        repeat: false,
                                      ),
                                    ),
                                  ),
                                // Success message (same style as duplicate)
                                if (_showSaved)
                                  Positioned(
                                    bottom: 80,
                                    left: 0,
                                    right: 0,
                                    child: IgnorePointer(
                                      child: Center(
                                        child: AnimatedBuilder(
                                          animation: _savedController,
                                          builder: (context, child) {
                                            final scale = _savedAnimation.value
                                                .clamp(0.0, 1.0);
                                            final opacity = _savedAnimation
                                                .value
                                                .clamp(0.0, 1.0);
                                            return Transform.scale(
                                              scale: scale,
                                              child: Opacity(
                                                opacity: opacity,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 10,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.success
                                                        .withOpacity(0.95),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppColors.success
                                                            .withOpacity(0.45),
                                                        blurRadius: 12,
                                                        spreadRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.check_circle,
                                                        color: AppColors.white,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Builder(
                                                            builder: (ctx) {
                                                              final l10n =
                                                                  AppLocalizations.of(
                                                                    ctx,
                                                                  )!;
                                                              final mbValue =
                                                                  (_deletedCount *
                                                                          2.5)
                                                                      .toStringAsFixed(
                                                                        1,
                                                                      );
                                                              return Text(
                                                                l10n.mbFreed(
                                                                  mbValue,
                                                                ),
                                                                style: theme
                                                                    .textTheme
                                                                    .titleSmall
                                                                    ?.copyWith(
                                                                      color: AppColors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                              );
                                                            },
                                                          ),
                                                          Builder(
                                                            builder: (ctx) {
                                                              final l10n =
                                                                  AppLocalizations.of(
                                                                    ctx,
                                                                  )!;
                                                              return Text(
                                                                l10n.spaceSaved,
                                                                style: theme
                                                                    .textTheme
                                                                    .labelSmall
                                                                    ?.copyWith(
                                                                      color: AppColors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                // Bottom notch
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.black,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 90,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: AppColors.black,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    // Bottom notch
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 90,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.freeUpStorageSpace,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

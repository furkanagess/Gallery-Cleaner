import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/preferences_service.dart';

/// New Year 2026 themed event card for 1000 Photos Delete Event
/// Displays above PhotoSwipeDeck in Swipe Tab
class NewYearEventCard extends StatefulWidget {
  const NewYearEventCard({
    super.key,
    this.onDismiss,
    this.onTap,
  });

  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  @override
  State<NewYearEventCard> createState() => _NewYearEventCardState();
}

class _NewYearEventCardState extends State<NewYearEventCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final PreferencesService _preferencesService = PreferencesService();
  int _currentDeleteCount = 0;
  static const int _initialTarget = 1000;
  static const int _levelIncrement = 500;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  Duration _timeRemaining = Duration.zero;
  
  // 1 Ocak 2026 00:00 hedef tarihi
  DateTime get _targetDate => DateTime(2026, 1, 1, 0, 0, 0);
  
  // Mevcut seviyenin başlangıç değerini hesapla
  int get _currentLevelStart {
    if (_currentDeleteCount < _initialTarget) {
      return 0;
    }
    // Her 500'de bir yeni seviye
    int level = ((_currentDeleteCount - _initialTarget) / _levelIncrement).floor();
    return _initialTarget + level * _levelIncrement;
  }
  
  // Mevcut seviyenin hedef değerini hesapla
  int get _currentLevelTarget {
    if (_currentDeleteCount < _initialTarget) {
      return _initialTarget;
    }
    return _currentLevelStart + _levelIncrement;
  }
  
  // Mevcut seviyedeki ilerleme
  int get _currentLevelProgress {
    return _currentDeleteCount - _currentLevelStart;
  }
  
  // Mevcut seviyedeki toplam hedef
  int get _currentLevelTotal {
    return _currentLevelTarget - _currentLevelStart;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
    _loadDeleteCount();
    _updateCountdown();
    // Periyodik olarak sayacı güncelle (her 2 saniyede bir)
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadDeleteCount();
    });
    // Geri sayımı her saniye güncelle
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }
  
  Future<void> _loadDeleteCount() async {
    final count = await _preferencesService.getNewYearEventDeleteCount();
    if (mounted) {
      setState(() {
        _currentDeleteCount = count;
      });
    }
  }
  
  void _updateCountdown() {
    final now = DateTime.now();
    if (now.isBefore(_targetDate)) {
      final difference = _targetDate.difference(now);
      if (mounted) {
        setState(() {
          _timeRemaining = difference;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _timeRemaining = Duration.zero;
        });
      }
    }
  }
  
  String _formatCountdown(Duration duration) {
    if (duration.inDays > 0) {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;
      return '${days}d ${hours}h ${minutes}m ${seconds}s';
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (duration.inMinutes > 0) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '${minutes}m ${seconds}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A5F), // Midnight blue
                AppColors.backgroundDark,
                const Color(0xFF5D9CEC).withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFBBF24).withOpacity(0.6), // Daha belirgin altın border
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFBBF24).withOpacity(0.4), // Daha belirgin altın glow
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.black.withOpacity(0.3),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Background decorative elements
                    Positioned.fill(
                      child: _buildBackgroundDecorations(),
                    ),
                    // Main content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: _buildEventTextSection(context, theme, isDark),
                    ),
                    // Geri sayım sağ üstte
                    if (_timeRemaining.inSeconds > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildCountdownWidget(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        // Kar yağışı animasyonu
        Positioned.fill(
          child: _buildSnowingAnimation(),
        ),
        // Çam ağacı görseli - sağ alt köşede
        Positioned(
          right: -20,
          bottom: -10,
          child: Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/new_year/christmas-tree.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
          ),
        ),
        // Sparkles
        ...List.generate(8, (index) {
          return Positioned(
            top: (index * 15.0) % 100,
            left: (index * 20.0) % 200,
            child: Opacity(
              opacity: 0.3,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24), // Gold
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFBBF24).withOpacity(0.8),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
  
  Widget _buildSnowingAnimation() {
    try {
      return Opacity(
        opacity: 0.6,
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Colors.white,
            BlendMode.srcATop,
          ),
          child: Lottie.asset(
            'assets/new_year/Snowing.json',
            fit: BoxFit.cover,
            repeat: true,
            animate: true,
          ),
        ),
      );
    } catch (e) {
      // Fallback if Lottie not available
      return const SizedBox.shrink();
    }
  }

  Widget _buildEventTextSection(BuildContext context, ThemeData theme, bool isDark) {
    final progress = (_currentLevelProgress / _currentLevelTotal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // "Happy New Year" başlığı
        Row(
          children: [
            Icon(
              Icons.celebration_rounded,
              size: 18,
              color: const Color(0xFFFBBF24),
            ),
            const SizedBox(width: 6),
            Text(
              'Happy New Year 2026',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFBBF24), // Gold
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: const Color(0xFFFBBF24).withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // "Delete X photos" text - dinamik hedef
        Text(
          'Delete $_currentLevelTotal photos',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        // Progress bar section
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFBBF24).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                // Progress fill - animasyonlu
                FractionallySizedBox(
                  widthFactor: progress,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFFBBF24), // Gold
                            Color(0xFFFFD700), // Bright gold
                            Color(0xFFFFE44D), // Lighter gold
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFBBF24).withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Progress text - bar'ın içinde ortada
                Center(
                  child: Text(
                    '$_currentLevelProgress / $_currentLevelTotal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: progress > 0.5
                          ? Colors.white
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                      shadows: progress > 0.5
                          ? [
                              const Shadow(
                                color: Colors.black26,
                                blurRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFBBF24).withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBBF24).withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 10,
            color: const Color(0xFFFBBF24),
          ),
          const SizedBox(width: 4),
          Text(
            _formatCountdown(_timeRemaining),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFBBF24),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

}


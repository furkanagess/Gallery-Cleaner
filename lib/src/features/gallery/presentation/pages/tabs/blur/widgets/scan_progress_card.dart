import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../application/gallery_providers.dart' show PremiumCubit;

class ScanProgressCard extends StatelessWidget {
  const ScanProgressCard({
    required this.title,
    required this.processed,
    required this.total,
    required this.fallbackLabel,
  });

  final String title;
  final int processed;
  final int total;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

    final hasTotal = total > 0;
    final progressValue = hasTotal ? (processed / total).clamp(0.0, 1.0) : null;
    final primaryLabel = title.isEmpty ? fallbackLabel : title;
    // Sayısal ilerleme gösterimi (0/500, 100/500 gibi)
    final statusText = hasTotal ? '$processed/$total' : '$processed';
    final helperText = hasTotal ? 'photos scanned' : 'photos analyzed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: containerColor.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            primaryLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: containerColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progressValue, minHeight: 6),
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: containerColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helperText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: containerColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

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
        color: theme.colorScheme.primaryContainer.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            primaryLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
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
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helperText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}


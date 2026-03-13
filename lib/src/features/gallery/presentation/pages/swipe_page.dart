import 'dart:async';
import 'dart:ui';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/services/fcm_service.dart';
import '../../application/gallery_providers.dart';
import '../../application/blur_detection_provider.dart';
import '../../application/duplicate_detection_provider.dart';
import '../../../onboarding/application/permissions_controller.dart';
import '../../../../core/services/interstitial_ads_service.dart';
import '../../application/gallery_stats_provider.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_three_d_button.dart';
import '../../../settings/presentation/settings_page.dart';
import '../../../settings/presentation/premium_success_dialog.dart';
import '../../../../core/services/revenuecat_service.dart';
import '../widgets/first_paywall_dialog.dart';
import 'package:gallery_cleaner/src/core/utils/view_refresh_cubit.dart';
import 'swipe_tab.dart' show SwipeTab;
import 'tabs/blur/blur_tab.dart' show BlurTab;
import 'tabs/blur/widgets/blur_tab_indicator.dart' show BlurTabIndicator;
import 'tabs/duplicate/duplicate_tab.dart' show DuplicateTab;
import 'tabs/duplicate/widgets/duplicate_tab_indicator.dart'
    show DuplicateTabIndicator;

part 'swipe_page_helpers.dart';
part 'swipe_page_widgets.dart';
part 'swipe_page_bottom_sheets.dart';

/// Ad unit types for different features (used only for UI identification)
enum AdUnitType {
  deleteLimit, // Delete rights
  blurScanLimit, // Blur scan rights
  duplicateScanLimit, // Duplicate scan rights
}

Future<void> _presentAlbumPicker({
  required BuildContext context,
  required List<pm.AssetPathEntity> albums,
  required pm.AssetPathEntity? selectedAlbum,
  required ValueChanged<pm.AssetPathEntity?> onSelected,
}) async {
  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context)!;

  if (albums.isEmpty) {
    return;
  }

  final filteredAlbums = albums.where((album) => !album.isAll).toList();

  // Date Range and Sort Order için cubit'leri al
  final dateFilterCubit = context.read<AlbumFilterCubit>();
  final sortOrderCubit = context.read<AlbumSortOrderCubit>();

  final initialDateRange = dateFilterCubit.state;
  final initialSortOrder = sortOrderCubit.state;

  // Tüm seçimleri tek bir bottomsheet'te topla - Apply butonuna basıldığında uygulanacak
  final result = await showModalBottomSheet<Map<String, dynamic>?>(
    context: context,
    backgroundColor: AppColors.transparent,
    isScrollControlled: true,
    builder: (context) {
      // Premium durumunu kontrol et
      final isPremiumAsync = context.watch<PremiumCubit>().state;
      isPremiumAsync.maybeWhen(data: (premium) => premium, orElse: () => false);

      // Bottom navigation bar'daki container rengiyle aynı
      final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
        alpha: 0.8,
      );

      // StatefulBuilder içinde state tutmak için Map kullan - closure ile erişim
      final state = <String, dynamic>{
        'selectedAlbum': selectedAlbum,
        'startDate': initialDateRange.startDate,
        'endDate': initialDateRange.endDate,
        'sortOrder': initialSortOrder,
      };

      return StatefulBuilder(
        builder: (context, setState) {
          // State'ten değerleri al
          final tempSelectedAlbum =
              state['selectedAlbum'] as pm.AssetPathEntity?;
          final tempStartDate = state['startDate'] as DateTime?;
          final tempEndDate = state['endDate'] as DateTime?;
          final tempSortOrder = state['sortOrder'] as SortOrder;

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Stack(
                children: [
                  // Background ambiance layer
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.surface.withValues(alpha: 0.95),
                          theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.9,
                          ),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.1,
                          ),
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(
                            alpha: 0.1,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 4),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      containerColor.withValues(alpha: 0.2),
                                      containerColor.withValues(alpha: 0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.photo_library_rounded,
                                  size: 24,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.albumSelection,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.5,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.selectAlbumToView,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Album Selection Section
                                Text(
                                  l10n.albumSelection,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Yatay Album List (All Photos + Albums)
                                SizedBox(
                                  height: 90,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    physics: const BouncingScrollPhysics(),
                                    cacheExtent: 400,
                                    itemCount:
                                        filteredAlbums.length +
                                        1, // +1 for "All Photos"
                                    itemBuilder: (context, index) {
                                      // İlk item "All Photos"
                                      if (index == 0) {
                                        final isSelected =
                                            tempSelectedAlbum == null;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: Material(
                                            color: AppColors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  state['selectedAlbum'] = null;
                                                });
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 120,
                                                      maxWidth: 140,
                                                      minHeight: 74,
                                                      maxHeight: 90,
                                                    ),
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: isSelected
                                                      ? LinearGradient(
                                                          colors: [
                                                            containerColor
                                                                .withValues(
                                                                  alpha: 0.3,
                                                                ),
                                                            containerColor
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                          ],
                                                        )
                                                      : null,
                                                  color: isSelected
                                                      ? null
                                                      : theme
                                                            .colorScheme
                                                            .surfaceContainerHighest
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? containerColor
                                                              .withValues(
                                                                alpha: 0.3,
                                                              )
                                                        : theme
                                                              .colorScheme
                                                              .outline
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                    width: isSelected ? 1.5 : 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? containerColor
                                                                  .withValues(
                                                                    alpha: 0.2,
                                                                  )
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        Icons.grid_view_rounded,
                                                        color: isSelected
                                                            ? containerColor
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.7,
                                                                  ),
                                                        size: 20,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Flexible(
                                                      child: Text(
                                                        l10n.allPhotos,
                                                        style: theme
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  isSelected
                                                                  ? FontWeight
                                                                        .w600
                                                                  : FontWeight
                                                                        .w500,
                                                              color: isSelected
                                                                  ? containerColor
                                                                  : theme
                                                                        .colorScheme
                                                                        .onSurface,
                                                            ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 2,
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      const SizedBox(height: 4),
                                                    if (isSelected)
                                                      Icon(
                                                        Icons
                                                            .check_circle_rounded,
                                                        color: containerColor,
                                                        size: 16,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      // Diğer albümler
                                      final album = filteredAlbums[index - 1];
                                      final isSelected =
                                          tempSelectedAlbum?.id == album.id;
                                      final isLastItem =
                                          index == filteredAlbums.length;
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          right: isLastItem ? 0 : 12,
                                        ),
                                        child: Material(
                                          color: AppColors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                state['selectedAlbum'] = album;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minWidth: 120,
                                                maxWidth: 160,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                gradient: isSelected
                                                    ? LinearGradient(
                                                        colors: [
                                                          containerColor
                                                              .withValues(
                                                                alpha: 0.3,
                                                              ),
                                                          containerColor
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                        ],
                                                      )
                                                    : null,
                                                color: isSelected
                                                    ? null
                                                    : theme
                                                          .colorScheme
                                                          .surfaceContainerHighest
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? containerColor
                                                            .withValues(
                                                              alpha: 0.3,
                                                            )
                                                      : theme
                                                            .colorScheme
                                                            .outline
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                  width: isSelected ? 1.5 : 1,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? containerColor
                                                                .withValues(
                                                                  alpha: 0.2,
                                                                )
                                                          : theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.folder_rounded,
                                                      color: isSelected
                                                          ? containerColor
                                                          : theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                  alpha: 0.7,
                                                                ),
                                                      size: 20,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Flexible(
                                                    child: Text(
                                                      album.name,
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                isSelected
                                                                ? FontWeight
                                                                      .w600
                                                                : FontWeight
                                                                      .w500,
                                                            color: isSelected
                                                                ? containerColor
                                                                : theme
                                                                      .colorScheme
                                                                      .onSurface,
                                                          ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 2,
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    const SizedBox(height: 4),
                                                  if (isSelected)
                                                    Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: containerColor,
                                                      size: 16,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 32),
                                // Date Range Section
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 18,
                                      color: containerColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.dateRange,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Material(
                                        color: AppColors.transparent,
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  tempStartDate ??
                                                  DateTime.now(),
                                              firstDate: DateTime(2000),
                                              lastDate: DateTime.now(),
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                state['startDate'] = picked;
                                              });
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                              gradient: tempStartDate != null
                                                  ? LinearGradient(
                                                      colors: [
                                                        containerColor
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        containerColor
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                      ],
                                                    )
                                                  : null,
                                              color: tempStartDate != null
                                                  ? null
                                                  : theme
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: tempStartDate != null
                                                    ? containerColor.withValues(
                                                        alpha: 0.3,
                                                      )
                                                    : theme.colorScheme.outline
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                width: tempStartDate != null
                                                    ? 1.5
                                                    : 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.play_arrow_rounded,
                                                      size: 16,
                                                      color:
                                                          tempStartDate != null
                                                          ? containerColor
                                                          : theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      l10n.startDate,
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color:
                                                                tempStartDate !=
                                                                    null
                                                                ? containerColor
                                                                : theme
                                                                      .colorScheme
                                                                      .onSurface
                                                                      .withValues(
                                                                        alpha:
                                                                            0.6,
                                                                      ),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  tempStartDate != null
                                                      ? DateFormat(
                                                          'dd.MM.yyyy',
                                                        ).format(tempStartDate)
                                                      : l10n.notSelected,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            tempStartDate !=
                                                                null
                                                            ? theme
                                                                  .colorScheme
                                                                  .onSurface
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.5,
                                                                  ),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Material(
                                        color: AppColors.transparent,
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  tempEndDate ?? DateTime.now(),
                                              firstDate:
                                                  tempStartDate ??
                                                  DateTime(2000),
                                              lastDate: DateTime.now(),
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                state['endDate'] = picked;
                                              });
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                              gradient: tempEndDate != null
                                                  ? LinearGradient(
                                                      colors: [
                                                        containerColor
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        containerColor
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                      ],
                                                    )
                                                  : null,
                                              color: tempEndDate != null
                                                  ? null
                                                  : theme
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: tempEndDate != null
                                                    ? containerColor.withValues(
                                                        alpha: 0.3,
                                                      )
                                                    : theme.colorScheme.outline
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                width: tempEndDate != null
                                                    ? 1.5
                                                    : 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.stop_rounded,
                                                      size: 16,
                                                      color: tempEndDate != null
                                                          ? containerColor
                                                          : theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      l10n.endDate,
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color:
                                                                tempEndDate !=
                                                                    null
                                                                ? containerColor
                                                                : theme
                                                                      .colorScheme
                                                                      .onSurface
                                                                      .withValues(
                                                                        alpha:
                                                                            0.6,
                                                                      ),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  tempEndDate != null
                                                      ? DateFormat(
                                                          'dd.MM.yyyy',
                                                        ).format(tempEndDate)
                                                      : l10n.notSelected,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            tempEndDate != null
                                                            ? theme
                                                                  .colorScheme
                                                                  .onSurface
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.5,
                                                                  ),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (tempStartDate != null ||
                                    tempEndDate != null) ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        state['startDate'] = null;
                                        state['endDate'] = null;
                                      });
                                    },
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                      color: theme.colorScheme.error,
                                    ),
                                    label: Text(
                                      l10n.clearDateFilter,
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      side: BorderSide(
                                        color: theme.colorScheme.error,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 32),
                                // Sort Order Section
                                Builder(
                                  builder: (builderContext) {
                                    final isPremiumAsync = builderContext
                                        .watch<PremiumCubit>()
                                        .state;
                                    isPremiumAsync.maybeWhen(
                                      data: (premium) => premium,
                                      orElse: () => false,
                                    );
                                    final containerColorSort = theme
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withValues(alpha: 0.8);

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.sort_rounded,
                                              size: 18,
                                              color: containerColorSort,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.sort,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: theme
                                                        .colorScheme
                                                        .onPrimaryContainer
                                                        .withValues(alpha: 0.8),
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Material(
                                                color: AppColors.transparent,
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      state['sortOrder'] =
                                                          SortOrder.newest;
                                                    });
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 16,
                                                          horizontal: 12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          tempSortOrder ==
                                                              SortOrder.newest
                                                          ? containerColorSort
                                                          : theme
                                                                .colorScheme
                                                                .surfaceContainerHighest
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            tempSortOrder ==
                                                                SortOrder.newest
                                                            ? containerColorSort
                                                            : theme
                                                                  .colorScheme
                                                                  .outline
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  ),
                                                        width:
                                                            tempSortOrder ==
                                                                SortOrder.newest
                                                            ? 2
                                                            : 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .arrow_downward_rounded,
                                                          size: 20,
                                                          color:
                                                              tempSortOrder ==
                                                                  SortOrder
                                                                      .newest
                                                              ? AppColors
                                                                    .surface
                                                              : theme
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                      alpha:
                                                                          0.7,
                                                                    ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          l10n.newest,
                                                          style: theme.textTheme.titleSmall?.copyWith(
                                                            fontWeight:
                                                                tempSortOrder ==
                                                                    SortOrder
                                                                        .newest
                                                                ? FontWeight
                                                                      .w600
                                                                : FontWeight
                                                                      .w500,
                                                            color:
                                                                tempSortOrder ==
                                                                    SortOrder
                                                                        .newest
                                                                ? AppColors
                                                                      .surface
                                                                : theme
                                                                      .colorScheme
                                                                      .onSurface,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Material(
                                                color: AppColors.transparent,
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      state['sortOrder'] =
                                                          SortOrder.oldest;
                                                    });
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 16,
                                                          horizontal: 12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          tempSortOrder ==
                                                              SortOrder.oldest
                                                          ? containerColorSort
                                                          : theme
                                                                .colorScheme
                                                                .surfaceContainerHighest
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            tempSortOrder ==
                                                                SortOrder.oldest
                                                            ? containerColorSort
                                                            : theme
                                                                  .colorScheme
                                                                  .outline
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  ),
                                                        width:
                                                            tempSortOrder ==
                                                                SortOrder.oldest
                                                            ? 2
                                                            : 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .arrow_upward_rounded,
                                                          size: 20,
                                                          color:
                                                              tempSortOrder ==
                                                                  SortOrder
                                                                      .oldest
                                                              ? AppColors
                                                                    .surface
                                                              : theme
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                      alpha:
                                                                          0.7,
                                                                    ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          l10n.oldest,
                                                          style: theme.textTheme.titleSmall?.copyWith(
                                                            fontWeight:
                                                                tempSortOrder ==
                                                                    SortOrder
                                                                        .oldest
                                                                ? FontWeight
                                                                      .w600
                                                                : FontWeight
                                                                      .w500,
                                                            color:
                                                                tempSortOrder ==
                                                                    SortOrder
                                                                        .oldest
                                                                ? AppColors
                                                                      .surface
                                                                : theme
                                                                      .colorScheme
                                                                      .onSurface,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.colorScheme.surface.withValues(alpha: 0),
                                theme.colorScheme.surface.withValues(
                                  alpha: 0.8,
                                ),
                              ],
                            ),
                          ),
                          child: Builder(
                            builder: (buttonContext) {
                              final isPremiumAsync = buttonContext
                                  .watch<PremiumCubit>()
                                  .state;
                              isPremiumAsync.maybeWhen(
                                data: (premium) => premium,
                                orElse: () => false,
                              );
                              final containerColorButton = theme
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withValues(alpha: 0.8);

                              return Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      containerColorButton,
                                      containerColorButton.withValues(
                                        alpha: 0.85,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: containerColorButton,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: containerColorButton.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: AppColors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop({
                                        'selectedAlbum': state['selectedAlbum'],
                                        'startDate': state['startDate'],
                                        'endDate': state['endDate'],
                                        'sortOrder': state['sortOrder'],
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 20,
                                            color: AppColors.surface,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            l10n.apply,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color: AppColors.surface,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
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
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (!context.mounted) return;

  // Apply butonuna basıldığında tüm değişiklikleri uygula
  if (result != null) {
    // Album seçimini uygula (bottom sheet kapandıktan sonra async olarak)
    final newSelectedAlbum = result['selectedAlbum'] as pm.AssetPathEntity?;
    if (newSelectedAlbum != selectedAlbum) {
      // Microtask ile bir sonraki frame'de çalıştır, UI thread'i bloke etme
      Future.microtask(() {
        if (context.mounted) {
          onSelected(newSelectedAlbum);
        }
      });
    }

    // Filter ve sort değişikliklerini uygula
    dateFilterCubit.setDateRange(
      result['startDate'] as DateTime?,
      result['endDate'] as DateTime?,
    );
    sortOrderCubit.setSortOrder(result['sortOrder'] as SortOrder);
  }
}

class SwipePage extends StatefulWidget {
  const SwipePage({super.key});

  @override
  State<SwipePage> createState() => _SwipePageState();

  /// Silme işleminden sonra paywall dialog göster (public helper)
  static Future<void> showPaywallDialogAfterDelete(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => FirstPaywallDialog(
        onPurchaseComplete: () {
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }
}

class _SwipePageState extends State<SwipePage>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        CubitStateMixin<SwipePage> {
  late TabController _tabController;
  late AnimationController _historyPulseController;
  late AnimationController _blurTabPulseController;
  late AnimationController _duplicateTabPulseController;

  int? _previousTabIndex; // Scan sırasında tab değişimini engellemek için
  bool _tabListenerAdded = false; // Listener'ın eklenip eklenmediğini takip et
  bool _isNavigatingToResults =
      false; // Results ekranına yönlendirme yapılıyor mu?

  // Stream subscription'ları sakla - dispose'da iptal etmek için
  StreamSubscription? _permissionsSubscription;
  StreamSubscription? _blurDetectionSubscription;
  StreamSubscription? _duplicateDetectionSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _previousTabIndex = _tabController.index;
    // TabController ile TabSelectionCubit'i senkronize et
    context.read<TabSelectionCubit>().selectTab(_tabController.index);

    // Bildirim izni: uygulama ilk açılışında değil, swipe page init olduğunda iste
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FCMService.instance.requestNotificationPermission();
    });

    _historyPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _blurTabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _duplicateTabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Interstisial ad servisine premium dialog callback'i ayarla
    InterstitialAdsService.instance.onPremiumDialogTrigger = () {
      if (mounted) {
        _showPremiumDialog();
      }
    };

    // Lifecycle observer'ı ekle (arka plan/ön plan kontrolü için)
    WidgetsBinding.instance.addObserver(this);

    // İzin durumunu hemen kontrol et - böylece izin varsa hiç izin ekranı gösterilmez
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // İzin durumunu refresh et (güncel durumu almak için)
      await context.read<PermissionsCubit>().refresh();

      // Stream listener'ları ekle - sadece bir kez
      _setupStreamListeners();

      // İlk açılışta paywall dialog göster
      _checkAndShowFirstPaywall();
    });
  }

  void _setupStreamListeners() {
    if (!mounted) return;

    debugPrint('🔧 [SwipePage] Setting up stream listeners...');

    // İzin durumu listener'ı - sadece UI güncellemesi için
    _permissionsSubscription?.cancel();
    final permissionsCubit = context.read<PermissionsCubit>();
    _permissionsSubscription = permissionsCubit.stream.listen((next) {
      // İzin durumu değişikliği sadece UI güncellemesi için kullanılıyor
      // Otomatik analiz başlatılmıyor
    });

    // Blur tarama durumu listener'ı - scan tamamlandığında results sayfasına yönlendir
    _blurDetectionSubscription?.cancel();
    final blurDetectionCubit = context.read<BlurDetectionCubit>();
    debugPrint('🔧 [SwipePage] Creating blur detection listener...');

    // Mevcut state'i kontrol et ve previous state olarak sakla
    var previousBlurState = blurDetectionCubit.state;
    debugPrint(
      '🔧 [SwipePage] Current blur state: isScanning=${previousBlurState.isScanning}, hasCompletedScan=${previousBlurState.hasCompletedScan}',
    );

    // Eğer scan zaten tamamlanmışsa bildirim gönder
    if (previousBlurState.hasCompletedScan &&
        !previousBlurState.isScanning &&
        !_isNavigatingToResults) {
      debugPrint(
        '⚠️ [SwipePage] Blur scan already completed when listener was set up, sending notification...',
      );
      _isNavigatingToResults = true;
      unawaited(_sendScanCompletedNotification('blur'));
      _navigateToResultsPage('/results/blur');
    }

    _blurDetectionSubscription = blurDetectionCubit.stream.listen((next) {
      debugPrint('🔔 [SwipePage] Blur detection stream event received!');
      if (!mounted) {
        debugPrint('⚠️ [SwipePage] Widget not mounted, skipping blur listener');
        return;
      }

      final wasScanning = previousBlurState.isScanning;
      final isNowScanning = next.isScanning;
      final hasCompleted = next.hasCompletedScan && !next.isScanning;

      debugPrint(
        '🔍 [SwipePage] Blur scan state: wasScanning=$wasScanning, isNowScanning=$isNowScanning, hasCompleted=$hasCompleted, _isNavigatingToResults=$_isNavigatingToResults',
      );
      debugPrint(
        '   - previous state: ${previousBlurState.isScanning}, ${previousBlurState.hasCompletedScan}',
      );
      debugPrint(
        '   - next state: ${next.isScanning}, ${next.hasCompletedScan}',
      );

      // Previous state'i güncelle
      previousBlurState = next;

      // Yeni bir tarama başladığında navigation flag'ini sıfırla
      if (!wasScanning && isNowScanning && _isNavigatingToResults) {
        debugPrint(
          '🧭 [SwipePage] Blur scan started, resetting navigation guard flag',
        );
        _isNavigatingToResults = false;
      }

      // Scan tamamlandığında bildirim gönder ve results sayfasına yönlendir
      if (wasScanning &&
          !isNowScanning &&
          hasCompleted &&
          !_isNavigatingToResults) {
        debugPrint(
          '✅ [SwipePage] Blur scan completed, sending notification and navigating to results page',
        );
        _isNavigatingToResults = true;

        // Bildirim gönder (unawaited - navigation'ı beklemez ama hataları yakalar)
        unawaited(_sendScanCompletedNotification('blur'));

        // Results sayfasına yönlendir
        _navigateToResultsPage('/results/blur');
      }
    });

    // Duplicate tarama durumu listener'ı - scan tamamlandığında results sayfasına yönlendir
    _duplicateDetectionSubscription?.cancel();
    final duplicateDetectionCubit = context.read<DuplicateDetectionCubit>();
    debugPrint('🔧 [SwipePage] Creating duplicate detection listener...');

    // Mevcut state'i kontrol et ve previous state olarak sakla
    var previousDuplicateState = duplicateDetectionCubit.state;
    debugPrint(
      '🔧 [SwipePage] Current duplicate state: isScanning=${previousDuplicateState.isScanning}, hasCompletedScan=${previousDuplicateState.hasCompletedScan}',
    );

    // Eğer scan zaten tamamlanmışsa bildirim gönder
    if (previousDuplicateState.hasCompletedScan &&
        !previousDuplicateState.isScanning &&
        !_isNavigatingToResults) {
      debugPrint(
        '⚠️ [SwipePage] Duplicate scan already completed when listener was set up, sending notification...',
      );
      _isNavigatingToResults = true;
      unawaited(_sendScanCompletedNotification('duplicate'));
      _navigateToResultsPage('/results/duplicate');
    }

    _duplicateDetectionSubscription = duplicateDetectionCubit.stream.listen((
      next,
    ) {
      debugPrint('🔔 [SwipePage] Duplicate detection stream event received!');
      if (!mounted) {
        debugPrint(
          '⚠️ [SwipePage] Widget not mounted, skipping duplicate listener',
        );
        return;
      }

      final wasScanning = previousDuplicateState.isScanning;
      final isNowScanning = next.isScanning;
      final hasCompleted = next.hasCompletedScan && !next.isScanning;

      debugPrint(
        '🔍 [SwipePage] Duplicate scan state: wasScanning=$wasScanning, isNowScanning=$isNowScanning, hasCompleted=$hasCompleted, _isNavigatingToResults=$_isNavigatingToResults',
      );
      debugPrint(
        '   - previous state: ${previousDuplicateState.isScanning}, ${previousDuplicateState.hasCompletedScan}',
      );
      debugPrint(
        '   - next state: ${next.isScanning}, ${next.hasCompletedScan}',
      );

      // Previous state'i güncelle
      previousDuplicateState = next;

      // Yeni bir tarama başladığında navigation flag'ini sıfırla
      if (!wasScanning && isNowScanning && _isNavigatingToResults) {
        debugPrint(
          '🧭 [SwipePage] Duplicate scan started, resetting navigation guard flag',
        );
        _isNavigatingToResults = false;
      }

      // Scan tamamlandığında bildirim gönder ve results sayfasına yönlendir
      if (wasScanning &&
          !isNowScanning &&
          hasCompleted &&
          !_isNavigatingToResults) {
        debugPrint(
          '✅ [SwipePage] Duplicate scan completed, sending notification and navigating to results page',
        );
        _isNavigatingToResults = true;

        // Bildirim gönder (unawaited - navigation'ı beklemez ama hataları yakalar)
        unawaited(_sendScanCompletedNotification('duplicate'));

        // Results sayfasına yönlendir
        _navigateToResultsPage('/results/duplicate');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }

  /// İlk açılışta paywall dialog göster
  Future<void> _checkAndShowFirstPaywall() async {
    if (!mounted) return;

    try {
      final prefsService = PreferencesService();

      // İlk paywall zaten gösterildi mi kontrol et
      final isFirstPaywallShown = await prefsService.isFirstPaywallShown();
      if (isFirstPaywallShown) {
        debugPrint('📱 [SwipePage] First paywall already shown, skipping...');
        return;
      }

      // Premium kullanıcı mı kontrol et
      final isPremium = await prefsService.isPremium();
      if (isPremium) {
        debugPrint('📱 [SwipePage] User is premium, skipping first paywall...');
        // Premium kullanıcıda da flag'i set et
        await prefsService.setFirstPaywallShown(true);
        return;
      }

      // Galeri yüklendi mi kontrol et - assets yüklendikten sonra göster
      if (!mounted) return;
      final galleryCubit = context.read<GalleryPagingCubit>();
      final galleryAssets = galleryCubit.state;
      final hasAssets = galleryAssets.maybeWhen(
        data: (assets) => assets.isNotEmpty,
        orElse: () => false,
      );

      if (!hasAssets) {
        debugPrint('📱 [SwipePage] Gallery not loaded yet, waiting...');
        // Galeri yüklenene kadar bekle (maksimum 10 saniye)
        int attempts = 0;
        while (attempts < 20 && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          final currentAssets = galleryCubit.state;
          final hasCurrentAssets = currentAssets.maybeWhen(
            data: (assets) => assets.isNotEmpty,
            orElse: () => false,
          );
          if (hasCurrentAssets) {
            debugPrint(
              '📱 [SwipePage] Gallery loaded, showing first paywall...',
            );
            break;
          }
          attempts++;
        }
      }

      if (!mounted) return;

      // Kısa bir gecikme sonra dialog göster (kullanıcı deneyimi için)
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      // İlk paywall dialog'u göster
      debugPrint('📱 [SwipePage] Showing first paywall dialog...');
      await _showFirstPaywallDialog();

      // Flag'i set et
      await prefsService.setFirstPaywallShown(true);
    } catch (e) {
      debugPrint('❌ [SwipePage] Error checking first paywall: $e');
    }
  }

  /// İlk paywall dialog'u göster
  Future<void> _showFirstPaywallDialog() async {
    if (!mounted) return;

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _FirstPaywallDialog(
        onPurchaseComplete: () {
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _showPremiumDialog() {
    if (!mounted) return;
    debugPrint(
      '💰 [SwipePage] Showing first paywall dialog after 3 interstitial ads',
    );
    // First Paywall Dialog'u göster
    _showFirstPaywallDialog();
  }

  /// Scan tamamlandı bildirimi gönder (güvenli ve async)
  Future<void> _sendScanCompletedNotification(String scanType) async {
    try {
      debugPrint(
        '📱 [SwipePage] Starting notification send process for: $scanType',
      );

      if (!mounted) {
        debugPrint('⚠️ [SwipePage] Widget not mounted, skipping notification');
        return;
      }

      debugPrint('📱 [SwipePage] Widget is mounted, getting localizations...');
      final l10n = AppLocalizations.of(context);
      if (l10n == null) {
        debugPrint(
          '⚠️ [SwipePage] Localizations not available, skipping notification',
        );
        return;
      }

      debugPrint(
        '📱 [SwipePage] Localizations available, preparing notification...',
      );
      final title = scanType == 'blur'
          ? l10n.scanCompletedSuccessfully
          : l10n.scanCompletedSuccessfullyDuplicate;
      final body = l10n.openAppAndViewResults;

      debugPrint('📱 [SwipePage] Notification details:');
      debugPrint('   - Title: $title');
      debugPrint('   - Body: $body');
      debugPrint('   - Scan type: $scanType');

      // FCMService'in initialize olduğundan emin ol
      debugPrint('📱 [SwipePage] Checking FCMService initialization...');
      try {
        // Bildirimi göster (await ile - hataları yakalamak için)
        debugPrint(
          '📱 [SwipePage] Calling FCMService.showScanCompletedNotification...',
        );
        await FCMService.instance.showScanCompletedNotification(
          title: title,
          body: body,
          scanType: scanType,
        );
        debugPrint(
          '✅ [SwipePage] Scan completed notification sent successfully',
        );
      } catch (fcmError, fcmStackTrace) {
        debugPrint('❌ [SwipePage] FCMService error: $fcmError');
        debugPrint('❌ [SwipePage] FCMService stack trace: $fcmStackTrace');
        // Hata olsa bile devam et - bildirim kritik değil
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [SwipePage] Exception while sending notification: $e');
      debugPrint('❌ [SwipePage] Stack trace: $stackTrace');
      // Hata olsa bile devam et - bildirim kritik değil
    }
  }

  /// Scan tamamlandığında results sayfasına yönlendir (basit ve güvenilir versiyon)
  Future<void> _navigateToResultsPage(String route) async {
    if (!mounted) return;

    debugPrint('🚀 [SwipePage] Navigating to results page: $route');

    // Premium kontrolü ve ad gösterimi
    final prefsService = PreferencesService();
    final isPremium = await prefsService.isPremium();

    if (!isPremium) {
      try {
        debugPrint(
          '📱 [SwipePage] Showing interstitial ad before navigation...',
        );
        final adService = InterstitialAdsService.instance;
        final adShown = await adService
            .showAd()
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                debugPrint('⚠️ [SwipePage] Ad timeout, continuing...');
                return false;
              },
            )
            .catchError((e) {
              debugPrint('⚠️ [SwipePage] Ad error: $e, continuing...');
              return false;
            });

        if (adShown == true) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        debugPrint('⚠️ [SwipePage] Error in ad flow: $e, continuing...');
      }
    }

    // Results sayfasına yönlendir
    if (!mounted) return;

    // Kısa bir gecikme - state değişikliklerinin tamamlanmasını bekle
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    debugPrint('🚀 [SwipePage] Executing navigation to $route');
    try {
      context.push(route).then((_) {
        if (mounted) {
          _isNavigatingToResults = false;
        }
      });
    } catch (e) {
      debugPrint('❌ [SwipePage] Navigation error: $e');
      if (mounted) {
        _isNavigatingToResults = false;
      }
    }
  }

  @override
  void dispose() {
    // Lifecycle observer'ı kaldır
    WidgetsBinding.instance.removeObserver(this);

    // Callback'i temizle
    InterstitialAdsService.instance.onPremiumDialogTrigger = null;

    // Stream subscription'ları iptal et
    _permissionsSubscription?.cancel();
    _blurDetectionSubscription?.cancel();
    _duplicateDetectionSubscription?.cancel();

    _tabController.dispose();
    _historyPulseController.dispose();
    _blurTabPulseController.dispose();
    _duplicateTabPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithCubit(() => _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final permission = context.watch<PermissionsCubit>().state;
    final blurState = context.watch<BlurDetectionCubit>().state;
    final duplicateState = context.watch<DuplicateDetectionCubit>().state;
    final isScanning = blurState.isScanning || duplicateState.isScanning;

    // TabController listener - scan sırasında tab değişimini engelle
    // Listener'ı sadece bir kez ekle
    if (!_tabListenerAdded) {
      _tabController.addListener(() {
        if (!mounted) return;
        final blurState = context.read<BlurDetectionCubit>().state;
        final duplicateState = context.read<DuplicateDetectionCubit>().state;
        final isScanning = blurState.isScanning || duplicateState.isScanning;

        if (isScanning && _previousTabIndex != null) {
          // Scan sırasında tab değişimini geri al
          if (_tabController.index != _previousTabIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _tabController.index != _previousTabIndex) {
                _tabController.animateTo(_previousTabIndex!);
              }
            });
          }
        } else {
          // Normal durumda önceki index'i güncelle
          _previousTabIndex = _tabController.index;
        }
      });
      _tabListenerAdded = true;
    } else if (!isScanning) {
      // Listener zaten var, sadece önceki index'i güncelle
      _previousTabIndex = _tabController.index;
    }

    // Stream listener'lar artık initState'de ekleniyor - burada tekrar ekleme

    // İzin durumu unknown ise lottie'li splash loading göster (izin kontrolü yapılıyor)
    // Böylece izin varsa hiç izin ekranı gösterilmez
    if (permission == GalleryPermissionStatus.unknown) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.1),
                theme.colorScheme.secondary.withValues(alpha: 0.05),
                AppColors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lottie animasyonu
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Lottie.asset(
                    'assets/lottie/loading.json',
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
                const SizedBox(height: 32),
                // App ismi
                Text(
                  'Gallery Cleaner',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // İzin yoksa izin ekranı göster
    if (permission != GalleryPermissionStatus.authorized) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: AppColors.transparent,
          elevation: 0,
          title: Text(l10n.appTitle, overflow: TextOverflow.ellipsis),
        ),
        body: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 120,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      l10n.galleryPermissionRequired,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.galleryPermissionDescription,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PermissionFeature(
                            icon: Icons.swipe,
                            title: l10n.quickCleanupTitle,
                            description: l10n.quickCleanupDescription,
                          ),
                          const SizedBox(height: 16),
                          _PermissionFeature(
                            icon: Icons.folder,
                            title: l10n.organizeTitle,
                            description: l10n.organizeDescription,
                          ),
                          const SizedBox(height: 16),
                          _PermissionFeature(
                            icon: Icons.delete_outline,
                            title: l10n.safeDeleteTitle,
                            description: l10n.safeDeleteDescription,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.lock_open),
                          label: Text(l10n.grantPermission),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () async {
                            await context.read<PermissionsCubit>().request();
                            // İzin verildiğinde otomatik analiz başlatılmıyor
                            // Analiz sadece permission_request_page'de izin verildiğinde (ilk defa) başlatılıyor
                            // veya kullanıcı galeri istatistikleri sayfasından "Tekrardan Analiz Et" butonuna basarak başlatıyor
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBody: true, // Bottom bar'ın arkasından içerik geçebilsin
      extendBodyBehindAppBar: false,
      resizeToAvoidBottomInset: false,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ana içerik
          SafeArea(
            top: true,
            bottom: true,
            child: Column(
              children: [
                _ModernTopInfoBar(
                  tabController: _tabController,
                  isScanning: isScanning,
                ),
                // Tab Content - Bottom padding yok, navbar'ın arkasından geçebilsin
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      SwipeTab(),
                      BlurTab(),
                      DuplicateTab(),
                      SettingsPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Floating Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom:
                MediaQuery.of(context).padding.bottom +
                (Platform.isAndroid ? 16 : 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: AppColors.transparent,
                child: _LiquidGlassBottomNavBar(
                  tabController: _tabController,
                  isScanning: isScanning,
                  blurTabPulseController: _blurTabPulseController,
                  duplicateTabPulseController: _duplicateTabPulseController,
                  onTabChanged: (index) {
                    _previousTabIndex = index;
                    context.read<TabSelectionCubit>().selectTab(index);
                  },
                  onTabTap: (index) {
                    if (isScanning) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.doNotLeaveScreenDuringScan),
                          duration: const Duration(seconds: 2),
                          backgroundColor: theme.colorScheme.errorContainer,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    HapticFeedback.lightImpact();
                    _previousTabIndex = index;
                    context.read<TabSelectionCubit>().selectTab(index);
                    if (_blurTabPulseController.isAnimating) {
                      _blurTabPulseController.stop();
                      _blurTabPulseController.reset();
                    }
                    if (_duplicateTabPulseController.isAnimating) {
                      _duplicateTabPulseController.stop();
                      _duplicateTabPulseController.reset();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Modern Scan Limit Badge
class _ModernScanLimitBadge extends StatelessWidget {
  const _ModernScanLimitBadge({required this.adUnitType});

  final AdUnitType adUnitType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.8,
    );
    final scanLimitAsync = adUnitType == AdUnitType.blurScanLimit
        ? context.watch<BlurScanLimitCubit>().state
        : context.watch<DuplicateScanLimitCubit>().state;
    final isPremiumAsync = context.watch<PremiumCubit>().state;

    return scanLimitAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (scanLimit) {
        return isPremiumAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (isPremium) {
            final displayValue = isPremium ? '∞' : '$scanLimit';

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: containerColor.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: containerColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.remainingScanRights,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: AppColors.surface.withValues(alpha: 0.9),
                          letterSpacing: 0.3,
                          shadows: null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayValue,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: AppColors.surface,
                          letterSpacing: -0.5,
                          height: 1,
                          shadows: null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Rastgele snowflake PNG'leri arka plan
                // Snowman görseli container içinde sağ altta
              ],
            );
          },
        );
      },
    );
  }
}

// Modern Album Selection Button
class _ModernAlbumSelectionButton extends StatelessWidget {
  const _ModernAlbumSelectionButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final albumsAsync = context.watch<AlbumsCubit>().state;
    final selectedAlbum = context.watch<SelectedAlbumCubit>().state;
    final dateFilter = context.watch<AlbumFilterCubit>().state;
    final sortOrder = context.watch<AlbumSortOrderCubit>().state;
    final albumsData = albumsAsync.valueOrNull;
    final canOpenAlbumPicker = albumsData != null && albumsData.isNotEmpty;
    final displayAlbumName = selectedAlbum?.name ?? l10n.allPhotos;
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.8,
    );

    final hasDateFilter = dateFilter.hasFilter;
    final sortText = sortOrder == SortOrder.newest ? l10n.newest : l10n.oldest;

    Future<void> openAlbumPicker() async {
      final availableAlbums = albumsData;
      if (availableAlbums == null || availableAlbums.isEmpty) return;
      await _presentAlbumPicker(
        context: context,
        albums: availableAlbums,
        selectedAlbum: selectedAlbum,
        onSelected: (album) {
          context.read<SelectedAlbumCubit>().select(album);
        },
      );
    }

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: canOpenAlbumPicker ? openAlbumPicker : null,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: canOpenAlbumPicker
                    ? containerColor
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: canOpenAlbumPicker
                      ? containerColor.withValues(alpha: 0.9)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: canOpenAlbumPicker
                        ? containerColor.withValues(alpha: 0.35)
                        : theme.colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show title only if no filters are applied
                        if (!hasDateFilter &&
                            sortOrder == SortOrder.newest) ...[
                          Text(
                            l10n.albumSettings,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: canOpenAlbumPicker
                                  ? AppColors.surface.withValues(alpha: 0.9)
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.3,
                                    ),
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          displayAlbumName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize:
                                hasDateFilter || sortOrder != SortOrder.newest
                                ? 11
                                : 12,
                            color: canOpenAlbumPicker
                                ? AppColors.surface
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.3,
                                  ),
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (hasDateFilter || sortOrder != SortOrder.newest) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (hasDateFilter)
                                Builder(
                                  builder: (badgeContext) {
                                    // Premium durumunu kontrol et
                                    final isPremiumAsync = badgeContext
                                        .watch<PremiumCubit>()
                                        .state;
                                    isPremiumAsync.maybeWhen(
                                      data: (premium) => premium,
                                      orElse: () => false,
                                    );

                                    // Bottom navigation bar'daki container rengiyle aynı
                                    final containerColor = theme
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withValues(alpha: 0.8);

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: containerColor.withValues(
                                          alpha: 0.3,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 10,
                                            color: AppColors.surface,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              '${dateFilter.startDate != null ? DateFormat('dd.MM').format(dateFilter.startDate!) : ''}${dateFilter.startDate != null && dateFilter.endDate != null ? ' - ' : ''}${dateFilter.endDate != null ? DateFormat('dd.MM').format(dateFilter.endDate!) : ''}',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.surface,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              if (sortOrder != SortOrder.newest)
                                Builder(
                                  builder: (badgeContext) {
                                    // Premium durumunu kontrol et
                                    final isPremiumAsync = badgeContext
                                        .watch<PremiumCubit>()
                                        .state;
                                    isPremiumAsync.maybeWhen(
                                      data: (premium) => premium,
                                      orElse: () => false,
                                    );

                                    // Bottom navigation bar'daki container rengiyle aynı
                                    final containerColor = theme
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withValues(alpha: 0.8);

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: containerColor.withValues(
                                          alpha: 0.3,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            sortOrder == SortOrder.oldest
                                                ? Icons.arrow_upward_rounded
                                                : Icons.arrow_downward_rounded,
                                            size: 10,
                                            color: AppColors.surface,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            sortText,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.surface,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canOpenAlbumPicker) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            // Rastgele snowflake PNG'leri arka plan

            // Christmas Wreath görseli sağ altta
          ],
        ),
      ),
    );
  }
}

class _DeleteLimitInfo extends StatefulWidget {
  const _DeleteLimitInfo();

  @override
  State<_DeleteLimitInfo> createState() => _DeleteLimitInfoState();
}

class _DeleteLimitInfoState extends State<_DeleteLimitInfo>
    with CubitStateMixin<_DeleteLimitInfo> {
  void _showAddRightsDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.9 + (value * 0.1),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  l10n.increaseDeletionRights,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Premium purchase button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      SettingsPage.showPurchaseDialog(context);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.buyUnlimitedRights,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Cancel button
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.7,
                    ),
                  ),
                  child: Text(
                    l10n.cancel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final deleteLimitAsync = context.watch<DeleteLimitCubit>().state;
    final isPremiumAsync = context.watch<PremiumCubit>().state;

    return deleteLimitAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (deleteLimit) {
        return isPremiumAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (isPremium) {
            // Container decoration kaldırıldı
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Deletion rights badge and Album selection
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Deletion rights badge - Premium için parlak tasarım
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primaryContainer,
                                theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.8,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: ColorFiltered(
                                            colorFilter: ColorFilter.mode(
                                              theme
                                                  .colorScheme
                                                  .onPrimaryContainer
                                                  .withValues(alpha: 0.9),
                                              BlendMode.srcATop,
                                            ),
                                            child: Lottie.asset(
                                              'assets/lottie/trash.json',
                                              width: 13,
                                              height: 13,
                                              fit: BoxFit.contain,
                                              repeat: true,
                                              options: LottieOptions(
                                                enableMergePaths: true,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            l10n.remainingDeletionRights,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontWeight: isPremium
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  fontSize: 10,
                                                  color: theme
                                                      .colorScheme
                                                      .onPrimaryContainer
                                                      .withValues(alpha: 0.9),
                                                  letterSpacing: isPremium
                                                      ? 0.4
                                                      : 0.3,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPremium ? '∞' : '$deleteLimit',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            fontSize: isPremium ? 26 : 20,
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                            letterSpacing: isPremium
                                                ? -1.5
                                                : -1.2,
                                            height: 1,
                                            shadows: isPremium
                                                ? [
                                                    Shadow(
                                                      color: theme
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                      blurRadius: 10,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                    Shadow(
                                                      color: theme
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                      blurRadius: 6,
                                                      offset: const Offset(
                                                        0,
                                                        1,
                                                      ),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Premium icon veya + Button
                              if (isPremium)
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.primaryContainer,
                                        theme.colorScheme.primaryContainer
                                            .withValues(alpha: 0.7),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.5),
                                        blurRadius: 12,
                                        offset: const Offset(0, 2),
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 22,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                )
                              else
                                Material(
                                  color: AppColors.transparent,
                                  child: InkWell(
                                    onTap: () => _showAddRightsDialog(context),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme
                                              .colorScheme
                                              .onPrimaryContainer
                                              .withValues(alpha: 0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Album selection dropdown button
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: Builder(
                          builder: (context) {
                            final albumsAsync = context
                                .watch<AlbumsCubit>()
                                .state;
                            final selectedAlbum = context
                                .watch<SelectedAlbumCubit>()
                                .state;
                            final albumsData = albumsAsync.valueOrNull;
                            final canOpenAlbumPicker =
                                albumsData != null && albumsData.isNotEmpty;
                            final displayAlbumName =
                                selectedAlbum?.name ?? l10n.allPhotos;

                            Future<void> openAlbumPicker() async {
                              final availableAlbums = albumsData;
                              if (availableAlbums == null ||
                                  availableAlbums.isEmpty) {
                                return;
                              }
                              await _presentAlbumPicker(
                                context: context,
                                albums: availableAlbums,
                                selectedAlbum: selectedAlbum,
                                onSelected: (album) {
                                  context.read<SelectedAlbumCubit>().select(
                                    album,
                                  );
                                },
                              );
                            }

                            return Material(
                              color: AppColors.transparent,
                              child: InkWell(
                                onTap: canOpenAlbumPicker
                                    ? openAlbumPicker
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  height: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.photo_library_outlined,
                                        size: 16,
                                        color: canOpenAlbumPicker
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          displayAlbumName,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: canOpenAlbumPicker
                                                    ? theme
                                                          .colorScheme
                                                          .onSurface
                                                    : theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        size: 20,
                                        color: canOpenAlbumPicker
                                            ? theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7)
                                            : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.3),
                                      ),
                                    ],
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
              ],
            );
          },
        );
      },
    );
  }
}

// Liquid Glass Bottom Navigation Bar with Stadium Shape
class _LiquidGlassBottomNavBar extends StatefulWidget {
  const _LiquidGlassBottomNavBar({
    required this.tabController,
    required this.isScanning,
    required this.blurTabPulseController,
    required this.duplicateTabPulseController,
    required this.onTabChanged,
    required this.onTabTap,
  });

  final TabController tabController;
  final bool isScanning;
  final AnimationController blurTabPulseController;
  final AnimationController duplicateTabPulseController;
  final void Function(int index) onTabChanged;
  final void Function(int index) onTabTap;

  @override
  State<_LiquidGlassBottomNavBar> createState() =>
      _LiquidGlassBottomNavBarState();
}

class _LiquidGlassBottomNavBarState extends State<_LiquidGlassBottomNavBar> {
  int? _lastDragIndex;
  double? _dragProgress;

  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;

    final newIndex = widget.tabController.index;
    widget.onTabChanged(newIndex);

    if (_dragProgress == null) {
      setState(() {});
    }
  }

  void _handleDragSelection({required double dx, required double maxWidth}) {
    if (maxWidth <= 0) return;
    final tabWidth = maxWidth / 4;
    if (tabWidth <= 0) return;

    final safeDx = dx.clamp(0.0, maxWidth);
    final progress = (safeDx / tabWidth).clamp(0.0, 3.0);
    _dragProgress = progress;

    final targetIndex = (safeDx / tabWidth).floor().clamp(0, 3);
    if (_lastDragIndex != targetIndex) {
      _lastDragIndex = targetIndex;
      widget.tabController.animateTo(
        targetIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      widget.onTabTap(targetIndex);
    }

    setState(() {});
  }

  void _completeDragSelection() {
    final progress = _dragProgress;
    if (progress == null) return;

    final targetIndex = progress.floor().clamp(0, 3);
    widget.tabController.animateTo(
      targetIndex,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    widget.onTabTap(targetIndex);
    _dragProgress = null;
    _lastDragIndex = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IgnorePointer(
      ignoring: widget.isScanning,
      child: Opacity(
        opacity: widget.isScanning ? 0.5 : 1.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final navWidth = availableWidth;
            final itemWidth = navWidth / 4;
            final navBg1 = theme.colorScheme.primary.withValues(alpha: 0.15);
            final navBg2 = theme.colorScheme.primary.withValues(alpha: 0.08);
            final borderColor = theme.colorScheme.primary.withValues(
              alpha: 0.3,
            );

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) {
                _handleDragSelection(
                  dx: details.localPosition.dx,
                  maxWidth: constraints.maxWidth,
                );
              },
              onHorizontalDragUpdate: (details) {
                _handleDragSelection(
                  dx: details.localPosition.dx,
                  maxWidth: constraints.maxWidth,
                );
              },
              onHorizontalDragEnd: (_) => _completeDragSelection(),
              onHorizontalDragCancel: _completeDragSelection,
              child: SizedBox(
                width: navWidth,
                height: 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Liquid glass background (no blur)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [navBg1, navBg2],
                            ),
                            border: Border.all(color: borderColor, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Sliding indicator - TabController'ın animasyonunu direkt kullan
                    AnimatedBuilder(
                      animation:
                          widget.tabController.animation ??
                          AlwaysStoppedAnimation(
                            widget.tabController.index.toDouble(),
                          ),
                      builder: (context, child) {
                        final animationValue =
                            (_dragProgress ??
                                    widget.tabController.animation?.value ??
                                    widget.tabController.index.toDouble())
                                .clamp(0.0, 3.0);
                        final indicatorCenter =
                            (animationValue * itemWidth) + (itemWidth / 2);
                        final indicatorWidth = itemWidth - 12;
                        final indicatorLeft =
                            indicatorCenter - (indicatorWidth / 2);

                        final containerColor =
                            theme.colorScheme.onPrimaryContainer;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: indicatorLeft,
                              top: 4,
                              bottom: 4,
                              width: indicatorWidth,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: containerColor,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    // Tab buttons - Eşit genişlikte itemlar, seçili item'ın ikonu tam ortada
                    Positioned.fill(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTabButton(
                              context: context,
                              theme: theme,
                              index: 0,
                              icon: Icons.swipe_rounded,
                            ),
                          ),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final selectedTabIndex = context
                                    .watch<TabSelectionCubit>()
                                    .state;
                                return _buildTabButton(
                                  context: context,
                                  theme: theme,
                                  index: 1,
                                  customWidget: BlurTabIndicator(
                                    isSelected: selectedTabIndex == 1,
                                  ),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final selectedTabIndex = context
                                    .watch<TabSelectionCubit>()
                                    .state;
                                return _buildTabButton(
                                  context: context,
                                  theme: theme,
                                  index: 2,
                                  customWidget: DuplicateTabIndicator(
                                    isSelected: selectedTabIndex == 2,
                                  ),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: _buildTabButton(
                              context: context,
                              theme: theme,
                              index: 3,
                              icon: Icons.settings_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required BuildContext context,
    required ThemeData theme,
    required int index,
    IconData? icon,
    Widget? customWidget,
  }) {
    final selectedTabIndex = context.watch<TabSelectionCubit>().state;
    final isSelected = selectedTabIndex == index;

    final selectedIconColor = theme.colorScheme.surface;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () {
          widget.tabController.animateTo(index);
          context.read<TabSelectionCubit>().selectTab(index);
          widget.onTabTap(index);
        },
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 48,
          width: double.infinity,
          alignment: Alignment.center,
          child:
              customWidget ??
              Semantics(
                button: true,
                selected: isSelected,
                child: Icon(
                  icon,
                  size: isSelected ? 22 : 18,
                  color: isSelected
                      ? selectedIconColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
        ),
      ),
    );
  }
}

// Permission feature widget for permission request screen
class _PermissionFeature extends StatelessWidget {
  const _PermissionFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _showDeleteSuccessDialog(
  BuildContext context,
  int deletedCount, {
  double deletedSizeMB = 0.0,
}) async {
  debugPrint(
    '🎯 [SwipePage] _showDeleteSuccessDialog çağrıldı - deletedCount: $deletedCount, deletedSizeMB: $deletedSizeMB',
  );

  if (!context.mounted) {
    debugPrint(
      '❌ [SwipePage] Context not mounted at start, cannot show dialog',
    );
    return;
  }

  // Root context'i başta sakla - reklam akışından sonra kullanmak için
  final dialogContext = context;
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  // Premium kontrolü - premium kullanıcılar reklam görmesin
  debugPrint('🔍 [SwipePage] Checking premium status...');
  final prefsService = PreferencesService();
  final isPremium = await prefsService.isPremium();
  debugPrint('💰 [SwipePage] Premium status: $isPremium');

  // Premium değilse interstitial ad göster (önce ad, sonra dialog)
  // Ad başarısız olsa bile dialog mutlaka gösterilecek
  // Reklam zaten uygulama açılışında yüklenmiş olmalı
  if (!isPremium) {
    debugPrint('📱 [SwipePage] Non-premium user, showing interstitial ad...');
    try {
      final adService = InterstitialAdsService.instance;

      // Ad göster ve kapatılmasını bekle (timeout ile - maksimum 35 saniye bekle)
      // showAd zaten 30 saniye timeout'a sahip, ekstra 5 saniye buffer
      try {
        debugPrint('📱 [SwipePage] Attempting to show preloaded ad...');
        final adShown = await adService
            .showAd()
            .timeout(
              const Duration(seconds: 35),
              onTimeout: () {
                debugPrint(
                  '⚠️ [SwipePage] Ad showing timeout, continuing to show dialog',
                );
                return false;
              },
            )
            .catchError((e) {
              debugPrint(
                '⚠️ [SwipePage] Ad showing error: $e, continuing to show dialog',
              );
              return false;
            });

        debugPrint('📱 [SwipePage] Ad shown result: $adShown');

        if (adShown == true) {
          // Ad kapatıldı, kısa bir bekleme sonra dialog göster
          debugPrint(
            '📱 [SwipePage] Ad was shown, waiting 500ms before dialog...',
          );
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          debugPrint(
            '📱 [SwipePage] Ad was not shown, proceeding to dialog...',
          );
        }
      } catch (e) {
        debugPrint(
          '⚠️ [SwipePage] Error showing ad: $e, continuing to show dialog',
        );
        // Hata olsa bile devam et
      }
    } catch (e) {
      debugPrint(
        '⚠️ [SwipePage] Error in ad flow: $e, continuing to show dialog',
      );
      // Hata olsa bile dialog göster
    }
  } else {
    debugPrint('💰 [SwipePage] Premium user, skipping ad...');
  }

  // Dialog'u göster (ad gösterilmiş olsun veya olmasın - HER KOŞULDA)
  // dialogContext başta saklandı, async gap sonrası kullanım güvenli
  debugPrint(
    '✅ [SwipePage] Showing cleanup complete dialog - deletedCount: $deletedCount',
  );

  try {
    debugPrint('🎬 [SwipePage] Calling showDialog...');
    await Future.delayed(const Duration(milliseconds: 100)); // Kısa bir bekleme
    await showDialog(
      context: dialogContext, // ignore: use_build_context_synchronously
      useRootNavigator: true, // Root navigator kullan
      barrierDismissible: true,
      barrierColor: AppColors.black.withValues(alpha: 0.5),
      builder: (dialogContext) {
        debugPrint('🎬 [SwipePage] Dialog builder called');

        // Bottom navigation bar'daki container rengiyle aynı
        final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
          alpha: 0.8,
        );

        return Dialog(
          backgroundColor: AppColors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.85 + (value * 0.15),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Stack(
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.2),
                        blurRadius: 32,
                        spreadRadius: 0,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Success icon with background - New Year themed
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.2,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        l10n.cleanupComplete,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      // Stats container
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$deletedCount ${deletedCount == 1 ? l10n.photo : l10n.photos}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.storage_outlined,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.mbFreed(
                                    deletedSizeMB.toStringAsFixed(1),
                                  ),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.cleanupCompleteMessageWithCountAndSize(
                          deletedCount,
                          deletedSizeMB.toStringAsFixed(1),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                          fontSize: 15,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Done button - 3D button
                      AppThreeDButton(
                        label: l10n.done,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        baseColor: containerColor,
                        textColor: AppColors.white,
                        fullWidth: true,
                        height: 56,
                      ),
                    ],
                  ),
                ),
                // Decorative New Year elements
              ],
            ),
          ),
        );
      },
    );
    debugPrint('✅ [SwipePage] showDialog completed successfully');
  } catch (e, stackTrace) {
    debugPrint('❌ [SwipePage] Error showing dialog: $e');
    debugPrint('❌ [SwipePage] Stack trace: $stackTrace');
  }
}

/// İlk paywall dialog widget'ı - StatefulWidget olarak satın alma işlemi yapabilir
class _FirstPaywallDialog extends StatefulWidget {
  const _FirstPaywallDialog({required this.onPurchaseComplete});

  final VoidCallback onPurchaseComplete;

  @override
  State<_FirstPaywallDialog> createState() => _FirstPaywallDialogState();
}

class _FirstPaywallDialogState extends State<_FirstPaywallDialog>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
  String? _productPrice;
  String? _originalPrice;
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

    _loadProductInfo();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadProductInfo() async {
    try {
      final rc = RevenueCatService.instance;
      await rc.initialize();

      // Paket bilgisini al
      final package = await rc.fetchLifetimePackage();
      if (package != null) {
        final product = package.storeProduct;
        final priceString = product.priceString;
        final priceValue = _parsePrice(priceString);

        if (mounted) {
          setState(() {
            if (priceValue != null) {
              // %25 indirim göster
              final increasedPrice = priceValue * 1.25;
              final currencySymbol = _extractCurrencySymbol(priceString);
              _originalPrice =
                  '$currencySymbol${increasedPrice.toStringAsFixed(2)}';
              _productPrice = priceString;
            } else {
              _productPrice = priceString;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ [FirstPaywallDialog] Error loading product info: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load product information';
        });
      }
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
      _errorMessage = null;
    });

    try {
      final rc = RevenueCatService.instance;
      await rc.initialize();

      if (await rc.isPremium()) {
        await _handlePremiumUnlocked();
        return;
      }

      final success = await rc.purchaseLifetime();
      if (!mounted) return;

      if (success) {
        await _handlePremiumUnlocked();
      } else {
        final premiumNow = await rc.isPremium();
        if (premiumNow) {
          await _handlePremiumUnlocked();
        } else {
          setState(() {
            _errorMessage = l10n.failedToInitiatePurchase;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${l10n.purchaseError}: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePremiumUnlocked() async {
    if (!mounted) return;

    // Premium cubit'leri refresh et
    context.read<PremiumCubit>().refresh();
    context.read<GeneralScanLimitCubit>().refresh();
    await context.read<DeleteLimitCubit>().refresh();

    // Dialog'u kapat
    if (!mounted) return;
    Navigator.of(context).pop();

    // Premium success dialog göster
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        try {
          await PremiumSuccessDialog.show(context);
          widget.onPurchaseComplete();
        } catch (e) {
          debugPrint(
            '⚠️ [FirstPaywallDialog] Error showing success dialog: $e',
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final pricePrimaryTextColor = AppColors.textPrimary(theme.brightness);
    final priceSecondaryTextColor = AppColors.textSecondary(theme.brightness);
    // Dinamik container rengi (premium durumuna göre)
    final containerColor = theme.colorScheme.onPrimaryContainer.withValues(
      alpha: 0.8,
    );

    return Dialog(
      backgroundColor: AppColors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Dekoratif arka plan desenleri
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      containerColor.withValues(alpha: 0.15),
                      containerColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.12),
                      AppColors.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: 20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.1),
                      AppColors.secondary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Ana içerik
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24), // Spacer for centering
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                        color: theme.colorScheme.onSurface,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Premium Görsel (Icon + Gradient Container) - Daha küçük ve yukarıda
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        containerColor.withValues(alpha: 0.2),
                        AppColors.accent.withValues(alpha: 0.15),
                        AppColors.secondary.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: containerColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: containerColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 40,
                    color: containerColor,
                  ),
                ),
                const SizedBox(height: 12),
                // Satın almaya yönlendirici cümle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    l10n.unlockPremiumFeatures,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                // Compact Features (2-3 özellik)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCompactFeatureItem(
                        theme,
                        Icons.auto_delete_rounded,
                        l10n.unlimitedDeletions,
                        containerColor,
                      ),
                      const SizedBox(height: 8),
                      _buildCompactFeatureItem(
                        theme,
                        Icons.scanner_rounded,
                        l10n.unlimitedScans,
                        containerColor,
                      ),
                      const SizedBox(height: 8),
                      _buildCompactFeatureItem(
                        theme,
                        Icons.block_rounded,
                        l10n.noAds,
                        containerColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // One-time Offer Badge ve %25 OFF Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        l10n.oneTimeOffer,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.success,
                            AppColors.success.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_offer_rounded,
                            size: 14,
                            color: AppColors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.discount25Short,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.5,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Price section (paywall_page.dart stili)
                if (_productPrice != null && _originalPrice != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
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
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 120,
                                    ),
                                    child: Text(
                                      _originalPrice!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            decorationThickness: 2,
                                            decorationColor:
                                                priceSecondaryTextColor
                                                    .withValues(
                                                      alpha: isDark ? 0.8 : 0.7,
                                                    ),
                                            color: priceSecondaryTextColor
                                                .withValues(
                                                  alpha: isDark ? 0.85 : 0.65,
                                                ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.success.withValues(
                                          alpha: 0.4,
                                        ),
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          flex: 1,
                          fit: FlexFit.loose,
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale:
                                    0.98 + (_pulseAnimation.value - 1) * 0.02,
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
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Error message
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
                  const SizedBox(height: 12),
                ],
                // Upgrade button (paywall_page.dart stili - gradient, pulse)
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
                                offset: Offset(0, 10 * _pulseAnimation.value),
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
                                                  AlwaysStoppedAnimation<Color>(
                                                    theme.colorScheme.onPrimary,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            l10n.processing,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: theme.colorScheme.surface,
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
                // Maybe Later button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: AppColors.transparent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.maybeLater,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.noSubscriptionsNoFees,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFeatureItem(
    ThemeData theme,
    IconData icon,
    String text,
    Color containerColor,
  ) {
    final color = containerColor;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.2,
                  ),
                ]
              : [
                  theme.colorScheme.surface.withValues(alpha: 0.95),
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.15 : 0.12),
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.12),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.2,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(Icons.check_rounded, size: 12, color: color),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:lottie/lottie.dart';
import '../../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../app/theme/app_three_d_button.dart';
import '../../../../../../../app/theme/app_colors.dart';

// Album Selection Sheet
class AlbumSelectionSheet extends StatelessWidget {
  const AlbumSelectionSheet({required this.albums});

  final List<pm.AssetPathEntity> albums;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Temalı renkler
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          // Arka plan kar efekti
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  AppColors.white,
                  BlendMode.srcATop,
                ),
                child: Lottie.asset(
                  'assets/new_year/Snowing.json',
                  fit: BoxFit.cover,
                  repeat: true,
                ),
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary.withOpacity(0.12),
                  primary.withOpacity(0.06),
                  surface.withOpacity(0.9),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: primary.withOpacity(0.25),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primary.withOpacity(0.3),
                              primary.withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primary.withOpacity(0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Image.asset(
                          'assets/new_year/christmas-tree.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.selectAlbum,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: -0.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: albums.length,
                    physics: const BouncingScrollPhysics(),
                    itemExtent: 68,
                    cacheExtent: 400,
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primary.withOpacity(0.25),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/new_year/gift-box.png',
                              width: 22,
                              height: 22,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        title: Text(
                          album.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        onTap: () {
                          Navigator.of(context).pop(album);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: AppThreeDButton(
                    label: l10n.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                    baseColor: primary,
                    textColor: AppColors.white,
                    fullWidth: true,
                    height: 52,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

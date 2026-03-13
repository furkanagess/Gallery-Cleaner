part of 'swipe_page.dart';

/// Paywall, bildirim ve sonuç sayfası navigasyon mantığını yöneten mixin.
mixin SwipePagePaywallAndNavigationMixin<T extends StatefulWidget>
    on State<T> {
  /// İlk açılışta paywall dialog göster
  Future<void> _checkAndShowFirstPaywall() async {
    if (!mounted) return;

    try {
      final prefsService = PreferencesService();

      // İlk paywall zaten gösterildi mi kontrol et
      final isFirstPaywallShown = await prefsService.isFirstPaywallShown();
      if (isFirstPaywallShown) {
        debugPrint(
          '📱 [SwipePage] First paywall already shown, skipping...',
        );
        return;
      }

      // Premium kullanıcı mı kontrol et
      final isPremium = await prefsService.isPremium();
      if (isPremium) {
        debugPrint(
          '📱 [SwipePage] User is premium, skipping first paywall...',
        );
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

  /// İlk paywall dialog'unu göster
  Future<void> _showFirstPaywallDialog() async {
    if (!mounted) return;

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

  /// Interstitial reklam eşiği aşıldığında premium dialog'u göster
  void _showPremiumDialog() {
    if (!mounted) return;
    debugPrint(
      '💰 [SwipePage] Showing first paywall dialog after 3 interstitial ads',
    );
    _showFirstPaywallDialog();
  }

  /// Scan tamamlandı bildirimi gönder (güvenli ve async)
  Future<void> _sendScanCompletedNotification(String scanType) async {
    try {
      debugPrint(
        '📱 [SwipePage] Starting notification send process for: $scanType',
      );

      if (!mounted) {
        debugPrint(
          '⚠️ [SwipePage] Widget not mounted, skipping notification',
        );
        return;
      }

      debugPrint(
        '📱 [SwipePage] Widget is mounted, getting localizations...',
      );
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
      // Hata olsa bile uygulama akışını bozma
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
              debugPrint(
                '⚠️ [SwipePage] Ad error: $e, continuing...',
              );
              return false;
            });

        if (adShown == true) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        debugPrint('⚠️ [SwipePage] Error in ad flow: $e, continuing...');
      }
    }

    if (!mounted) return;

    // Kısa bir gecikme - state değişikliklerinin tamamlanmasını bekle
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    debugPrint('🚀 [SwipePage] Executing navigation to $route');
    try {
      context.push(route).then((_) {
        if (mounted) {
          // Bu flag asıl State sınıfında tanımlı; mixin aynı library'de olduğu için erişebilir
          // ignore: invalid_use_of_protected_member
          // (lint bastırmak için, runtime'da güvenli)
          // `_isNavigatingToResults` alanı _SwipePageState içinde.
          // Burada direkt atama yapılacak; derleyici bunu kabul ediyor çünkü aynı kütüphane.
          // Bu yorum sadece niyet açıklaması; davranışı değiştirmez.
          // ignore: unnecessary_statements
          (_this as dynamic)._isNavigatingToResults = false;
        }
      });
    } catch (e) {
      debugPrint('❌ [SwipePage] Navigation error: $e');
      if (mounted) {
        (_this as dynamic)._isNavigatingToResults = false;
      }
    }
  }

  // Mixin içinden gerçek State instance'ına erişmek için yardımcı getter.
  State<T> get _this => this;
}


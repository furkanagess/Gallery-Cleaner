// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Galeri Temizleyici';

  @override
  String get settings => 'Ayarlar';

  @override
  String get theme => 'Tema';

  @override
  String get light => 'Açık';

  @override
  String get dark => 'Koyu';

  @override
  String get system => 'Sistem';

  @override
  String get language => 'Dil';

  @override
  String get turkish => 'Türkçe';

  @override
  String get english => 'İngilizce';

  @override
  String get spanish => 'İspanyolca';

  @override
  String get galleryPermissionRequired => 'Galeri izni gerekli.';

  @override
  String get grantPermission => 'İzin Ver';

  @override
  String get folderTargets => 'Klasör Hedefleri';

  @override
  String get history => 'Geçmiş';

  @override
  String get swipeLeftToDelete => 'Sola kaydır: Sil';

  @override
  String get swipeRightToKeep => 'Sağa kaydır: Tut';

  @override
  String get noPhotosToShow => 'Gösterilecek fotoğraf yok.';

  @override
  String get selectAlbum => 'Albüm Seç';

  @override
  String get selectAlbumToView => 'Görüntülenecek Albüm Seç';

  @override
  String get allPhotos => 'Tüm Fotoğraflar';

  @override
  String get changeAlbum => 'Albüm Değiştir';

  @override
  String get dragPhotoHere => 'Fotoğrafı buraya sürükleyin';

  @override
  String get albumNotFound => 'Albüm bulunamadı';

  @override
  String movingToAlbum(String album) {
    return '$album albümüne taşınıyor...';
  }

  @override
  String movedToAlbum(String album) {
    return '$album albümüne taşındı';
  }

  @override
  String get moveToAlbumFailed =>
      'Albüme taşıma başarısız oldu. Lütfen tekrar deneyin.';

  @override
  String deleteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return '$countString Sil';
  }

  @override
  String deletePhotos(int count) {
    return 'Fotoğrafları sil ($count)';
  }

  @override
  String get applyDeletions => 'Silme İşlemlerini Uygula';

  @override
  String get undo => 'Geri Al';

  @override
  String get deleteLimitTitle => '100 Görsel Silme Hakkı';

  @override
  String get dailyDeleteLimit => 'Günlük silme limitiniz: 100 görsel';

  @override
  String get undoAll => 'Hepsini Geri Al';

  @override
  String get historyAndQueue => 'İstatistikler';

  @override
  String get noHistoryYet => 'Henüz İstatistik Yok';

  @override
  String get noHistoryYetDescription =>
      'Fotoğraflarınızı gözden geçirmeye ve düzenlemeye başlayın, aktivitelerinizi ve istatistiklerinizi burada görün.';

  @override
  String get keep => 'TUT';

  @override
  String get delete => 'SİL';

  @override
  String get move => 'TAŞI';

  @override
  String get pending => 'Bekliyor';

  @override
  String get applied => 'Uygulandı';

  @override
  String get undone => 'Geri Alındı';

  @override
  String get undoAllButton => 'Hepsini Undo';

  @override
  String deletedSuccessfully(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return '$countString fotoğraf başarıyla silindi.';
  }

  @override
  String get success => 'Başarılı!';

  @override
  String get ok => 'Tamam';

  @override
  String get startCleaning => 'Galerini\ntemizlemeye başla';

  @override
  String get swipeCardsDescription =>
      'Kartları sağa kaydır: Tut • sola kaydır: Sil. Üst hedeflere sürükleyerek klasörlere taşı.';

  @override
  String get quickSwipe => 'Hızlı swipe';

  @override
  String get dragToFolder => 'Klasöre sürükle';

  @override
  String get undoSafety => 'Undo güvenliği';

  @override
  String get galleryInfo => 'Galeri Bilgileri';

  @override
  String get album => 'Albüm';

  @override
  String get photoVideo => 'Fotoğraf & Video';

  @override
  String get totalSize => 'Toplam Boyut';

  @override
  String get galleryInfoLoading => 'Galeri bilgileri yükleniyor...';

  @override
  String get loadingMayTakeFewSeconds =>
      'Bu işlem birkaç saniye sürebilir lütfen bekleyiniz';

  @override
  String get galleryInfoNotAvailable => 'Galeri bilgileri alınamadı';

  @override
  String get tryAgain => 'Tekrar Dene';

  @override
  String get startCleaningButton => 'Temizlemeye Başla';

  @override
  String get loading => 'Yükleniyor...';

  @override
  String get galleryInfoNotLoaded => 'Galeri bilgileri yüklenemedi';

  @override
  String get grantPermissionToStart =>
      'Başlamak için fotoğraf erişimine izin ver';

  @override
  String get start => 'Başla';

  @override
  String get managePermissionsInSettings => 'İzinleri Ayarlarda Yönet';

  @override
  String get iosDeleteNote =>
      'iOS\'ta silmeler \"Recently Deleted\"e taşınır ve 30 gün içinde geri alınabilir.';

  @override
  String get swipeLeftToDeleteTitle =>
      'Sola Kaydırarak Sil,\nSağa Kaydırarak Tut';

  @override
  String get swipeLeftToDeleteDescription =>
      'Fotoğraflarınızı hızlca gözden geçirmek için kartları sağa veya sola kaydırın. Sağa kaydırarak tutun, sola kaydırarak silin.';

  @override
  String get organizeAlbumsTitle => 'Albümlerini\nOrganize Et';

  @override
  String get organizeAlbumsDescription =>
      'Fotoğraflarınızı üstteki albümlere sürükleyerek düzenleyin. Klasörlerinizi organize edin ve fotoğraflarınızı istediğiniz yere taşıyın.';

  @override
  String get deleteUselessPhotosTitle => 'Kullanışsız Kötü\nFotoğrafları Sil';

  @override
  String get deleteUselessPhotosDescription =>
      'Telefonunda yer açmak için bulanık, yanlış çekilmiş veya gereksiz fotoğrafları silin. Depolama alanınızı temizleyin ve daha fazla yer açın.';

  @override
  String get skip => 'Atla';

  @override
  String get continueButton => 'Devam Et';

  @override
  String get startButton => 'Başla';

  @override
  String get galleryPermission => 'Galeri İzni';

  @override
  String get photoLibraryAccessRequired =>
      'Fotoğraf kütüphanesine erişim gerekli';

  @override
  String get permissionRequestDescription =>
      'Swipe ile düzenlemek için fotoğraflarına erişim iznine ihtiyacımız var. İstediğin zaman ayarlardan yönetebilirsin.';

  @override
  String get allowAccess => 'İzin Ver';

  @override
  String get openSettings => 'Ayarları Aç';

  @override
  String get checkAgain => 'Yeniden Kontrol Et';

  @override
  String get weNeedYourAccess => 'Erişiminize ihtiyacımız var';

  @override
  String get recentlyDeleted => 'Son Silinen Fotoğraflar';

  @override
  String get restorePhoto => 'Fotoğrafı Geri Al';

  @override
  String get restorePhotoMessage =>
      'Bu fotoğraf geri alınacak. Devam etmek istiyor musunuz?';

  @override
  String get cancel => 'İptal';

  @override
  String get restore => 'Geri Al';

  @override
  String get photoRestored => 'Fotoğraf geri alındı';

  @override
  String get remainingDeletionRights => 'Kalan Silme';

  @override
  String get watchAdToEarn => 'Reklam İzle';

  @override
  String get adNotReady =>
      'Reklam henüz hazır değil. Lütfen birkaç saniye sonra tekrar deneyin.';

  @override
  String get earnDeletionRights => '+20 Silme';

  @override
  String get watchAdAndEarnDeletionRights => '+20 Silme';

  @override
  String get galleryPermissionDescription =>
      'Galeri temizleme işlemlerini yapabilmek için fotoğraf ve videolarınıza erişim iznine ihtiyacımız var.';

  @override
  String get quickCleanupTitle => 'Hızlı Temizlik';

  @override
  String get quickCleanupDescription =>
      'Fotoğraflarınızı hızlıca gözden geçirin';

  @override
  String get organizeTitle => 'Organize Et';

  @override
  String get organizeDescription => 'Albümlerinize taşıyın ve düzenleyin';

  @override
  String get safeDeleteTitle => 'Güvenli Silme';

  @override
  String get safeDeleteDescription => 'Gereksiz fotoğrafları temizleyin';

  @override
  String get increaseDeletionRights => 'Silme Haklarını Artır';

  @override
  String get increaseScanRights => 'Tarama Haklarını Artır';

  @override
  String earnDeleteRights(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '+$amountString Silme';
  }

  @override
  String earnScanRights(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '+$amountString Tarama';
  }

  @override
  String get earnedDeletionRights => '20 silme hakkı kazandınız!';

  @override
  String get goPremium => 'Premium Ol';

  @override
  String get premiumTitle => 'Premium\'a Geç';

  @override
  String get unlockPremiumFeatures => 'Premium Özelliklerin Kilidini Aç';

  @override
  String get premiumDescription =>
      'Premium üyelik ile sınırsız silme hakkı kazanın ve tüm özelliklere erişin!';

  @override
  String get premiumFeatures => 'Premium Özellikler';

  @override
  String get unlimitedDeletions => 'Sınırsız silme hakkı';

  @override
  String get noAds => 'Reklamsız deneyim';

  @override
  String get prioritySupport => 'Öncelikli destek';

  @override
  String get upgradeNow => 'Şimdi Yükselt';

  @override
  String get maybeLater => 'Belki Daha Sonra';

  @override
  String get buyUnlimitedRights => 'Sınırsız Silme Satın Al';

  @override
  String get buyUnlimitedBlurRights => 'Sınırsız Blur Satın Al';

  @override
  String get buyUnlimitedDuplicateRights => 'Sınırsız Duplicate Satın Al';

  @override
  String get unlimitedBlurScans => 'Sınırsız Blur Taraması • Ömür Boyu Erişim';

  @override
  String get unlimitedDuplicateScans =>
      'Sınırsız Duplicate Taraması • Ömür Boyu Erişim';

  @override
  String get oneTimePayment => 'Tek Seferlik Ödeme';

  @override
  String get noMoreAds => 'Artık reklam yok';

  @override
  String get lifetimeAccess => 'Ömür boyu erişim';

  @override
  String get purchaseNow => 'Şimdi Satın Al';

  @override
  String get limitedTimeOffer => 'Sınırlı Süre';

  @override
  String get discount25 => '%25 İndirim';

  @override
  String get originalPrice => 'Orijinal Fiyat';

  @override
  String get saveNow => 'Şimdi Kazan';

  @override
  String get bestValue => 'En İyi Değer';

  @override
  String get purchaseSuccessful =>
      'Satın alma başarılı! Premium özelliklere erişebilirsiniz.';

  @override
  String get lifetimeAccessMessage => 'Artık ömür boyu bu haklara sahipsiniz!';

  @override
  String get youArePremium => 'Premium\'sunuz';

  @override
  String get active => 'AKTİF';

  @override
  String get premiumAccessDescription =>
      'Tüm premium özelliklere erişiminiz var. Sınırsız silme, tarama ve daha fazlası!';

  @override
  String get unlimited => 'Sınırsız';

  @override
  String get adFree => 'Reklamsız';

  @override
  String get priority => 'Öncelikli';

  @override
  String get paywallTitle =>
      'Daha Akıllı, Daha Temiz Bir Galerinin Kilidini Aç';

  @override
  String get paywallSubtitle =>
      'Yapay zekâ destekli temizlik. Tek seferlik ödeme. Ömür boyu erişim.';

  @override
  String get oneTimeOffer => 'TEK SEFERLİK TEKLİF';

  @override
  String get payOnceOwnForever => 'Bir kez öde. Sonsuza dek senin olsun.';

  @override
  String get discount25Short => '%25 İNDİRİM';

  @override
  String get upgradeToPremium => 'Premium’a Yükselt';

  @override
  String get continueWithFree => 'Ücretsiz sürüm ile devam et';

  @override
  String get noSubscriptionsNoFees => 'Abonelik yok. Gizli ücret yok.';

  @override
  String get featureUnlimitedDeletions => 'Sınırsız Silme';

  @override
  String get featureUnlimitedDeletionsDesc => 'Galerini limitsizce temizle.';

  @override
  String get featureAIDetection => 'YZ Blur ve Çift Tespit';

  @override
  String get featureAIDetectionDesc =>
      'İstemediğin fotoğrafları bul ve kaldır.';

  @override
  String get featureAutoClean => 'Akıllı Otomatik Temizlik Önerileri';

  @override
  String get featureAutoCleanDesc =>
      'YZ, silinmesi gerekenleri senin için önerir.';

  @override
  String get featureAdFree => 'Reklamsız Deneyim';

  @override
  String get featureAdFreeDesc => 'Kesintisiz, sade bir arayüzün tadını çıkar.';

  @override
  String get processing => 'İşleniyor...';

  @override
  String get storeNotAvailable => 'Mağaza kullanılamıyor';

  @override
  String get purchaseFailed => 'Satın alma başarısız. Lütfen tekrar deneyin.';

  @override
  String get failedToInitiatePurchase => 'Satın alma başlatılamadı';

  @override
  String get purchaseError => 'Satın alma hatası';

  @override
  String get purchasesRestoredSuccessfully =>
      'Satın alımlar başarıyla geri yüklendi!';

  @override
  String get noPreviousPurchases =>
      'Geri yüklenecek önceki satın alma bulunamadı.';

  @override
  String get restoreError => 'Geri yükleme hatası';

  @override
  String get restoring => 'Geri yükleniyor...';

  @override
  String get restorePurchases => 'Satın Alımları Geri Yükle';

  @override
  String get duplicatePhotos => 'Yinelenen Fotoğraflar';

  @override
  String get scanForDuplicates => 'Yinelenen Fotoğrafları Tara';

  @override
  String get scanningDuplicates => 'Yinelenen fotoğraflar taranıyor...';

  @override
  String get noDuplicatesFound => 'Yinelenen fotoğraf bulunamadı';

  @override
  String duplicatesFound(int count) {
    return '$count yinelenen grup bulundu';
  }

  @override
  String get totalDuplicates => 'Toplam Yinelenen';

  @override
  String get spaceToSave => 'Kazanılacak Alan';

  @override
  String get deleteDuplicates => 'Yinelenenleri Sil';

  @override
  String get selectAlbumsToScan => 'Taranacak Albümleri Seç';

  @override
  String get scanSelectedAlbums => 'Seçili Albümleri Tara';

  @override
  String get deleteAllDuplicates => 'Tüm Yinelenenleri Sil';

  @override
  String deleteAllDuplicatesMessage(int count) {
    return '$count yinelenen fotoğraf silinecek. Emin misiniz?';
  }

  @override
  String get deleteAllBlurryPhotos => 'Tüm Blurlu Fotoğrafları Sil';

  @override
  String deleteAllBlurryPhotosMessage(int count) {
    return '$count blurlu fotoğraf silinecek. Emin misiniz?';
  }

  @override
  String get startNewScan => 'Yeni Tarama Başlat';

  @override
  String get scanResults => 'Tarama Sonuçları';

  @override
  String get scanCompleted => 'Tarama Tamamlandı';

  @override
  String scanCompletedBlurMessage(int count) {
    return '$count blurlu fotoğraf bulundu';
  }

  @override
  String scanCompletedDuplicateMessage(int count) {
    return '$count duplicate grup bulundu';
  }

  @override
  String get noBlurryPhotosFound =>
      'Galerinizde blurlu veya pixelleşmiş fotoğraf bulunamadı.';

  @override
  String get noDuplicatePhotosFound =>
      'Galerinizde duplicate fotoğraf bulunamadı.';

  @override
  String get duplicateGroup => 'Yinelenen Grup';

  @override
  String photosInGroup(int count) {
    return '$count fotoğraf';
  }

  @override
  String get keepOldest => 'En Eski Korunacak';

  @override
  String scanningAlbum(String album) {
    return '$album taranıyor...';
  }

  @override
  String get noDeleteRightsLeft => 'Silme Hakkınız Kalmadı';

  @override
  String get noDeleteRightsLeftMessage =>
      'Silme hakkınız kalmadı. Galerinizi temizlemeye devam etmek için sınırsız silme hakkı satın alın.';

  @override
  String get galleryStatsTitle => 'Galeri İstatistikleri';

  @override
  String get stop => 'Durdur';

  @override
  String get spaceSaved => 'Kazanılan';

  @override
  String get lastAnalysis => 'Son analiz:';

  @override
  String get previousAnalysis => 'Önceki analiz:';

  @override
  String get mediaLabel => 'Medya';

  @override
  String get sizeLabel => 'Boyut';

  @override
  String get albumDetails => 'Albüm Detayları';

  @override
  String get mediaUnit => 'medya';

  @override
  String get ofGallery => 'galerinin';

  @override
  String get reAnalyze => 'Tekrardan Analiz Et';

  @override
  String get autoAnalyzeOnLaunch => 'Uygulama açılışında otomatik analiz';

  @override
  String get autoAnalyzeOnLaunchDescription =>
      'Uygulama açıldığında galeriyi otomatik olarak analiz et';

  @override
  String progressFormat(String albums, int media) {
    return '$albums albüm • $media medya';
  }

  @override
  String errorMessage(String error) {
    return 'Hata: $error';
  }

  @override
  String get deleteOperationFailed =>
      'Silme işlemi başarısız oldu. Lütfen tekrar deneyin.';

  @override
  String get blurPhotosTitle => 'Blurlu Fotoğraflar';

  @override
  String get blurDetectionTitle => 'Blur ve Pixelation Tespiti';

  @override
  String get blurPhotoDetection => 'Blurlu Fotoğraf Tespiti';

  @override
  String get blurDetectionDescription =>
      'Seçtiğiniz albümlerde blurlu ve pixelleşmiş fotoğrafları tespit edin';

  @override
  String get sensitivity => 'Hassasiyet';

  @override
  String thresholdLabel(String value) {
    return 'Threshold: $value';
  }

  @override
  String get thresholdDescription =>
      'Düşük değer = Daha fazla blur tespiti\nYüksek değer = Sadece çok blurlu fotoğraflar';

  @override
  String get sensitivityLow => 'Düşük';

  @override
  String get sensitivityMedium => 'Orta';

  @override
  String get sensitivityHigh => 'Yüksek';

  @override
  String get sensitivityDescription =>
      'Hassasiyet seviyesi, bulanık fotoğrafların tespit edilme oranını belirler. Düşük hassasiyet daha fazla fotoğraf tespit eder, yüksek hassasiyet sadece çok bulanık fotoğrafları bulur.';

  @override
  String get sensitivityLevelsDescription =>
      '• Düşük: Hafif bulanık fotoğrafları da tespit eder (daha fazla sonuç)\n• Orta: Orta seviye bulanık fotoğrafları tespit eder (dengeli)\n• Yüksek: Sadece çok bulanık fotoğrafları tespit eder (daha az sonuç)';

  @override
  String get currentSensitivity => 'Mevcut Hassasiyet';

  @override
  String get noScanRightsLeft => 'Tarama Hakkınız Kalmadı';

  @override
  String get albumSelection => 'Albüm Seçimi';

  @override
  String get startScan => 'Tarama Başlat';

  @override
  String get scanningBlurPhotos =>
      'Blurlu ve pixelleşmiş fotoğraflar taranıyor...';

  @override
  String get premiumScan => 'Premium Tarama';

  @override
  String get remainingScanRights => 'Kalan Tarama';

  @override
  String get scanLimit => 'Tarama Limiti';

  @override
  String get scanLimitLow => 'Tarama hakkınız azaldı! Premium\'a yükseltin.';

  @override
  String watchAdToGetScanLimit(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Reklam İzle +$amountString Tarama Hakkı';
  }

  @override
  String get photoUnit => 'fotoğraf';

  @override
  String get selectAlbumsAndScan => 'Albümleri seçip tarama yapın';

  @override
  String get noDuplicateGroupsFound => 'Duplicate grup bulunamadı';

  @override
  String stateInfo(int albums, int groups) {
    return '$albums albüm, $groups grup';
  }

  @override
  String get blurDetectionDescriptionFromAppBar =>
      'Yapay zeka destekli bulanık ve pixelleşmiş fotoğraf tespiti. Depolama alanınızı temizleyin ve kaliteli fotoğraflarınızı koruyun.';

  @override
  String get duplicateDetectionDescriptionFromAppBar =>
      'Yapay zeka destekli yinelenen fotoğraf tespiti. Gereksiz kopyaları temizleyerek depolama alanınızı optimize edin.';

  @override
  String get aiPowered => 'Yapay Zeka Destekli';

  @override
  String get listView => 'Liste görünümü';

  @override
  String get gridView => 'Grid görünümü';

  @override
  String get unknown => 'Bilinmeyen';

  @override
  String blurScoreLabel(String score) {
    return 'Blur: $score';
  }

  @override
  String pixelationScoreLabel(String score) {
    return 'Pixel: $score';
  }

  @override
  String get deletePhoto => 'Fotoğrafı Sil';

  @override
  String deletePhotoMessage(String type) {
    return 'Bu $type fotoğraf silinecek.';
  }

  @override
  String get close => 'Kapat';

  @override
  String deleteDuplicatesMessage(int count) {
    return '$count duplicate fotoğraf silinecek.';
  }

  @override
  String get noResultsFound => 'Sonuç bulunamadı';

  @override
  String get group => 'Grup';

  @override
  String get photo => 'Fotoğraf';

  @override
  String get blurry => 'Blurlu';

  @override
  String get pixelated => 'Pixelleşmiş';

  @override
  String get blurryAndPixelated => 'Blurlu ve Pixelleşmiş';

  @override
  String get sharp => 'Keskin';

  @override
  String get scanningDuplicatePhotos => 'Duplicate Fotoğraflar Taranıyor...';

  @override
  String get duplicatePhotoDetection => 'Duplicate Fotoğraf Tespiti';

  @override
  String get blurDetectionOnboardingTitle => 'Bulanık Fotoğrafları Tespit Et';

  @override
  String get blurDetectionOnboardingDescription =>
      'Galerinizdeki bulanık ve pixelleşmiş fotoğrafları otomatik olarak tespit edin. Bu fotoğrafları kolayca bulup silebilirsiniz.';

  @override
  String get duplicateDetectionOnboardingTitle => 'Aynı Fotoğrafları Bul';

  @override
  String get duplicateDetectionOnboardingDescription =>
      'Galerinizdeki tekrarlanan fotoğrafları akıllı algoritma ile tespit edin. Gereksiz kopyaları temizleyerek alan kazanın.';

  @override
  String get weNeedYourAccessTitle => 'Erişiminize\nİhtiyacımız Var';

  @override
  String get resetToStart => 'Galeri Başına Dön';

  @override
  String get swipeTab => 'Kaydır';

  @override
  String get blurTab => 'Bulanık';

  @override
  String get duplicateTab => 'Yinelenen';

  @override
  String get cleanupComplete => 'Temizlik Tamamlandı!';

  @override
  String get cleanupCompleteMessage =>
      'Seçilen tüm fotoğraflar başarıyla silindi. Galeriniz artık daha temiz ve hafif.';

  @override
  String cleanupCompleteMessageWithCount(int count) {
    return '$count fotoğraf başarıyla silindi. Galeriniz artık daha temiz ve hafif.';
  }

  @override
  String get done => 'Tamam';

  @override
  String get viewGallery => 'Galeriyi Görüntüle';

  @override
  String get scanRightNotUsed => 'Tarama hakkınız kullanılmadı';

  @override
  String get noBlurryPhotosFoundTitle => 'Blurlu Fotoğraf Bulunamadı';

  @override
  String get noDuplicatesFoundTitle => 'Duplicate Fotoğraf Bulunamadı';

  @override
  String get scanCompletedSuccessfully =>
      'Harika haber! Galeri taramanız başarıyla tamamlandı.';

  @override
  String get scanCompletedSuccessfullyDuplicate =>
      'Mükemmel! Galeri taramanız başarıyla tamamlandı.';

  @override
  String get rateApp => 'Uygulamayı Değerlendir';

  @override
  String get rateAppDescription =>
      'Uygulamayı beğendiniz mi? Lütfen mağazada bizi değerlendirin!';

  @override
  String get couldNotOpenStore => 'Mağaza açılamadı';
}

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
  String get noHistoryYet => 'Henüz geçmiş yok.';

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
  String get earnDeletionRights => '+20 Silme';

  @override
  String get adNotReady =>
      'Reklam henüz hazır değil. Lütfen birkaç saniye sonra tekrar deneyin.';

  @override
  String get earnedDeletionRights => '20 silme hakkı kazandınız!';

  @override
  String get goPremium => 'Premium Ol';

  @override
  String get premiumTitle => 'Premium\'a Geç';

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
  String get oneTimePayment => 'Tek Seferlik Ödeme';

  @override
  String get noMoreAds => 'Artık reklam yok';

  @override
  String get lifetimeAccess => 'Ömür boyu erişim';

  @override
  String get purchaseNow => 'Şimdi Satın Al';
}

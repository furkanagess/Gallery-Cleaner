// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Gallery Cleaner';

  @override
  String get settings => 'Settings';

  @override
  String get theme => 'Theme';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';

  @override
  String get language => 'Language';

  @override
  String get turkish => 'Turkish';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Spanish';

  @override
  String get galleryPermissionRequired => 'Gallery permission required.';

  @override
  String get grantPermission => 'Grant Permission';

  @override
  String get folderTargets => 'Folder Targets';

  @override
  String get history => 'History';

  @override
  String get swipeLeftToDelete => 'Swipe left: Delete';

  @override
  String get swipeRightToKeep => 'Swipe right: Keep';

  @override
  String get noPhotosToShow => 'No photos to show.';

  @override
  String get selectAlbum => 'Select Album';

  @override
  String get selectAlbumToView => 'Select Album to View';

  @override
  String get allPhotos => 'All Photos';

  @override
  String get changeAlbum => 'Change Album';

  @override
  String get dragPhotoHere => 'Drag photo here';

  @override
  String get albumNotFound => 'Album not found';

  @override
  String movingToAlbum(String album) {
    return 'Moving to $album...';
  }

  @override
  String movedToAlbum(String album) {
    return 'Moved to $album';
  }

  @override
  String get moveToAlbumFailed => 'Failed to move to album. Please try again.';

  @override
  String deleteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return '$countString Delete';
  }

  @override
  String deletePhotos(int count) {
    return 'Delete Photos ($count)';
  }

  @override
  String get applyDeletions => 'Apply Deletions';

  @override
  String get undo => 'Undo';

  @override
  String get deleteLimitTitle => '100 Photo Delete Limit';

  @override
  String get dailyDeleteLimit => 'Your daily delete limit: 100 photos';

  @override
  String get undoAll => 'Undo All';

  @override
  String get historyAndQueue => 'Statistics';

  @override
  String get noHistoryYet => 'No history yet.';

  @override
  String get keep => 'KEEP';

  @override
  String get delete => 'DELETE';

  @override
  String get move => 'MOVE';

  @override
  String get pending => 'Pending';

  @override
  String get applied => 'Applied';

  @override
  String get undone => 'Undone';

  @override
  String get undoAllButton => 'Undo All';

  @override
  String deletedSuccessfully(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return '$countString photos deleted successfully.';
  }

  @override
  String get success => 'Success!';

  @override
  String get ok => 'OK';

  @override
  String get startCleaning => 'Start cleaning your gallery';

  @override
  String get swipeCardsDescription =>
      'Swipe cards right: Keep • left: Delete. Drag to top targets to move to folders.';

  @override
  String get quickSwipe => 'Quick swipe';

  @override
  String get dragToFolder => 'Drag to folder';

  @override
  String get undoSafety => 'Undo safety';

  @override
  String get galleryInfo => 'Gallery Info';

  @override
  String get album => 'Album';

  @override
  String get photoVideo => 'Photos & Videos';

  @override
  String get totalSize => 'Total Size';

  @override
  String get galleryInfoLoading => 'Loading gallery info...';

  @override
  String get loadingMayTakeFewSeconds =>
      'This process may take a few seconds, please wait';

  @override
  String get galleryInfoNotAvailable => 'Gallery info not available';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get startCleaningButton => 'Start Cleaning';

  @override
  String get loading => 'Loading...';

  @override
  String get galleryInfoNotLoaded => 'Gallery info could not be loaded';

  @override
  String get grantPermissionToStart => 'Grant photo access permission to start';

  @override
  String get start => 'Start';

  @override
  String get managePermissionsInSettings => 'Manage Permissions in Settings';

  @override
  String get iosDeleteNote =>
      'On iOS, deletions are moved to \"Recently Deleted\" and can be recovered within 30 days.';

  @override
  String get swipeLeftToDeleteTitle =>
      'Swipe Left to Delete,\nSwipe Right to Keep';

  @override
  String get swipeLeftToDeleteDescription =>
      'Quickly review your photos by swiping cards left or right. Swipe right to keep, swipe left to delete.';

  @override
  String get organizeAlbumsTitle => 'Organize Your\nAlbums';

  @override
  String get organizeAlbumsDescription =>
      'Drag your photos to the albums above to organize them. Organize your folders and move your photos wherever you want.';

  @override
  String get deleteUselessPhotosTitle => 'Delete Useless Bad\nPhotos';

  @override
  String get deleteUselessPhotosDescription =>
      'Delete blurry, incorrectly taken, or unnecessary photos to free up space on your phone. Clean up your storage and make more room.';

  @override
  String get skip => 'Skip';

  @override
  String get continueButton => 'Continue';

  @override
  String get startButton => 'Start';

  @override
  String get galleryPermission => 'Gallery Permission';

  @override
  String get photoLibraryAccessRequired => 'Photo library access is required';

  @override
  String get permissionRequestDescription =>
      'We need access to your photos to organize with swipe. You can manage this anytime from settings.';

  @override
  String get allowAccess => 'Allow Access';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get checkAgain => 'Check Again';

  @override
  String get weNeedYourAccess => 'We need your access';

  @override
  String get recentlyDeleted => 'Recently Deleted Photos';

  @override
  String get restorePhoto => 'Restore Photo';

  @override
  String get restorePhotoMessage =>
      'This photo will be restored. Do you want to continue?';

  @override
  String get cancel => 'Cancel';

  @override
  String get restore => 'Restore';

  @override
  String get photoRestored => 'Photo restored';

  @override
  String get remainingDeletionRights => 'Remaining Deletion';

  @override
  String get watchAdToEarn => 'Watch Ad';

  @override
  String get earnDeletionRights => '+20 Deletions';

  @override
  String get adNotReady =>
      'Ad is not ready yet. Please try again in a few seconds.';

  @override
  String get earnedDeletionRights => 'You earned 20 deletion rights!';

  @override
  String get goPremium => 'Go Premium';

  @override
  String get premiumTitle => 'Go Premium';

  @override
  String get premiumDescription =>
      'Get unlimited deletion rights and access to all features with Premium membership!';

  @override
  String get premiumFeatures => 'Premium Features';

  @override
  String get unlimitedDeletions => 'Unlimited deletion rights';

  @override
  String get noAds => 'Ad-free experience';

  @override
  String get prioritySupport => 'Priority support';

  @override
  String get upgradeNow => 'Upgrade Now';

  @override
  String get maybeLater => 'Maybe Later';

  @override
  String get buyUnlimitedRights => 'Buy Unlimited Deletion';

  @override
  String get oneTimePayment => 'One-Time Payment';

  @override
  String get noMoreAds => 'No more ads';

  @override
  String get lifetimeAccess => 'Lifetime access';

  @override
  String get purchaseNow => 'Purchase Now';
}

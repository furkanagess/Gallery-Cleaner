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
  String get selectAlbumToView => 'Select the album you want to view';

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
  String get noHistoryYet => 'No Statistics Yet';

  @override
  String get noHistoryYetDescription =>
      'Start reviewing and organizing your photos to see your activity and statistics here.';

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
  String get loadingYourGallery => 'Loading Your Gallery';

  @override
  String get loadingYourGalleryDescription =>
      'We are preparing your photos and videos. Please wait...';

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
  String get adNotReady => 'Ad Loading...';

  @override
  String get earnDeletionRights => '+20 Deletions';

  @override
  String get watchAdAndEarnDeletionRights => '+20 Deletions';

  @override
  String get galleryPermissionDescription =>
      'We need access to your photos and videos to perform gallery cleaning operations.';

  @override
  String get privacySecurityInfo => '🔒 Your Privacy Matters';

  @override
  String get privacySecurityPoint1 =>
      'Your photos and videos are never shared with anyone';

  @override
  String get privacySecurityPoint2 =>
      'All processing happens only on your device';

  @override
  String get privacySecurityPoint3 =>
      'We do not collect, store, or transmit any of your personal media';

  @override
  String get quickCleanupTitle => 'Quick Cleanup';

  @override
  String get quickCleanupDescription => 'Quickly review your photos';

  @override
  String get organizeTitle => 'Organize';

  @override
  String get organizeDescription => 'Move and organize to your albums';

  @override
  String get safeDeleteTitle => 'Safe Delete';

  @override
  String get safeDeleteDescription => 'Clean up unnecessary photos';

  @override
  String get increaseDeletionRights => 'Increase Deletion Rights';

  @override
  String get increaseScanRights => 'Increase Scan Rights';

  @override
  String earnDeleteRights(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '+$amountString Deletions';
  }

  @override
  String earnScanRights(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '+$amountString Scans';
  }

  @override
  String get earnedDeletionRights => 'You earned 20 deletion rights!';

  @override
  String get goPremium => 'Go Premium';

  @override
  String get premiumTitle => 'Go Premium';

  @override
  String get unlockPremiumFeatures => 'Unlock Premium Features';

  @override
  String get premiumDescription =>
      'Get unlimited deletion rights and access to all features with Premium membership!';

  @override
  String get premiumFeatures => 'Premium Features';

  @override
  String get unlimitedDeletions => 'Unlimited deletion rights';

  @override
  String get unlimitedScans => 'Unlimited Scans';

  @override
  String get noAds => 'Ad-free experience';

  @override
  String get allPremiumFeatures => 'All Premium Features';

  @override
  String get welcomeToPremium => 'Unlock all premium features:';

  @override
  String get prioritySupport => 'Priority support';

  @override
  String get upgradeNow => 'Upgrade Now';

  @override
  String get maybeLater => 'Maybe Later';

  @override
  String get buyUnlimitedRights => 'Buy Unlimited Deletion';

  @override
  String get buyUnlimitedBlurRights => 'Buy Unlimited Blur';

  @override
  String get buyUnlimitedDuplicateRights => 'Buy Unlimited Duplicate';

  @override
  String get unlimitedBlurScans => 'Unlimited Blur Scans • Lifetime Access';

  @override
  String get unlimitedDuplicateScans =>
      'Unlimited Duplicate Scans • Lifetime Access';

  @override
  String get oneTimePayment => 'One-Time Payment';

  @override
  String get noMoreAds => 'No more ads';

  @override
  String get lifetimeAccess => 'Lifetime access';

  @override
  String get purchaseNow => 'Purchase Now';

  @override
  String get limitedTimeOffer => 'Limited Time';

  @override
  String get discount25 => '25% Off';

  @override
  String get originalPrice => 'Original Price';

  @override
  String get saveNow => 'Save Now';

  @override
  String get bestValue => 'Best Value';

  @override
  String get purchaseSuccessful =>
      'Purchase successful! You now have access to premium features.';

  @override
  String get lifetimeAccessMessage =>
      'You now have lifetime access to these benefits!';

  @override
  String get youArePremium => 'You are Premium';

  @override
  String get active => 'ACTIVE';

  @override
  String get premiumAccessDescription =>
      'You have access to all premium features. Unlimited deletion, scanning, and more!';

  @override
  String get premiumActive => 'Premium Active!';

  @override
  String get premiumActiveMessage =>
      'Congratulations! Your premium membership is active. You now have access to all features.';

  @override
  String get startUsing => 'Start Using';

  @override
  String get unlimited => 'Unlimited';

  @override
  String get adFree => 'Ad-free';

  @override
  String get priority => 'Priority';

  @override
  String get paywallTitle => 'Unlock a Smarter, Cleaner Gallery';

  @override
  String get paywallSubtitle =>
      'AI-powered photo cleanup. One-time payment. Lifetime access.';

  @override
  String get oneTimeOffer => 'ONE-TIME OFFER';

  @override
  String get payOnceOwnForever => 'Pay once. Own it forever.';

  @override
  String get discount25Short => '25% OFF';

  @override
  String get upgradeToPremium => 'Upgrade to Premium';

  @override
  String get continueWithFree => 'Continue with Free Version';

  @override
  String get noSubscriptionsNoFees => 'No subscriptions. No hidden fees.';

  @override
  String get featureUnlimitedDeletions => 'Unlimited Deletions';

  @override
  String get featureUnlimitedDeletionsDesc =>
      'Clean your gallery without any limits.';

  @override
  String get featureAIDetection => 'AI Blur & Duplicate Detection';

  @override
  String get featureAIDetectionDesc => 'Find and remove unwanted photos.';

  @override
  String get featureAutoClean => 'Smart Auto-Clean Suggestions';

  @override
  String get featureAutoCleanDesc =>
      'Let our AI find photos to delete for you.';

  @override
  String get featureAdFree => 'Ad-Free Experience';

  @override
  String get featureAdFreeDesc => 'Enjoy a seamless, ad-free interface.';

  @override
  String get processing => 'Processing...';

  @override
  String get storeNotAvailable => 'Store is not available';

  @override
  String get purchaseFailed => 'Purchase failed. Please try again.';

  @override
  String get failedToInitiatePurchase => 'Failed to initiate purchase';

  @override
  String get purchaseError => 'Purchase error';

  @override
  String get purchasesRestoredSuccessfully =>
      'Purchases restored successfully!';

  @override
  String get noPreviousPurchases => 'No previous purchases found to restore.';

  @override
  String get restoreError => 'Restore error';

  @override
  String get restoring => 'Restoring...';

  @override
  String get restorePurchases => 'Restore Purchases';

  @override
  String get duplicatePhotos => 'Duplicate Photos';

  @override
  String get scanForDuplicates => 'Scan for Duplicates';

  @override
  String get scanningDuplicates => 'Scanning for duplicates...';

  @override
  String get noDuplicatesFound => 'No duplicate photos found';

  @override
  String duplicatesFound(int count) {
    return '$count duplicate groups found';
  }

  @override
  String get totalDuplicates => 'Total Duplicates';

  @override
  String get spaceToSave => 'Space to Save';

  @override
  String get deleteDuplicates => 'Delete Duplicates';

  @override
  String get selectAlbumsToScan => 'Select Albums to Scan';

  @override
  String get scanSelectedAlbums => 'Scan Selected Albums';

  @override
  String get deleteAllDuplicates => 'Delete All Duplicates';

  @override
  String deleteAllDuplicatesMessage(int count) {
    return '$count duplicate photos will be deleted. Are you sure?';
  }

  @override
  String get deleteAllBlurryPhotos => 'Delete All Blurry Photos';

  @override
  String deleteAllBlurryPhotosMessage(int count) {
    return '$count blurry photos will be deleted. Are you sure?';
  }

  @override
  String get startNewScan => 'Start New Scan';

  @override
  String get scanResults => 'Scan Results';

  @override
  String get scanCompleted => 'Scan Completed';

  @override
  String scanCompletedBlurMessage(int count) {
    return '$count blurry photos found';
  }

  @override
  String scanCompletedDuplicateMessage(int count) {
    return '$count duplicate groups found';
  }

  @override
  String get noBlurryPhotosFound =>
      'No blurry or pixelated photos found in your gallery.';

  @override
  String get noDuplicatePhotosFound =>
      'No duplicate photos found in your gallery.';

  @override
  String get duplicateGroup => 'Duplicate Group';

  @override
  String photosInGroup(int count) {
    return '$count photos';
  }

  @override
  String get keepOldest => 'Keep Oldest';

  @override
  String scanningAlbum(String album) {
    return 'Scanning $album...';
  }

  @override
  String get noDeleteRightsLeft => 'No Deletion Rights Left';

  @override
  String get noDeleteRightsLeftMessage =>
      'You have no deletion rights left. Get unlimited deletion rights to continue cleaning your gallery.';

  @override
  String get galleryStatsTitle => 'Gallery Statistics';

  @override
  String get generalStatistics => 'General Statistics';

  @override
  String get totalPhotos => 'Total Photos';

  @override
  String get items => 'items';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get ago => 'ago';

  @override
  String get justNow => 'Just now';

  @override
  String get stop => 'Stop';

  @override
  String get spaceSaved => 'Space Saved';

  @override
  String get lastAnalysis => 'Last analysis:';

  @override
  String get previousAnalysis => 'Previous analysis:';

  @override
  String get mediaLabel => 'Media';

  @override
  String get sizeLabel => 'Size';

  @override
  String get albumDetails => 'Album Details';

  @override
  String get mediaUnit => 'media';

  @override
  String get ofGallery => 'of gallery';

  @override
  String get reAnalyze => 'Re-analyze';

  @override
  String get autoAnalyzeOnLaunch => 'Auto-analyze on launch';

  @override
  String get autoAnalyzeOnLaunchDescription =>
      'Automatically analyze gallery when app opens';

  @override
  String progressFormat(String albums, int media) {
    return '$albums albums • $media media';
  }

  @override
  String errorMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get deleteOperationFailed =>
      'Delete operation failed. Please try again.';

  @override
  String get blurPhotosTitle => 'Blurry Photos';

  @override
  String get blurDetectionTitle => 'Blur and Pixelation Detection';

  @override
  String get blurPhotoDetection => 'Blurry Photo Detection';

  @override
  String get blurDetectionDescription =>
      'Detect blurry and pixelated photos in selected albums';

  @override
  String get sensitivity => 'Sensitivity';

  @override
  String get duplicateMode => 'Mode';

  @override
  String thresholdLabel(String value) {
    return 'Threshold: $value';
  }

  @override
  String get thresholdDescription =>
      'Low value = More blur detection\nHigh value = Only very blurry photos';

  @override
  String get sensitivityLow => 'Low';

  @override
  String get sensitivityMedium => 'Medium';

  @override
  String get sensitivityHigh => 'High';

  @override
  String get sensitivityDescription =>
      'Sensitivity level determines how many blurry photos are detected. Low sensitivity detects more photos, high sensitivity only finds very blurry photos.';

  @override
  String get sensitivityLevelsDescription =>
      'Low: Detects slightly blurry photos as well (more results)\nMedium: Detects moderately blurry photos (balanced)\nHigh: Only detects very blurry photos (fewer results)';

  @override
  String get currentSensitivity => 'Current Sensitivity';

  @override
  String get noScanRightsLeft => 'No Scan Rights Left';

  @override
  String get albumSelection => 'Album Selection';

  @override
  String get startScan => 'Start Scan';

  @override
  String get scanningBlurPhotos => 'Scanning blurry and pixelated photos...';

  @override
  String get premiumScan => 'Premium Scan';

  @override
  String get remainingScanRights => 'Remaining Scan';

  @override
  String get scanLimit => 'Scan Limit';

  @override
  String get scanLimitLow =>
      'Your scan limit is running low! Upgrade to Premium.';

  @override
  String watchAdToGetScanLimit(int amount) {
    final intl.NumberFormat amountNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Watch Ad +$amountString Scan Limit';
  }

  @override
  String get photoUnit => 'photos';

  @override
  String get selectAlbumsAndScan => 'Select albums and scan';

  @override
  String get noDuplicateGroupsFound => 'No duplicate groups found';

  @override
  String stateInfo(int albums, int groups) {
    return '$albums albums, $groups groups';
  }

  @override
  String get blurDetectionDescriptionFromAppBar =>
      'AI-powered blurry and pixelated photo detection. Clean up your storage and keep only quality images.';

  @override
  String get duplicateDetectionDescriptionFromAppBar =>
      'AI-powered duplicate photo detection. Clean up unnecessary copies and optimize your storage space.';

  @override
  String get aiPowered => 'AI-Powered';

  @override
  String get listView => 'List view';

  @override
  String get gridView => 'Grid view';

  @override
  String get unknown => 'Unknown';

  @override
  String blurScoreLabel(String score) {
    return 'Blur: $score';
  }

  @override
  String pixelationScoreLabel(String score) {
    return 'Pixel: $score';
  }

  @override
  String get deletePhoto => 'Delete Photo';

  @override
  String deletePhotoMessage(String type) {
    return 'This $type photo will be deleted.';
  }

  @override
  String get close => 'Close';

  @override
  String deleteDuplicatesMessage(int count) {
    return '$count duplicate photos will be deleted.';
  }

  @override
  String get noResultsFound => 'No results found';

  @override
  String get group => 'Group';

  @override
  String get photo => 'Photo';

  @override
  String get blurry => 'Blurry';

  @override
  String get pixelated => 'Pixelated';

  @override
  String get blurryAndPixelated => 'Blurry and Pixelated';

  @override
  String get sharp => 'Sharp';

  @override
  String get scanningDuplicatePhotos => 'Scanning duplicate photos...';

  @override
  String get duplicatePhotoDetection => 'Duplicate Photo Detection';

  @override
  String get blurDetectionOnboardingTitle => 'Detect Blurry Photos';

  @override
  String get blurDetectionOnboardingDescription =>
      'Automatically detect blurry and pixelated photos in your gallery. You can easily find and delete these photos.';

  @override
  String get duplicateDetectionOnboardingTitle => 'Find Duplicate Photos';

  @override
  String get duplicateDetectionOnboardingDescription =>
      'Detect duplicate photos in your gallery with smart algorithm. Free up space by cleaning unnecessary copies.';

  @override
  String get weNeedYourAccessTitle => 'We Need Your\nAccess';

  @override
  String get resetToStart => 'Reset to Start';

  @override
  String get swipeTab => 'Swipe';

  @override
  String get blurTab => 'Blur';

  @override
  String get duplicateTab => 'Duplicate';

  @override
  String get cleanupComplete => 'Cleanup Complete!';

  @override
  String get cleanupCompleteMessage =>
      'All selected photos have been successfully deleted. Your gallery is now cleaner and lighter.';

  @override
  String cleanupCompleteMessageWithCount(int count) {
    return '$count photo(s) have been successfully deleted. Your gallery is now cleaner and lighter.';
  }

  @override
  String get done => 'Done';

  @override
  String get viewGallery => 'View Gallery';

  @override
  String get scanRightNotUsed => 'Your scan right was not used';

  @override
  String get noBlurryPhotosFoundTitle => 'No Blurry Photos Found';

  @override
  String get noDuplicatesFoundTitle => 'No Duplicates Found';

  @override
  String get scanCompletedSuccessfully => 'Scan completed successfully!';

  @override
  String get scanCompletedSuccessfullyDuplicate =>
      'Scan completed successfully!';

  @override
  String get openAppAndViewResults => 'Open the app and view results';

  @override
  String get rateApp => 'Rate App';

  @override
  String get rateAppDescription =>
      'Enjoying the app? Please rate us on the store!';

  @override
  String get couldNotOpenStore => 'Could not open store';

  @override
  String estimatedTimeSeconds(int seconds) {
    return '~$seconds seconds';
  }

  @override
  String estimatedTimeMinutes(int minutes) {
    return '~$minutes minutes';
  }

  @override
  String estimatedScanTime(String time) {
    return 'Estimated time: $time';
  }

  @override
  String maxPhotoLimitWarning(int count) {
    return 'Selected album contains $count photos. Maximum 1000 photos can be analyzed at once.';
  }

  @override
  String get confirmBlurScan => 'Start blur detection?';

  @override
  String get confirmBlurScanMessage =>
      'Blur detection will be performed on selected albums. Do you want to continue?';

  @override
  String get confirmDuplicateScan => 'Start duplicate detection?';

  @override
  String get confirmDuplicateScanMessage =>
      'Duplicate detection will be performed on selected albums. Do you want to continue?';

  @override
  String get scan => 'Scan';

  @override
  String get duplicateModeLowSpeedHighAccuracy => 'Low Speed\nHigh Accuracy';

  @override
  String get duplicateModeBalanced => 'Balanced';

  @override
  String get duplicateModeHighSpeedLowAccuracy => 'High Speed\nLow Accuracy';

  @override
  String get duplicateModeLevelsDescription =>
      'Low Speed/High Accuracy: Most accurate results, takes longer\nBalanced: Speed and accuracy balance\nHigh Speed/Low Accuracy: Fast results, less accurate';

  @override
  String get allPhotosReviewedTitle => 'All Photos Reviewed!';

  @override
  String get allPhotosReviewedDescription =>
      'Great job! You\'ve reviewed all available photos.';

  @override
  String get removeAdsAndUnlimitedDeletions =>
      'Remove Ads and Get Unlimited Deletion Rights';

  @override
  String get removeAdsAndUnlimitedDeletionsDescription =>
      'Upgrade to Premium and enjoy an ad-free experience with unlimited deletion rights forever!';

  @override
  String get doNotLeaveScreenDuringScan =>
      'Please do not leave this screen while the scan is in progress.';

  @override
  String get viewResults => 'View Results';

  @override
  String get viewLastResults => 'View Last Results';

  @override
  String get filterAndSort => 'Filter and Sort';

  @override
  String get filterAndSortDescription => 'Date range and sort options';

  @override
  String get dateRange => 'Date Range';

  @override
  String get startDate => 'Start';

  @override
  String get endDate => 'End';

  @override
  String get notSelected => 'Not Selected';

  @override
  String get clearDateFilter => 'Clear Date Filter';

  @override
  String get sort => 'Sort';

  @override
  String get newest => 'Newest';

  @override
  String get oldest => 'Oldest';

  @override
  String get apply => 'Apply';

  @override
  String get albumSettings => 'Album Settings';

  @override
  String get getUnlimitedScans => 'Get Unlimited Scans';

  @override
  String get noRightsLeft => 'No rights left';

  @override
  String get getUnlimitedDeletions => 'Get Unlimited Deletions';

  @override
  String get scanTip1 => '📱 Scroll through reels while we work!';

  @override
  String get scanTip2 => '☕ Grab a cup of coffee from the kitchen!';

  @override
  String get scanTip3 => '💌 Text your loved one while you wait!';

  @override
  String get scanTip4 => '📚 Read a book or an article!';

  @override
  String get scanTip5 => '🎵 Listen to your favorite music!';

  @override
  String get scanTip6 => '💬 Chat with your friends!';

  @override
  String get scanTip7 => '🌐 Browse social media!';

  @override
  String get scanTip8 => '🚶 Take a short walk around!';

  @override
  String get scanTip9 => '💧 Drink some water and stay hydrated!';

  @override
  String get scanTip10 => '👀 Rest your eyes for a moment!';

  @override
  String get scanTip11 => '🎧 Listen to a podcast!';

  @override
  String get scanTip12 => '🏠 Do some quick house chores!';

  @override
  String get scanTip13 => '🍿 Grab a snack!';

  @override
  String get scanTip14 => '📞 Call a friend or family member!';

  @override
  String get scanTip15 => '🎮 Play a quick game!';
}

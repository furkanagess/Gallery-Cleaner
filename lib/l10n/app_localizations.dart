import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('tr'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Gallery Cleaner'**
  String get appTitle;

  /// Settings page title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Theme section title
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// System theme option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// Language section title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Turkish language option
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get turkish;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Spanish language option
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// Message when gallery permission is required
  ///
  /// In en, this message translates to:
  /// **'Gallery permission required.'**
  String get galleryPermissionRequired;

  /// Button to grant permission
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get grantPermission;

  /// Folder targets tooltip
  ///
  /// In en, this message translates to:
  /// **'Folder Targets'**
  String get folderTargets;

  /// History button tooltip
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// Swipe left instruction
  ///
  /// In en, this message translates to:
  /// **'Swipe left: Delete'**
  String get swipeLeftToDelete;

  /// Swipe right instruction
  ///
  /// In en, this message translates to:
  /// **'Swipe right: Keep'**
  String get swipeRightToKeep;

  /// Message when there are no photos
  ///
  /// In en, this message translates to:
  /// **'No photos to show.'**
  String get noPhotosToShow;

  /// Album selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Album'**
  String get selectAlbum;

  /// Album selection bottom sheet description
  ///
  /// In en, this message translates to:
  /// **'Select the album you want to view'**
  String get selectAlbumToView;

  /// All photos option
  ///
  /// In en, this message translates to:
  /// **'All Photos'**
  String get allPhotos;

  /// Drop zone label for changing album
  ///
  /// In en, this message translates to:
  /// **'Change Album'**
  String get changeAlbum;

  /// No description provided for @dragPhotoHere.
  ///
  /// In en, this message translates to:
  /// **'Drag photo here'**
  String get dragPhotoHere;

  /// Message when album is not found
  ///
  /// In en, this message translates to:
  /// **'Album not found'**
  String get albumNotFound;

  /// Message when moving photo to album
  ///
  /// In en, this message translates to:
  /// **'Moving to {album}...'**
  String movingToAlbum(String album);

  /// Success message when photo is moved to album
  ///
  /// In en, this message translates to:
  /// **'Moved to {album}'**
  String movedToAlbum(String album);

  /// Error message when moving to album fails
  ///
  /// In en, this message translates to:
  /// **'Failed to move to album. Please try again.'**
  String get moveToAlbumFailed;

  /// Button text with delete count
  ///
  /// In en, this message translates to:
  /// **'{count} Delete'**
  String deleteCount(int count);

  /// Button text for deleting photos with count
  ///
  /// In en, this message translates to:
  /// **'Delete Photos ({count})'**
  String deletePhotos(int count);

  /// Button to apply pending deletions
  ///
  /// In en, this message translates to:
  /// **'Apply Deletions'**
  String get applyDeletions;

  /// Button to undo last action
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// Title for delete limit info
  ///
  /// In en, this message translates to:
  /// **'100 Photo Delete Limit'**
  String get deleteLimitTitle;

  /// Daily delete limit message
  ///
  /// In en, this message translates to:
  /// **'Your daily delete limit: 100 photos'**
  String get dailyDeleteLimit;

  /// Button to undo all pending actions
  ///
  /// In en, this message translates to:
  /// **'Undo All'**
  String get undoAll;

  /// Statistics page title
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get historyAndQueue;

  /// Title when there is no history
  ///
  /// In en, this message translates to:
  /// **'No Statistics Yet'**
  String get noHistoryYet;

  /// Description when there is no history
  ///
  /// In en, this message translates to:
  /// **'Start reviewing and organizing your photos to see your activity and statistics here.'**
  String get noHistoryYetDescription;

  /// Keep action type
  ///
  /// In en, this message translates to:
  /// **'KEEP'**
  String get keep;

  /// Delete action type
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get delete;

  /// Move action type
  ///
  /// In en, this message translates to:
  /// **'MOVE'**
  String get move;

  /// Pending status
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Applied status
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get applied;

  /// Undone status
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get undone;

  /// Button to undo all actions
  ///
  /// In en, this message translates to:
  /// **'Undo All'**
  String get undoAllButton;

  /// Success message when photos are deleted
  ///
  /// In en, this message translates to:
  /// **'{count} photos deleted successfully.'**
  String deletedSuccessfully(int count);

  /// Success dialog title
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get success;

  /// OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Title on start clean page
  ///
  /// In en, this message translates to:
  /// **'Start cleaning your gallery'**
  String get startCleaning;

  /// Description on start clean page
  ///
  /// In en, this message translates to:
  /// **'Swipe cards right: Keep • left: Delete. Drag to top targets to move to folders.'**
  String get swipeCardsDescription;

  /// Feature chip text
  ///
  /// In en, this message translates to:
  /// **'Quick swipe'**
  String get quickSwipe;

  /// Feature chip text
  ///
  /// In en, this message translates to:
  /// **'Drag to folder'**
  String get dragToFolder;

  /// Feature chip text
  ///
  /// In en, this message translates to:
  /// **'Undo safety'**
  String get undoSafety;

  /// Gallery information section title
  ///
  /// In en, this message translates to:
  /// **'Gallery Info'**
  String get galleryInfo;

  /// Album label
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// Photos and videos label
  ///
  /// In en, this message translates to:
  /// **'Photos & Videos'**
  String get photoVideo;

  /// Total size label
  ///
  /// In en, this message translates to:
  /// **'Total Size'**
  String get totalSize;

  /// Loading message for gallery info
  ///
  /// In en, this message translates to:
  /// **'Loading gallery info...'**
  String get galleryInfoLoading;

  /// Message during gallery info loading
  ///
  /// In en, this message translates to:
  /// **'This process may take a few seconds, please wait'**
  String get loadingMayTakeFewSeconds;

  /// Loading description while optimizing storage
  ///
  /// In en, this message translates to:
  /// **'Optimizing your gallery space...'**
  String get loadingDescriptionOptimizingSpace;

  /// Loading description while scanning media
  ///
  /// In en, this message translates to:
  /// **'Scanning your memories for duplicates and blur...'**
  String get loadingDescriptionScanningMemories;

  /// Loading description while preparing report
  ///
  /// In en, this message translates to:
  /// **'Preparing your cleanup plan...'**
  String get loadingDescriptionPreparingReport;

  /// Error message when gallery info cannot be retrieved
  ///
  /// In en, this message translates to:
  /// **'Gallery info not available'**
  String get galleryInfoNotAvailable;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// Button to start cleaning
  ///
  /// In en, this message translates to:
  /// **'Start Cleaning'**
  String get startCleaningButton;

  /// Loading text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Title for gallery loading screen
  ///
  /// In en, this message translates to:
  /// **'Loading Your Gallery'**
  String get loadingYourGallery;

  /// Description for gallery loading screen
  ///
  /// In en, this message translates to:
  /// **'We are preparing your photos and videos. Please wait...'**
  String get loadingYourGalleryDescription;

  /// Indicates how many photos have been loaded
  ///
  /// In en, this message translates to:
  /// **'{count} photos loaded'**
  String photosLoaded(int count);

  /// Indicates photo loading progress with percentage
  ///
  /// In en, this message translates to:
  /// **'{loaded} / {total} photos ({percentage}%)'**
  String photosLoadingProgress(int loaded, int total, int percentage);

  /// Error message when gallery info fails to load
  ///
  /// In en, this message translates to:
  /// **'Gallery info could not be loaded'**
  String get galleryInfoNotLoaded;

  /// Message when permission is needed
  ///
  /// In en, this message translates to:
  /// **'Grant photo access permission to start'**
  String get grantPermissionToStart;

  /// Start button
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// Button to open settings for permissions
  ///
  /// In en, this message translates to:
  /// **'Manage Permissions in Settings'**
  String get managePermissionsInSettings;

  /// Note about iOS deletion behavior
  ///
  /// In en, this message translates to:
  /// **'On iOS, deletions are moved to \"Recently Deleted\" and can be recovered within 30 days.'**
  String get iosDeleteNote;

  /// Onboarding page 1 title
  ///
  /// In en, this message translates to:
  /// **'Swipe Left to Delete,\nSwipe Right to Keep'**
  String get swipeLeftToDeleteTitle;

  /// Onboarding page 1 description
  ///
  /// In en, this message translates to:
  /// **'Quickly review your photos by swiping cards left or right. Swipe right to keep, swipe left to delete.'**
  String get swipeLeftToDeleteDescription;

  /// Onboarding page 2 title
  ///
  /// In en, this message translates to:
  /// **'Organize Your\nAlbums'**
  String get organizeAlbumsTitle;

  /// Onboarding page 2 description
  ///
  /// In en, this message translates to:
  /// **'Drag your photos to the albums above to organize them. Organize your folders and move your photos wherever you want.'**
  String get organizeAlbumsDescription;

  /// Onboarding page 3 title
  ///
  /// In en, this message translates to:
  /// **'Delete Useless Bad\nPhotos'**
  String get deleteUselessPhotosTitle;

  /// Onboarding page 3 description
  ///
  /// In en, this message translates to:
  /// **'Delete blurry, incorrectly taken, or unnecessary photos to free up space on your phone. Clean up your storage and make more room.'**
  String get deleteUselessPhotosDescription;

  /// Skip button
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Continue button
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Start button
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startButton;

  /// Gallery permission page title
  ///
  /// In en, this message translates to:
  /// **'Gallery Permission'**
  String get galleryPermission;

  /// Permission request title
  ///
  /// In en, this message translates to:
  /// **'Photo library access is required'**
  String get photoLibraryAccessRequired;

  /// Permission request description
  ///
  /// In en, this message translates to:
  /// **'We need access to your photos to organize with swipe. You can manage this anytime from settings.'**
  String get permissionRequestDescription;

  /// Button to allow access
  ///
  /// In en, this message translates to:
  /// **'Allow Access'**
  String get allowAccess;

  /// Button to open settings
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// Button to check permission again
  ///
  /// In en, this message translates to:
  /// **'Check Again'**
  String get checkAgain;

  /// Background page title when permission dialog is shown
  ///
  /// In en, this message translates to:
  /// **'We need your access'**
  String get weNeedYourAccess;

  /// Title for recently deleted photos section
  ///
  /// In en, this message translates to:
  /// **'Recently Deleted Photos'**
  String get recentlyDeleted;

  /// Dialog title for restoring a photo
  ///
  /// In en, this message translates to:
  /// **'Restore Photo'**
  String get restorePhoto;

  /// Message in restore photo dialog
  ///
  /// In en, this message translates to:
  /// **'This photo will be restored. Do you want to continue?'**
  String get restorePhotoMessage;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Restore button
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// Success message when photo is restored
  ///
  /// In en, this message translates to:
  /// **'Photo restored'**
  String get photoRestored;

  /// Remaining deletion rights label (daily)
  ///
  /// In en, this message translates to:
  /// **'Daily Remaining Deletion'**
  String get remainingDeletionRights;

  /// Button text to watch ad
  ///
  /// In en, this message translates to:
  /// **'Watch Ad'**
  String get watchAdToEarn;

  /// Ad not ready message
  ///
  /// In en, this message translates to:
  /// **'Ad Loading...'**
  String get adNotReady;

  /// Text showing deletion rights earned from watching ad
  ///
  /// In en, this message translates to:
  /// **'+20 Deletions'**
  String get earnDeletionRights;

  /// Button text to watch ad and earn deletion rights
  ///
  /// In en, this message translates to:
  /// **'+20 Deletions'**
  String get watchAdAndEarnDeletionRights;

  /// Description for gallery permission request
  ///
  /// In en, this message translates to:
  /// **'We need access to your photos and videos to perform gallery cleaning operations.'**
  String get galleryPermissionDescription;

  /// Privacy and security information text for permission request page
  ///
  /// In en, this message translates to:
  /// **'Your Privacy Matters'**
  String get privacySecurityInfo;

  /// No description provided for @privacySecurityPoint1.
  ///
  /// In en, this message translates to:
  /// **'Your photos and videos are never shared with anyone'**
  String get privacySecurityPoint1;

  /// No description provided for @privacySecurityPoint2.
  ///
  /// In en, this message translates to:
  /// **'All processing happens only on your device'**
  String get privacySecurityPoint2;

  /// No description provided for @privacySecurityPoint3.
  ///
  /// In en, this message translates to:
  /// **'We do not collect, store, or transmit any of your personal media'**
  String get privacySecurityPoint3;

  /// Quick cleanup feature title
  ///
  /// In en, this message translates to:
  /// **'Quick Cleanup'**
  String get quickCleanupTitle;

  /// Quick cleanup feature description
  ///
  /// In en, this message translates to:
  /// **'Quickly review your photos'**
  String get quickCleanupDescription;

  /// Organize feature title
  ///
  /// In en, this message translates to:
  /// **'Organize'**
  String get organizeTitle;

  /// Organize feature description
  ///
  /// In en, this message translates to:
  /// **'Move and organize to your albums'**
  String get organizeDescription;

  /// Safe delete feature title
  ///
  /// In en, this message translates to:
  /// **'Safe Delete'**
  String get safeDeleteTitle;

  /// Safe delete feature description
  ///
  /// In en, this message translates to:
  /// **'Clean up unnecessary photos'**
  String get safeDeleteDescription;

  /// Title for increasing deletion rights dialog
  ///
  /// In en, this message translates to:
  /// **'Increase Deletion Rights'**
  String get increaseDeletionRights;

  /// Title for increasing scan rights dialog
  ///
  /// In en, this message translates to:
  /// **'Increase Scan Rights'**
  String get increaseScanRights;

  /// Text showing deletion rights earned from watching ad with amount
  ///
  /// In en, this message translates to:
  /// **'+{amount} Deletions'**
  String earnDeleteRights(int amount);

  /// Text showing scan rights earned from watching ad with amount
  ///
  /// In en, this message translates to:
  /// **'+{amount} Scans'**
  String earnScanRights(int amount);

  /// Success message when user earns deletion rights from ad
  ///
  /// In en, this message translates to:
  /// **'You earned 20 deletion rights!'**
  String get earnedDeletionRights;

  /// Button text to go premium
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get goPremium;

  /// Premium dialog title
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get premiumTitle;

  /// Title for premium paywall dialog
  ///
  /// In en, this message translates to:
  /// **'Unlock Premium Features'**
  String get unlockPremiumFeatures;

  /// Premium dialog description
  ///
  /// In en, this message translates to:
  /// **'Get unlimited deletion rights and access to all features with Premium membership!'**
  String get premiumDescription;

  /// Premium features title
  ///
  /// In en, this message translates to:
  /// **'Premium Features'**
  String get premiumFeatures;

  /// Unlimited deletions feature
  ///
  /// In en, this message translates to:
  /// **'Unlimited deletion rights'**
  String get unlimitedDeletions;

  /// Unlimited scans feature
  ///
  /// In en, this message translates to:
  /// **'Unlimited Scans'**
  String get unlimitedScans;

  /// No ads feature
  ///
  /// In en, this message translates to:
  /// **'Ad-free experience'**
  String get noAds;

  /// All premium features text
  ///
  /// In en, this message translates to:
  /// **'All Premium Features'**
  String get allPremiumFeatures;

  /// Welcome message for premium features
  ///
  /// In en, this message translates to:
  /// **'Unlock all premium features:'**
  String get welcomeToPremium;

  /// Priority support feature
  ///
  /// In en, this message translates to:
  /// **'Priority support'**
  String get prioritySupport;

  /// Upgrade button text
  ///
  /// In en, this message translates to:
  /// **'Upgrade Now'**
  String get upgradeNow;

  /// Maybe later button text
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get maybeLater;

  /// Button text to buy unlimited deletion rights
  ///
  /// In en, this message translates to:
  /// **'Buy Unlimited Deletion'**
  String get buyUnlimitedRights;

  /// Button text to buy unlimited blur scan rights
  ///
  /// In en, this message translates to:
  /// **'Buy Unlimited Blur'**
  String get buyUnlimitedBlurRights;

  /// Button text to buy unlimited duplicate scan rights
  ///
  /// In en, this message translates to:
  /// **'Buy Unlimited Duplicate'**
  String get buyUnlimitedDuplicateRights;

  /// Unlimited blur scans feature text
  ///
  /// In en, this message translates to:
  /// **'Unlimited Blur Scans • Lifetime Access'**
  String get unlimitedBlurScans;

  /// Unlimited duplicate scans feature text
  ///
  /// In en, this message translates to:
  /// **'Unlimited Duplicate Scans • Lifetime Access'**
  String get unlimitedDuplicateScans;

  /// One time payment label
  ///
  /// In en, this message translates to:
  /// **'One-Time Payment'**
  String get oneTimePayment;

  /// No more ads feature
  ///
  /// In en, this message translates to:
  /// **'No more ads'**
  String get noMoreAds;

  /// Lifetime access feature
  ///
  /// In en, this message translates to:
  /// **'Lifetime access'**
  String get lifetimeAccess;

  /// Purchase now button text
  ///
  /// In en, this message translates to:
  /// **'Purchase Now'**
  String get purchaseNow;

  /// Limited time offer label
  ///
  /// In en, this message translates to:
  /// **'Limited Time'**
  String get limitedTimeOffer;

  /// 25% discount label
  ///
  /// In en, this message translates to:
  /// **'25% Off'**
  String get discount25;

  /// Original price label
  ///
  /// In en, this message translates to:
  /// **'Original Price'**
  String get originalPrice;

  /// Save now text
  ///
  /// In en, this message translates to:
  /// **'Save Now'**
  String get saveNow;

  /// Best value badge
  ///
  /// In en, this message translates to:
  /// **'Best Value'**
  String get bestValue;

  /// Message when purchase is successful
  ///
  /// In en, this message translates to:
  /// **'Purchase successful! You now have access to premium features.'**
  String get purchaseSuccessful;

  /// Message shown when user becomes premium - lifetime access confirmation
  ///
  /// In en, this message translates to:
  /// **'You now have lifetime access to these benefits!'**
  String get lifetimeAccessMessage;

  /// Title shown when user is premium
  ///
  /// In en, this message translates to:
  /// **'You are Premium'**
  String get youArePremium;

  /// Active status badge text
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get active;

  /// Description text for premium users explaining their access
  ///
  /// In en, this message translates to:
  /// **'You have access to all premium features. Unlimited deletion, scanning, and more!'**
  String get premiumAccessDescription;

  /// Title shown in purchase success dialog
  ///
  /// In en, this message translates to:
  /// **'Premium Active!'**
  String get premiumActive;

  /// Message shown in purchase success dialog
  ///
  /// In en, this message translates to:
  /// **'Congratulations! Your premium membership is active. You now have access to all features.'**
  String get premiumActiveMessage;

  /// Button text to start using premium features
  ///
  /// In en, this message translates to:
  /// **'Start Using'**
  String get startUsing;

  /// Short label for unlimited feature
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// Short label for ad-free feature
  ///
  /// In en, this message translates to:
  /// **'Ad-free'**
  String get adFree;

  /// Short label for priority support feature
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// Paywall main title
  ///
  /// In en, this message translates to:
  /// **'Unlock a Smarter, Cleaner Gallery'**
  String get paywallTitle;

  /// Paywall subtitle
  ///
  /// In en, this message translates to:
  /// **'AI-powered photo cleanup. One-time payment. Lifetime access.'**
  String get paywallSubtitle;

  /// Badge text for one-time offer
  ///
  /// In en, this message translates to:
  /// **'ONE-TIME OFFER'**
  String get oneTimeOffer;

  /// One-time purchase catchy text
  ///
  /// In en, this message translates to:
  /// **'Pay once. Own it forever.'**
  String get payOnceOwnForever;

  /// Short discount label
  ///
  /// In en, this message translates to:
  /// **'25% OFF'**
  String get discount25Short;

  /// Upgrade button label
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get upgradeToPremium;

  /// Continue without purchase
  ///
  /// In en, this message translates to:
  /// **'Continue with Free Version'**
  String get continueWithFree;

  /// Footer text with no subscription message
  ///
  /// In en, this message translates to:
  /// **'No subscriptions. No hidden fees.'**
  String get noSubscriptionsNoFees;

  /// Feature title - unlimited deletions
  ///
  /// In en, this message translates to:
  /// **'Unlimited Deletions'**
  String get featureUnlimitedDeletions;

  /// Feature description - unlimited deletions
  ///
  /// In en, this message translates to:
  /// **'Clean your gallery without any limits.'**
  String get featureUnlimitedDeletionsDesc;

  /// Feature title - AI detection
  ///
  /// In en, this message translates to:
  /// **'AI Blur & Duplicate Detection'**
  String get featureAIDetection;

  /// Feature description - AI detection
  ///
  /// In en, this message translates to:
  /// **'Find and remove unwanted photos.'**
  String get featureAIDetectionDesc;

  /// Feature title - auto clean
  ///
  /// In en, this message translates to:
  /// **'Smart Auto-Clean Suggestions'**
  String get featureAutoClean;

  /// Feature description - auto clean
  ///
  /// In en, this message translates to:
  /// **'Let our AI find photos to delete for you.'**
  String get featureAutoCleanDesc;

  /// Feature title - ad free
  ///
  /// In en, this message translates to:
  /// **'Ad-Free Experience'**
  String get featureAdFree;

  /// Feature description - ad free
  ///
  /// In en, this message translates to:
  /// **'Enjoy a seamless, ad-free interface.'**
  String get featureAdFreeDesc;

  /// Loading text for purchase in progress
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// Message when store is not available
  ///
  /// In en, this message translates to:
  /// **'Store is not available'**
  String get storeNotAvailable;

  /// Message when purchase fails
  ///
  /// In en, this message translates to:
  /// **'Purchase failed. Please try again.'**
  String get purchaseFailed;

  /// Message when purchase initiation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to initiate purchase'**
  String get failedToInitiatePurchase;

  /// Message when purchase error occurs
  ///
  /// In en, this message translates to:
  /// **'Purchase error'**
  String get purchaseError;

  /// Message when purchases are restored successfully
  ///
  /// In en, this message translates to:
  /// **'Purchases restored successfully!'**
  String get purchasesRestoredSuccessfully;

  /// Message when no previous purchases are found
  ///
  /// In en, this message translates to:
  /// **'No previous purchases found to restore.'**
  String get noPreviousPurchases;

  /// Message when restore error occurs
  ///
  /// In en, this message translates to:
  /// **'Restore error'**
  String get restoreError;

  /// Message when restoring purchases
  ///
  /// In en, this message translates to:
  /// **'Restoring...'**
  String get restoring;

  /// Button text to restore purchases
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// Duplicate photos page title
  ///
  /// In en, this message translates to:
  /// **'Duplicate Photos'**
  String get duplicatePhotos;

  /// Button to scan for duplicate photos
  ///
  /// In en, this message translates to:
  /// **'Scan for Duplicates'**
  String get scanForDuplicates;

  /// Message when scanning for duplicates
  ///
  /// In en, this message translates to:
  /// **'Scanning for duplicates...'**
  String get scanningDuplicates;

  /// Message when no duplicates are found
  ///
  /// In en, this message translates to:
  /// **'No duplicate photos found'**
  String get noDuplicatesFound;

  /// Message showing duplicate groups count
  ///
  /// In en, this message translates to:
  /// **'{count} duplicate groups found'**
  String duplicatesFound(int count);

  /// Label for total duplicate photos count
  ///
  /// In en, this message translates to:
  /// **'Total Duplicates'**
  String get totalDuplicates;

  /// Label for space that can be saved
  ///
  /// In en, this message translates to:
  /// **'Space to Save'**
  String get spaceToSave;

  /// Button to delete duplicate photos
  ///
  /// In en, this message translates to:
  /// **'Delete Duplicates'**
  String get deleteDuplicates;

  /// Title for album selection dialog for scanning
  ///
  /// In en, this message translates to:
  /// **'Select Albums to Scan'**
  String get selectAlbumsToScan;

  /// Button to scan selected albums
  ///
  /// In en, this message translates to:
  /// **'Scan Selected Albums'**
  String get scanSelectedAlbums;

  /// Button to delete all duplicate photos
  ///
  /// In en, this message translates to:
  /// **'Delete All Duplicates'**
  String get deleteAllDuplicates;

  /// Message for deleting all duplicate photos
  ///
  /// In en, this message translates to:
  /// **'{count} duplicate photos will be deleted. Are you sure?'**
  String deleteAllDuplicatesMessage(int count);

  /// Button to delete all blurry photos
  ///
  /// In en, this message translates to:
  /// **'Delete All Blurry Photos'**
  String get deleteAllBlurryPhotos;

  /// Message for deleting all blurry photos
  ///
  /// In en, this message translates to:
  /// **'{count} blurry photos will be deleted. Are you sure?'**
  String deleteAllBlurryPhotosMessage(int count);

  /// Button to start a new scan
  ///
  /// In en, this message translates to:
  /// **'Start New Scan'**
  String get startNewScan;

  /// Title for scan results page
  ///
  /// In en, this message translates to:
  /// **'Scan Results'**
  String get scanResults;

  /// Scan completed title
  ///
  /// In en, this message translates to:
  /// **'Scan Completed'**
  String get scanCompleted;

  /// Scan completed message for blur photos
  ///
  /// In en, this message translates to:
  /// **'{count} blurry photos found'**
  String scanCompletedBlurMessage(int count);

  /// Scan completed message for duplicate photos
  ///
  /// In en, this message translates to:
  /// **'{count} duplicate groups found'**
  String scanCompletedDuplicateMessage(int count);

  /// No blurry photos found message
  ///
  /// In en, this message translates to:
  /// **'No blurry or pixelated photos found in your gallery.'**
  String get noBlurryPhotosFound;

  /// No duplicate photos found message
  ///
  /// In en, this message translates to:
  /// **'No duplicate photos found in your gallery.'**
  String get noDuplicatePhotosFound;

  /// Label for duplicate photo group
  ///
  /// In en, this message translates to:
  /// **'Duplicate Group'**
  String get duplicateGroup;

  /// Number of photos in duplicate group
  ///
  /// In en, this message translates to:
  /// **'{count} photos'**
  String photosInGroup(int count);

  /// Label indicating oldest photo will be kept
  ///
  /// In en, this message translates to:
  /// **'Keep Oldest'**
  String get keepOldest;

  /// Message when scanning a specific album
  ///
  /// In en, this message translates to:
  /// **'Scanning {album}...'**
  String scanningAlbum(String album);

  /// Title when deletion rights are exhausted
  ///
  /// In en, this message translates to:
  /// **'No Deletion Rights Left'**
  String get noDeleteRightsLeft;

  /// Message when deletion rights are exhausted
  ///
  /// In en, this message translates to:
  /// **'You have no deletion rights left. Get unlimited deletion rights to continue cleaning your gallery.'**
  String get noDeleteRightsLeftMessage;

  /// Gallery statistics page title
  ///
  /// In en, this message translates to:
  /// **'Gallery Statistics'**
  String get galleryStatsTitle;

  /// General statistics section title
  ///
  /// In en, this message translates to:
  /// **'General Statistics'**
  String get generalStatistics;

  /// Total photos label
  ///
  /// In en, this message translates to:
  /// **'Total Photos'**
  String get totalPhotos;

  /// Items label for album media count
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get items;

  /// Yesterday text for time ago
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Ago suffix for time ago
  ///
  /// In en, this message translates to:
  /// **'ago'**
  String get ago;

  /// Just now text for time ago
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Stop button text
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// Space saved label
  ///
  /// In en, this message translates to:
  /// **'Space Saved'**
  String get spaceSaved;

  /// Last analysis label
  ///
  /// In en, this message translates to:
  /// **'Last analysis:'**
  String get lastAnalysis;

  /// Previous analysis label
  ///
  /// In en, this message translates to:
  /// **'Previous analysis:'**
  String get previousAnalysis;

  /// Media label for change chip
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get mediaLabel;

  /// Size label for change chip
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sizeLabel;

  /// Album details section title
  ///
  /// In en, this message translates to:
  /// **'Album Details'**
  String get albumDetails;

  /// Media unit text (singular/plural)
  ///
  /// In en, this message translates to:
  /// **'media'**
  String get mediaUnit;

  /// Percentage of total gallery text
  ///
  /// In en, this message translates to:
  /// **'of gallery'**
  String get ofGallery;

  /// Re-analyze button text
  ///
  /// In en, this message translates to:
  /// **'Re-analyze'**
  String get reAnalyze;

  /// Toggle label for auto-analyze on app launch
  ///
  /// In en, this message translates to:
  /// **'Auto-analyze on launch'**
  String get autoAnalyzeOnLaunch;

  /// Description text for auto-analyze toggle
  ///
  /// In en, this message translates to:
  /// **'Automatically analyze gallery when app opens'**
  String get autoAnalyzeOnLaunchDescription;

  /// Progress text format showing albums and media count
  ///
  /// In en, this message translates to:
  /// **'{albums} albums • {media} media'**
  String progressFormat(String albums, int media);

  /// Error message with error text
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorMessage(String error);

  /// Message shown when delete operation fails
  ///
  /// In en, this message translates to:
  /// **'Delete operation failed. Please try again.'**
  String get deleteOperationFailed;

  /// Blur photos page title
  ///
  /// In en, this message translates to:
  /// **'Blurry Photos'**
  String get blurPhotosTitle;

  /// Blur detection page title
  ///
  /// In en, this message translates to:
  /// **'Blur and Pixelation Detection'**
  String get blurDetectionTitle;

  /// Blur photo detection title
  ///
  /// In en, this message translates to:
  /// **'Blurry Photo Detection'**
  String get blurPhotoDetection;

  /// Blur detection description
  ///
  /// In en, this message translates to:
  /// **'Detect blurry and pixelated photos in selected albums'**
  String get blurDetectionDescription;

  /// Sensitivity label
  ///
  /// In en, this message translates to:
  /// **'Sensitivity'**
  String get sensitivity;

  /// Duplicate detection mode label
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get duplicateMode;

  /// Threshold label with value
  ///
  /// In en, this message translates to:
  /// **'Threshold: {value}'**
  String thresholdLabel(String value);

  /// Threshold description
  ///
  /// In en, this message translates to:
  /// **'Low value = More blur detection\nHigh value = Only very blurry photos'**
  String get thresholdDescription;

  /// Low sensitivity label
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get sensitivityLow;

  /// Medium sensitivity label
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get sensitivityMedium;

  /// High sensitivity label
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get sensitivityHigh;

  /// Sensitivity description
  ///
  /// In en, this message translates to:
  /// **'Sensitivity level determines how many blurry photos are detected. Low sensitivity detects more photos, high sensitivity only finds very blurry photos.'**
  String get sensitivityDescription;

  /// Detailed description of sensitivity levels
  ///
  /// In en, this message translates to:
  /// **'Low: Detects slightly blurry photos as well (more results)\nMedium: Detects moderately blurry photos (balanced)\nHigh: Only detects very blurry photos (fewer results)'**
  String get sensitivityLevelsDescription;

  /// Current sensitivity label
  ///
  /// In en, this message translates to:
  /// **'Current Sensitivity'**
  String get currentSensitivity;

  /// No scan rights left message
  ///
  /// In en, this message translates to:
  /// **'No Scan Rights Left'**
  String get noScanRightsLeft;

  /// Album selection bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Album Selection'**
  String get albumSelection;

  /// Start scan button text
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get startScan;

  /// Scanning blur photos message
  ///
  /// In en, this message translates to:
  /// **'Scanning blurry and pixelated photos...'**
  String get scanningBlurPhotos;

  /// Premium scan label
  ///
  /// In en, this message translates to:
  /// **'Premium Scan'**
  String get premiumScan;

  /// Remaining scan rights label
  ///
  /// In en, this message translates to:
  /// **'Remaining Scan'**
  String get remainingScanRights;

  /// Scan limit label
  ///
  /// In en, this message translates to:
  /// **'Scan Limit'**
  String get scanLimit;

  /// Scan limit low warning message
  ///
  /// In en, this message translates to:
  /// **'Your scan limit is running low! Upgrade to Premium.'**
  String get scanLimitLow;

  /// Watch ad to get scan limit button text
  ///
  /// In en, this message translates to:
  /// **'Watch Ad +{amount} Scan Limit'**
  String watchAdToGetScanLimit(int amount);

  /// Photo unit text
  ///
  /// In en, this message translates to:
  /// **'photos'**
  String get photoUnit;

  /// Select albums and scan message
  ///
  /// In en, this message translates to:
  /// **'Select albums and scan'**
  String get selectAlbumsAndScan;

  /// No duplicate groups found message
  ///
  /// In en, this message translates to:
  /// **'No duplicate groups found'**
  String get noDuplicateGroupsFound;

  /// State information with albums and groups count
  ///
  /// In en, this message translates to:
  /// **'{albums} albums, {groups} groups'**
  String stateInfo(int albums, int groups);

  /// Blur detection description from app bar
  ///
  /// In en, this message translates to:
  /// **'AI-powered blurry and pixelated photo detection. Clean up your storage and keep only quality images.'**
  String get blurDetectionDescriptionFromAppBar;

  /// Duplicate detection description from app bar
  ///
  /// In en, this message translates to:
  /// **'AI-powered duplicate photo detection. Clean up unnecessary copies and optimize your storage space.'**
  String get duplicateDetectionDescriptionFromAppBar;

  /// AI powered label
  ///
  /// In en, this message translates to:
  /// **'AI-Powered'**
  String get aiPowered;

  /// List view tooltip
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// Grid view tooltip
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// Unknown album name
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// Blur score label
  ///
  /// In en, this message translates to:
  /// **'Blur: {score}'**
  String blurScoreLabel(String score);

  /// Pixelation score label
  ///
  /// In en, this message translates to:
  /// **'Pixel: {score}'**
  String pixelationScoreLabel(String score);

  /// Delete photo dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Photo'**
  String get deletePhoto;

  /// Delete photo confirmation message
  ///
  /// In en, this message translates to:
  /// **'This {type} photo will be deleted.'**
  String deletePhotoMessage(String type);

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Delete duplicates confirmation message
  ///
  /// In en, this message translates to:
  /// **'{count} duplicate photos will be deleted.'**
  String deleteDuplicatesMessage(int count);

  /// No results found message
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// Group label
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// Photo singular
  ///
  /// In en, this message translates to:
  /// **'photo'**
  String get photo;

  /// Blurry photo type
  ///
  /// In en, this message translates to:
  /// **'Blurry'**
  String get blurry;

  /// Pixelated photo type
  ///
  /// In en, this message translates to:
  /// **'Pixelated'**
  String get pixelated;

  /// Blurry and pixelated photo type
  ///
  /// In en, this message translates to:
  /// **'Blurry and Pixelated'**
  String get blurryAndPixelated;

  /// Sharp photo type
  ///
  /// In en, this message translates to:
  /// **'Sharp'**
  String get sharp;

  /// Scanning duplicate photos message
  ///
  /// In en, this message translates to:
  /// **'Scanning duplicate photos...'**
  String get scanningDuplicatePhotos;

  /// Duplicate photo detection title
  ///
  /// In en, this message translates to:
  /// **'Duplicate Photo Detection'**
  String get duplicatePhotoDetection;

  /// Onboarding page 4 title for blur detection
  ///
  /// In en, this message translates to:
  /// **'Detect Blurry Photos'**
  String get blurDetectionOnboardingTitle;

  /// Onboarding page 4 description for blur detection
  ///
  /// In en, this message translates to:
  /// **'Automatically detect blurry and pixelated photos in your gallery. You can easily find and delete these photos.'**
  String get blurDetectionOnboardingDescription;

  /// Onboarding page 5 title for duplicate detection
  ///
  /// In en, this message translates to:
  /// **'Find Duplicate Photos'**
  String get duplicateDetectionOnboardingTitle;

  /// Onboarding page 5 description for duplicate detection
  ///
  /// In en, this message translates to:
  /// **'Detect duplicate photos in your gallery with smart algorithm. Free up space by cleaning unnecessary copies.'**
  String get duplicateDetectionOnboardingDescription;

  /// Permission request page title with line break
  ///
  /// In en, this message translates to:
  /// **'We Need Your\nAccess'**
  String get weNeedYourAccessTitle;

  /// Button text to reset gallery to start
  ///
  /// In en, this message translates to:
  /// **'Reset to Start'**
  String get resetToStart;

  /// Swipe tab name
  ///
  /// In en, this message translates to:
  /// **'Swipe'**
  String get swipeTab;

  /// Blur tab name
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get blurTab;

  /// Duplicate tab name
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicateTab;

  /// Title for cleanup complete dialog
  ///
  /// In en, this message translates to:
  /// **'Cleanup Complete!'**
  String get cleanupComplete;

  /// Message for cleanup complete dialog
  ///
  /// In en, this message translates to:
  /// **'All selected photos have been successfully deleted. Your gallery is now cleaner and lighter.'**
  String get cleanupCompleteMessage;

  /// Message for cleanup complete dialog with deleted count
  ///
  /// In en, this message translates to:
  /// **'{count} photo(s) have been successfully deleted. Your gallery is now cleaner and lighter.'**
  String cleanupCompleteMessageWithCount(int count);

  /// Message for cleanup complete dialog with deleted count and size
  ///
  /// In en, this message translates to:
  /// **'{count} photo(s) have been successfully deleted and {size} MB of space freed. Your gallery is now cleaner and lighter.'**
  String cleanupCompleteMessageWithCountAndSize(int count, String size);

  /// Photos label
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// MB freed text
  ///
  /// In en, this message translates to:
  /// **'{size} MB freed'**
  String mbFreed(String size);

  /// Done button text
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// View gallery link text
  ///
  /// In en, this message translates to:
  /// **'View Gallery'**
  String get viewGallery;

  /// Message shown when scan completes with no results, indicating scan right was not consumed
  ///
  /// In en, this message translates to:
  /// **'Your scan right was not used'**
  String get scanRightNotUsed;

  /// Title shown when no blurry photos are found after scan
  ///
  /// In en, this message translates to:
  /// **'No Blurry Photos Found'**
  String get noBlurryPhotosFoundTitle;

  /// Title shown when no duplicate photos are found after scan
  ///
  /// In en, this message translates to:
  /// **'No Duplicates Found'**
  String get noDuplicatesFoundTitle;

  /// Success message shown when scan completes with no results
  ///
  /// In en, this message translates to:
  /// **'Scan completed successfully!'**
  String get scanCompletedSuccessfully;

  /// Success message shown when duplicate scan completes with no results
  ///
  /// In en, this message translates to:
  /// **'Scan completed successfully!'**
  String get scanCompletedSuccessfullyDuplicate;

  /// Message telling user to open app and view scan results
  ///
  /// In en, this message translates to:
  /// **'Open the app and view results'**
  String get openAppAndViewResults;

  /// Title for rate app section
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rateApp;

  /// Description for rate app section
  ///
  /// In en, this message translates to:
  /// **'Enjoying the app? Please rate us on the store!'**
  String get rateAppDescription;

  /// Support message for rate app dialog
  ///
  /// In en, this message translates to:
  /// **'Support our growth! Could you take 3 seconds to rate the app?'**
  String get rateAppSupportMessage;

  /// Thank you message
  ///
  /// In en, this message translates to:
  /// **'Thank You!'**
  String get thankYou;

  /// Thanks for feedback message
  ///
  /// In en, this message translates to:
  /// **'Thanks for your feedback!'**
  String get thanksForFeedback;

  /// Error message when store cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open store'**
  String get couldNotOpenStore;

  /// Estimated scan time in seconds
  ///
  /// In en, this message translates to:
  /// **'~{seconds} seconds'**
  String estimatedTimeSeconds(int seconds);

  /// Estimated scan time in minutes
  ///
  /// In en, this message translates to:
  /// **'~{minutes} minutes'**
  String estimatedTimeMinutes(int minutes);

  /// Estimated scan time label with time value
  ///
  /// In en, this message translates to:
  /// **'Estimated time: {time}'**
  String estimatedScanTime(String time);

  /// Warning message when selected album has more than 1000 photos
  ///
  /// In en, this message translates to:
  /// **'Selected album contains {count} photos. Maximum 1000 photos can be analyzed at once.'**
  String maxPhotoLimitWarning(int count);

  /// Confirmation dialog title for starting blur scan
  ///
  /// In en, this message translates to:
  /// **'Start blur detection?'**
  String get confirmBlurScan;

  /// Confirmation dialog message for starting blur scan
  ///
  /// In en, this message translates to:
  /// **'Blur detection will be performed on selected albums. Do you want to continue?'**
  String get confirmBlurScanMessage;

  /// Confirmation dialog title for starting duplicate scan
  ///
  /// In en, this message translates to:
  /// **'Start duplicate detection?'**
  String get confirmDuplicateScan;

  /// Confirmation dialog message for starting duplicate scan
  ///
  /// In en, this message translates to:
  /// **'Duplicate detection will be performed on selected albums. Do you want to continue?'**
  String get confirmDuplicateScanMessage;

  /// Scan button text
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// Low speed high accuracy mode label for duplicate detection
  ///
  /// In en, this message translates to:
  /// **'Low Speed\nHigh Accuracy'**
  String get duplicateModeLowSpeedHighAccuracy;

  /// Balanced mode label for duplicate detection
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get duplicateModeBalanced;

  /// High speed low accuracy mode label for duplicate detection
  ///
  /// In en, this message translates to:
  /// **'High Speed\nLow Accuracy'**
  String get duplicateModeHighSpeedLowAccuracy;

  /// Detailed description of duplicate detection mode levels
  ///
  /// In en, this message translates to:
  /// **'Low Speed/High Accuracy: Most accurate results, takes longer\nBalanced: Speed and accuracy balance\nHigh Speed/Low Accuracy: Fast results, less accurate'**
  String get duplicateModeLevelsDescription;

  /// Title shown when all photos have been reviewed
  ///
  /// In en, this message translates to:
  /// **'All Photos Reviewed!'**
  String get allPhotosReviewedTitle;

  /// Description shown when all photos have been reviewed
  ///
  /// In en, this message translates to:
  /// **'Great job! You\'ve reviewed all available photos.'**
  String get allPhotosReviewedDescription;

  /// Title for premium dialog after 3 ads
  ///
  /// In en, this message translates to:
  /// **'Remove Ads and Get Unlimited Deletion Rights'**
  String get removeAdsAndUnlimitedDeletions;

  /// Description for premium dialog after 3 ads
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium and enjoy an ad-free experience with unlimited deletion rights forever!'**
  String get removeAdsAndUnlimitedDeletionsDescription;

  /// Warning message shown when user tries to navigate away during scan
  ///
  /// In en, this message translates to:
  /// **'Please do not leave this screen while the scan is in progress.'**
  String get doNotLeaveScreenDuringScan;

  /// Button text to view scan results
  ///
  /// In en, this message translates to:
  /// **'View Results'**
  String get viewResults;

  /// Button text to view last scan results
  ///
  /// In en, this message translates to:
  /// **'View Last Results'**
  String get viewLastResults;

  /// Filter and sort bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Filter and Sort'**
  String get filterAndSort;

  /// Filter and sort bottom sheet description
  ///
  /// In en, this message translates to:
  /// **'Date range and sort options'**
  String get filterAndSortDescription;

  /// Date range section title
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRange;

  /// Start date label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startDate;

  /// End date label
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endDate;

  /// Not selected state text
  ///
  /// In en, this message translates to:
  /// **'Not Selected'**
  String get notSelected;

  /// Button to clear date filter
  ///
  /// In en, this message translates to:
  /// **'Clear Date Filter'**
  String get clearDateFilter;

  /// Sort section title
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// Newest sort option
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// Oldest sort option
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get oldest;

  /// Apply button text
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Album settings button label
  ///
  /// In en, this message translates to:
  /// **'Album Settings'**
  String get albumSettings;

  /// Button text to get unlimited scans
  ///
  /// In en, this message translates to:
  /// **'Get Unlimited Scans'**
  String get getUnlimitedScans;

  /// Message when scan rights are exhausted
  ///
  /// In en, this message translates to:
  /// **'No rights left'**
  String get noRightsLeft;

  /// Button text to get unlimited deletions
  ///
  /// In en, this message translates to:
  /// **'Get Unlimited Deletions'**
  String get getUnlimitedDeletions;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'📱 Scroll through reels while we work!'**
  String get scanTip1;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'☕ Grab a cup of coffee from the kitchen!'**
  String get scanTip2;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'💌 Text your loved one while you wait!'**
  String get scanTip3;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'📚 Read a book or an article!'**
  String get scanTip4;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'🎵 Listen to your favorite music!'**
  String get scanTip5;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'💬 Chat with your friends!'**
  String get scanTip6;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'🌐 Browse social media!'**
  String get scanTip7;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'🚶 Take a short walk around!'**
  String get scanTip8;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'💧 Drink some water and stay hydrated!'**
  String get scanTip9;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'👀 Rest your eyes for a moment!'**
  String get scanTip10;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'🎧 Listen to a podcast!'**
  String get scanTip11;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'🏠 Do some quick house chores!'**
  String get scanTip12;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'🍿 Grab a snack!'**
  String get scanTip13;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'📞 Call a friend or family member!'**
  String get scanTip14;

  /// Tip shown during scan
  ///
  /// In en, this message translates to:
  /// **'🎮 Play a quick game!'**
  String get scanTip15;

  /// Title for gallery report page
  ///
  /// In en, this message translates to:
  /// **'Gallery Report'**
  String get galleryReportTitle;

  /// Videos label
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// Screenshots label
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get screenshots;

  /// Media label
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media;

  /// Description text on gallery report page
  ///
  /// In en, this message translates to:
  /// **'Our users clean approximately 50% of their gallery on average, significantly freeing up storage space'**
  String get galleryReportDescription;

  /// Title for review delete photos page
  ///
  /// In en, this message translates to:
  /// **'Review Photos to Delete'**
  String get reviewDeletePhotos;

  /// Message when there are no photos to delete
  ///
  /// In en, this message translates to:
  /// **'No photos to delete'**
  String get noPhotosToDelete;

  /// Message when delete limit is reached
  ///
  /// In en, this message translates to:
  /// **'You can only delete {count} photos per day'**
  String deleteLimitReached(int count);

  /// Text shown while deleting photos
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deleting;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// Title for storage cleanup onboarding screen
  ///
  /// In en, this message translates to:
  /// **'Free Up Storage Space'**
  String get freeUpStorageSpace;

  /// Storage label
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// Message showing how much storage and media can be cleaned
  ///
  /// In en, this message translates to:
  /// **'{gb} GB and {media} {mediaLabel} you can clean'**
  String youCanClean(String gb, int media, String mediaLabel);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

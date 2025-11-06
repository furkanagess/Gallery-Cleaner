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

  /// Album selector label
  ///
  /// In en, this message translates to:
  /// **'Select Album to View'**
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

  /// Message when there is no history
  ///
  /// In en, this message translates to:
  /// **'No history yet.'**
  String get noHistoryYet;

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

  /// Remaining deletion rights label
  ///
  /// In en, this message translates to:
  /// **'Remaining Deletion Rights'**
  String get remainingDeletionRights;

  /// Button text to watch ad
  ///
  /// In en, this message translates to:
  /// **'Watch Ad'**
  String get watchAdToEarn;

  /// Text showing deletion rights earned from watching ad
  ///
  /// In en, this message translates to:
  /// **'+20 Deletions'**
  String get earnDeletionRights;

  /// Message when ad is not ready
  ///
  /// In en, this message translates to:
  /// **'Ad is not ready yet. Please try again in a few seconds.'**
  String get adNotReady;

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

  /// No ads feature
  ///
  /// In en, this message translates to:
  /// **'Ad-free experience'**
  String get noAds;

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
  /// **'Buy Unlimited Rights'**
  String get buyUnlimitedRights;

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

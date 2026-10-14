import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'WuselWall'**
  String get appTitle;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get unexpectedError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Check your network and try again.'**
  String get errorNetwork;

  /// No description provided for @errorAuth.
  ///
  /// In en, this message translates to:
  /// **'You are not signed in, or your session has expired.'**
  String get errorAuth;

  /// No description provided for @errorPermission.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to do that.'**
  String get errorPermission;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'That could not be found.'**
  String get errorNotFound;

  /// No description provided for @errorConflict.
  ///
  /// In en, this message translates to:
  /// **'That clashes with something that already exists.'**
  String get errorConflict;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'That input is not valid.'**
  String get errorValidation;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorUnknown;

  /// No description provided for @configMissing.
  ///
  /// In en, this message translates to:
  /// **'This build is missing its configuration: {missing}'**
  String configMissing(String missing);

  /// No description provided for @registerAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get registerAdult;

  /// No description provided for @registerKid.
  ///
  /// In en, this message translates to:
  /// **'Kid'**
  String get registerKid;

  /// No description provided for @registerKiosk.
  ///
  /// In en, this message translates to:
  /// **'Wall display'**
  String get registerKiosk;

  /// No description provided for @systemTitle.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTitle;

  /// No description provided for @systemBuild.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get systemBuild;

  /// No description provided for @systemEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get systemEnvironment;

  /// No description provided for @systemBackendUrl.
  ///
  /// In en, this message translates to:
  /// **'Backend URL'**
  String get systemBackendUrl;

  /// No description provided for @systemConnectivity.
  ///
  /// In en, this message translates to:
  /// **'Connectivity'**
  String get systemConnectivity;

  /// No description provided for @systemNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get systemNetwork;

  /// No description provided for @systemOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get systemOnline;

  /// No description provided for @systemOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get systemOffline;

  /// No description provided for @systemUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get systemUnknown;

  /// No description provided for @systemBackend.
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get systemBackend;

  /// No description provided for @systemStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get systemStatus;

  /// No description provided for @systemStatusOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get systemStatusOk;

  /// No description provided for @systemDbVersion.
  ///
  /// In en, this message translates to:
  /// **'Database version'**
  String get systemDbVersion;

  /// No description provided for @systemServerTime.
  ///
  /// In en, this message translates to:
  /// **'Server time'**
  String get systemServerTime;

  /// No description provided for @setupHeadline.
  ///
  /// In en, this message translates to:
  /// **'Welcome to WuselWall'**
  String get setupHeadline;

  /// No description provided for @doorTagline.
  ///
  /// In en, this message translates to:
  /// **'The family plan for the kitchen wall'**
  String get doorTagline;

  /// No description provided for @setupEnrolAction.
  ///
  /// In en, this message translates to:
  /// **'Connect with a code'**
  String get setupEnrolAction;

  /// No description provided for @setupHouseholdAction.
  ///
  /// In en, this message translates to:
  /// **'Start a new family'**
  String get setupHouseholdAction;

  /// No description provided for @wizardTitle.
  ///
  /// In en, this message translates to:
  /// **'New household'**
  String get wizardTitle;

  /// No description provided for @wizardCreate.
  ///
  /// In en, this message translates to:
  /// **'Create household'**
  String get wizardCreate;

  /// No description provided for @fieldSetupToken.
  ///
  /// In en, this message translates to:
  /// **'Setup token'**
  String get fieldSetupToken;

  /// No description provided for @fieldHouseholdName.
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get fieldHouseholdName;

  /// No description provided for @fieldYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get fieldYourName;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password (at least 10 characters)'**
  String get fieldPassword;

  /// No description provided for @fieldPasswordSimple.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPasswordSimple;

  /// No description provided for @fieldPin.
  ///
  /// In en, this message translates to:
  /// **'6-digit PIN'**
  String get fieldPin;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInAction;

  /// No description provided for @enrolTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect this device'**
  String get enrolTitle;

  /// No description provided for @enrolBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the code shown on a device that is already connected.'**
  String get enrolBody;

  /// No description provided for @enrolCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Enrolment code'**
  String get enrolCodeLabel;

  /// No description provided for @enrolAction.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get enrolAction;

  /// No description provided for @errSetupTokenInvalid.
  ///
  /// In en, this message translates to:
  /// **'The setup token is not valid.'**
  String get errSetupTokenInvalid;

  /// No description provided for @errSetupClosed.
  ///
  /// In en, this message translates to:
  /// **'This system is already connected.'**
  String get errSetupClosed;

  /// No description provided for @errPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'The password needs at least 10 characters.'**
  String get errPasswordTooShort;

  /// No description provided for @errPinFormat.
  ///
  /// In en, this message translates to:
  /// **'The PIN must be exactly 6 digits.'**
  String get errPinFormat;

  /// No description provided for @errCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code is wrong or has expired.'**
  String get errCodeInvalid;

  /// No description provided for @errGuardianRequired.
  ///
  /// In en, this message translates to:
  /// **'Only a guardian can do that.'**
  String get errGuardianRequired;

  /// No description provided for @errDeviceRevoked.
  ///
  /// In en, this message translates to:
  /// **'This device has been blocked.'**
  String get errDeviceRevoked;

  /// No description provided for @errActorRequired.
  ///
  /// In en, this message translates to:
  /// **'Tap your name first.'**
  String get errActorRequired;

  /// No description provided for @errNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name.'**
  String get errNameRequired;

  /// No description provided for @errInvalidLogin.
  ///
  /// In en, this message translates to:
  /// **'Email or password is wrong.'**
  String get errInvalidLogin;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @shoppingTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get shoppingTitle;

  /// No description provided for @shoppingAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get shoppingAddHint;

  /// No description provided for @shoppingQuantityHint.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get shoppingQuantityHint;

  /// No description provided for @shoppingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to buy'**
  String get shoppingEmpty;

  /// No description provided for @shoppingFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish shopping'**
  String get shoppingFinish;

  /// No description provided for @shoppingFinishConfirm.
  ///
  /// In en, this message translates to:
  /// **'Finish this trip? Ticked items are removed, the rest stays on the list.'**
  String get shoppingFinishConfirm;

  /// No description provided for @shoppingFinished.
  ///
  /// In en, this message translates to:
  /// **'{bought} bought, {left} carried over'**
  String shoppingFinished(int bought, int left);

  /// No description provided for @actingWho.
  ///
  /// In en, this message translates to:
  /// **'Who are you?'**
  String get actingWho;

  /// No description provided for @pinTitle.
  ///
  /// In en, this message translates to:
  /// **'Guardian PIN'**
  String get pinTitle;

  /// No description provided for @pinPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN for {name}'**
  String pinPrompt(String name);

  /// No description provided for @pinWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN. {left} attempts left.'**
  String pinWrong(int left);

  /// No description provided for @pinBackoff.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment.'**
  String get pinBackoff;

  /// No description provided for @pinLocked.
  ///
  /// In en, this message translates to:
  /// **'PIN locked. A guardian must sign in to unlock it.'**
  String get pinLocked;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get settingsMembers;

  /// No description provided for @settingsDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get settingsDevices;

  /// No description provided for @addMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get addMember;

  /// No description provided for @memberName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get memberName;

  /// No description provided for @roleGuardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get roleGuardian;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @addDevice.
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get addDevice;

  /// No description provided for @deviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceLabel;

  /// No description provided for @createCode.
  ///
  /// In en, this message translates to:
  /// **'Create code'**
  String get createCode;

  /// No description provided for @enrolmentCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enrolment code'**
  String get enrolmentCodeTitle;

  /// No description provided for @enrolmentCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter this code on the new device within 10 minutes. It works once.'**
  String get enrolmentCodeHint;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'this device'**
  String get thisDevice;

  /// No description provided for @deviceRevoked.
  ///
  /// In en, this message translates to:
  /// **'blocked'**
  String get deviceRevoked;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get revoke;

  /// No description provided for @revokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Block \"{device}\"? It loses access immediately.'**
  String revokeConfirm(String device);

  /// No description provided for @signOutDevice.
  ///
  /// In en, this message translates to:
  /// **'Sign out this device'**
  String get signOutDevice;

  /// No description provided for @classPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get classPersonal;

  /// No description provided for @classShared.
  ///
  /// In en, this message translates to:
  /// **'Shared (tap to switch)'**
  String get classShared;

  /// No description provided for @classKiosk.
  ///
  /// In en, this message translates to:
  /// **'Wall display'**
  String get classKiosk;

  /// No description provided for @systemDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get systemDevice;

  /// No description provided for @systemRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get systemRegister;

  /// No description provided for @systemEnrolled.
  ///
  /// In en, this message translates to:
  /// **'Enrolled'**
  String get systemEnrolled;

  /// No description provided for @errRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get errRateLimited;

  /// No description provided for @errMfaRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your authenticator app first.'**
  String get errMfaRequired;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQr;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the setup code'**
  String get scanTitle;

  /// No description provided for @enrolmentQrLabel.
  ///
  /// In en, this message translates to:
  /// **'QR code for the enrolment code'**
  String get enrolmentQrLabel;

  /// No description provided for @mfaTitle.
  ///
  /// In en, this message translates to:
  /// **'Second factor'**
  String get mfaTitle;

  /// No description provided for @mfaBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app.'**
  String get mfaBody;

  /// No description provided for @mfaCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get mfaCodeLabel;

  /// No description provided for @mfaVerify.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get mfaVerify;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Name this device'**
  String get registerTitle;

  /// No description provided for @registerBody.
  ///
  /// In en, this message translates to:
  /// **'{name}, this phone is new to the household. Give it a name so you can recognise (and block) it later.'**
  String registerBody(String name);

  /// No description provided for @registerDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s phone'**
  String registerDefaultLabel(String name);

  /// No description provided for @registerAction.
  ///
  /// In en, this message translates to:
  /// **'Use this device'**
  String get registerAction;

  /// No description provided for @signInPasskey.
  ///
  /// In en, this message translates to:
  /// **'Sign in with passkey'**
  String get signInPasskey;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @totpTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor sign-in'**
  String get totpTitle;

  /// No description provided for @totpOn.
  ///
  /// In en, this message translates to:
  /// **'On: a code is needed at every sign-in.'**
  String get totpOn;

  /// No description provided for @totpOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get totpOff;

  /// No description provided for @totpEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get totpEnable;

  /// No description provided for @totpDisable.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get totpDisable;

  /// No description provided for @totpScanBody.
  ///
  /// In en, this message translates to:
  /// **'Scan this code with an authenticator app, then enter the 6-digit code it shows.'**
  String get totpScanBody;

  /// No description provided for @totpQrLabel.
  ///
  /// In en, this message translates to:
  /// **'QR code for setting up the authenticator app'**
  String get totpQrLabel;

  /// No description provided for @passkeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Passkey'**
  String get passkeyTitle;

  /// No description provided for @passkeyBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in with fingerprint or face instead of a password.'**
  String get passkeyBody;

  /// No description provided for @passkeyAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get passkeyAdd;

  /// No description provided for @passkeyAdded.
  ///
  /// In en, this message translates to:
  /// **'Passkey added.'**
  String get passkeyAdded;

  /// No description provided for @shoppingHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get shoppingHistory;

  /// No description provided for @shoppingHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No finished trips yet'**
  String get shoppingHistoryEmpty;

  /// No description provided for @shoppingSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search or add'**
  String get shoppingSearchHint;

  /// No description provided for @shoppingTilesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tiles appear here once you have bought something. Type a name to add an item.'**
  String get shoppingTilesEmpty;

  /// No description provided for @shoppingInTrolley.
  ///
  /// In en, this message translates to:
  /// **'In the trolley ({count})'**
  String shoppingInTrolley(int count);

  /// No description provided for @shoppingUncategorised.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get shoppingUncategorised;

  /// No description provided for @shoppingNewList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get shoppingNewList;

  /// No description provided for @shoppingListName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get shoppingListName;

  /// No description provided for @shoppingListKind.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get shoppingListKind;

  /// No description provided for @shoppingKindSupermarket.
  ///
  /// In en, this message translates to:
  /// **'Supermarket'**
  String get shoppingKindSupermarket;

  /// No description provided for @shoppingKindDrugstore.
  ///
  /// In en, this message translates to:
  /// **'Drugstore'**
  String get shoppingKindDrugstore;

  /// No description provided for @shoppingKindHardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware store'**
  String get shoppingKindHardware;

  /// No description provided for @shoppingKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get shoppingKindOther;

  /// No description provided for @shoppingMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Make default list'**
  String get shoppingMakeDefault;

  /// No description provided for @shoppingEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get shoppingEditItem;

  /// No description provided for @shoppingSpecHint.
  ///
  /// In en, this message translates to:
  /// **'Note, e.g. organic or 500 g'**
  String get shoppingSpecHint;

  /// No description provided for @shoppingCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get shoppingCategory;

  /// No description provided for @shoppingRemoveOne.
  ///
  /// In en, this message translates to:
  /// **'One less'**
  String get shoppingRemoveOne;

  /// No description provided for @errListExists.
  ///
  /// In en, this message translates to:
  /// **'A list with that name already exists.'**
  String get errListExists;

  /// No description provided for @errSpecTooLong.
  ///
  /// In en, this message translates to:
  /// **'That note is too long (40 characters at most).'**
  String get errSpecTooLong;

  /// No description provided for @errKioskForbidden.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be done on the wall display.'**
  String get errKioskForbidden;

  /// No description provided for @shoppingCat_produce.
  ///
  /// In en, this message translates to:
  /// **'Fruit & vegetables'**
  String get shoppingCat_produce;

  /// No description provided for @shoppingCat_bakery.
  ///
  /// In en, this message translates to:
  /// **'Bread & bakery'**
  String get shoppingCat_bakery;

  /// No description provided for @shoppingCat_dairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy & cheese'**
  String get shoppingCat_dairy;

  /// No description provided for @shoppingCat_meat_fish.
  ///
  /// In en, this message translates to:
  /// **'Meat & fish'**
  String get shoppingCat_meat_fish;

  /// No description provided for @shoppingCat_pantry.
  ///
  /// In en, this message translates to:
  /// **'Pantry'**
  String get shoppingCat_pantry;

  /// No description provided for @shoppingCat_frozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get shoppingCat_frozen;

  /// No description provided for @shoppingCat_drinks.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get shoppingCat_drinks;

  /// No description provided for @shoppingCat_household.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get shoppingCat_household;

  /// No description provided for @shoppingCat_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get shoppingCat_other;

  /// No description provided for @shoppingCat_care.
  ///
  /// In en, this message translates to:
  /// **'Body care'**
  String get shoppingCat_care;

  /// No description provided for @shoppingCat_baby.
  ///
  /// In en, this message translates to:
  /// **'Baby & kids'**
  String get shoppingCat_baby;

  /// No description provided for @shoppingCat_cleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get shoppingCat_cleaning;

  /// No description provided for @shoppingCat_health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get shoppingCat_health;

  /// No description provided for @shoppingCat_tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get shoppingCat_tools;

  /// No description provided for @shoppingCat_screws.
  ///
  /// In en, this message translates to:
  /// **'Screws & fixings'**
  String get shoppingCat_screws;

  /// No description provided for @shoppingCat_electrical.
  ///
  /// In en, this message translates to:
  /// **'Electrical'**
  String get shoppingCat_electrical;

  /// No description provided for @shoppingCat_garden.
  ///
  /// In en, this message translates to:
  /// **'Garden'**
  String get shoppingCat_garden;

  /// No description provided for @shoppingCreateTile.
  ///
  /// In en, this message translates to:
  /// **'Add “{name}”'**
  String shoppingCreateTile(String name);

  /// No description provided for @shoppingAddedBy.
  ///
  /// In en, this message translates to:
  /// **'Added by {name}'**
  String shoppingAddedBy(String name);

  /// No description provided for @pinChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Guardian PIN'**
  String get pinChangeTitle;

  /// No description provided for @pinChangeBody.
  ///
  /// In en, this message translates to:
  /// **'Set a new 6-digit PIN. This also unlocks a PIN that was locked by too many wrong tries.'**
  String get pinChangeBody;

  /// No description provided for @pinChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get pinChangeAction;

  /// No description provided for @pinChangeField.
  ///
  /// In en, this message translates to:
  /// **'New PIN (6 digits)'**
  String get pinChangeField;

  /// No description provided for @pinChanged.
  ///
  /// In en, this message translates to:
  /// **'PIN changed.'**
  String get pinChanged;

  /// No description provided for @shoppingTripItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String shoppingTripItems(int count);

  /// Banner while the offline outbox holds changes the server has not confirmed yet
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to be sent} other{{count} changes waiting to be sent}}'**
  String shoppingPending(int count);

  /// No description provided for @shoppingItemPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be sent'**
  String get shoppingItemPending;

  /// No description provided for @errCategoryNotFound.
  ///
  /// In en, this message translates to:
  /// **'That category no longer exists. The change was not saved.'**
  String get errCategoryNotFound;

  /// No description provided for @errNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'That name is too long.'**
  String get errNameTooLong;

  /// No description provided for @errActorInvalid.
  ///
  /// In en, this message translates to:
  /// **'That person is no longer part of the household. The change was not saved.'**
  String get errActorInvalid;

  /// No description provided for @doorApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get doorApple;

  /// No description provided for @doorGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get doorGoogle;

  /// No description provided for @doorEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get doorEmail;

  /// No description provided for @doorOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get doorOr;

  /// No description provided for @errProviderFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Try again, or sign in with your email.'**
  String get errProviderFailed;

  /// No description provided for @errSignupDisabled.
  ///
  /// In en, this message translates to:
  /// **'There is no WuselWall account for this address yet. Sign in with your email and password, then connect Apple or Google under Settings → Sign-in.'**
  String get errSignupDisabled;

  /// No description provided for @errIdentityAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This Apple or Google account is already connected to another WuselWall account.'**
  String get errIdentityAlreadyExists;

  /// No description provided for @errLastSignInMethod.
  ///
  /// In en, this message translates to:
  /// **'This is your only way to sign in, so it cannot be removed.'**
  String get errLastSignInMethod;

  /// No description provided for @errEmailExists.
  ///
  /// In en, this message translates to:
  /// **'This email address already belongs to another account.'**
  String get errEmailExists;

  /// No description provided for @signInMethodsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in'**
  String get signInMethodsTitle;

  /// No description provided for @signInMethodEmail.
  ///
  /// In en, this message translates to:
  /// **'Email and password'**
  String get signInMethodEmail;

  /// No description provided for @signInMethodApple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get signInMethodApple;

  /// No description provided for @signInMethodGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get signInMethodGoogle;

  /// No description provided for @signInMethodNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get signInMethodNotConnected;

  /// No description provided for @signInMethodConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get signInMethodConnect;

  /// No description provided for @signInMethodRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get signInMethodRemove;

  /// No description provided for @signInMethodLinkElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Connect it in the app on your phone.'**
  String get signInMethodLinkElsewhere;

  /// No description provided for @signInMethodConnected.
  ///
  /// In en, this message translates to:
  /// **'{provider} is connected.'**
  String signInMethodConnected(String provider);

  /// No description provided for @signInMethodRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {provider}? You will no longer be able to sign in with it.'**
  String signInMethodRemoveConfirm(String provider);

  /// No description provided for @boardWeekNumber.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String boardWeekNumber(int week);

  /// No description provided for @boardToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get boardToday;

  /// No description provided for @boardNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get boardNow;

  /// No description provided for @boardNextUp.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get boardNextUp;

  /// No description provided for @boardThen.
  ///
  /// In en, this message translates to:
  /// **'then'**
  String get boardThen;

  /// No description provided for @boardInMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {minutes} min'**
  String boardInMinutes(int minutes);

  /// No description provided for @boardInHours.
  ///
  /// In en, this message translates to:
  /// **'in {hours} h {minutes} min'**
  String boardInHours(int hours, int minutes);

  /// No description provided for @boardNothingMoreToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing else planned today'**
  String get boardNothingMoreToday;

  /// No description provided for @boardUpdatedSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'updated {seconds} s ago'**
  String boardUpdatedSecondsAgo(int seconds);

  /// No description provided for @boardUpdatedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'updated {minutes} min ago'**
  String boardUpdatedMinutesAgo(int minutes);

  /// No description provided for @boardLastUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'last updated {time}'**
  String boardLastUpdatedAt(String time);

  /// No description provided for @boardOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection – this is the last known plan.'**
  String get boardOffline;

  /// No description provided for @boardLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the week …'**
  String get boardLoading;

  /// No description provided for @boardZoneWhere.
  ///
  /// In en, this message translates to:
  /// **'Who is where'**
  String get boardZoneWhere;

  /// No description provided for @boardZoneWhereHint.
  ///
  /// In en, this message translates to:
  /// **'pale = as usual · bold = different'**
  String get boardZoneWhereHint;

  /// No description provided for @boardZoneEvents.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get boardZoneEvents;

  /// No description provided for @boardZoneEventsHint.
  ///
  /// In en, this message translates to:
  /// **'dots = who is involved · dashed = not certain yet'**
  String get boardZoneEventsHint;

  /// No description provided for @boardZoneMeal.
  ///
  /// In en, this message translates to:
  /// **'Hot meal'**
  String get boardZoneMeal;

  /// No description provided for @boardZoneMealHint.
  ///
  /// In en, this message translates to:
  /// **'filled dot = eating · open dot = not there'**
  String get boardZoneMealHint;

  /// No description provided for @boardMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get boardMorning;

  /// No description provided for @boardAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get boardAfternoon;

  /// No description provided for @boardEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get boardEvening;

  /// No description provided for @boardUntil.
  ///
  /// In en, this message translates to:
  /// **'until {time}'**
  String boardUntil(String time);

  /// No description provided for @boardFrom.
  ///
  /// In en, this message translates to:
  /// **'from {time}'**
  String boardFrom(String time);

  /// No description provided for @boardAllDay.
  ///
  /// In en, this message translates to:
  /// **'all day'**
  String get boardAllDay;

  /// No description provided for @boardMoreEvents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 more} other{+{count} more}}'**
  String boardMoreEvents(int count);

  /// No description provided for @boardMoreCount.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String boardMoreCount(int count);

  /// No description provided for @boardNoSchool.
  ///
  /// In en, this message translates to:
  /// **'free'**
  String get boardNoSchool;

  /// No description provided for @boardCareUntil.
  ///
  /// In en, this message translates to:
  /// **'{label} until {time}'**
  String boardCareUntil(String label, String time);

  /// No description provided for @boardCareDefault.
  ///
  /// In en, this message translates to:
  /// **'Care'**
  String get boardCareDefault;

  /// No description provided for @boardBusyUntil.
  ///
  /// In en, this message translates to:
  /// **'Meetings until {time}'**
  String boardBusyUntil(String time);

  /// No description provided for @boardMealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get boardMealLunch;

  /// No description provided for @boardMealDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get boardMealDinner;

  /// No description provided for @boardMealNothingPlanned.
  ///
  /// In en, this message translates to:
  /// **'nothing planned'**
  String get boardMealNothingPlanned;

  /// No description provided for @boardMealCook.
  ///
  /// In en, this message translates to:
  /// **'{name} cooks'**
  String boardMealCook(String name);

  /// No description provided for @boardMealGuests.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 guest} other{+{count} guests}}'**
  String boardMealGuests(int count);

  /// No description provided for @boardEating.
  ///
  /// In en, this message translates to:
  /// **'{name} is eating'**
  String boardEating(String name);

  /// No description provided for @boardNotEating.
  ///
  /// In en, this message translates to:
  /// **'{name} is not eating'**
  String boardNotEating(String name);

  /// No description provided for @boardOpenToday.
  ///
  /// In en, this message translates to:
  /// **'Open today'**
  String get boardOpenToday;

  /// No description provided for @boardAllDone.
  ///
  /// In en, this message translates to:
  /// **'All done today'**
  String get boardAllDone;

  /// No description provided for @boardShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get boardShoppingList;

  /// No description provided for @boardNightMode.
  ///
  /// In en, this message translates to:
  /// **'Night view'**
  String get boardNightMode;

  /// No description provided for @boardBackToWeek.
  ///
  /// In en, this message translates to:
  /// **'Back to the week'**
  String get boardBackToWeek;

  /// No description provided for @boardTentative.
  ///
  /// In en, this message translates to:
  /// **'not certain yet'**
  String get boardTentative;

  /// No description provided for @boardNoAppointments.
  ///
  /// In en, this message translates to:
  /// **'No appointments'**
  String get boardNoAppointments;

  /// No description provided for @boardSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get boardSchool;

  /// No description provided for @boardSchoolSpan.
  ///
  /// In en, this message translates to:
  /// **'School {span}'**
  String boardSchoolSpan(String span);

  /// No description provided for @boardNoSchoolToday.
  ///
  /// In en, this message translates to:
  /// **'No school'**
  String get boardNoSchoolToday;

  /// No description provided for @boardWeekend.
  ///
  /// In en, this message translates to:
  /// **'Weekend'**
  String get boardWeekend;

  /// No description provided for @boardWeekOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s week'**
  String boardWeekOf(String name);

  /// No description provided for @boardTimetableTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s timetable'**
  String boardTimetableTitle(String name);

  /// No description provided for @boardClass.
  ///
  /// In en, this message translates to:
  /// **'Class {label}'**
  String boardClass(String label);

  /// No description provided for @boardPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period {index}'**
  String boardPeriod(int index);

  /// No description provided for @boardBreak.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get boardBreak;

  /// No description provided for @boardLessonOver.
  ///
  /// In en, this message translates to:
  /// **'over'**
  String get boardLessonOver;

  /// No description provided for @boardLessonNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get boardLessonNow;

  /// No description provided for @boardLessonCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get boardLessonCancelled;

  /// No description provided for @boardLessonSubstituted.
  ///
  /// In en, this message translates to:
  /// **'Substitute'**
  String get boardLessonSubstituted;

  /// No description provided for @boardLessonRoomChange.
  ///
  /// In en, this message translates to:
  /// **'Room change'**
  String get boardLessonRoomChange;

  /// No description provided for @boardLessonExtra.
  ///
  /// In en, this message translates to:
  /// **'Extra'**
  String get boardLessonExtra;

  /// No description provided for @boardPackTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Pack for tomorrow: {items}'**
  String boardPackTomorrow(String items);

  /// No description provided for @boardPackToday.
  ///
  /// In en, this message translates to:
  /// **'Pack for today: {items}'**
  String boardPackToday(String items);

  /// No description provided for @boardWholeWeek.
  ///
  /// In en, this message translates to:
  /// **'The whole week'**
  String get boardWholeWeek;

  /// No description provided for @boardMealWeek.
  ///
  /// In en, this message translates to:
  /// **'This week\'s meals'**
  String get boardMealWeek;

  /// No description provided for @boardBaseline.
  ///
  /// In en, this message translates to:
  /// **'Usually: {label}'**
  String boardBaseline(String label);

  /// No description provided for @boardNoDeviation.
  ///
  /// In en, this message translates to:
  /// **'as usual'**
  String get boardNoDeviation;

  /// No description provided for @boardCooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get boardCooking;

  /// No description provided for @boardAppointmentsOf.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get boardAppointmentsOf;

  /// No description provided for @boardTasksOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s tasks'**
  String boardTasksOf(String name);

  /// No description provided for @boardTasksComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Tasks arrive with the next update.'**
  String get boardTasksComingSoon;

  /// No description provided for @presenceWorking.
  ///
  /// In en, this message translates to:
  /// **'At work'**
  String get presenceWorking;

  /// No description provided for @presenceHomeOffice.
  ///
  /// In en, this message translates to:
  /// **'Home office'**
  String get presenceHomeOffice;

  /// No description provided for @presenceTravel.
  ///
  /// In en, this message translates to:
  /// **'Travelling'**
  String get presenceTravel;

  /// No description provided for @presenceAway.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get presenceAway;

  /// No description provided for @presenceOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get presenceOff;

  /// No description provided for @presenceChildcare.
  ///
  /// In en, this message translates to:
  /// **'Childcare'**
  String get presenceChildcare;

  /// No description provided for @errSettingInvalid.
  ///
  /// In en, this message translates to:
  /// **'That value is outside the allowed range.'**
  String get errSettingInvalid;

  /// No description provided for @errSettingUnknown.
  ///
  /// In en, this message translates to:
  /// **'That setting does not exist.'**
  String get errSettingUnknown;

  /// No description provided for @errSettingTarget.
  ///
  /// In en, this message translates to:
  /// **'That setting cannot be changed for this person or device.'**
  String get errSettingTarget;

  /// No description provided for @householdSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Household settings'**
  String get householdSettingsTitle;

  /// No description provided for @householdSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Defaults for tasks, calendar, meals and the kitchen display'**
  String get householdSettingsSubtitle;

  /// No description provided for @settingsSectionHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household and members'**
  String get settingsSectionHousehold;

  /// No description provided for @settingsSectionTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get settingsSectionTasks;

  /// No description provided for @settingsSectionCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar and school'**
  String get settingsSectionCalendar;

  /// No description provided for @settingsSectionMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get settingsSectionMeals;

  /// No description provided for @settingsSectionKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen display'**
  String get settingsSectionKitchen;

  /// No description provided for @settingsSectionDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get settingsSectionDevice;

  /// No description provided for @settingsSectionMine.
  ///
  /// In en, this message translates to:
  /// **'My settings'**
  String get settingsSectionMine;

  /// No description provided for @settingPickPersonFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose who you are first. Your own settings appear here then.'**
  String get settingPickPersonFirst;

  /// No description provided for @settingIsDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingIsDefault;

  /// No description provided for @settingIsCustom.
  ///
  /// In en, this message translates to:
  /// **'Customised'**
  String get settingIsCustom;

  /// No description provided for @settingReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get settingReset;

  /// No description provided for @settingOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingOn;

  /// No description provided for @settingOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingOff;

  /// No description provided for @settingFrom.
  ///
  /// In en, this message translates to:
  /// **'from'**
  String get settingFrom;

  /// No description provided for @settingTo.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get settingTo;

  /// No description provided for @settingIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get settingIncrease;

  /// No description provided for @settingDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get settingDecrease;

  /// No description provided for @settingDayPartsMorningEnds.
  ///
  /// In en, this message translates to:
  /// **'Morning until'**
  String get settingDayPartsMorningEnds;

  /// No description provided for @settingDayPartsEveningStarts.
  ///
  /// In en, this message translates to:
  /// **'Evening from'**
  String get settingDayPartsEveningStarts;

  /// No description provided for @settingUnitPoints.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point} other{{count} points}}'**
  String settingUnitPoints(int count);

  /// No description provided for @settingUnitMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String settingUnitMinutes(int count);

  /// No description provided for @settingUnitSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count} s'**
  String settingUnitSeconds(int count);

  /// No description provided for @settingValueName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get settingValueName;

  /// No description provided for @settingValueInitial.
  ///
  /// In en, this message translates to:
  /// **'Initial'**
  String get settingValueInitial;

  /// No description provided for @settingValueDuty.
  ///
  /// In en, this message translates to:
  /// **'Duty'**
  String get settingValueDuty;

  /// No description provided for @settingValueBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get settingValueBonus;

  /// No description provided for @settingValueRequired.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get settingValueRequired;

  /// No description provided for @settingValueSelfServe.
  ///
  /// In en, this message translates to:
  /// **'Self-serve'**
  String get settingValueSelfServe;

  /// No description provided for @settingValueWholeFamily.
  ///
  /// In en, this message translates to:
  /// **'Whole family'**
  String get settingValueWholeFamily;

  /// No description provided for @settingValueAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get settingValueAll;

  /// No description provided for @settingValueNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingValueNone;

  /// No description provided for @settingValueLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get settingValueLunch;

  /// No description provided for @settingValueDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get settingValueDinner;

  /// No description provided for @settingBoardMemberLabelTitle.
  ///
  /// In en, this message translates to:
  /// **'Names on the board'**
  String get settingBoardMemberLabelTitle;

  /// No description provided for @settingBoardMemberLabelHelp.
  ///
  /// In en, this message translates to:
  /// **'A name reads better than an initial from two metres. Pick initials if visitors are often in the kitchen.'**
  String get settingBoardMemberLabelHelp;

  /// No description provided for @settingTasksDutyPointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Points for a duty'**
  String get settingTasksDutyPointsTitle;

  /// No description provided for @settingTasksDutyPointsHelp.
  ///
  /// In en, this message translates to:
  /// **'Duties are expected of everyone, so they earn little or nothing. The streak is their reward.'**
  String get settingTasksDutyPointsHelp;

  /// No description provided for @settingTasksBonusPointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Points for a bonus task'**
  String get settingTasksBonusPointsTitle;

  /// No description provided for @settingTasksBonusPointsHelp.
  ///
  /// In en, this message translates to:
  /// **'One bonus task buys the cheapest starter reward, so a younger child gets there within days.'**
  String get settingTasksBonusPointsHelp;

  /// No description provided for @settingTasksKindTitle.
  ///
  /// In en, this message translates to:
  /// **'New tasks are'**
  String get settingTasksKindTitle;

  /// No description provided for @settingTasksKindHelp.
  ///
  /// In en, this message translates to:
  /// **'A new chore is a duty unless someone deliberately makes it a bonus. That keeps the earning surface narrow.'**
  String get settingTasksKindHelp;

  /// No description provided for @settingTasksVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Guardians check chores'**
  String get settingTasksVerificationTitle;

  /// No description provided for @settingTasksVerificationHelp.
  ///
  /// In en, this message translates to:
  /// **'Checking turns every chore into an inspection, so use it only for valuable bonus tasks.'**
  String get settingTasksVerificationHelp;

  /// No description provided for @settingTasksJokersTitle.
  ///
  /// In en, this message translates to:
  /// **'Streak jokers per month'**
  String get settingTasksJokersTitle;

  /// No description provided for @settingTasksJokersHelp.
  ///
  /// In en, this message translates to:
  /// **'A joker keeps a streak alive on a missed day, so one sick day does not wipe out a three-week streak.'**
  String get settingTasksJokersHelp;

  /// No description provided for @settingTasksRewardApprovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Rewards need approval'**
  String get settingTasksRewardApprovalTitle;

  /// No description provided for @settingTasksRewardApprovalHelp.
  ///
  /// In en, this message translates to:
  /// **'A guardian approves each redemption with the PIN. Self-serve suits only trivial rewards.'**
  String get settingTasksRewardApprovalHelp;

  /// No description provided for @settingCalendarMembersEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Members edit their own events'**
  String get settingCalendarMembersEditTitle;

  /// No description provided for @settingCalendarMembersEditHelp.
  ///
  /// In en, this message translates to:
  /// **'Children create and edit events they attend themselves. Deleting someone else\'s event stays a guardian action.'**
  String get settingCalendarMembersEditHelp;

  /// No description provided for @settingCalendarKeyDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'New events on the kitchen wall'**
  String get settingCalendarKeyDefaultTitle;

  /// No description provided for @settingCalendarKeyDefaultHelp.
  ///
  /// In en, this message translates to:
  /// **'Decides which new events appear on the kitchen wall without anyone ticking the box. Review it after two weeks of use.'**
  String get settingCalendarKeyDefaultHelp;

  /// No description provided for @settingSchoolReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Members report timetable changes'**
  String get settingSchoolReportTitle;

  /// No description provided for @settingSchoolReportHelp.
  ///
  /// In en, this message translates to:
  /// **'Only guardians maintain the timetable. With this on, a child can report a cancelled lesson for a guardian to confirm.'**
  String get settingSchoolReportHelp;

  /// No description provided for @settingSchoolEquipmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Equipment hint for tomorrow'**
  String get settingSchoolEquipmentTitle;

  /// No description provided for @settingSchoolEquipmentHelp.
  ///
  /// In en, this message translates to:
  /// **'Shows what to bring tomorrow, such as sports kit, from tomorrow\'s subjects.'**
  String get settingSchoolEquipmentHelp;

  /// No description provided for @settingMealsSchoolDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Warm meal on school days'**
  String get settingMealsSchoolDayTitle;

  /// No description provided for @settingMealsSchoolDayHelp.
  ///
  /// In en, this message translates to:
  /// **'The one warm meal on the kitchen wall. On school days children eat lunch at school or in the Hort.'**
  String get settingMealsSchoolDayHelp;

  /// No description provided for @settingMealsFreeDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Warm meal on free days'**
  String get settingMealsFreeDayTitle;

  /// No description provided for @settingMealsFreeDayHelp.
  ///
  /// In en, this message translates to:
  /// **'For weekends and holidays.'**
  String get settingMealsFreeDayHelp;

  /// No description provided for @settingMealsAwayTitle.
  ///
  /// In en, this message translates to:
  /// **'Away means not eating'**
  String get settingMealsAwayTitle;

  /// No description provided for @settingMealsAwayHelp.
  ///
  /// In en, this message translates to:
  /// **'Travelling or away over a meal\'s time marks that person as not eating, so most days need no input.'**
  String get settingMealsAwayHelp;

  /// No description provided for @settingMealsCareCutoffTitle.
  ///
  /// In en, this message translates to:
  /// **'Lunch cut-off for care'**
  String get settingMealsCareCutoffTitle;

  /// No description provided for @settingMealsCareCutoffHelp.
  ///
  /// In en, this message translates to:
  /// **'A child whose care runs past this time is out for lunch.'**
  String get settingMealsCareCutoffHelp;

  /// No description provided for @settingBoardRolloverTitle.
  ///
  /// In en, this message translates to:
  /// **'Kitchen wall moves on'**
  String get settingBoardRolloverTitle;

  /// No description provided for @settingBoardRolloverHelp.
  ///
  /// In en, this message translates to:
  /// **'When the wall moves to the coming week. Sunday evening planning wants next week; Saturday morning still wants this one.'**
  String get settingBoardRolloverHelp;

  /// No description provided for @settingBoardDayPartsTitle.
  ///
  /// In en, this message translates to:
  /// **'Morning, afternoon, evening'**
  String get settingBoardDayPartsTitle;

  /// No description provided for @settingBoardDayPartsHelp.
  ///
  /// In en, this message translates to:
  /// **'Where the appointment zone splits into morning, afternoon and evening.'**
  String get settingBoardDayPartsHelp;

  /// No description provided for @settingDeviceNightHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Night theme hours'**
  String get settingDeviceNightHoursTitle;

  /// No description provided for @settingDeviceNightHoursHelp.
  ///
  /// In en, this message translates to:
  /// **'When the kiosk switches to the amber night theme.'**
  String get settingDeviceNightHoursHelp;

  /// No description provided for @settingDeviceIdleRevertTitle.
  ///
  /// In en, this message translates to:
  /// **'Back to the wall after'**
  String get settingDeviceIdleRevertTitle;

  /// No description provided for @settingDeviceIdleRevertHelp.
  ///
  /// In en, this message translates to:
  /// **'How long an opened profile or detail view stays open before the kiosk returns to the wall.'**
  String get settingDeviceIdleRevertHelp;

  /// No description provided for @settingMemberCompletionSoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Sound when a chore is ticked'**
  String get settingMemberCompletionSoundTitle;

  /// No description provided for @settingMemberCompletionSoundHelp.
  ///
  /// In en, this message translates to:
  /// **'Ticking a chore off makes a short sound. Switch it off if you do not want it.'**
  String get settingMemberCompletionSoundHelp;

  /// No description provided for @settingCalendarTentativeTitle.
  ///
  /// In en, this message translates to:
  /// **'Check uncertain events at'**
  String get settingCalendarTentativeTitle;

  /// No description provided for @settingCalendarTentativeHelp.
  ///
  /// In en, this message translates to:
  /// **'Asks whether a tentative entry is happening, so it does not stay uncertain until it starts.'**
  String get settingCalendarTentativeHelp;

  /// No description provided for @settingNotifyMorningTitle.
  ///
  /// In en, this message translates to:
  /// **'Morning summary'**
  String get settingNotifyMorningTitle;

  /// No description provided for @settingNotifyMorningHelp.
  ///
  /// In en, this message translates to:
  /// **'Today\'s tasks and events for you. Pending redemptions appear here for guardians.'**
  String get settingNotifyMorningHelp;

  /// No description provided for @settingNotifyEventReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder before events'**
  String get settingNotifyEventReminderTitle;

  /// No description provided for @settingNotifyEventReminderHelp.
  ///
  /// In en, this message translates to:
  /// **'A notification before an event starts.'**
  String get settingNotifyEventReminderHelp;

  /// No description provided for @settingNotifyTaskVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'When a chore is verified'**
  String get settingNotifyTaskVerifiedTitle;

  /// No description provided for @settingNotifyTaskVerifiedHelp.
  ///
  /// In en, this message translates to:
  /// **'A notification when a guardian verifies a chore and its points are credited.'**
  String get settingNotifyTaskVerifiedHelp;

  /// No description provided for @settingNotifyRedemptionTitle.
  ///
  /// In en, this message translates to:
  /// **'When a reward is requested'**
  String get settingNotifyRedemptionTitle;

  /// No description provided for @settingNotifyRedemptionHelp.
  ///
  /// In en, this message translates to:
  /// **'An immediate notification when a child asks for a reward.'**
  String get settingNotifyRedemptionHelp;

  /// Care end next to notable lessons on the wall, e.g. 'Hort 15'
  ///
  /// In en, this message translates to:
  /// **'{label} {time}'**
  String boardCareShort(String label, String time);

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get calendarDay;

  /// No description provided for @calendarThreeDays.
  ///
  /// In en, this message translates to:
  /// **'3 days'**
  String get calendarThreeDays;

  /// No description provided for @calendarWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarWeek;

  /// No description provided for @calendarPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get calendarPrevious;

  /// No description provided for @calendarNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get calendarNext;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String calendarRange(String from, String to);

  /// No description provided for @calendarNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get calendarNewEvent;

  /// No description provided for @calendarEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned'**
  String get calendarEmpty;

  /// No description provided for @calendarEditorPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'The event editor is coming soon.'**
  String get calendarEditorPlaceholder;

  /// No description provided for @eventEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get eventEditTitle;

  /// No description provided for @eventTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get eventTitleLabel;

  /// No description provided for @eventTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title.'**
  String get eventTitleRequired;

  /// No description provided for @eventKindAppointment.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get eventKindAppointment;

  /// No description provided for @eventKindPresence.
  ///
  /// In en, this message translates to:
  /// **'Presence'**
  String get eventKindPresence;

  /// No description provided for @eventPresenceState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get eventPresenceState;

  /// No description provided for @eventPresenceStateRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a state.'**
  String get eventPresenceStateRequired;

  /// No description provided for @eventAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get eventAllDay;

  /// No description provided for @eventStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get eventStarts;

  /// No description provided for @eventEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get eventEnds;

  /// No description provided for @eventEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end must be after the start.'**
  String get eventEndBeforeStart;

  /// No description provided for @eventAttendees.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get eventAttendees;

  /// No description provided for @eventAttendeesWholeFamily.
  ///
  /// In en, this message translates to:
  /// **'Nobody picked: this is for the whole family.'**
  String get eventAttendeesWholeFamily;

  /// No description provided for @eventLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get eventLocation;

  /// No description provided for @eventNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get eventNotes;

  /// No description provided for @eventTentative.
  ///
  /// In en, this message translates to:
  /// **'Not sure yet'**
  String get eventTentative;

  /// No description provided for @eventKeyDisplay.
  ///
  /// In en, this message translates to:
  /// **'Show on the kitchen display'**
  String get eventKeyDisplay;

  /// No description provided for @eventRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get eventRepeat;

  /// No description provided for @eventRepeatNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get eventRepeatNever;

  /// No description provided for @eventRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get eventRepeatDaily;

  /// No description provided for @eventRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get eventRepeatWeekly;

  /// No description provided for @eventRepeatBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get eventRepeatBiweekly;

  /// No description provided for @eventRepeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get eventRepeatMonthly;

  /// No description provided for @eventRepeatSpecificDays.
  ///
  /// In en, this message translates to:
  /// **'Specific days (shift plan)'**
  String get eventRepeatSpecificDays;

  /// No description provided for @eventRepeatMonthlyDay.
  ///
  /// In en, this message translates to:
  /// **'on the {day}.'**
  String eventRepeatMonthlyDay(int day);

  /// No description provided for @eventRepeatMonthlyNth.
  ///
  /// In en, this message translates to:
  /// **'the {n}. {weekday} of the month'**
  String eventRepeatMonthlyNth(int n, String weekday);

  /// No description provided for @eventRepeatMonthlyLast.
  ///
  /// In en, this message translates to:
  /// **'the last {weekday}'**
  String eventRepeatMonthlyLast(String weekday);

  /// No description provided for @eventRepeatDays.
  ///
  /// In en, this message translates to:
  /// **'On these days'**
  String get eventRepeatDays;

  /// No description provided for @eventRepeatEnds.
  ///
  /// In en, this message translates to:
  /// **'Repeat ends'**
  String get eventRepeatEnds;

  /// No description provided for @eventRepeatUntil.
  ///
  /// In en, this message translates to:
  /// **'on a date'**
  String get eventRepeatUntil;

  /// No description provided for @eventRepeatCount.
  ///
  /// In en, this message translates to:
  /// **'after {count} times'**
  String eventRepeatCount(int count);

  /// No description provided for @eventDaysPicked.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String eventDaysPicked(int count);

  /// No description provided for @eventDienstplanHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap the days that count. The start day is always included.'**
  String get eventDienstplanHelp;

  /// No description provided for @eventCustomRule.
  ///
  /// In en, this message translates to:
  /// **'Custom rule'**
  String get eventCustomRule;

  /// No description provided for @eventCustomRuleHelp.
  ///
  /// In en, this message translates to:
  /// **'This repeat pattern cannot be edited here. It stays as it is.'**
  String get eventCustomRuleHelp;

  /// No description provided for @eventWeekdaysRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one weekday.'**
  String get eventWeekdaysRequired;

  /// No description provided for @eventDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this event?'**
  String get eventDeleteConfirm;

  /// No description provided for @eventScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Which events?'**
  String get eventScopeTitle;

  /// No description provided for @eventScopeDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete which events?'**
  String get eventScopeDeleteTitle;

  /// No description provided for @eventScopeThis.
  ///
  /// In en, this message translates to:
  /// **'Only this event'**
  String get eventScopeThis;

  /// No description provided for @eventScopeSeries.
  ///
  /// In en, this message translates to:
  /// **'All events in the series'**
  String get eventScopeSeries;

  /// No description provided for @errEventInvalid.
  ///
  /// In en, this message translates to:
  /// **'This event is not valid.'**
  String get errEventInvalid;

  /// No description provided for @errRruleInvalid.
  ///
  /// In en, this message translates to:
  /// **'This repeat pattern cannot be saved.'**
  String get errRruleInvalid;

  /// No description provided for @errAttendeeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Someone you chose does not belong to this household.'**
  String get errAttendeeInvalid;

  /// No description provided for @errEventNotFound.
  ///
  /// In en, this message translates to:
  /// **'This event no longer exists.'**
  String get errEventNotFound;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get scheduleTitle;

  /// No description provided for @tasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTitle;

  /// No description provided for @mealsTitle.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get mealsTitle;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'This part is being built.'**
  String get comingSoon;

  /// No description provided for @mealsWeekRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String mealsWeekRange(String from, String to);

  /// No description provided for @mealsPrevWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get mealsPrevWeek;

  /// No description provided for @mealsNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get mealsNextWeek;

  /// No description provided for @mealsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get mealsThisWeek;

  /// No description provided for @mealsRecipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get mealsRecipes;

  /// No description provided for @mealsFillShopping.
  ///
  /// In en, this message translates to:
  /// **'Fill shopping list'**
  String get mealsFillShopping;

  /// No description provided for @mealsSlotBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealsSlotBreakfast;

  /// No description provided for @mealsSlotLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealsSlotLunch;

  /// No description provided for @mealsSlotDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealsSlotDinner;

  /// No description provided for @mealsSlotSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealsSlotSnack;

  /// No description provided for @mealsNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned yet'**
  String get mealsNothingYet;

  /// No description provided for @mealsAddOther.
  ///
  /// In en, this message translates to:
  /// **'Add meal'**
  String get mealsAddOther;

  /// No description provided for @mealsDragHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a meal and drop it on another day to move it.'**
  String get mealsDragHint;

  /// No description provided for @mealsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Meal on {day}'**
  String mealsEditTitle(String day);

  /// No description provided for @mealsFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Dish or note'**
  String get mealsFieldLabel;

  /// No description provided for @mealsFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Pizza, leftovers, a recipe name …'**
  String get mealsFieldHint;

  /// No description provided for @mealsSuggestionHelp.
  ///
  /// In en, this message translates to:
  /// **'Matching recipes. Tap one to use it; its ingredients then go on the shopping list.'**
  String get mealsSuggestionHelp;

  /// No description provided for @mealsServings.
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get mealsServings;

  /// No description provided for @mealsCook.
  ///
  /// In en, this message translates to:
  /// **'Cooks'**
  String get mealsCook;

  /// No description provided for @mealsCookNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody'**
  String get mealsCookNobody;

  /// No description provided for @mealsTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get mealsTime;

  /// No description provided for @mealsTimeNone.
  ///
  /// In en, this message translates to:
  /// **'No time'**
  String get mealsTimeNone;

  /// No description provided for @mealsGuests.
  ///
  /// In en, this message translates to:
  /// **'Guests'**
  String get mealsGuests;

  /// No description provided for @mealsEatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Who is eating'**
  String get mealsEatingTitle;

  /// No description provided for @mealsEatingHelp.
  ///
  /// In en, this message translates to:
  /// **'Someone who is away or travelling over the meal, or who has Hort past the cut-off, is switched off automatically. Set it by hand only when that is not true.'**
  String get mealsEatingHelp;

  /// No description provided for @mealsEatingAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get mealsEatingAuto;

  /// No description provided for @mealsEatingYes.
  ///
  /// In en, this message translates to:
  /// **'Eating'**
  String get mealsEatingYes;

  /// No description provided for @mealsEatingNo.
  ///
  /// In en, this message translates to:
  /// **'Not eating'**
  String get mealsEatingNo;

  /// No description provided for @mealsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete meal'**
  String get mealsDelete;

  /// No description provided for @mealsPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Fill shopping list'**
  String get mealsPreviewTitle;

  /// No description provided for @mealsPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to add. Free-text meals have no ingredients; recipes put theirs on the list.'**
  String get mealsPreviewEmpty;

  /// No description provided for @mealsPreviewOnList.
  ///
  /// In en, this message translates to:
  /// **'Already on the list'**
  String get mealsPreviewOnList;

  /// No description provided for @mealsPreviewFor.
  ///
  /// In en, this message translates to:
  /// **'For {meals}'**
  String mealsPreviewFor(String meals);

  /// No description provided for @mealsPreviewAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {count, plural, =0{nothing} =1{1 item} other{{count} items}}'**
  String mealsPreviewAdd(int count);

  /// No description provided for @mealsPreviewAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item added to the shopping list} other{{count} items added to the shopping list}}'**
  String mealsPreviewAdded(int count);

  /// No description provided for @mealsRecipesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get mealsRecipesTitle;

  /// No description provided for @mealsRecipeSearch.
  ///
  /// In en, this message translates to:
  /// **'Search recipes'**
  String get mealsRecipeSearch;

  /// No description provided for @mealsRecipesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recipes yet. A dish name is enough for a meal; a recipe adds its ingredients to the shopping list.'**
  String get mealsRecipesEmpty;

  /// No description provided for @mealsRecipeNew.
  ///
  /// In en, this message translates to:
  /// **'New recipe'**
  String get mealsRecipeNew;

  /// No description provided for @mealsRecipeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit recipe'**
  String get mealsRecipeEdit;

  /// No description provided for @mealsRecipeTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get mealsRecipeTitleField;

  /// No description provided for @mealsIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get mealsIngredients;

  /// No description provided for @mealsIngredientName.
  ///
  /// In en, this message translates to:
  /// **'Ingredient'**
  String get mealsIngredientName;

  /// No description provided for @mealsIngredientQuantity.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get mealsIngredientQuantity;

  /// No description provided for @mealsIngredientUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get mealsIngredientUnit;

  /// No description provided for @mealsIngredientNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get mealsIngredientNote;

  /// No description provided for @mealsIngredientAdd.
  ///
  /// In en, this message translates to:
  /// **'Add ingredient'**
  String get mealsIngredientAdd;

  /// No description provided for @mealsIngredientRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove ingredient'**
  String get mealsIngredientRemove;

  /// No description provided for @mealsIngredientMove.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get mealsIngredientMove;

  /// No description provided for @mealsNoIngredients.
  ///
  /// In en, this message translates to:
  /// **'No ingredients listed.'**
  String get mealsNoIngredients;

  /// No description provided for @mealsSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get mealsSteps;

  /// No description provided for @mealsStepsHint.
  ///
  /// In en, this message translates to:
  /// **'One step per line'**
  String get mealsStepsHint;

  /// No description provided for @mealsTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get mealsTags;

  /// No description provided for @mealsTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Separated by commas, e.g. quick, vegetarian'**
  String get mealsTagsHint;

  /// No description provided for @mealsSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Source link'**
  String get mealsSourceUrl;

  /// No description provided for @mealsSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get mealsSource;

  /// No description provided for @mealsRecipeSave.
  ///
  /// In en, this message translates to:
  /// **'Save recipe'**
  String get mealsRecipeSave;

  /// No description provided for @mealsRecipeDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete recipe'**
  String get mealsRecipeDelete;

  /// No description provided for @mealsRecipeDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”? Meals that use it keep their name.'**
  String mealsRecipeDeleteConfirm(String title);

  /// No description provided for @mealsRecipeTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'A recipe needs a title.'**
  String get mealsRecipeTitleRequired;

  /// No description provided for @mealsKioskHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a dot to change who is eating'**
  String get mealsKioskHint;

  /// No description provided for @errMealInvalid.
  ///
  /// In en, this message translates to:
  /// **'That meal could not be saved. Check the entry and try again.'**
  String get errMealInvalid;

  /// No description provided for @schoolSetupCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up the school'**
  String get schoolSetupCardTitle;

  /// No description provided for @schoolSetupCardBody.
  ///
  /// In en, this message translates to:
  /// **'Add the school, its bell times and the terms. Then the timetable can be entered.'**
  String get schoolSetupCardBody;

  /// No description provided for @schoolSetupAction.
  ///
  /// In en, this message translates to:
  /// **'Set up school'**
  String get schoolSetupAction;

  /// No description provided for @schoolEnterTimetableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the timetable'**
  String get schoolEnterTimetableTitle;

  /// No description provided for @schoolEnterTimetableBody.
  ///
  /// In en, this message translates to:
  /// **'{name} has no timetable for this term yet.'**
  String schoolEnterTimetableBody(String name);

  /// No description provided for @schoolEnterTimetableAction.
  ///
  /// In en, this message translates to:
  /// **'Enter timetable'**
  String get schoolEnterTimetableAction;

  /// No description provided for @schoolNoChildren.
  ///
  /// In en, this message translates to:
  /// **'No child in the household yet.'**
  String get schoolNoChildren;

  /// No description provided for @schoolEditSchool.
  ///
  /// In en, this message translates to:
  /// **'Edit school'**
  String get schoolEditSchool;

  /// No description provided for @schoolEditTimetable.
  ///
  /// In en, this message translates to:
  /// **'Edit timetable'**
  String get schoolEditTimetable;

  /// No description provided for @schoolPrevWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get schoolPrevWeek;

  /// No description provided for @schoolNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get schoolNextWeek;

  /// No description provided for @schoolThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get schoolThisWeek;

  /// No description provided for @schoolWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Week {week} · {from} – {to}'**
  String schoolWeekLabel(int week, String from, String to);

  /// No description provided for @schoolChooseChild.
  ///
  /// In en, this message translates to:
  /// **'Choose child'**
  String get schoolChooseChild;

  /// No description provided for @schoolHolidayBand.
  ///
  /// In en, this message translates to:
  /// **'{name} · {range}'**
  String schoolHolidayBand(String name, String range);

  /// No description provided for @schoolNoLessonsToday.
  ///
  /// In en, this message translates to:
  /// **'No lessons'**
  String get schoolNoLessonsToday;

  /// No description provided for @schoolPackTomorrowNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing to pack for tomorrow.'**
  String get schoolPackTomorrowNone;

  /// No description provided for @schoolLessonActions.
  ///
  /// In en, this message translates to:
  /// **'{subject}, {day}, {period}'**
  String schoolLessonActions(String subject, String day, String period);

  /// No description provided for @schoolCancelLesson.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get schoolCancelLesson;

  /// No description provided for @schoolSubstitute.
  ///
  /// In en, this message translates to:
  /// **'Substitute'**
  String get schoolSubstitute;

  /// No description provided for @schoolRoomChange.
  ///
  /// In en, this message translates to:
  /// **'Room changed'**
  String get schoolRoomChange;

  /// No description provided for @schoolResetException.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get schoolResetException;

  /// No description provided for @schoolPickSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get schoolPickSubject;

  /// No description provided for @schoolSearchSubject.
  ///
  /// In en, this message translates to:
  /// **'Find subject'**
  String get schoolSearchSubject;

  /// No description provided for @schoolTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get schoolTeacher;

  /// No description provided for @schoolNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get schoolNote;

  /// No description provided for @schoolRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get schoolRoom;

  /// No description provided for @schoolApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get schoolApply;

  /// No description provided for @schoolSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get schoolSaved;

  /// No description provided for @schoolNoSubjects.
  ///
  /// In en, this message translates to:
  /// **'No subjects yet. Add them in the school setup.'**
  String get schoolNoSubjects;

  /// No description provided for @schoolSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get schoolSetupTitle;

  /// No description provided for @schoolSectionSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get schoolSectionSchool;

  /// No description provided for @schoolName.
  ///
  /// In en, this message translates to:
  /// **'Name of the school'**
  String get schoolName;

  /// No description provided for @schoolState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get schoolState;

  /// No description provided for @schoolStateNone.
  ///
  /// In en, this message translates to:
  /// **'Not given'**
  String get schoolStateNone;

  /// No description provided for @schoolStateBW.
  ///
  /// In en, this message translates to:
  /// **'Baden-Württemberg'**
  String get schoolStateBW;

  /// No description provided for @schoolStateBY.
  ///
  /// In en, this message translates to:
  /// **'Bavaria'**
  String get schoolStateBY;

  /// No description provided for @schoolStateBE.
  ///
  /// In en, this message translates to:
  /// **'Berlin'**
  String get schoolStateBE;

  /// No description provided for @schoolStateBB.
  ///
  /// In en, this message translates to:
  /// **'Brandenburg'**
  String get schoolStateBB;

  /// No description provided for @schoolStateHB.
  ///
  /// In en, this message translates to:
  /// **'Bremen'**
  String get schoolStateHB;

  /// No description provided for @schoolStateHH.
  ///
  /// In en, this message translates to:
  /// **'Hamburg'**
  String get schoolStateHH;

  /// No description provided for @schoolStateHE.
  ///
  /// In en, this message translates to:
  /// **'Hesse'**
  String get schoolStateHE;

  /// No description provided for @schoolStateMV.
  ///
  /// In en, this message translates to:
  /// **'Mecklenburg-Western Pomerania'**
  String get schoolStateMV;

  /// No description provided for @schoolStateNI.
  ///
  /// In en, this message translates to:
  /// **'Lower Saxony'**
  String get schoolStateNI;

  /// No description provided for @schoolStateNW.
  ///
  /// In en, this message translates to:
  /// **'North Rhine-Westphalia'**
  String get schoolStateNW;

  /// No description provided for @schoolStateRP.
  ///
  /// In en, this message translates to:
  /// **'Rhineland-Palatinate'**
  String get schoolStateRP;

  /// No description provided for @schoolStateSL.
  ///
  /// In en, this message translates to:
  /// **'Saarland'**
  String get schoolStateSL;

  /// No description provided for @schoolStateSN.
  ///
  /// In en, this message translates to:
  /// **'Saxony'**
  String get schoolStateSN;

  /// No description provided for @schoolStateST.
  ///
  /// In en, this message translates to:
  /// **'Saxony-Anhalt'**
  String get schoolStateST;

  /// No description provided for @schoolStateSH.
  ///
  /// In en, this message translates to:
  /// **'Schleswig-Holstein'**
  String get schoolStateSH;

  /// No description provided for @schoolStateTH.
  ///
  /// In en, this message translates to:
  /// **'Thuringia'**
  String get schoolStateTH;

  /// No description provided for @schoolBellTimes.
  ///
  /// In en, this message translates to:
  /// **'Bell times'**
  String get schoolBellTimes;

  /// No description provided for @schoolAddLesson.
  ///
  /// In en, this message translates to:
  /// **'Add lesson'**
  String get schoolAddLesson;

  /// No description provided for @schoolAddBreak.
  ///
  /// In en, this message translates to:
  /// **'Add break'**
  String get schoolAddBreak;

  /// No description provided for @schoolRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get schoolRemove;

  /// No description provided for @schoolStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get schoolStart;

  /// No description provided for @schoolEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get schoolEnd;

  /// No description provided for @schoolTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get schoolTerms;

  /// No description provided for @schoolAddTerm.
  ///
  /// In en, this message translates to:
  /// **'Add term'**
  String get schoolAddTerm;

  /// No description provided for @schoolTermEdit.
  ///
  /// In en, this message translates to:
  /// **'Term'**
  String get schoolTermEdit;

  /// No description provided for @schoolTermName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get schoolTermName;

  /// No description provided for @schoolFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get schoolFrom;

  /// No description provided for @schoolTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get schoolTo;

  /// No description provided for @schoolAbWeek.
  ///
  /// In en, this message translates to:
  /// **'A/B anchor week (calendar week)'**
  String get schoolAbWeek;

  /// No description provided for @schoolAbWeekHint.
  ///
  /// In en, this message translates to:
  /// **'A week that is an A week. Empty: every week is the same.'**
  String get schoolAbWeekHint;

  /// No description provided for @schoolCurrent.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get schoolCurrent;

  /// No description provided for @schoolSubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get schoolSubjects;

  /// No description provided for @schoolAddSubject.
  ///
  /// In en, this message translates to:
  /// **'Add subject'**
  String get schoolAddSubject;

  /// No description provided for @schoolSubjectEdit.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get schoolSubjectEdit;

  /// No description provided for @schoolSubjectShort.
  ///
  /// In en, this message translates to:
  /// **'Short name'**
  String get schoolSubjectShort;

  /// No description provided for @schoolTint.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get schoolTint;

  /// No description provided for @schoolEquipment.
  ///
  /// In en, this message translates to:
  /// **'Things to bring'**
  String get schoolEquipment;

  /// No description provided for @schoolNotable.
  ///
  /// In en, this message translates to:
  /// **'Show on the wall'**
  String get schoolNotable;

  /// No description provided for @schoolSubjectInUse.
  ///
  /// In en, this message translates to:
  /// **'This subject is still in a timetable. Remove it there first.'**
  String get schoolSubjectInUse;

  /// No description provided for @schoolInvalid.
  ///
  /// In en, this message translates to:
  /// **'These details do not fit together.'**
  String get schoolInvalid;

  /// No description provided for @schoolHolidays.
  ///
  /// In en, this message translates to:
  /// **'Holidays and free days'**
  String get schoolHolidays;

  /// No description provided for @schoolAddHoliday.
  ///
  /// In en, this message translates to:
  /// **'Add holiday'**
  String get schoolAddHoliday;

  /// No description provided for @schoolHolidayEdit.
  ///
  /// In en, this message translates to:
  /// **'Holiday'**
  String get schoolHolidayEdit;

  /// No description provided for @schoolHolidayName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get schoolHolidayName;

  /// No description provided for @schoolEditorClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get schoolEditorClass;

  /// No description provided for @schoolWeekCycle.
  ///
  /// In en, this message translates to:
  /// **'Week rhythm'**
  String get schoolWeekCycle;

  /// No description provided for @schoolCycleWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get schoolCycleWeekly;

  /// No description provided for @schoolCycleAb.
  ///
  /// In en, this message translates to:
  /// **'A/B weeks'**
  String get schoolCycleAb;

  /// No description provided for @schoolParityAll.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get schoolParityAll;

  /// No description provided for @schoolParityA.
  ///
  /// In en, this message translates to:
  /// **'A week'**
  String get schoolParityA;

  /// No description provided for @schoolParityB.
  ///
  /// In en, this message translates to:
  /// **'B week'**
  String get schoolParityB;

  /// No description provided for @schoolClearDay.
  ///
  /// In en, this message translates to:
  /// **'Clear day'**
  String get schoolClearDay;

  /// No description provided for @schoolClearCell.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get schoolClearCell;

  /// No description provided for @schoolCopyFrom.
  ///
  /// In en, this message translates to:
  /// **'Copy from…'**
  String get schoolCopyFrom;

  /// No description provided for @schoolCopyPick.
  ///
  /// In en, this message translates to:
  /// **'Copy timetable from'**
  String get schoolCopyPick;

  /// No description provided for @schoolCareRows.
  ///
  /// In en, this message translates to:
  /// **'After school care'**
  String get schoolCareRows;

  /// No description provided for @schoolAddCare.
  ///
  /// In en, this message translates to:
  /// **'Add care'**
  String get schoolAddCare;

  /// No description provided for @schoolCareTitle.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get schoolCareTitle;

  /// No description provided for @schoolCareDays.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get schoolCareDays;

  /// No description provided for @schoolSaveTimetable.
  ///
  /// In en, this message translates to:
  /// **'Save timetable'**
  String get schoolSaveTimetable;

  /// No description provided for @schoolWeekdayPick.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get schoolWeekdayPick;

  /// No description provided for @feedTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar subscriptions'**
  String get feedTitle;

  /// No description provided for @feedSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The family calendar in Outlook or on an iPhone'**
  String get feedSettingsSubtitle;

  /// No description provided for @feedNew.
  ///
  /// In en, this message translates to:
  /// **'New subscription'**
  String get feedNew;

  /// No description provided for @feedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet. A subscription shows appointments in Outlook or on an iPhone, read-only.'**
  String get feedEmpty;

  /// No description provided for @feedRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get feedRevoked;

  /// No description provided for @feedNeverFetched.
  ///
  /// In en, this message translates to:
  /// **'Never fetched'**
  String get feedNeverFetched;

  /// No description provided for @feedLastFetched.
  ///
  /// In en, this message translates to:
  /// **'Last fetched: {when}'**
  String feedLastFetched(String when);

  /// No description provided for @feedAgoJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get feedAgoJustNow;

  /// No description provided for @feedAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String feedAgoMinutes(int count);

  /// No description provided for @feedAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String feedAgoHours(int count);

  /// No description provided for @feedAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String feedAgoDays(int count);

  /// No description provided for @feedFetchCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{fetched once} other{fetched {count} times}}'**
  String feedFetchCount(int count);

  /// No description provided for @feedSummaryAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get feedSummaryAppointments;

  /// No description provided for @feedSummaryPresence.
  ///
  /// In en, this message translates to:
  /// **'Presence'**
  String get feedSummaryPresence;

  /// No description provided for @feedSummaryEveryone.
  ///
  /// In en, this message translates to:
  /// **'All members'**
  String get feedSummaryEveryone;

  /// No description provided for @feedSummarySchoolDay.
  ///
  /// In en, this message translates to:
  /// **'School day'**
  String get feedSummarySchoolDay;

  /// No description provided for @feedSummarySchoolLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get feedSummarySchoolLessons;

  /// No description provided for @feedWhoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Whose events'**
  String get feedWhoseTitle;

  /// No description provided for @feedWhoseHelp.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected: everyone'**
  String get feedWhoseHelp;

  /// No description provided for @feedLabelField.
  ///
  /// In en, this message translates to:
  /// **'Subscription name'**
  String get feedLabelField;

  /// No description provided for @feedLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. work laptop Outlook'**
  String get feedLabelHint;

  /// No description provided for @feedWhatTitle.
  ///
  /// In en, this message translates to:
  /// **'What'**
  String get feedWhatTitle;

  /// No description provided for @feedKindPresenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Presence'**
  String get feedKindPresenceTitle;

  /// No description provided for @feedPresenceHint.
  ///
  /// In en, this message translates to:
  /// **'Shows who is where and when (work, home office, off …). Better left off for work devices and children.'**
  String get feedPresenceHint;

  /// No description provided for @feedSchoolTitle.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get feedSchoolTitle;

  /// No description provided for @feedSchoolOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get feedSchoolOff;

  /// No description provided for @feedSchoolHint.
  ///
  /// In en, this message translates to:
  /// **'School days as one all-day entry, or every lesson.'**
  String get feedSchoolHint;

  /// No description provided for @feedCreate.
  ///
  /// In en, this message translates to:
  /// **'Create subscription'**
  String get feedCreate;

  /// No description provided for @feedUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription address'**
  String get feedUrlTitle;

  /// No description provided for @feedUrlOnce.
  ///
  /// In en, this message translates to:
  /// **'This address is shown only once. Anyone who has it can see the events, so treat it like a password.'**
  String get feedUrlOnce;

  /// No description provided for @feedCopyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get feedCopyUrl;

  /// No description provided for @feedCopyWebcal.
  ///
  /// In en, this message translates to:
  /// **'Copy webcal link'**
  String get feedCopyWebcal;

  /// No description provided for @feedWebcalLabel.
  ///
  /// In en, this message translates to:
  /// **'webcal link (opens the iPhone dialog)'**
  String get feedWebcalLabel;

  /// No description provided for @feedCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied.'**
  String get feedCopied;

  /// No description provided for @feedQrLabel.
  ///
  /// In en, this message translates to:
  /// **'QR code with the subscription address'**
  String get feedQrLabel;

  /// No description provided for @feedHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How to subscribe'**
  String get feedHowTitle;

  /// No description provided for @feedHowOutlook.
  ///
  /// In en, this message translates to:
  /// **'Outlook on the web: Calendar → Add calendar → Subscribe from web → paste the address → name it “Family”.'**
  String get feedHowOutlook;

  /// No description provided for @feedHowIphone.
  ///
  /// In en, this message translates to:
  /// **'iPhone: Settings → Apps → Calendar → Accounts → Add Account → Other → Add Subscribed Calendar → paste the address. Or tap the webcal link.'**
  String get feedHowIphone;

  /// No description provided for @feedRevokeAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get feedRevokeAction;

  /// No description provided for @feedRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Revoke “{label}”? It stops receiving events at once.'**
  String feedRevokeConfirm(String label);

  /// No description provided for @baselineTitle.
  ///
  /// In en, this message translates to:
  /// **'Usual place'**
  String get baselineTitle;

  /// No description provided for @baselineSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where everyone usually is'**
  String get baselineSettingsSubtitle;

  /// No description provided for @baselineHelp.
  ///
  /// In en, this message translates to:
  /// **'Where you usually are. Only deviations get entered, so a normal day stays empty.'**
  String get baselineHelp;

  /// No description provided for @baselineNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing set'**
  String get baselineNone;

  /// No description provided for @baselineLabelField.
  ///
  /// In en, this message translates to:
  /// **'Own label (optional)'**
  String get baselineLabelField;

  /// No description provided for @baselineLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. at home'**
  String get baselineLabelHint;

  /// No description provided for @baselineSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get baselineSaved;

  /// No description provided for @busyTitle.
  ///
  /// In en, this message translates to:
  /// **'Meetings until'**
  String get busyTitle;

  /// No description provided for @busyPickTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a time'**
  String get busyPickTime;

  /// No description provided for @busyThisDay.
  ///
  /// In en, this message translates to:
  /// **'This day only'**
  String get busyThisDay;

  /// No description provided for @busyWholeWeek.
  ///
  /// In en, this message translates to:
  /// **'Apply to the whole week (Mon–Fri)'**
  String get busyWholeWeek;

  /// No description provided for @busyRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get busyRemove;

  /// No description provided for @busyHelp.
  ///
  /// In en, this message translates to:
  /// **'Until when you are not available. Just the time: no appointments, no details.'**
  String get busyHelp;

  /// No description provided for @busyFor.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get busyFor;

  /// No description provided for @tasksTabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tasksTabToday;

  /// No description provided for @tasksTabApprovals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get tasksTabApprovals;

  /// No description provided for @tasksTabChores.
  ///
  /// In en, this message translates to:
  /// **'Chores'**
  String get tasksTabChores;

  /// No description provided for @tasksTabRewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get tasksTabRewards;

  /// No description provided for @tasksTabPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get tasksTabPoints;

  /// No description provided for @tasksNothingToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today.'**
  String get tasksNothingToday;

  /// No description provided for @tasksOpenForAnyone.
  ///
  /// In en, this message translates to:
  /// **'Open for anyone'**
  String get tasksOpenForAnyone;

  /// No description provided for @tasksWaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'waiting for approval'**
  String get tasksWaitingApproval;

  /// No description provided for @tasksDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tasksDone;

  /// No description provided for @tasksUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get tasksUndo;

  /// No description provided for @tasksCompletedSnack.
  ///
  /// In en, this message translates to:
  /// **'{title} done'**
  String tasksCompletedSnack(String title);

  /// No description provided for @tasksPointsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point} other{{count} points}}'**
  String tasksPointsCount(int count);

  /// No description provided for @tasksStreakBadge.
  ///
  /// In en, this message translates to:
  /// **'🔥 {count}'**
  String tasksStreakBadge(int count);

  /// No description provided for @tasksStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day in a row} other{{count} days in a row}}'**
  String tasksStreakDays(int count);

  /// No description provided for @tasksOpenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{none open} =1{1 open} other{{count} open}}'**
  String tasksOpenCount(int count);

  /// No description provided for @tasksKindDuty.
  ///
  /// In en, this message translates to:
  /// **'Duty'**
  String get tasksKindDuty;

  /// No description provided for @tasksKindBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get tasksKindBonus;

  /// No description provided for @tasksApprovalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to check.'**
  String get tasksApprovalsEmpty;

  /// No description provided for @tasksCheckChores.
  ///
  /// In en, this message translates to:
  /// **'Chores to check'**
  String get tasksCheckChores;

  /// No description provided for @tasksRewardRequests.
  ///
  /// In en, this message translates to:
  /// **'Reward requests'**
  String get tasksRewardRequests;

  /// No description provided for @tasksApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get tasksApprove;

  /// No description provided for @tasksDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get tasksDecline;

  /// No description provided for @tasksRequestedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} wants {reward}'**
  String tasksRequestedBy(String name, String reward);

  /// No description provided for @tasksDoneBy.
  ///
  /// In en, this message translates to:
  /// **'Done by {name}'**
  String tasksDoneBy(String name);

  /// No description provided for @tasksNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get tasksNoteOptional;

  /// No description provided for @tasksNoChores.
  ///
  /// In en, this message translates to:
  /// **'No chores yet.'**
  String get tasksNoChores;

  /// No description provided for @tasksStarterTitle.
  ///
  /// In en, this message translates to:
  /// **'Start with the starter pack'**
  String get tasksStarterTitle;

  /// No description provided for @tasksStarterHelp.
  ///
  /// In en, this message translates to:
  /// **'Five chores, three rewards and four badges to begin with. Everything can be changed afterwards.'**
  String get tasksStarterHelp;

  /// No description provided for @tasksStarterAdd.
  ///
  /// In en, this message translates to:
  /// **'Add starter pack'**
  String get tasksStarterAdd;

  /// No description provided for @tasksStarterDone.
  ///
  /// In en, this message translates to:
  /// **'Starter pack added.'**
  String get tasksStarterDone;

  /// No description provided for @tasksNewChore.
  ///
  /// In en, this message translates to:
  /// **'New chore'**
  String get tasksNewChore;

  /// No description provided for @tasksEditChore.
  ///
  /// In en, this message translates to:
  /// **'Edit chore'**
  String get tasksEditChore;

  /// No description provided for @tasksFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get tasksFieldTitle;

  /// No description provided for @tasksTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title.'**
  String get tasksTitleRequired;

  /// No description provided for @tasksFieldIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get tasksFieldIcon;

  /// No description provided for @tasksNoIcon.
  ///
  /// In en, this message translates to:
  /// **'No icon'**
  String get tasksNoIcon;

  /// No description provided for @tasksFieldKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get tasksFieldKind;

  /// No description provided for @tasksKindDutyHelp.
  ///
  /// In en, this message translates to:
  /// **'Expected of everyone; earns little.'**
  String get tasksKindDutyHelp;

  /// No description provided for @tasksKindBonusHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional extra work; earns points.'**
  String get tasksKindBonusHelp;

  /// No description provided for @tasksFieldPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get tasksFieldPoints;

  /// No description provided for @tasksFieldRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get tasksFieldRepeat;

  /// No description provided for @tasksRepeatOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get tasksRepeatOnce;

  /// No description provided for @tasksRepeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get tasksRepeatDaily;

  /// No description provided for @tasksRepeatWeekdays.
  ///
  /// In en, this message translates to:
  /// **'On weekdays'**
  String get tasksRepeatWeekdays;

  /// No description provided for @tasksRepeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get tasksRepeatWeekly;

  /// No description provided for @tasksRepeatBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get tasksRepeatBiweekly;

  /// No description provided for @tasksRepeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get tasksRepeatMonthly;

  /// No description provided for @tasksWeekdayOne.
  ///
  /// In en, this message translates to:
  /// **'Weekday'**
  String get tasksWeekdayOne;

  /// No description provided for @tasksWeekdayMany.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get tasksWeekdayMany;

  /// No description provided for @tasksWeekdaysRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one weekday.'**
  String get tasksWeekdaysRequired;

  /// No description provided for @tasksFieldStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts on'**
  String get tasksFieldStarts;

  /// No description provided for @tasksFieldWindow.
  ///
  /// In en, this message translates to:
  /// **'Can be done'**
  String get tasksFieldWindow;

  /// No description provided for @tasksWindowDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Only on the due day} other{{count} days from the due day}}'**
  String tasksWindowDays(int count);

  /// No description provided for @tasksFieldWho.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get tasksFieldWho;

  /// No description provided for @tasksWhoFixed.
  ///
  /// In en, this message translates to:
  /// **'One person'**
  String get tasksWhoFixed;

  /// No description provided for @tasksWhoRotating.
  ///
  /// In en, this message translates to:
  /// **'Taking turns'**
  String get tasksWhoRotating;

  /// No description provided for @tasksWhoOpen.
  ///
  /// In en, this message translates to:
  /// **'Whoever wants'**
  String get tasksWhoOpen;

  /// No description provided for @tasksWhoEach.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get tasksWhoEach;

  /// No description provided for @tasksPickOne.
  ///
  /// In en, this message translates to:
  /// **'Who does it?'**
  String get tasksPickOne;

  /// No description provided for @tasksPickPool.
  ///
  /// In en, this message translates to:
  /// **'Who takes part?'**
  String get tasksPickPool;

  /// No description provided for @tasksPickOpenPool.
  ///
  /// In en, this message translates to:
  /// **'Who may take it? Empty means everyone.'**
  String get tasksPickOpenPool;

  /// No description provided for @tasksPoolRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one person.'**
  String get tasksPoolRequired;

  /// No description provided for @tasksFieldVerification.
  ///
  /// In en, this message translates to:
  /// **'Approval by a grown-up'**
  String get tasksFieldVerification;

  /// No description provided for @tasksVerificationHelp.
  ///
  /// In en, this message translates to:
  /// **'Points come after a check.'**
  String get tasksVerificationHelp;

  /// No description provided for @tasksArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get tasksArchive;

  /// No description provided for @tasksArchiveHelp.
  ///
  /// In en, this message translates to:
  /// **'The chore disappears. Its open entries in the future are removed.'**
  String get tasksArchiveHelp;

  /// No description provided for @tasksNoRewards.
  ///
  /// In en, this message translates to:
  /// **'No rewards yet.'**
  String get tasksNoRewards;

  /// No description provided for @tasksNewReward.
  ///
  /// In en, this message translates to:
  /// **'New reward'**
  String get tasksNewReward;

  /// No description provided for @tasksEditReward.
  ///
  /// In en, this message translates to:
  /// **'Edit reward'**
  String get tasksEditReward;

  /// No description provided for @tasksFieldCost.
  ///
  /// In en, this message translates to:
  /// **'Cost in points'**
  String get tasksFieldCost;

  /// No description provided for @tasksFieldStock.
  ///
  /// In en, this message translates to:
  /// **'Stock (empty means unlimited)'**
  String get tasksFieldStock;

  /// No description provided for @tasksFieldNeedsApproval.
  ///
  /// In en, this message translates to:
  /// **'Needs approval first'**
  String get tasksFieldNeedsApproval;

  /// No description provided for @tasksNeedsApprovalHelp.
  ///
  /// In en, this message translates to:
  /// **'Off only suits small things.'**
  String get tasksNeedsApprovalHelp;

  /// No description provided for @tasksAskForReward.
  ///
  /// In en, this message translates to:
  /// **'Ask for it'**
  String get tasksAskForReward;

  /// No description provided for @tasksRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent.'**
  String get tasksRequestSent;

  /// No description provided for @tasksRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Redeemed.'**
  String get tasksRedeemed;

  /// No description provided for @tasksSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get tasksSoldOut;

  /// No description provided for @tasksMissingPoints.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point short} other{{count} points short}}'**
  String tasksMissingPoints(int count);

  /// No description provided for @tasksHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tasksHistory;

  /// No description provided for @tasksNoHistory.
  ///
  /// In en, this message translates to:
  /// **'Nothing redeemed yet.'**
  String get tasksNoHistory;

  /// No description provided for @tasksRedemptionRequested.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get tasksRedemptionRequested;

  /// No description provided for @tasksRedemptionApproved.
  ///
  /// In en, this message translates to:
  /// **'Redeemed, not handed over yet'**
  String get tasksRedemptionApproved;

  /// No description provided for @tasksRedemptionDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get tasksRedemptionDeclined;

  /// No description provided for @tasksRedemptionFulfilled.
  ///
  /// In en, this message translates to:
  /// **'Handed over'**
  String get tasksRedemptionFulfilled;

  /// No description provided for @tasksHandOver.
  ///
  /// In en, this message translates to:
  /// **'Mark as handed over'**
  String get tasksHandOver;

  /// No description provided for @tasksNoLedger.
  ///
  /// In en, this message translates to:
  /// **'No movements yet.'**
  String get tasksNoLedger;

  /// No description provided for @tasksLedgerTask.
  ///
  /// In en, this message translates to:
  /// **'Chore done'**
  String get tasksLedgerTask;

  /// No description provided for @tasksLedgerUndo.
  ///
  /// In en, this message translates to:
  /// **'Taken back'**
  String get tasksLedgerUndo;

  /// No description provided for @tasksLedgerRedemption.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get tasksLedgerRedemption;

  /// No description provided for @tasksLedgerAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get tasksLedgerAdjustment;

  /// No description provided for @tasksLedgerBadge.
  ///
  /// In en, this message translates to:
  /// **'Badge'**
  String get tasksLedgerBadge;

  /// No description provided for @tasksLedgerBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get tasksLedgerBonus;

  /// No description provided for @tasksAdjust.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get tasksAdjust;

  /// No description provided for @tasksAdjustTitle.
  ///
  /// In en, this message translates to:
  /// **'Correct points for {name}'**
  String tasksAdjustTitle(String name);

  /// No description provided for @tasksFieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Points (+ or −)'**
  String get tasksFieldAmount;

  /// No description provided for @tasksAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number other than 0.'**
  String get tasksAmountInvalid;

  /// No description provided for @tasksFieldReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (required)'**
  String get tasksFieldReason;

  /// No description provided for @tasksReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Please give a reason.'**
  String get tasksReasonRequired;

  /// No description provided for @tasksBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get tasksBalanceTitle;

  /// No description provided for @tasksBoardStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get tasksBoardStreakLabel;

  /// No description provided for @errTaskInvalid.
  ///
  /// In en, this message translates to:
  /// **'That chore is not valid.'**
  String get errTaskInvalid;

  /// No description provided for @errTaskNotYours.
  ///
  /// In en, this message translates to:
  /// **'Only the person it is for can do that.'**
  String get errTaskNotYours;

  /// No description provided for @errBalanceInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Not enough points for that.'**
  String get errBalanceInsufficient;

  /// No description provided for @errRewardOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'That reward is sold out.'**
  String get errRewardOutOfStock;

  /// No description provided for @errTaskNotOpen.
  ///
  /// In en, this message translates to:
  /// **'This chore is no longer open.'**
  String get errTaskNotOpen;

  /// No description provided for @tasksActionTick.
  ///
  /// In en, this message translates to:
  /// **'Tick off'**
  String get tasksActionTick;

  /// No description provided for @tasksPointsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number, 0 or more.'**
  String get tasksPointsInvalid;

  /// No description provided for @kidTabToday.
  ///
  /// In en, this message translates to:
  /// **'My day'**
  String get kidTabToday;

  /// No description provided for @kidTabSchool.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get kidTabSchool;

  /// No description provided for @kidTabPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get kidTabPoints;

  /// No description provided for @kidTabShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get kidTabShopping;

  /// No description provided for @kidTabFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get kidTabFamily;

  /// No description provided for @kidWhoAreYou.
  ///
  /// In en, this message translates to:
  /// **'Hi! Tap your name.'**
  String get kidWhoAreYou;

  /// No description provided for @kidGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}!'**
  String kidGreeting(String name);

  /// No description provided for @kidTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'My chores'**
  String get kidTasksTitle;

  /// No description provided for @kidTasksNone.
  ///
  /// In en, this message translates to:
  /// **'You have no chores today.'**
  String get kidTasksNone;

  /// No description provided for @kidTasksAllDone.
  ///
  /// In en, this message translates to:
  /// **'All done! 🎉'**
  String get kidTasksAllDone;

  /// No description provided for @kidTasksAllDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Well done, you did everything for today.'**
  String get kidTasksAllDoneBody;

  /// No description provided for @kidAwaitsCheck.
  ///
  /// In en, this message translates to:
  /// **'being checked'**
  String get kidAwaitsCheck;

  /// No description provided for @kidDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get kidDone;

  /// No description provided for @kidTaskDoneSnack.
  ///
  /// In en, this message translates to:
  /// **'{title} done!'**
  String kidTaskDoneSnack(String title);

  /// No description provided for @kidUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get kidUndo;

  /// No description provided for @kidSchoolTitle.
  ///
  /// In en, this message translates to:
  /// **'School today'**
  String get kidSchoolTitle;

  /// No description provided for @kidNoSchoolToday.
  ///
  /// In en, this message translates to:
  /// **'No school today.'**
  String get kidNoSchoolToday;

  /// No description provided for @kidHoliday.
  ///
  /// In en, this message translates to:
  /// **'Holidays: {name}'**
  String kidHoliday(String name);

  /// No description provided for @kidNoTimetable.
  ///
  /// In en, this message translates to:
  /// **'No timetable has been entered for you yet.'**
  String get kidNoTimetable;

  /// No description provided for @kidRoom.
  ///
  /// In en, this message translates to:
  /// **'Room {room}'**
  String kidRoom(String room);

  /// No description provided for @kidNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get kidNow;

  /// No description provided for @kidLessonCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get kidLessonCancelled;

  /// No description provided for @kidLessonSubstituted.
  ///
  /// In en, this message translates to:
  /// **'substitute teacher'**
  String get kidLessonSubstituted;

  /// No description provided for @kidLessonRoomChange.
  ///
  /// In en, this message translates to:
  /// **'different room'**
  String get kidLessonRoomChange;

  /// No description provided for @kidCareUntil.
  ///
  /// In en, this message translates to:
  /// **'Care until {time}'**
  String kidCareUntil(String time);

  /// No description provided for @kidTomorrowNeeds.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow you need: {items}'**
  String kidTomorrowNeeds(String items);

  /// No description provided for @kidMealDinner.
  ///
  /// In en, this message translates to:
  /// **'Tonight we are having {dish}'**
  String kidMealDinner(String dish);

  /// No description provided for @kidMealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch today is {dish}'**
  String kidMealLunch(String dish);

  /// No description provided for @kidMealNoneDinner.
  ///
  /// In en, this message translates to:
  /// **'Nothing is planned for tonight yet.'**
  String get kidMealNoneDinner;

  /// No description provided for @kidMealNoneLunch.
  ///
  /// In en, this message translates to:
  /// **'Nothing is planned for lunch yet.'**
  String get kidMealNoneLunch;

  /// No description provided for @kidMealEatingYou.
  ///
  /// In en, this message translates to:
  /// **'You are eating too.'**
  String get kidMealEatingYou;

  /// No description provided for @kidEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'My appointments today'**
  String get kidEventsTitle;

  /// No description provided for @kidNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No appointments today.'**
  String get kidNoEvents;

  /// No description provided for @kidAllDay.
  ///
  /// In en, this message translates to:
  /// **'all day'**
  String get kidAllDay;

  /// No description provided for @kidTimetableTitle.
  ///
  /// In en, this message translates to:
  /// **'My timetable'**
  String get kidTimetableTitle;

  /// No description provided for @kidTodayMarker.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get kidTodayMarker;

  /// No description provided for @kidYourPoints.
  ///
  /// In en, this message translates to:
  /// **'Your points'**
  String get kidYourPoints;

  /// No description provided for @kidRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get kidRewardsTitle;

  /// No description provided for @kidRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get kidRedeem;

  /// No description provided for @kidNeedMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 point to go} other{{count} points to go}}'**
  String kidNeedMore(int count);

  /// No description provided for @kidWaitsApproval.
  ///
  /// In en, this message translates to:
  /// **'waiting for approval'**
  String get kidWaitsApproval;

  /// No description provided for @kidRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Your reward is waiting for approval.'**
  String get kidRequestSent;

  /// No description provided for @kidRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Redeemed! 🎉'**
  String get kidRedeemed;

  /// No description provided for @kidSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out for now'**
  String get kidSoldOut;

  /// No description provided for @kidBadgesTitle.
  ///
  /// In en, this message translates to:
  /// **'My badges'**
  String get kidBadgesTitle;

  /// No description provided for @kidStreaksTitle.
  ///
  /// In en, this message translates to:
  /// **'My streaks'**
  String get kidStreaksTitle;

  /// No description provided for @kidStreak.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day {title} 🔥} other{{days} days {title} 🔥}}'**
  String kidStreak(int days, String title);

  /// No description provided for @kidFamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'Family today'**
  String get kidFamilyTitle;

  /// No description provided for @kidOpenTasks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No chores open} =1{1 chore open} other{{count} chores open}}'**
  String kidOpenTasks(int count);

  /// No description provided for @kidNoPlanToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned today'**
  String get kidNoPlanToday;

  /// No description provided for @schoolsUiAddSchool.
  ///
  /// In en, this message translates to:
  /// **'Another school'**
  String get schoolsUiAddSchool;

  /// No description provided for @schoolsUiNewSchool.
  ///
  /// In en, this message translates to:
  /// **'New school'**
  String get schoolsUiNewSchool;

  /// No description provided for @schoolsUiPickSchool.
  ///
  /// In en, this message translates to:
  /// **'Choose school'**
  String get schoolsUiPickSchool;

  /// No description provided for @schoolsUiAskSchool.
  ///
  /// In en, this message translates to:
  /// **'Which school?'**
  String get schoolsUiAskSchool;

  /// No description provided for @schoolsUiSchoolOf.
  ///
  /// In en, this message translates to:
  /// **'School: {name}'**
  String schoolsUiSchoolOf(String name);

  /// No description provided for @schoolsUiDayMenu.
  ///
  /// In en, this message translates to:
  /// **'Day actions'**
  String get schoolsUiDayMenu;

  /// No description provided for @schoolsUiCopyDay.
  ///
  /// In en, this message translates to:
  /// **'Copy day to…'**
  String get schoolsUiCopyDay;

  /// No description provided for @schoolsUiCopyDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy {day} to'**
  String schoolsUiCopyDayTitle(String day);

  /// No description provided for @schoolsUiCopyDayApply.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get schoolsUiCopyDayApply;

  /// No description provided for @schoolsUiSwapDay.
  ///
  /// In en, this message translates to:
  /// **'Swap with…'**
  String get schoolsUiSwapDay;

  /// No description provided for @schoolsUiSwapDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Swap {day} with'**
  String schoolsUiSwapDayTitle(String day);

  /// No description provided for @schoolsUiDayCleared.
  ///
  /// In en, this message translates to:
  /// **'Day cleared'**
  String get schoolsUiDayCleared;

  /// No description provided for @schoolsUiDayCopied.
  ///
  /// In en, this message translates to:
  /// **'Day copied'**
  String get schoolsUiDayCopied;

  /// No description provided for @schoolsUiDaySwapped.
  ///
  /// In en, this message translates to:
  /// **'Days swapped'**
  String get schoolsUiDaySwapped;

  /// No description provided for @schoolsUiUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get schoolsUiUndo;

  /// No description provided for @mealsUxSuggestOften.
  ///
  /// In en, this message translates to:
  /// **'Family favourites'**
  String get mealsUxSuggestOften;

  /// No description provided for @mealsUxSuggestRare.
  ///
  /// In en, this message translates to:
  /// **'Not had in a while'**
  String get mealsUxSuggestRare;

  /// No description provided for @mealsUxClearedSnack.
  ///
  /// In en, this message translates to:
  /// **'{title} removed'**
  String mealsUxClearedSnack(String title);

  /// No description provided for @mealsUxUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get mealsUxUndo;

  /// No description provided for @mealsUxFromMealPlan.
  ///
  /// In en, this message translates to:
  /// **'From the meal plan'**
  String get mealsUxFromMealPlan;

  /// No description provided for @mealsUxForMeal.
  ///
  /// In en, this message translates to:
  /// **'For: {meal} · {day}'**
  String mealsUxForMeal(String meal, String day);
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
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

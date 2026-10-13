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

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get setupTitle;

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
  /// **'This device is not set up yet'**
  String get setupHeadline;

  /// No description provided for @setupBody.
  ///
  /// In en, this message translates to:
  /// **'Enrol this device with a code from a guardian, sign in as a guardian, or set up a new household.'**
  String get setupBody;

  /// No description provided for @setupEnrolAction.
  ///
  /// In en, this message translates to:
  /// **'Set up this device with a code'**
  String get setupEnrolAction;

  /// No description provided for @setupSignInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in as guardian'**
  String get setupSignInAction;

  /// No description provided for @setupHouseholdAction.
  ///
  /// In en, this message translates to:
  /// **'Set up a new household'**
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
  /// **'Set up this device'**
  String get enrolTitle;

  /// No description provided for @enrolBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the code shown on a device that is already set up.'**
  String get enrolBody;

  /// No description provided for @enrolCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Enrolment code'**
  String get enrolCodeLabel;

  /// No description provided for @enrolAction.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get enrolAction;

  /// No description provided for @errSetupTokenInvalid.
  ///
  /// In en, this message translates to:
  /// **'The setup token is not valid.'**
  String get errSetupTokenInvalid;

  /// No description provided for @errSetupClosed.
  ///
  /// In en, this message translates to:
  /// **'This system is already set up.'**
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

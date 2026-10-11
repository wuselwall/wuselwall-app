// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WuselWall';

  @override
  String get unexpectedError => 'An unexpected error occurred';

  @override
  String get retry => 'Try again';

  @override
  String get errorNetwork =>
      'No connection to the server. Check your network and try again.';

  @override
  String get errorAuth => 'You are not signed in, or your session has expired.';

  @override
  String get errorPermission => 'You are not allowed to do that.';

  @override
  String get errorNotFound => 'That could not be found.';

  @override
  String get errorConflict =>
      'That clashes with something that already exists.';

  @override
  String get errorValidation => 'That input is not valid.';

  @override
  String get errorUnknown => 'Something went wrong.';

  @override
  String configMissing(String missing) {
    return 'This build is missing its configuration: $missing';
  }

  @override
  String get setupTitle => 'Set up';

  @override
  String get registerAdult => 'Adult';

  @override
  String get registerKid => 'Kid';

  @override
  String get registerKiosk => 'Wall display';

  @override
  String get systemTitle => 'System';

  @override
  String get systemBuild => 'Build';

  @override
  String get systemEnvironment => 'Environment';

  @override
  String get systemBackendUrl => 'Backend URL';

  @override
  String get systemConnectivity => 'Connectivity';

  @override
  String get systemNetwork => 'Network';

  @override
  String get systemOnline => 'Online';

  @override
  String get systemOffline => 'Offline';

  @override
  String get systemUnknown => 'Unknown';

  @override
  String get systemBackend => 'Backend';

  @override
  String get systemStatus => 'Status';

  @override
  String get systemStatusOk => 'OK';

  @override
  String get systemDbVersion => 'Database version';

  @override
  String get systemServerTime => 'Server time';

  @override
  String get setupHeadline => 'This device is not set up yet';

  @override
  String get setupBody =>
      'Enrol this device with a code from a guardian, sign in as a guardian, or set up a new household.';

  @override
  String get setupEnrolAction => 'Set up this device with a code';

  @override
  String get setupSignInAction => 'Sign in as guardian';

  @override
  String get setupHouseholdAction => 'Set up a new household';

  @override
  String get wizardTitle => 'New household';

  @override
  String get wizardCreate => 'Create household';

  @override
  String get fieldSetupToken => 'Setup token';

  @override
  String get fieldHouseholdName => 'Household name';

  @override
  String get fieldYourName => 'Your name';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password (at least 10 characters)';

  @override
  String get fieldPasswordSimple => 'Password';

  @override
  String get fieldPin => '6-digit PIN';

  @override
  String get fieldRequired => 'Required';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInAction => 'Sign in';

  @override
  String get enrolTitle => 'Set up this device';

  @override
  String get enrolBody =>
      'Enter the code shown on a device that is already set up.';

  @override
  String get enrolCodeLabel => 'Enrolment code';

  @override
  String get enrolAction => 'Set up';

  @override
  String get errSetupTokenInvalid => 'The setup token is not valid.';

  @override
  String get errSetupClosed => 'This system is already set up.';

  @override
  String get errPasswordTooShort =>
      'The password needs at least 10 characters.';

  @override
  String get errPinFormat => 'The PIN must be exactly 6 digits.';

  @override
  String get errCodeInvalid => 'That code is wrong or has expired.';

  @override
  String get errGuardianRequired => 'Only a guardian can do that.';

  @override
  String get errDeviceRevoked => 'This device has been blocked.';

  @override
  String get errActorRequired => 'Tap your name first.';

  @override
  String get errNameRequired => 'Please enter a name.';

  @override
  String get errInvalidLogin => 'Email or password is wrong.';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get delete => 'Delete';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get shoppingTitle => 'Shopping list';

  @override
  String get shoppingAddHint => 'Add item';

  @override
  String get shoppingQuantityHint => 'Quantity';

  @override
  String get shoppingEmpty => 'Nothing to buy';

  @override
  String get shoppingFinish => 'Finish shopping';

  @override
  String get shoppingFinishConfirm =>
      'Finish this trip? Ticked items are removed, the rest stays on the list.';

  @override
  String shoppingFinished(int bought, int left) {
    return '$bought bought, $left carried over';
  }

  @override
  String get actingWho => 'Who are you?';

  @override
  String get pinTitle => 'Guardian PIN';

  @override
  String pinPrompt(String name) {
    return 'Enter the PIN for $name';
  }

  @override
  String pinWrong(int left) {
    return 'Wrong PIN. $left attempts left.';
  }

  @override
  String get pinBackoff => 'Too many attempts. Please wait a moment.';

  @override
  String get pinLocked => 'PIN locked. A guardian must sign in to unlock it.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsMembers => 'Members';

  @override
  String get settingsDevices => 'Devices';

  @override
  String get addMember => 'Add member';

  @override
  String get memberName => 'Name';

  @override
  String get roleGuardian => 'Guardian';

  @override
  String get roleMember => 'Member';

  @override
  String get addDevice => 'Add device';

  @override
  String get deviceLabel => 'Device name';

  @override
  String get createCode => 'Create code';

  @override
  String get enrolmentCodeTitle => 'Enrolment code';

  @override
  String get enrolmentCodeHint =>
      'Enter this code on the new device within 10 minutes. It works once.';

  @override
  String get thisDevice => 'this device';

  @override
  String get deviceRevoked => 'blocked';

  @override
  String get revoke => 'Block';

  @override
  String revokeConfirm(String device) {
    return 'Block \"$device\"? It loses access immediately.';
  }

  @override
  String get signOutDevice => 'Sign out this device';

  @override
  String get classPersonal => 'Personal';

  @override
  String get classShared => 'Shared (tap to switch)';

  @override
  String get classKiosk => 'Wall display';

  @override
  String get systemDevice => 'This device';

  @override
  String get systemRegister => 'Register';

  @override
  String get systemEnrolled => 'Enrolled';

  @override
  String get errRateLimited =>
      'Too many attempts. Please wait a few minutes and try again.';

  @override
  String get errMfaRequired =>
      'Enter the code from your authenticator app first.';

  @override
  String get scanQr => 'Scan QR code';

  @override
  String get scanTitle => 'Scan the setup code';

  @override
  String get enrolmentQrLabel => 'QR code for the enrolment code';

  @override
  String get mfaTitle => 'Second factor';

  @override
  String get mfaBody => 'Enter the 6-digit code from your authenticator app.';

  @override
  String get mfaCodeLabel => '6-digit code';

  @override
  String get mfaVerify => 'Confirm';

  @override
  String get registerTitle => 'Name this device';

  @override
  String registerBody(String name) {
    return '$name, this phone is new to the household. Give it a name so you can recognise (and block) it later.';
  }

  @override
  String registerDefaultLabel(String name) {
    return '$name\'s phone';
  }

  @override
  String get registerAction => 'Use this device';

  @override
  String get signInPasskey => 'Sign in with passkey';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get totpTitle => 'Two-factor sign-in';

  @override
  String get totpOn => 'On: a code is needed at every sign-in.';

  @override
  String get totpOff => 'Off';

  @override
  String get totpEnable => 'Turn on';

  @override
  String get totpDisable => 'Turn off';

  @override
  String get totpScanBody =>
      'Scan this code with an authenticator app, then enter the 6-digit code it shows.';

  @override
  String get passkeyTitle => 'Passkey';

  @override
  String get passkeyBody =>
      'Sign in with fingerprint or face instead of a password.';

  @override
  String get passkeyAdd => 'Add';

  @override
  String get passkeyAdded => 'Passkey added.';

  @override
  String get shoppingHistory => 'History';

  @override
  String get shoppingHistoryEmpty => 'No finished trips yet';

  @override
  String get shoppingSearchHint => 'Search or add';

  @override
  String get shoppingTilesEmpty =>
      'Tiles appear here once you have bought something. Type a name to add an item.';

  @override
  String shoppingInTrolley(int count) {
    return 'In the trolley ($count)';
  }

  @override
  String get shoppingUncategorised => 'Uncategorised';

  @override
  String get shoppingNewList => 'New list';

  @override
  String get shoppingListName => 'Name';

  @override
  String get shoppingListKind => 'Layout';

  @override
  String get shoppingKindSupermarket => 'Supermarket';

  @override
  String get shoppingKindDrugstore => 'Drugstore';

  @override
  String get shoppingKindHardware => 'Hardware store';

  @override
  String get shoppingKindOther => 'Other';

  @override
  String get shoppingMakeDefault => 'Make default list';

  @override
  String get shoppingEditItem => 'Edit item';

  @override
  String get shoppingSpecHint => 'Note, e.g. organic or 500 g';

  @override
  String get shoppingCategory => 'Category';

  @override
  String get shoppingRemoveOne => 'One less';

  @override
  String get errListExists => 'A list with that name already exists.';

  @override
  String get errSpecTooLong => 'That note is too long (40 characters at most).';

  @override
  String get errKioskForbidden => 'This can\'t be done on the wall display.';

  @override
  String get shoppingCat_produce => 'Fruit & vegetables';

  @override
  String get shoppingCat_bakery => 'Bread & bakery';

  @override
  String get shoppingCat_dairy => 'Dairy & cheese';

  @override
  String get shoppingCat_meat_fish => 'Meat & fish';

  @override
  String get shoppingCat_pantry => 'Pantry';

  @override
  String get shoppingCat_frozen => 'Frozen';

  @override
  String get shoppingCat_drinks => 'Drinks';

  @override
  String get shoppingCat_household => 'Household';

  @override
  String get shoppingCat_other => 'Other';

  @override
  String get shoppingCat_care => 'Body care';

  @override
  String get shoppingCat_baby => 'Baby & kids';

  @override
  String get shoppingCat_cleaning => 'Cleaning';

  @override
  String get shoppingCat_health => 'Health';

  @override
  String get shoppingCat_tools => 'Tools';

  @override
  String get shoppingCat_screws => 'Screws & fixings';

  @override
  String get shoppingCat_electrical => 'Electrical';

  @override
  String get shoppingCat_garden => 'Garden';

  @override
  String shoppingCreateTile(String name) {
    return 'Add “$name”';
  }

  @override
  String shoppingAddedBy(String name) {
    return 'Added by $name';
  }

  @override
  String get pinChangeTitle => 'Guardian PIN';

  @override
  String get pinChangeBody =>
      'Set a new 6-digit PIN. This also unlocks a PIN that was locked by too many wrong tries.';

  @override
  String get pinChangeAction => 'Change';

  @override
  String get pinChangeField => 'New PIN (6 digits)';

  @override
  String get pinChanged => 'PIN changed.';
}

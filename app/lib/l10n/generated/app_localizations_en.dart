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
  String get setupHeadline => 'Welcome to WuselWall';

  @override
  String get setupOfflineWelcome =>
      'You’re offline. Connect to the internet to sign in, accept an invitation, or connect a shared device. These options will be available when you reconnect.';

  @override
  String get doorTagline => 'The family plan for the kitchen wall';

  @override
  String get setupHouseholdAction => 'Start a new family';

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
  String get enrolTitle => 'Connect this device';

  @override
  String get enrolBody =>
      'Enter the code shown on a device that is already connected.';

  @override
  String get enrolCodeLabel => 'Enrolment code';

  @override
  String get enrolAction => 'Connect';

  @override
  String get errSetupTokenInvalid => 'The setup token is not valid.';

  @override
  String get errSetupClosed => 'This system is already connected.';

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
  String get classShared => 'Shared';

  @override
  String get classSharedHint => 'Several people use it: tap a name to switch.';

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
  String get totpQrLabel => 'QR code for setting up the authenticator app';

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

  @override
  String shoppingTripItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String shoppingPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to be sent',
      one: '1 change waiting to be sent',
    );
    return '$_temp0';
  }

  @override
  String get shoppingItemPending => 'Waiting to be sent';

  @override
  String get errCategoryNotFound =>
      'That category no longer exists. The change was not saved.';

  @override
  String get errNameTooLong => 'That name is too long.';

  @override
  String get errActorInvalid =>
      'That person is no longer part of the household. The change was not saved.';

  @override
  String get doorEmail => 'Continue with email';

  @override
  String get doorOr => 'or';

  @override
  String get errSignupDisabled =>
      'There is no WuselWall account for this address yet. Ask your family for an invitation, or start a new family.';

  @override
  String get errEmailExists =>
      'This email address already belongs to another account.';

  @override
  String get signInMethodsTitle => 'Sign-in';

  @override
  String get signInMethodEmail => 'Email code';

  @override
  String boardWeekNumber(int week) {
    return 'Week $week';
  }

  @override
  String get boardToday => 'Today';

  @override
  String get boardNow => 'Now';

  @override
  String get boardNextUp => 'Next';

  @override
  String get boardThen => 'then';

  @override
  String boardInMinutes(int minutes) {
    return 'in $minutes min';
  }

  @override
  String boardInHours(int hours, int minutes) {
    return 'in $hours h $minutes min';
  }

  @override
  String get boardNothingMoreToday => 'Nothing else planned today';

  @override
  String boardLastUpdatedAt(String time) {
    return 'last updated $time';
  }

  @override
  String get boardOffline => 'No connection – this is the last known plan.';

  @override
  String get boardLoading => 'Loading the week …';

  @override
  String get boardZoneWhere => 'Who is where';

  @override
  String get boardZoneMeal => 'Hot meal';

  @override
  String get boardMorning => 'Morning';

  @override
  String get boardAfternoon => 'Afternoon';

  @override
  String get boardEvening => 'Evening';

  @override
  String boardUntil(String time) {
    return 'until $time';
  }

  @override
  String boardFrom(String time) {
    return 'from $time';
  }

  @override
  String get boardAllDay => 'all day';

  @override
  String boardMoreEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+1 more',
    );
    return '$_temp0';
  }

  @override
  String boardMoreCount(int count) {
    return '+$count';
  }

  @override
  String get boardNoSchool => 'free';

  @override
  String boardCareUntil(String label, String time) {
    return '$label until $time';
  }

  @override
  String get boardCareDefault => 'Care';

  @override
  String boardBusyUntil(String time) {
    return 'Meetings until $time';
  }

  @override
  String get boardMealLunch => 'Lunch';

  @override
  String get boardMealDinner => 'Dinner';

  @override
  String get boardMealNothingPlanned => 'nothing planned';

  @override
  String boardMealCook(String name) {
    return '$name cooks';
  }

  @override
  String boardMealGuests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count guests',
      one: '+1 guest',
    );
    return '$_temp0';
  }

  @override
  String boardEating(String name) {
    return '$name is eating';
  }

  @override
  String boardNotEating(String name) {
    return '$name is not eating';
  }

  @override
  String get boardOpenToday => 'Open today';

  @override
  String get boardAllDone => 'All done today';

  @override
  String get boardShoppingList => 'Shopping list';

  @override
  String get boardNightMode => 'Night view';

  @override
  String get boardBackToWeek => 'Back to the week';

  @override
  String get boardTentative => 'not certain yet';

  @override
  String get boardNoAppointments => 'No appointments';

  @override
  String get boardSchool => 'School';

  @override
  String boardSchoolSpan(String span) {
    return 'School $span';
  }

  @override
  String get boardNoSchoolToday => 'No school';

  @override
  String get boardWeekend => 'Weekend';

  @override
  String boardWeekOf(String name) {
    return '$name\'s week';
  }

  @override
  String boardTimetableTitle(String name) {
    return '$name\'s timetable';
  }

  @override
  String boardClass(String label) {
    return 'Class $label';
  }

  @override
  String boardPeriod(int index) {
    return 'Period $index';
  }

  @override
  String get boardBreak => 'Break';

  @override
  String get boardLessonOver => 'over';

  @override
  String get boardLessonNow => 'now';

  @override
  String get boardLessonCancelled => 'Cancelled';

  @override
  String get boardLessonSubstituted => 'Substitute';

  @override
  String get boardLessonRoomChange => 'Room change';

  @override
  String get boardLessonExtra => 'Extra';

  @override
  String boardPackTomorrow(String items) {
    return 'Pack for tomorrow: $items';
  }

  @override
  String boardPackToday(String items) {
    return 'Pack for today: $items';
  }

  @override
  String get boardWholeWeek => 'The whole week';

  @override
  String get boardMealWeek => 'This week\'s meals';

  @override
  String boardBaseline(String label) {
    return 'Usually: $label';
  }

  @override
  String get boardNoDeviation => 'as usual';

  @override
  String get boardCooking => 'Cooking';

  @override
  String get boardAppointmentsOf => 'Appointments';

  @override
  String boardTasksOf(String name) {
    return '$name\'s tasks';
  }

  @override
  String get boardTasksComingSoon => 'Tasks arrive with the next update.';

  @override
  String get presenceWorking => 'At work';

  @override
  String get presenceHomeOffice => 'Home office';

  @override
  String get presenceTravel => 'Travelling';

  @override
  String get presenceAway => 'Away';

  @override
  String get presenceOff => 'Off';

  @override
  String get presenceChildcare => 'Childcare';

  @override
  String get errSettingInvalid => 'That value is outside the allowed range.';

  @override
  String get errSettingUnknown => 'That setting does not exist.';

  @override
  String get errSettingTarget =>
      'That setting cannot be changed for this person or device.';

  @override
  String get settingPickPersonFirst =>
      'Choose who you are first. Your own settings appear here then.';

  @override
  String get settingIsDefault => 'Default';

  @override
  String get settingIsCustom => 'Customised';

  @override
  String get settingReset => 'Reset to default';

  @override
  String get settingOn => 'On';

  @override
  String get settingOff => 'Off';

  @override
  String get settingFrom => 'from';

  @override
  String get settingTo => 'to';

  @override
  String get settingIncrease => 'Increase';

  @override
  String get settingDecrease => 'Decrease';

  @override
  String get settingDayPartsMorningEnds => 'Morning until';

  @override
  String get settingDayPartsEveningStarts => 'Evening from';

  @override
  String settingUnitPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String settingUnitMinutes(int count) {
    return '$count min';
  }

  @override
  String settingUnitSeconds(int count) {
    return '$count s';
  }

  @override
  String get settingValueName => 'Full name';

  @override
  String get settingValueInitial => 'Initial';

  @override
  String get settingValueDuty => 'Duty';

  @override
  String get settingValueBonus => 'Bonus';

  @override
  String get settingValueRequired => 'Approval';

  @override
  String get settingValueSelfServe => 'Self-serve';

  @override
  String get settingValueWholeFamily => 'Whole family';

  @override
  String get settingValueAll => 'All';

  @override
  String get settingValueNone => 'None';

  @override
  String get settingValueLunch => 'Lunch';

  @override
  String get settingValueDinner => 'Dinner';

  @override
  String get settingBoardMemberLabelTitle => 'Names on the board';

  @override
  String get settingBoardMemberLabelHelp =>
      'A name reads better than an initial from two metres. Pick initials if visitors are often in the kitchen.';

  @override
  String get settingTasksDutyPointsTitle => 'Points for a duty';

  @override
  String get settingTasksDutyPointsHelp =>
      'Duties are expected of everyone, so they earn little or nothing. The streak is their reward.';

  @override
  String get settingTasksBonusPointsTitle => 'Points for a bonus task';

  @override
  String get settingTasksBonusPointsHelp =>
      'One bonus task buys the cheapest starter reward, so a younger child gets there within days.';

  @override
  String get settingTasksKindTitle => 'New tasks are';

  @override
  String get settingTasksKindHelp =>
      'A new chore is a duty unless someone deliberately makes it a bonus. That keeps the earning surface narrow.';

  @override
  String get settingTasksVerificationTitle => 'Guardians check chores';

  @override
  String get settingTasksVerificationHelp =>
      'Checking turns every chore into an inspection, so use it only for valuable bonus tasks.';

  @override
  String get settingTasksJokersTitle => 'Streak jokers per month';

  @override
  String get settingTasksJokersHelp =>
      'A joker keeps a streak alive on a missed day, so one sick day does not wipe out a three-week streak.';

  @override
  String get settingTasksRewardApprovalTitle => 'Rewards need approval';

  @override
  String get settingTasksRewardApprovalHelp =>
      'A guardian approves each redemption with the PIN. Self-serve suits only trivial rewards.';

  @override
  String get settingCalendarMembersEditTitle => 'Members edit their own events';

  @override
  String get settingCalendarMembersEditHelp =>
      'Children create and edit events they attend themselves. Deleting someone else\'s event stays a guardian action.';

  @override
  String get settingCalendarKeyDefaultTitle => 'New events on the kitchen wall';

  @override
  String get settingCalendarKeyDefaultHelp =>
      'Decides which new events appear on the kitchen wall without anyone ticking the box. Review it after two weeks of use.';

  @override
  String get settingSchoolReportTitle => 'Members report timetable changes';

  @override
  String get settingSchoolReportHelp =>
      'Only guardians maintain the timetable. With this on, a child can report a cancelled lesson for a guardian to confirm.';

  @override
  String get settingSchoolEquipmentTitle => 'Equipment hint for tomorrow';

  @override
  String get settingSchoolEquipmentHelp =>
      'Shows what to bring tomorrow, such as sports kit, from tomorrow\'s subjects.';

  @override
  String get settingMealsSchoolDayTitle => 'Warm meal on school days';

  @override
  String get settingMealsSchoolDayHelp =>
      'The one warm meal on the kitchen wall. On school days children eat lunch at school or at after-school care.';

  @override
  String get settingMealsFreeDayTitle => 'Warm meal on free days';

  @override
  String get settingMealsFreeDayHelp => 'For weekends and holidays.';

  @override
  String get settingMealsAwayTitle => 'Away means not eating';

  @override
  String get settingMealsAwayHelp =>
      'Travelling or away over a meal\'s time marks that person as not eating, so most days need no input.';

  @override
  String get settingMealsCareCutoffTitle => 'Lunch cut-off for care';

  @override
  String get settingMealsCareCutoffHelp =>
      'A child whose care runs past this time is out for lunch.';

  @override
  String get settingBoardRolloverTitle => 'Kitchen wall moves on';

  @override
  String get settingBoardRolloverHelp =>
      'When the wall moves to the coming week. Sunday evening planning wants next week; Saturday morning still wants this one.';

  @override
  String get settingBoardDayPartsTitle => 'Morning, afternoon, evening';

  @override
  String get settingBoardDayPartsHelp =>
      'Where the appointment zone splits into morning, afternoon and evening.';

  @override
  String get settingDeviceNightHoursTitle => 'Night theme hours';

  @override
  String get settingDeviceNightHoursHelp =>
      'When the kiosk switches to the amber night theme.';

  @override
  String get settingDeviceIdleRevertTitle => 'Back to the wall after';

  @override
  String get settingDeviceIdleRevertHelp =>
      'How long an opened profile or detail view stays open before the kiosk returns to the wall.';

  @override
  String get settingMemberCompletionSoundTitle =>
      'Sound when a chore is ticked';

  @override
  String get settingMemberCompletionSoundHelp =>
      'Ticking a chore off makes a short sound. Switch it off if you do not want it.';

  @override
  String get settingCalendarTentativeTitle => 'Check uncertain events at';

  @override
  String get settingCalendarTentativeHelp =>
      'Asks whether a tentative entry is happening, so it does not stay uncertain until it starts.';

  @override
  String get settingNotifyMorningTitle => 'Morning summary';

  @override
  String get settingNotifyMorningHelp =>
      'Today\'s tasks and events for you. Pending redemptions appear here for guardians.';

  @override
  String get settingNotifyEventReminderTitle => 'Reminder before events';

  @override
  String get settingNotifyEventReminderHelp =>
      'A notification before an event starts.';

  @override
  String get settingNotifyTaskVerifiedTitle => 'When a chore is verified';

  @override
  String get settingNotifyTaskVerifiedHelp =>
      'A notification when a guardian verifies a chore and its points are credited.';

  @override
  String get settingNotifyRedemptionTitle => 'When a reward is requested';

  @override
  String get settingNotifyRedemptionHelp =>
      'An immediate notification when a child asks for a reward.';

  @override
  String boardCareShort(String label, String time) {
    return '$label $time';
  }

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarDay => 'Day';

  @override
  String get calendarThreeDays => '3 days';

  @override
  String get calendarWeek => 'Week';

  @override
  String get calendarPrevious => 'Previous';

  @override
  String get calendarNext => 'Next';

  @override
  String get calendarChooseView => 'Calendar view';

  @override
  String get calendarToday => 'Today';

  @override
  String calendarRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get calendarNewEvent => 'New event';

  @override
  String get calendarEmpty => 'Nothing planned';

  @override
  String get calendarEditorPlaceholder => 'The event editor is coming soon.';

  @override
  String get eventEditTitle => 'Edit event';

  @override
  String get eventTitleLabel => 'Title';

  @override
  String get eventTitleRequired => 'Enter a title.';

  @override
  String get eventKindAppointment => 'Appointment';

  @override
  String get eventKindPresence => 'Presence';

  @override
  String get eventPresenceState => 'State';

  @override
  String get eventPresenceStateRequired => 'Choose a state.';

  @override
  String get eventAllDay => 'All day';

  @override
  String get eventStarts => 'Starts';

  @override
  String get eventEnds => 'Ends';

  @override
  String get eventEndBeforeStart => 'The end must be after the start.';

  @override
  String get eventAttendees => 'Who';

  @override
  String get eventAttendeesWholeFamily =>
      'Nobody picked: this is for the whole family.';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventNotes => 'Notes';

  @override
  String get eventTentative => 'Not sure yet';

  @override
  String get eventKeyDisplay => 'Show on the kitchen display';

  @override
  String get eventKeyDisplayOn => 'This event shows on the kitchen display.';

  @override
  String get eventKeyDisplayOff =>
      'This event won’t show on the kitchen display.';

  @override
  String get eventKeyDisplayOffWholeFamily =>
      'Not on the kitchen display: only events for the whole family go there by default.';

  @override
  String get eventRepeat => 'Repeat';

  @override
  String get eventRepeatNever => 'Never';

  @override
  String get eventRepeatDaily => 'Daily';

  @override
  String get eventRepeatWeekly => 'Weekly';

  @override
  String get eventRepeatBiweekly => 'Every 2 weeks';

  @override
  String get eventRepeatMonthly => 'Monthly';

  @override
  String get eventRepeatSpecificDays => 'Specific days (shift plan)';

  @override
  String eventRepeatMonthlyDay(int day) {
    return 'on the $day.';
  }

  @override
  String eventRepeatMonthlyNth(int n, String weekday) {
    return 'the $n. $weekday of the month';
  }

  @override
  String eventRepeatMonthlyLast(String weekday) {
    return 'the last $weekday';
  }

  @override
  String get eventRepeatDays => 'On these days';

  @override
  String get eventRepeatEnds => 'Repeat ends';

  @override
  String get eventRepeatUntil => 'on a date';

  @override
  String eventRepeatCount(int count) {
    return 'after $count times';
  }

  @override
  String eventDaysPicked(int count) {
    return '$count days';
  }

  @override
  String get eventDienstplanHelp =>
      'Tap the days that count. The start day is always included.';

  @override
  String get eventCustomRule => 'Custom rule';

  @override
  String get eventCustomRuleHelp =>
      'This repeat pattern cannot be edited here. It stays as it is.';

  @override
  String get eventWeekdaysRequired => 'Choose at least one weekday.';

  @override
  String get eventDeleteConfirm => 'Delete this event?';

  @override
  String get eventScopeTitle => 'Which events?';

  @override
  String get eventScopeDeleteTitle => 'Delete which events?';

  @override
  String get eventScopeThis => 'Only this event';

  @override
  String get eventScopeSeries => 'All events in the series';

  @override
  String get errEventInvalid => 'This event is not valid.';

  @override
  String get errRruleInvalid => 'This repeat pattern cannot be saved.';

  @override
  String get errAttendeeInvalid =>
      'Someone you chose does not belong to this household.';

  @override
  String get errEventNotFound => 'This event no longer exists.';

  @override
  String get scheduleTitle => 'Timetable';

  @override
  String get tasksTitle => 'Tasks';

  @override
  String get mealsTitle => 'Meals';

  @override
  String get comingSoon => 'This part is being built.';

  @override
  String mealsWeekRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get mealsPrevWeek => 'Previous week';

  @override
  String get mealsNextWeek => 'Next week';

  @override
  String get mealsThisWeek => 'This week';

  @override
  String get mealsRecipes => 'Recipes';

  @override
  String get mealsFillShopping => 'Fill shopping list';

  @override
  String get mealsSlotBreakfast => 'Breakfast';

  @override
  String get mealsSlotLunch => 'Lunch';

  @override
  String get mealsSlotDinner => 'Dinner';

  @override
  String get mealsSlotSnack => 'Snack';

  @override
  String get mealsNothingYet => 'Nothing planned yet';

  @override
  String get mealsAddOther => 'Add meal';

  @override
  String get mealsDragHint =>
      'Long-press a meal and drop it on another day to move it.';

  @override
  String mealsEditTitle(String day) {
    return 'Meal on $day';
  }

  @override
  String get mealsFieldLabel => 'Dish or note';

  @override
  String get mealsFieldHint => 'Pizza, leftovers, a recipe name …';

  @override
  String get mealsSuggestionHelp =>
      'Matching recipes. Tap one to use it; its ingredients then go on the shopping list.';

  @override
  String get mealsServings => 'Servings';

  @override
  String get mealsCook => 'Cooks';

  @override
  String get mealsCookNobody => 'Nobody';

  @override
  String get mealsTime => 'Time';

  @override
  String get mealsTimeNone => 'No time';

  @override
  String get mealsGuests => 'Guests';

  @override
  String get mealsEatingTitle => 'Who is eating';

  @override
  String get mealsEatingHelp =>
      'Someone who is away or travelling over the meal, or who is at after-school care past the cut-off, is switched off automatically. Set it by hand only when that is not true.';

  @override
  String get mealsEatingAuto => 'Automatic';

  @override
  String get mealsEatingYes => 'Eating';

  @override
  String get mealsEatingNo => 'Not eating';

  @override
  String get mealsDelete => 'Delete meal';

  @override
  String get mealsPreviewTitle => 'Fill shopping list';

  @override
  String get mealsPreviewEmpty =>
      'Nothing to add. Free-text meals have no ingredients; recipes put theirs on the list.';

  @override
  String get mealsPreviewOnList => 'Already on the list';

  @override
  String mealsPreviewFor(String meals) {
    return 'For $meals';
  }

  @override
  String mealsPreviewAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'nothing',
    );
    return 'Add $_temp0';
  }

  @override
  String mealsPreviewAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items added to the shopping list',
      one: '1 item added to the shopping list',
    );
    return '$_temp0';
  }

  @override
  String get mealsRecipesTitle => 'Recipes';

  @override
  String get mealsRecipeSearch => 'Search recipes';

  @override
  String get mealsRecipesEmpty =>
      'No recipes yet. A dish name is enough for a meal; a recipe adds its ingredients to the shopping list.';

  @override
  String get mealsRecipeNew => 'New recipe';

  @override
  String get mealsRecipeEdit => 'Edit recipe';

  @override
  String get mealsRecipeTitleField => 'Title';

  @override
  String get mealsIngredients => 'Ingredients';

  @override
  String get mealsIngredientName => 'Ingredient';

  @override
  String get mealsIngredientQuantity => 'Amount';

  @override
  String get mealsIngredientUnit => 'Unit';

  @override
  String get mealsIngredientNote => 'Note';

  @override
  String get mealsIngredientAdd => 'Add ingredient';

  @override
  String get mealsIngredientRemove => 'Remove ingredient';

  @override
  String get mealsIngredientMove => 'Drag to reorder';

  @override
  String get mealsNoIngredients => 'No ingredients listed.';

  @override
  String get mealsSteps => 'Steps';

  @override
  String get mealsStepsHint => 'One step per line';

  @override
  String get mealsTags => 'Tags';

  @override
  String get mealsTagsHint => 'Separated by commas, e.g. quick, vegetarian';

  @override
  String get mealsSourceUrl => 'Source link';

  @override
  String get mealsSource => 'Source';

  @override
  String get mealsRecipeSave => 'Save recipe';

  @override
  String get mealsRecipeDelete => 'Delete recipe';

  @override
  String mealsRecipeDeleteConfirm(String title) {
    return 'Delete “$title”? Meals that use it keep their name.';
  }

  @override
  String get mealsRecipeTitleRequired => 'A recipe needs a title.';

  @override
  String get mealsKioskHint => 'Tap a dot to change who is eating';

  @override
  String get errMealInvalid =>
      'That meal could not be saved. Check the entry and try again.';

  @override
  String get schoolSetupCardTitle => 'Set up the school';

  @override
  String get schoolSetupCardBody =>
      'Add the school. Bell times and subjects are proposed; then enter the timetable or read it in.';

  @override
  String get schoolSetupAction => 'Set up school';

  @override
  String get schoolEnterTimetableTitle => 'Enter the timetable';

  @override
  String schoolEnterTimetableBody(String name) {
    return '$name has no timetable for the week shown yet.';
  }

  @override
  String get schoolEnterTimetableAction => 'Enter timetable';

  @override
  String get schoolNoChildren => 'No child in the household yet.';

  @override
  String get schoolEditSchool => 'Edit school';

  @override
  String get schoolEditTimetable => 'Edit timetable';

  @override
  String get schoolPrevWeek => 'Previous week';

  @override
  String get schoolNextWeek => 'Next week';

  @override
  String get schoolThisWeek => 'This week';

  @override
  String schoolWeekLabel(int week, String from, String to) {
    return 'Week $week · $from – $to';
  }

  @override
  String get schoolChooseChild => 'Choose child';

  @override
  String schoolHolidayBand(String name, String range) {
    return '$name · $range';
  }

  @override
  String get schoolNoLessonsToday => 'No lessons';

  @override
  String get schoolPackTomorrowNone => 'Nothing to pack for tomorrow.';

  @override
  String schoolLessonActions(String subject, String day, String period) {
    return '$subject, $day, $period';
  }

  @override
  String get schoolCancelLesson => 'Cancelled';

  @override
  String get schoolSubstitute => 'Substitute';

  @override
  String get schoolRoomChange => 'Room changed';

  @override
  String get schoolResetException => 'Reset';

  @override
  String get schoolPickSubject => 'Subject';

  @override
  String get schoolSearchSubject => 'Find subject';

  @override
  String get schoolTeacher => 'Teacher';

  @override
  String get schoolNote => 'Note';

  @override
  String get schoolRoom => 'Room';

  @override
  String get schoolApply => 'Apply';

  @override
  String get schoolSaved => 'Saved.';

  @override
  String get schoolNoSubjects =>
      'No subjects yet. Add them in the school setup.';

  @override
  String get schoolSetupTitle => 'School';

  @override
  String get schoolSectionSchool => 'School';

  @override
  String get schoolName => 'Name of the school';

  @override
  String get schoolBellTimes => 'Bell times';

  @override
  String get schoolAddLesson => 'Add lesson';

  @override
  String get schoolAddBreak => 'Add break';

  @override
  String get schoolRemove => 'Remove';

  @override
  String get schoolStart => 'Start';

  @override
  String get schoolEnd => 'End';

  @override
  String get schoolTerms => 'Terms';

  @override
  String get schoolAddTerm => 'Add term';

  @override
  String get schoolTermEdit => 'Edit term';

  @override
  String get schoolTermNew => 'New term';

  @override
  String get schoolTermName => 'Name';

  @override
  String get schoolTermNameHint => 'e.g. School year 2026/27 or 1st half-year';

  @override
  String get schoolFrom => 'From';

  @override
  String get schoolTo => 'To';

  @override
  String get schoolTermPickDate => 'Choose a date';

  @override
  String get schoolTermEndBeforeStart => 'Ends before it starts';

  @override
  String schoolTermMustCoverWeek(String week) {
    return 'Must include the week shown ($week)';
  }

  @override
  String get schoolAbWeeks => 'A and B weeks';

  @override
  String get schoolAbWeeksHint =>
      'Turn on if the timetable alternates between two weeks.';

  @override
  String get schoolAbWeek => 'Calendar week of an A week';

  @override
  String get schoolAbWeekHint =>
      'Week number, for example 43. From there the weeks alternate: B, A, B, …';

  @override
  String schoolAbWeekShown(int week) {
    return 'The week shown is calendar week $week.';
  }

  @override
  String get schoolAbWeekInvalid => 'Enter a week number from 1 to 53';

  @override
  String get schoolCurrent => 'current';

  @override
  String get schoolCurrentTerm => 'Current term';

  @override
  String get schoolCurrentTermHint =>
      'Marks the term you are in now. Only one per school.';

  @override
  String get schoolSubjects => 'Subjects';

  @override
  String get schoolAddSubject => 'Add subject';

  @override
  String get schoolSubjectEdit => 'Subject';

  @override
  String get schoolSubjectShort => 'Short name';

  @override
  String get schoolTint => 'Colour';

  @override
  String get schoolEquipment => 'Things to bring';

  @override
  String get schoolNotable => 'Show on the wall';

  @override
  String get schoolSubjectInUse =>
      'This subject is still in a timetable. Remove it there first.';

  @override
  String get schoolInvalid => 'These details do not fit together.';

  @override
  String get schoolHolidays => 'Holidays and free days';

  @override
  String get schoolAddHoliday => 'Add holiday';

  @override
  String get schoolHolidayEdit => 'Holiday';

  @override
  String get schoolHolidayName => 'Name';

  @override
  String get schoolEditorClass => 'Class';

  @override
  String get schoolWeekCycle => 'Week rhythm';

  @override
  String get schoolCycleWeekly => 'Every week';

  @override
  String get schoolCycleAb => 'A/B weeks';

  @override
  String get schoolParityAll => 'Every week';

  @override
  String get schoolParityA => 'A week';

  @override
  String get schoolParityB => 'B week';

  @override
  String get schoolClearDay => 'Clear day';

  @override
  String get schoolClearCell => 'Clear';

  @override
  String get schoolCopyFrom => 'Copy from…';

  @override
  String get schoolCopyPick => 'Copy timetable from';

  @override
  String get schoolCareRows => 'After school care';

  @override
  String get schoolAddCare => 'Add care';

  @override
  String get schoolCareTitle => 'Name';

  @override
  String get schoolCareDays => 'On';

  @override
  String get schoolSaveTimetable => 'Save timetable';

  @override
  String get schoolWeekdayPick => 'Days';

  @override
  String get feedTitle => 'Share the family calendar';

  @override
  String get feedSettingsSubtitle => 'Read-only, in Outlook or on an iPhone';

  @override
  String get feedNew => 'New subscription';

  @override
  String get feedEmpty =>
      'No subscriptions yet. A subscription shows appointments in Outlook or on an iPhone, read-only.';

  @override
  String get feedRevoked => 'Revoked';

  @override
  String get feedNeverFetched => 'Never fetched';

  @override
  String feedLastFetched(String when) {
    return 'Last fetched: $when';
  }

  @override
  String get feedAgoJustNow => 'just now';

  @override
  String feedAgoMinutes(int count) {
    return '$count min ago';
  }

  @override
  String feedAgoHours(int count) {
    return '$count h ago';
  }

  @override
  String feedAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String feedFetchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fetched $count times',
      one: 'fetched once',
    );
    return '$_temp0';
  }

  @override
  String get feedSummaryAppointments => 'Appointments';

  @override
  String get feedSummaryPresence => 'Presence';

  @override
  String get feedSummaryEveryone => 'All members';

  @override
  String get feedSummarySchoolDay => 'School day';

  @override
  String get feedSummarySchoolLessons => 'Lessons';

  @override
  String get feedWhoseTitle => 'Whose events';

  @override
  String get feedWhoseHelp => 'Nothing selected: everyone';

  @override
  String get feedLabelField => 'Subscription name';

  @override
  String get feedLabelHint => 'e.g. work laptop Outlook';

  @override
  String get feedWhatTitle => 'What';

  @override
  String get feedKindPresenceTitle => 'Presence';

  @override
  String get feedPresenceHint =>
      'Shows who is where and when (work, home office, off …). Better left off for work devices and children.';

  @override
  String get feedSchoolTitle => 'School';

  @override
  String get feedSchoolOff => 'Off';

  @override
  String get feedSchoolHint =>
      'School days as one all-day entry, or every lesson.';

  @override
  String get feedCreate => 'Create subscription';

  @override
  String get feedUrlTitle => 'Subscription address';

  @override
  String get feedUrlOnce =>
      'This address is shown only once. Anyone who has it can see the events, so treat it like a password.';

  @override
  String get feedCopyUrl => 'Copy address';

  @override
  String get feedCopyWebcal => 'Copy webcal link';

  @override
  String get feedWebcalLabel => 'webcal link (opens the iPhone dialog)';

  @override
  String get feedCopied => 'Address copied.';

  @override
  String get feedQrLabel => 'QR code with the subscription address';

  @override
  String get feedHowTitle => 'How to subscribe';

  @override
  String get feedHowOutlook =>
      'Outlook on the web: Calendar → Add calendar → Subscribe from web → paste the address → name it “Family”.';

  @override
  String get feedHowIphone =>
      'iPhone: Settings → Apps → Calendar → Accounts → Add Account → Other → Add Subscribed Calendar → paste the address. Or tap the webcal link.';

  @override
  String get feedRevokeAction => 'Revoke';

  @override
  String feedRevokeConfirm(String label) {
    return 'Revoke “$label”? It stops receiving events at once.';
  }

  @override
  String get baselineTitle => 'Usual week';

  @override
  String get baselineSettingsSubtitle =>
      'Where everyone usually is, day by day';

  @override
  String get baselineHelp =>
      'Where you usually are on each day of the week. Only deviations get entered, so a normal week stays empty.';

  @override
  String get baselineNone => 'Nothing set';

  @override
  String get baselineLabelField => 'Own label (optional)';

  @override
  String get baselineLabelHint => 'e.g. at home';

  @override
  String get baselineSaved => 'Saved.';

  @override
  String get usualCopyMonday => 'Tuesday to Friday like Monday';

  @override
  String usualDayTitle(String name, String weekday) {
    return '$name on $weekday';
  }

  @override
  String get usualDayApply => 'Apply';

  @override
  String get usualWholeDay => 'Whole day';

  @override
  String get usualSlots => 'Time slots';

  @override
  String get usualSlotState => 'Where';

  @override
  String get usualSlotFrom => 'From';

  @override
  String get usualSlotUntil => 'Until';

  @override
  String get usualAddSlot => 'Add time slot';

  @override
  String get usualRemoveSlot => 'Remove time slot';

  @override
  String get usualSlotsInvalid =>
      'Each time slot ends after it starts, and slots do not overlap.';

  @override
  String get usualAlternating => 'Alternating weeks (A/B)';

  @override
  String get usualAlternatingHelp => 'For a plan that repeats every two weeks.';

  @override
  String get usualWeekA => 'Week A';

  @override
  String get usualWeekB => 'Week B';

  @override
  String usualThisWeekIs(String week) {
    return 'This week is $week.';
  }

  @override
  String get usualWhichWeek => 'Which week is this week?';

  @override
  String get errUsualWeekInvalid => 'This usual week is not valid.';

  @override
  String get busyTitle => 'Meetings until';

  @override
  String get busyPickTime => 'Choose a time';

  @override
  String get busyThisDay => 'This day only';

  @override
  String get busyWholeWeek => 'Apply to the whole week (Mon–Fri)';

  @override
  String get busyRemove => 'Remove';

  @override
  String get busyHelp =>
      'Until when you are not available. Just the time: no appointments, no details.';

  @override
  String get busyFor => 'For';

  @override
  String get tasksTabToday => 'Today';

  @override
  String get tasksTabApprovals => 'Approvals';

  @override
  String get tasksTabChores => 'Chores';

  @override
  String get tasksTabRewards => 'Rewards';

  @override
  String get tasksTabPoints => 'Points';

  @override
  String get tasksNothingToday => 'Nothing due today.';

  @override
  String get tasksOpenForAnyone => 'Open for anyone';

  @override
  String get tasksWaitingApproval => 'waiting for approval';

  @override
  String get tasksDone => 'Done';

  @override
  String get tasksUndo => 'Undo';

  @override
  String tasksCompletedSnack(String title) {
    return '$title done';
  }

  @override
  String tasksPointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String tasksStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days in a row',
      one: '1 day in a row',
    );
    return '$_temp0';
  }

  @override
  String tasksOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open',
      one: '1 open',
      zero: 'none open',
    );
    return '$_temp0';
  }

  @override
  String get tasksKindDuty => 'Duty';

  @override
  String get tasksKindBonus => 'Bonus';

  @override
  String get tasksApprovalsEmpty => 'Nothing to check.';

  @override
  String get tasksCheckChores => 'Chores to check';

  @override
  String get tasksRewardRequests => 'Reward requests';

  @override
  String get tasksApprove => 'Approve';

  @override
  String get tasksDecline => 'Decline';

  @override
  String tasksRequestedBy(String name, String reward) {
    return '$name wants $reward';
  }

  @override
  String tasksDoneBy(String name) {
    return 'Done by $name';
  }

  @override
  String get tasksNoteOptional => 'Note (optional)';

  @override
  String get tasksNoChores => 'No chores yet.';

  @override
  String get tasksStarterHelp =>
      'Five chores, three rewards and four badges to begin with. Everything can be changed afterwards.';

  @override
  String get tasksStarterAdd => 'Add starter pack';

  @override
  String get tasksStarterDone => 'Starter pack added.';

  @override
  String get tasksNewChore => 'New chore';

  @override
  String get tasksEditChore => 'Edit chore';

  @override
  String get tasksFieldTitle => 'Title';

  @override
  String get tasksTitleRequired => 'Please enter a title.';

  @override
  String get tasksFieldIcon => 'Icon';

  @override
  String get taskIcon_dishes => 'Plate';

  @override
  String get taskIcon_table => 'Spoon';

  @override
  String get taskIcon_trash => 'Bin';

  @override
  String get taskIcon_bed => 'Bed';

  @override
  String get taskIcon_dog => 'Dog';

  @override
  String get taskIcon_plant => 'Plant';

  @override
  String get taskIcon_bike => 'Bike';

  @override
  String get taskIcon_book => 'Books';

  @override
  String get taskIcon_laundry => 'Laundry basket';

  @override
  String get taskIcon_teeth => 'Toothbrush';

  @override
  String get taskIcon_shopping => 'Shopping trolley';

  @override
  String get taskIcon_cooking => 'Frying pan';

  @override
  String get taskIcon_car => 'Car';

  @override
  String get taskIcon_toys => 'Teddy bear';

  @override
  String get taskIcon_star => 'Star';

  @override
  String get taskIcon_cinema => 'Film';

  @override
  String get taskIcon_moon => 'Moon';

  @override
  String get taskIcon_trip => 'Compass';

  @override
  String get tasksNoIcon => 'No icon';

  @override
  String get tasksFieldKind => 'Type';

  @override
  String get tasksKindDutyHelp => 'Expected of everyone; earns little.';

  @override
  String get tasksKindBonusHelp => 'Optional extra work; earns points.';

  @override
  String get tasksFieldPoints => 'Points';

  @override
  String get tasksFieldRepeat => 'Repeat';

  @override
  String get tasksRepeatOnce => 'Once';

  @override
  String get tasksRepeatDaily => 'Daily';

  @override
  String get tasksRepeatWeekdays => 'On weekdays';

  @override
  String get tasksRepeatWeekly => 'Weekly';

  @override
  String get tasksRepeatBiweekly => 'Every 2 weeks';

  @override
  String get tasksRepeatMonthly => 'Monthly';

  @override
  String get tasksWeekdayOne => 'Weekday';

  @override
  String get tasksWeekdayMany => 'Weekdays';

  @override
  String get tasksWeekdaysRequired => 'Pick at least one weekday.';

  @override
  String get tasksFieldStarts => 'Starts on';

  @override
  String get tasksFieldWindow => 'Can be done';

  @override
  String tasksWindowDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days from the due day',
      one: 'Only on the due day',
    );
    return '$_temp0';
  }

  @override
  String get tasksFieldWho => 'Who';

  @override
  String get tasksWhoFixed => 'One person';

  @override
  String get tasksWhoRotating => 'Taking turns';

  @override
  String get tasksWhoOpen => 'Whoever wants';

  @override
  String get tasksWhoEach => 'Everyone';

  @override
  String get tasksPickOne => 'Who does it?';

  @override
  String get tasksPickPool => 'Who takes part?';

  @override
  String get tasksPickOpenPool => 'Who may take it? Empty means everyone.';

  @override
  String get tasksPoolRequired => 'Pick at least one person.';

  @override
  String get tasksFieldVerification => 'Approval by a grown-up';

  @override
  String get tasksVerificationHelp => 'Points come after a check.';

  @override
  String get tasksArchive => 'Archive';

  @override
  String get tasksArchiveHelp =>
      'The chore disappears. Its open entries in the future are removed.';

  @override
  String get tasksNoRewards => 'No rewards yet.';

  @override
  String get tasksNewReward => 'New reward';

  @override
  String get tasksEditReward => 'Edit reward';

  @override
  String get tasksFieldCost => 'Cost in points';

  @override
  String get tasksFieldStock => 'Stock (empty means unlimited)';

  @override
  String get tasksFieldNeedsApproval => 'Needs approval first';

  @override
  String get tasksNeedsApprovalHelp => 'Off only suits small things.';

  @override
  String get tasksAskForReward => 'Ask for it';

  @override
  String get tasksRequestSent => 'Request sent.';

  @override
  String get tasksRedeemed => 'Redeemed.';

  @override
  String get tasksSoldOut => 'Sold out';

  @override
  String tasksMissingPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points short',
      one: '1 point short',
    );
    return '$_temp0';
  }

  @override
  String get tasksHistory => 'History';

  @override
  String get tasksNoHistory => 'Nothing redeemed yet.';

  @override
  String get tasksRedemptionRequested => 'Waiting for approval';

  @override
  String get tasksRedemptionApproved => 'Redeemed, not handed over yet';

  @override
  String get tasksRedemptionDeclined => 'Declined';

  @override
  String get tasksRedemptionFulfilled => 'Handed over';

  @override
  String get tasksHandOver => 'Mark as handed over';

  @override
  String get tasksNoLedger => 'No movements yet.';

  @override
  String get tasksLedgerTask => 'Chore done';

  @override
  String get tasksLedgerUndo => 'Taken back';

  @override
  String get tasksLedgerRedemption => 'Reward';

  @override
  String get tasksLedgerAdjustment => 'Correction';

  @override
  String get tasksLedgerBadge => 'Badge';

  @override
  String get tasksLedgerBonus => 'Bonus';

  @override
  String get tasksAdjust => 'Correct';

  @override
  String tasksAdjustTitle(String name) {
    return 'Correct points for $name';
  }

  @override
  String get tasksFieldAmount => 'Points (+ or −)';

  @override
  String get tasksAmountInvalid => 'Enter a number other than 0.';

  @override
  String get tasksFieldReason => 'Reason (required)';

  @override
  String get tasksReasonRequired => 'Please give a reason.';

  @override
  String get tasksBalanceTitle => 'Balance';

  @override
  String get tasksBoardStreakLabel => 'Streak';

  @override
  String get errTaskInvalid => 'That chore is not valid.';

  @override
  String get errTaskNotYours => 'Only the person it is for can do that.';

  @override
  String get errBalanceInsufficient => 'Not enough points for that.';

  @override
  String get errRewardOutOfStock => 'That reward is sold out.';

  @override
  String get errTaskNotOpen => 'This chore is no longer open.';

  @override
  String get tasksActionTick => 'Tick off';

  @override
  String get tasksPointsInvalid => 'Enter a whole number, 0 or more.';

  @override
  String get kidTabToday => 'My day';

  @override
  String get kidTabSchool => 'Timetable';

  @override
  String get kidTabPoints => 'Points';

  @override
  String get kidTabShopping => 'Shopping';

  @override
  String get kidTabFamily => 'Family';

  @override
  String get kidWhoAreYou => 'Hi! Tap your name.';

  @override
  String kidGreeting(String name) {
    return 'Hi, $name!';
  }

  @override
  String get kidTasksTitle => 'My chores';

  @override
  String get kidTasksNone => 'You have no chores today.';

  @override
  String get kidTasksAllDone => 'All done!';

  @override
  String get kidTasksAllDoneBody => 'Well done, you did everything for today.';

  @override
  String get kidAwaitsCheck => 'being checked';

  @override
  String get kidDone => 'Done';

  @override
  String kidTaskDoneSnack(String title) {
    return '$title done!';
  }

  @override
  String get kidUndo => 'Undo';

  @override
  String get kidSchoolTitle => 'School today';

  @override
  String get kidNoSchoolToday => 'No school today.';

  @override
  String kidHoliday(String name) {
    return 'Holidays: $name';
  }

  @override
  String get kidNoTimetable => 'No timetable has been entered for you yet.';

  @override
  String kidRoom(String room) {
    return 'Room $room';
  }

  @override
  String get kidNow => 'Now';

  @override
  String get kidLessonCancelled => 'cancelled';

  @override
  String get kidLessonSubstituted => 'substitute teacher';

  @override
  String get kidLessonRoomChange => 'different room';

  @override
  String kidCareUntil(String time) {
    return 'Care until $time';
  }

  @override
  String kidTomorrowNeeds(String items) {
    return 'Tomorrow you need: $items';
  }

  @override
  String kidMealDinner(String dish) {
    return 'Tonight we are having $dish';
  }

  @override
  String kidMealLunch(String dish) {
    return 'Lunch today is $dish';
  }

  @override
  String get kidMealNoneDinner => 'Nothing is planned for tonight yet.';

  @override
  String get kidMealNoneLunch => 'Nothing is planned for lunch yet.';

  @override
  String get kidMealEatingYou => 'You are eating too.';

  @override
  String get kidEventsTitle => 'My appointments today';

  @override
  String get kidNoEvents => 'No appointments today.';

  @override
  String get kidAllDay => 'all day';

  @override
  String get kidTimetableTitle => 'My timetable';

  @override
  String get kidTodayMarker => 'Today';

  @override
  String get kidYourPoints => 'Your points';

  @override
  String get kidRewardsTitle => 'Rewards';

  @override
  String get kidRedeem => 'Redeem';

  @override
  String kidNeedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points to go',
      one: '1 point to go',
    );
    return '$_temp0';
  }

  @override
  String get kidWaitsApproval => 'waiting for approval';

  @override
  String get kidRequestSent => 'Your reward is waiting for approval.';

  @override
  String get kidRedeemed => 'Redeemed!';

  @override
  String get kidSoldOut => 'Sold out for now';

  @override
  String get kidBadgesTitle => 'My badges';

  @override
  String get kidBadgeEarned => 'Earned';

  @override
  String get kidBadgeNotYet => 'Not earned yet';

  @override
  String get kidStreaksTitle => 'My streaks';

  @override
  String kidStreak(int days, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days $title',
      one: '1 day $title',
    );
    return '$_temp0';
  }

  @override
  String get kidFamilyTitle => 'Family today';

  @override
  String kidOpenTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chores open',
      one: '1 chore open',
      zero: 'No chores open',
    );
    return '$_temp0';
  }

  @override
  String get kidNoPlanToday => 'Nothing planned today';

  @override
  String get schoolsUiAddSchool => 'Another school';

  @override
  String get schoolsUiNewSchool => 'New school';

  @override
  String get schoolsUiPickSchool => 'Choose school';

  @override
  String get schoolsUiAskSchool => 'Which school?';

  @override
  String schoolsUiSchoolOf(String name) {
    return 'School: $name';
  }

  @override
  String get schoolsUiDayMenu => 'Day actions';

  @override
  String get schoolsUiCopyDay => 'Copy day to…';

  @override
  String schoolsUiCopyDayTitle(String day) {
    return 'Copy $day to';
  }

  @override
  String get schoolsUiCopyDayApply => 'Copy';

  @override
  String get schoolsUiSwapDay => 'Swap with…';

  @override
  String schoolsUiSwapDayTitle(String day) {
    return 'Swap $day with';
  }

  @override
  String get schoolsUiDayCleared => 'Day cleared';

  @override
  String get schoolsUiDayCopied => 'Day copied';

  @override
  String get schoolsUiDaySwapped => 'Days swapped';

  @override
  String get schoolsUiUndo => 'Undo';

  @override
  String get mealsUxSuggestOften => 'Family favourites';

  @override
  String get mealsUxSuggestRare => 'Not had in a while';

  @override
  String mealsUxClearedSnack(String title) {
    return '$title removed';
  }

  @override
  String get mealsUxUndo => 'Undo';

  @override
  String get mealsUxFromMealPlan => 'From the meal plan';

  @override
  String mealsUxForMeal(String meal, String day) {
    return 'For: $meal · $day';
  }

  @override
  String get todayTitle => 'Today';

  @override
  String get todayEmpty => 'Nothing is planned for today yet. Enjoy the quiet.';

  @override
  String get todayAgendaTitle => 'Appointments';

  @override
  String get todayAllDay => 'all day';

  @override
  String get todayTasksTitle => 'Your chores today';

  @override
  String get todayMealTitle => 'Warm meal';

  @override
  String todayMealLine(String slot, String dish) {
    return '$slot: $dish';
  }

  @override
  String get todayShoppingTitle => 'Shopping list';

  @override
  String todayShoppingOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items still open',
      one: '1 item still open',
    );
    return '$_temp0';
  }

  @override
  String todayNoticeJoined(String name) {
    return '$name joined';
  }

  @override
  String todayNoticeSignIn(String device) {
    return 'New sign-in: $device';
  }

  @override
  String get todayNoticeDismiss => 'Got it';

  @override
  String get todayNoticeMembers => 'Members';

  @override
  String get todayNoticeDevices => 'Devices';

  @override
  String get todayApprovalsTitle => 'Waiting for your approval';

  @override
  String todayApprovalsChecks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chores to check',
      one: '1 chore to check',
    );
    return '$_temp0';
  }

  @override
  String todayApprovalsRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reward requests',
      one: '1 reward request',
    );
    return '$_temp0';
  }

  @override
  String get todayStartTitle => 'Getting started';

  @override
  String todayStartProgress(int done, int total) {
    return '$done of $total';
  }

  @override
  String get todayStartNotNeeded => 'Not needed';

  @override
  String get todayStartInvitePartner => 'Invite your partner';

  @override
  String get todayStartConnectTablet => 'Connect the family tablet';

  @override
  String get todayStartWallDisplay => 'Set up the wall display';

  @override
  String get todayStartSetPin => 'Set your PIN';

  @override
  String get todayStartSubscribeFeed => 'Subscribe to the calendar';

  @override
  String get todayStartSchool => 'Add the timetable';

  @override
  String get settingsGettingStarted => 'Getting started';

  @override
  String get settingsGettingStartedSubtitle =>
      'Show the setup card on the Today tab again';

  @override
  String get settingsLicenses => 'Open-source licenses';

  @override
  String get settingsLicensesSubtitle =>
      'The licenses of the software and fonts WuselWall is built from';

  @override
  String get exportFamilyTitle => 'Family';

  @override
  String get exportAction => 'Export data';

  @override
  String get exportExplanation =>
      'All your family\'s data as a file, for example for a move to another server.';

  @override
  String get exportInProgress => 'Exporting data';

  @override
  String get exportPersonalDeviceRequired =>
      'The export works from your own phone only.';

  @override
  String boardHolidayLabel(String name) {
    return 'Public holiday · $name';
  }

  @override
  String get regionSettingTitle => 'Region';

  @override
  String get regionSettingHelp =>
      'Decides which public holidays apply and which school holidays you can import. Choose the canton, state or municipality.';

  @override
  String get regionFieldLabel => 'Region';

  @override
  String get regionFieldEmpty => 'No region chosen';

  @override
  String get regionFieldClear => 'Remove region';

  @override
  String get regionCountryDE => 'Germany';

  @override
  String get regionCountryAT => 'Austria';

  @override
  String get regionCountryCH => 'Switzerland';

  @override
  String get regionCountryLI => 'Liechtenstein';

  @override
  String get regionCountryOther => 'Other country (no region)';

  @override
  String get regionPickCountryTitle => 'Country';

  @override
  String get regionPickRegionTitle => 'Canton or state';

  @override
  String get regionPickSearch => 'Search';

  @override
  String regionPickWholeRegion(String name) {
    return 'All of $name';
  }

  @override
  String get regionPickDeeperTitle =>
      'Choose more precisely (district or municipality)';

  @override
  String get regionPickDeeperSearch => 'Type a municipality or district';

  @override
  String get regionPickNoMatch => 'Nothing found';

  @override
  String get regionPickLoading => 'Loading regions…';

  @override
  String get regionPickRetry => 'Try again';

  @override
  String get regionPickSkip => 'Continue without a region';

  @override
  String get regionPickEmpty => 'No regions for this country.';

  @override
  String get regionUnavailable =>
      'The region list is not available right now. Check the connection and try again.';

  @override
  String get regionCategoryCanton => 'Canton';

  @override
  String regionNameWithAbbreviation(String name, String abbreviation) {
    return '$name ($abbreviation)';
  }

  @override
  String regionNameTop(String category, String name) {
    return '$category $name';
  }

  @override
  String regionNameDeeper(String name, String category, String parent) {
    return '$name ($category), $parent';
  }

  @override
  String get regionImportAction => 'Import school holidays';

  @override
  String get regionImportNeedsRegion => 'Choose a region for the school first.';

  @override
  String get regionImportTitle => 'School holidays';

  @override
  String get regionImportIntro =>
      'Public holidays of the region apply automatically. Here you bring in the school holidays.';

  @override
  String get regionImportSwissHint =>
      'School holidays in Switzerland can differ by municipality. Check the dates.';

  @override
  String get regionImportNone =>
      'No school holidays found for the next 18 months.';

  @override
  String get regionImportAlready => 'already imported';

  @override
  String get regionImportOverlaps => 'overlaps an entry of your own';

  @override
  String get regionImportButton => 'Import';

  @override
  String regionImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count holidays imported',
      one: '1 holiday imported',
      zero: 'No holidays imported',
    );
    return '$_temp0';
  }

  @override
  String get regionImportAttribution => 'Data: OpenHolidays API · ODbL';

  @override
  String get regionImported => 'imported';

  @override
  String get extCalTitle => 'Add outside calendars';

  @override
  String get extCalSettingsSubtitle =>
      'Club fixtures, bin collection and more in the family calendar';

  @override
  String get extCalEmpty =>
      'No calendar subscribed yet. A subscription brings outside appointments into the family calendar, such as a club’s fixture list.';

  @override
  String get extCalNew => 'Subscribe to a calendar';

  @override
  String get extCalNewTitle => 'New calendar';

  @override
  String get extCalEditTitle => 'Edit calendar';

  @override
  String get extCalEdit => 'Edit';

  @override
  String get extCalNameLabel => 'Name';

  @override
  String get extCalNameHint => 'e.g. FC fixtures';

  @override
  String get extCalNameRequired => 'Give the calendar a name.';

  @override
  String get extCalUrlLabel => 'Address (ICS)';

  @override
  String get extCalUrlHelp =>
      'The address the calendar is published at, usually ending in .ics. Examples: your town’s bin collection calendar, a club’s fixture list. webcal:// addresses work too.';

  @override
  String get extCalUrlInvalid =>
      'That does not look like a web address (https://…).';

  @override
  String get extCalColourLabel => 'Colour';

  @override
  String extCalColourOption(int number) {
    return 'Colour $number';
  }

  @override
  String get extCalMembersLabel => 'Who?';

  @override
  String get extCalMembersHelp =>
      'Without a choice, the calendar is for the whole family.';

  @override
  String get extCalMembersWhole => 'Whole family';

  @override
  String get extCalShowOnBoard => 'Show on the kitchen display';

  @override
  String get extCalShowOnBoardHelp =>
      'Its appointments appear as key appointments on the kitchen display’s week board.';

  @override
  String extCalDeleteConfirm(String name) {
    return '“$name” and all its appointments will be removed.';
  }

  @override
  String get extCalDeleted => 'Calendar removed.';

  @override
  String get extCalRefreshNow => 'Refresh now';

  @override
  String extCalRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appointments loaded',
      one: '1 appointment loaded',
      zero: 'No appointments found',
    );
    return '$_temp0';
  }

  @override
  String get extCalNotModified => 'No changes since the last fetch.';

  @override
  String get extCalRecent =>
      'Fetched a moment ago. Try again in a few minutes.';

  @override
  String extCalRefreshFailed(String reason) {
    return 'The calendar could not be loaded: $reason';
  }

  @override
  String get extCalStatusPaused => 'Paused';

  @override
  String get extCalStatusNever => 'Loading for the first time …';

  @override
  String extCalStatusUpdated(String when) {
    return 'Updated $when';
  }

  @override
  String get extCalReadOnlyHint =>
      'Only guardians can subscribe to calendars or change them.';

  @override
  String get extCalErrUnreachable => 'The address cannot be reached right now.';

  @override
  String get extCalErrTimeout => 'The address answers too slowly.';

  @override
  String get extCalErrForbiddenHost => 'This address is not allowed.';

  @override
  String get extCalErrTooLarge => 'The calendar is too large (over 2 MB).';

  @override
  String get extCalErrNotIcs => 'That is not a calendar (ICS).';

  @override
  String get extCalErrHttp404 => 'Address not found (404).';

  @override
  String extCalErrHttp(int status) {
    return 'The address answers with error $status.';
  }

  @override
  String get extCalErrInternal =>
      'Something went wrong on the server. Try again later.';

  @override
  String get extCalErrDb => 'The appointments could not be stored.';

  @override
  String get extCalErrUnknown => 'The fetch did not work.';

  @override
  String get extCalErrInvalid =>
      'The calendar does not fit: check the name and colour.';

  @override
  String get extCalErrUrlInvalid =>
      'This address cannot be saved. It must start with https://.';

  @override
  String get extCalErrNotFound => 'This calendar no longer exists.';

  @override
  String get extCalImportedNote =>
      'Subscribed calendar — changes come from the source';

  @override
  String extCalFromCalendar(String name) {
    return 'From $name';
  }

  @override
  String get extCalAllDay => 'All day';

  @override
  String get extCalSheetTitle => 'Appointment from a subscription';

  @override
  String get extCalSettingsRefreshHint =>
      'The server fetches each calendar about once an hour.';

  @override
  String get extCalActive => 'Active';

  @override
  String get extCalUrlLoading => 'Loading the address';

  @override
  String get shoppingNavLabel => 'Shopping';

  @override
  String get scanHint =>
      'Hold the camera over the QR code on the other device.';

  @override
  String get scanCameraDenied =>
      'WuselWall has no access to the camera, so it cannot scan the code. Allow the camera in the system settings, or type the code instead.';

  @override
  String get scanCameraUnavailable =>
      'This device has no camera that WuselWall can use. Type the code instead.';

  @override
  String get scanWebUnsupported =>
      'This browser cannot scan QR codes. Type the code instead.';

  @override
  String get scanTypeCode => 'Type the code';

  @override
  String get feedSubTitle => 'Include outside calendars';

  @override
  String get feedSubHelp =>
      'Events from imported calendars (for example a club or the bin collection) also appear in this subscription.';

  @override
  String get feedSubSummary => 'Outside calendars';

  @override
  String get boardAllEvents => 'All events';

  @override
  String boardMemberDay(String name, String date) {
    return '$name, $date';
  }

  @override
  String get reminderChannelName => 'Reminders';

  @override
  String get reminderStartLabel => 'Turn on reminders';

  @override
  String reminderMorningEventsAndTasks(int events, int tasks) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events appointments',
      one: '1 appointment',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks chores',
      one: '1 chore',
    );
    return 'Today: $_temp0, $_temp1';
  }

  @override
  String reminderMorningEventsOnly(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events appointments',
      one: '1 appointment',
    );
    return 'Today: $_temp0';
  }

  @override
  String reminderMorningTasksOnly(int tasks) {
    String _temp0 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks chores',
      one: '1 chore',
    );
    return 'Today: $_temp0';
  }

  @override
  String reminderMorningApprovals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count approvals waiting',
      one: '1 approval waiting',
    );
    return '$_temp0';
  }

  @override
  String get reminderMorningNoEvents => 'Nothing is scheduled today.';

  @override
  String reminderMorningFirst(String time, String title) {
    return 'First up at $time: $title';
  }

  @override
  String reminderMorningAllDay(String title) {
    return 'All day: $title';
  }

  @override
  String reminderEventBody(String time) {
    return 'Starts at $time';
  }

  @override
  String get reminderSettingsTitle => 'Reminders';

  @override
  String get reminderSettingsSubtitle => 'On this phone';

  @override
  String get reminderSettingsSection => 'What you want to be reminded of';

  @override
  String get reminderStatusOn => 'Reminders are on on this phone.';

  @override
  String get reminderStatusOff => 'Reminders are off on this phone.';

  @override
  String get reminderStatusUnavailable => 'This device cannot show reminders.';

  @override
  String get reminderEnableAction => 'Turn on reminders';

  @override
  String get reminderDeniedNote =>
      'Without permission there are no reminders. You can change the permission in the system settings.';

  @override
  String get reminderLocalNote =>
      'Reminders are created on this phone. Nothing is sent to a server or to anyone else.';

  @override
  String get reminderOnlyPersonal =>
      'Reminders are only available on a member\'s personal device.';

  @override
  String get pairFrontDoorAction => 'Connect a family tablet or wall display';

  @override
  String get pairTitle => 'Connect this device';

  @override
  String get pairScanHint => 'Open WuselWall on your phone and scan this code.';

  @override
  String get pairCodeHint =>
      'Or on the phone: Settings → Devices → Connect a device, then type the code.';

  @override
  String get pairQrLabel => 'QR code to connect this device';

  @override
  String get pairWaiting => 'Waiting for approval …';

  @override
  String pairConnected(String household) {
    return 'Connected to $household';
  }

  @override
  String get pairOldCodeLink => 'I have a code from a phone (older version)';

  @override
  String get pairConnectAction => 'Connect a device';

  @override
  String get pairOldCodeAction => 'Create a code for an older device';

  @override
  String get pairEntryBody =>
      'Scan the code the new device shows, or type it in.';

  @override
  String get pairCodeField => 'Code from the new device';

  @override
  String get pairNext => 'Next';

  @override
  String get pairReviewBody => 'This is the code of the device to connect.';

  @override
  String get pairConfirmHint =>
      'Only confirm if you can see this device in front of you.';

  @override
  String get pairKindLabel => 'What kind of device is this?';

  @override
  String get pairKindWall => 'Wall display';

  @override
  String get pairKindKid => 'Kids\' tablet';

  @override
  String get pairKindFamily => 'Shared tablet';

  @override
  String get pairKindChild => 'A child\'s phone';

  @override
  String get pairChildLabel => 'Which child?';

  @override
  String get pairNameLabel => 'Device name';

  @override
  String get pairDefaultWall => 'Wall display';

  @override
  String get pairDefaultKid => 'Kids\' tablet';

  @override
  String get pairDefaultFamily => 'Tablet';

  @override
  String pairDefaultChild(String name) {
    return '$name\'s phone';
  }

  @override
  String get pairApproveAction => 'Connect';

  @override
  String get pairApproved => 'Device connected';

  @override
  String get pairOnlyOnPersonal => 'This works only on your own phone.';

  @override
  String get pairPinTitle => 'Set the guardian PIN';

  @override
  String get pairPinBody =>
      'The PIN confirms changes on shared devices. Set it once.';

  @override
  String get pairPinConfirm => 'Enter the PIN again';

  @override
  String get pairPinMismatch => 'The PINs do not match. Try again.';

  @override
  String get firstRunKioskTitle => 'Set up the wall display';

  @override
  String get firstRunKioskBody =>
      'Three steps, once on this device. Then it shows the week.';

  @override
  String get firstRunPinTitle => 'Keep the app open';

  @override
  String get firstRunPinIos =>
      'Settings → Accessibility → Guided Access: turn it on. Open WuselWall and press the top button three times quickly.';

  @override
  String get firstRunPinAndroid =>
      'Settings → Security → App pinning (on some devices “Screen pinning”). Open WuselWall, open Recents and tap the pin.';

  @override
  String get firstRunAwakeTitle => 'Keep the screen on';

  @override
  String get firstRunAwakeIos =>
      'Settings → Display & Brightness → Auto-Lock → Never.';

  @override
  String get firstRunAwakeAndroid =>
      'Settings → Display → Screen timeout: the longest setting.';

  @override
  String get firstRunPowerTitle => 'Leave it plugged in';

  @override
  String get firstRunPowerBody =>
      'Keep it on the mains, so it is ready again after a power cut.';

  @override
  String get firstRunDone => 'Done';

  @override
  String get firstRunKidTitle => 'Welcome';

  @override
  String get firstRunKidBody =>
      'Tap your picture, and WuselWall knows who you are.';

  @override
  String get firstRunKidStart => 'Let’s go';

  @override
  String get householdNewTitle => 'New family';

  @override
  String get householdNewFamilyName => 'Family name';

  @override
  String get householdNewYourName => 'Your name';

  @override
  String get householdNewColour => 'Your colour';

  @override
  String householdNewColourOption(String number) {
    return 'Colour $number';
  }

  @override
  String householdNewFamilyPrefill(String name) {
    return 'Family $name';
  }

  @override
  String householdNewDefaults(String timezone, String language) {
    return 'Time zone $timezone · Language $language — from your device';
  }

  @override
  String get householdLanguageDe => 'German';

  @override
  String get householdLanguageEn => 'English';

  @override
  String get householdLanguageFr => 'French';

  @override
  String get householdLanguageEs => 'Spanish';

  @override
  String get householdNewFounderCode => 'Setup code';

  @override
  String get householdNewFounderHelp =>
      'Use the setup code shown when your server was installed, or ask the person who runs it. This is not the code from your sign-in email.';

  @override
  String get householdNewCodeSaved =>
      'Setup code saved from your setup link. You do not need to enter it again.';

  @override
  String get householdSeedExamples =>
      'Start with examples — 5 tasks, 3 rewards';

  @override
  String get householdNewCreate => 'Create family';

  @override
  String get householdNewInvited => 'I was invited';

  @override
  String get householdInvitedNote => 'Invitations arrive with the next update.';

  @override
  String get householdNewSignOut => 'Sign out';

  @override
  String get householdNewErrNoCode =>
      'This server needs a setup code to create a family. Use the code from the server installation, not your email code.';

  @override
  String get householdNewErrCodeWrong =>
      'This setup code is invalid or has already been used. Ask the person who runs your server for a new setup link or code.';

  @override
  String get householdNewErrRateLimited =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get householdNewStalled =>
      'This is taking longer than usual. Please wait, or sign out and sign in again. Do not create the family a second time.';

  @override
  String get setupPrivacy => 'Privacy policy';

  @override
  String get householdMembersTitle => 'Who else is in your family?';

  @override
  String householdMembersYou(String name) {
    return '$name (you)';
  }

  @override
  String get householdKindChild => 'Child';

  @override
  String get householdKindAdult => 'Adult';

  @override
  String get householdMembersName => 'Name';

  @override
  String get householdMembersAdd => 'Add a person';

  @override
  String get householdMembersRemove => 'Remove';

  @override
  String get householdMembersDone => 'Done';

  @override
  String get householdMembersSkip => 'Skip';

  @override
  String get householdMembersHelp => 'You can invite adults later.';

  @override
  String householdDeviceLabel(String owner, String device) {
    return '$owner $device';
  }

  @override
  String get householdDeviceIphone => 'iPhone';

  @override
  String get householdDeviceAndroid => 'Android phone';

  @override
  String get householdDeviceBrowser => 'browser';

  @override
  String get householdDeviceComputer => 'computer';

  @override
  String get emailContinue => 'Continue';

  @override
  String get emailHavePassword => 'I have a password';

  @override
  String get emailWrongCredentials => 'Email or password is incorrect.';

  @override
  String get emailUseCodeInstead => 'Use an email code instead';

  @override
  String get emailOffline => 'No connection – signing in by email needs one.';

  @override
  String get emailRequired => 'Enter your email address.';

  @override
  String get emailInvalid => 'Enter a valid email address.';

  @override
  String get passwordRequired => 'Enter your password.';

  @override
  String get emailSendingCode => 'Sending code…';

  @override
  String get signInProgress => 'Signing in…';

  @override
  String get emailCodeTitle => 'Code from the email';

  @override
  String emailCodeSent(String email) {
    return 'We sent a 6-digit code to $email. It is valid for 10 minutes.';
  }

  @override
  String get emailCodeFieldLabel => 'Six-digit code';

  @override
  String get emailCodeWrong =>
      'That code is wrong or has expired. Try again, or ask for a new one.';

  @override
  String emailCodeResendIn(int seconds) {
    return 'No code? Send again (in $seconds s)';
  }

  @override
  String get emailCodeResend => 'No code? Send again';

  @override
  String get emailCodeSpam => 'Check your spam folder.';

  @override
  String get emailCodeResent => 'A new code is on its way.';

  @override
  String get emailCodeOtherMethod => 'Choose another way';

  @override
  String get emailCodeOtherAddress => 'Another email address';

  @override
  String get signInMethodTitle => 'How would you like to sign in next time?';

  @override
  String get signInMethodCode => 'With a code by email — nothing to remember';

  @override
  String get signInMethodPassword => 'With a password';

  @override
  String get passwordStrengthShort => 'Still too short';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthFair => 'Fair';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get settingsPasswordTitle => 'Password';

  @override
  String get settingsPasswordSet =>
      'Set. You can also sign in with email and password.';

  @override
  String get settingsPasswordNotSet =>
      'Not set. Signing in with an email code still works.';

  @override
  String get passwordSetAction => 'Set password';

  @override
  String get passwordChangeAction => 'Change password';

  @override
  String get passwordSaved => 'Your password is saved.';

  @override
  String get passwordDialogBody =>
      'At least 10 characters. The email code always stays available.';

  @override
  String signInMethodEmailSubtitle(String email) {
    return '$email — always available';
  }

  @override
  String get signInMethodAlwaysAvailable => 'Always available';

  @override
  String get leaveLeaveTile => 'Leave family';

  @override
  String get leaveLeaveExplain =>
      'Your account leaves the family. Your devices sign out. Entries stay with the family; afterwards you can start another family or join one.';

  @override
  String get leaveLeaveBlocked =>
      'Invite a second adult first, or delete the family.';

  @override
  String get leaveLeaveDialogTitle => 'Leave the family?';

  @override
  String get leaveLeaveDialogBody =>
      'You lose access to this family. It stays as it is, and the others stay in it.';

  @override
  String get leaveLeaveConfirm => 'Leave';

  @override
  String get leaveCancel => 'Cancel';

  @override
  String get leaveDeleteTile => 'Delete family';

  @override
  String get leaveDeleteExplain =>
      'The family and all its data are deleted immediately and permanently. All devices sign out. This cannot be undone.';

  @override
  String get leaveDeleteDialogTitle => 'Delete the family?';

  @override
  String get leaveDeleteDialogBody =>
      'All devices sign out, and the family is permanently deleted with all its data.';

  @override
  String leaveDeleteNameLabel(String name) {
    return 'Type ‘$name’ to confirm';
  }

  @override
  String get leaveDeleteNext => 'Next';

  @override
  String get leaveDeleteWordTitle => 'Delete for good?';

  @override
  String get leaveDeleteWordBody =>
      'The family and all its data are deleted immediately and permanently. Nobody can restore them, not even a guardian. Export the data first if you want to keep it.';

  @override
  String get leaveDeleteWord => 'DELETE';

  @override
  String leaveDeleteWordLabel(String word) {
    return 'Type $word to delete the family for good';
  }

  @override
  String get leaveDeleteConfirm => 'Delete family';

  @override
  String leaveDeletedTitle(String family, String date) {
    return '$family will be deleted for good on $date';
  }

  @override
  String get leaveDeletedBodyGuardian =>
      'You can restore the family. All data is still there. This phone becomes the family\'s phone again; the other devices sign in again.';

  @override
  String get leaveDeletedBodyMember =>
      'Only a guardian can restore the family. You can also start afresh; then your account leaves this family.';

  @override
  String get leaveRestore => 'Restore';

  @override
  String get leaveStartAfresh => 'Start afresh';

  @override
  String get leaveStartAfreshHint =>
      'Your account leaves the deleted family, and you start a new one.';

  @override
  String get leaveErrConfirmName => 'The name does not match.';

  @override
  String get leaveErrHouseholdDeleted => 'This family has been deleted.';

  @override
  String get leaveErrRestoreExpired => 'This family can no longer be restored.';

  @override
  String get leaveErrNotDeleted => 'This family is not deleted.';

  @override
  String get leaveErrAdultRequired => 'Only adults have their own account.';

  @override
  String get leaveErrAlreadyInHousehold =>
      'This account already belongs to a family.';

  @override
  String get inviteDoorAction => 'I have an invitation code';

  @override
  String get inviteCodeTitle => 'Invitation';

  @override
  String get inviteCodeBody =>
      'Enter the code, or paste the link you were sent.';

  @override
  String get inviteCodeLabel => 'Code or link';

  @override
  String get inviteCheckAction => 'Check invitation';

  @override
  String get inviteCodeInvalidFormat =>
      'That is neither an invitation code nor a WuselWall link.';

  @override
  String get inviteNoLonger =>
      'This invitation is no longer valid. Ask the person who invited you for a new one.';

  @override
  String get inviteRateLimited =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String inviteBanner(String inviter, String household) {
    return '$inviter has invited you to $household';
  }

  @override
  String inviteBannerNoInviter(String household) {
    return 'You are invited to $household';
  }

  @override
  String get inviteRoleLineGuardian =>
      'As a guardian you see everything and approve rewards.';

  @override
  String get inviteRoleLineMember =>
      'As a member you tick off tasks, without approving rewards.';

  @override
  String get inviteContinue => 'Continue to sign-in';

  @override
  String get inviteJoin => 'Join';

  @override
  String get inviteNewFamilyInstead => 'Start my own family';

  @override
  String inviteJoinTitle(String name, String household) {
    return 'You are $name in $household';
  }

  @override
  String get inviteJoinHint =>
      'Your name and colour, as the family sees them. You can change them later in Settings.';

  @override
  String get inviteJoinDecline => 'Don\'t join';

  @override
  String inviteAlreadyIn(String household) {
    return 'You are already in $household.';
  }

  @override
  String inviteAlreadyInTitle(String household) {
    return 'You\'re already in $household';
  }

  @override
  String inviteAlreadyInSame(String household) {
    return 'This invitation is for $household, and you\'re already in it. There\'s nothing more to do.';
  }

  @override
  String get inviteAlreadyInLeaveHint =>
      'An account belongs to one family only. To join, first leave the family you\'re in now; the invitation then carries on.';

  @override
  String get inviteAlreadyInLeaveHintUnknown =>
      'An account belongs to one family only. To join another, first leave the family you\'re in now, then open the invitation again.';

  @override
  String get inviteAlreadyInDevice =>
      'This device already belongs to a family. Open the invitation on the invited person\'s own phone.';

  @override
  String get invitePartnerPickTitle => 'Who would you like to invite?';

  @override
  String get invitePartnerExisting => 'Already in the family, no account yet';

  @override
  String get invitePartnerSomeoneElse => 'Someone else';

  @override
  String get invitePartnerSomeoneElseHint => 'Adds a new adult to the family';

  @override
  String get inviteNothingKept => 'There is no invitation to join any more.';

  @override
  String inviteResultTitle(String name) {
    return 'Invitation for $name';
  }

  @override
  String get inviteResultHint =>
      'The person enters the code in WuselWall, or scans the QR code.';

  @override
  String inviteValidUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String get inviteQrLabel => 'QR code of the invitation';

  @override
  String get inviteShare => 'Share';

  @override
  String get inviteDone => 'Done';

  @override
  String inviteShareMessage(
    String household,
    String link,
    String code,
    String server,
  ) {
    return 'Join $household on WuselWall: $link — or enter the code $code in the app, on the server $server.';
  }

  @override
  String get inviteAdultTitle => 'Invite an adult';

  @override
  String get inviteAdultName => 'Name';

  @override
  String get inviteAdultRole => 'Role';

  @override
  String get inviteRoleGuardian => 'Guardian';

  @override
  String get inviteRoleMember => 'Member';

  @override
  String get inviteRoleGuardianHelp => 'Sees everything and approves rewards.';

  @override
  String get inviteRoleMemberHelp =>
      'Ticks off tasks but does not approve rewards. For an au pair or grandparents.';

  @override
  String get inviteAdultEmail => 'Email (optional)';

  @override
  String get inviteAdultEmailHelp =>
      'With this address the person finds the invitation by itself when signing in.';

  @override
  String get inviteEmailInvalid => 'That does not look like an email address.';

  @override
  String get inviteCreate => 'Create invitation';

  @override
  String get inviteInviteAction => 'Invite';

  @override
  String inviteOpenUntil(String date) {
    return 'Invited · until $date';
  }

  @override
  String get inviteShareAgain => 'Share again';

  @override
  String get inviteWithdraw => 'Withdraw';

  @override
  String get inviteWithdrawn => 'Invitation withdrawn.';

  @override
  String get inviteScanTitle => 'Scan invitation';

  @override
  String get accountDeleteTile => 'Delete account';

  @override
  String get accountDeleteExplain =>
      'Your account and its sign-in methods are deleted, and you are signed out everywhere. Your profile stays in the family with its history.';

  @override
  String get accountDeleteBlocked =>
      'You are the last guardian with an account in this family. Invite a second adult first, or delete the family.';

  @override
  String get accountDeleteDialogTitle => 'Delete account?';

  @override
  String get accountDeleteDialogBody =>
      'This cannot be undone. Your sign-in is removed, and your profile stays in the family.';

  @override
  String get accountDeleteConfirm => 'Delete account';

  @override
  String get accountDeleteRefused =>
      'The account could not be deleted. Try again later.';

  @override
  String get accountDeleteReauthTitle => 'Please confirm it is you';

  @override
  String accountDeleteReauthBody(String email) {
    return 'Deleting an account needs a fresh sign-in. We send a code to $email.';
  }

  @override
  String get accountDeleteReauthSend => 'Send code';

  @override
  String get accountDeleteReauthCodeLabel => 'Code from the email';

  @override
  String get accountDeleteReauthConfirm => 'Confirm';

  @override
  String get accountDeleteReauthSignInAgain =>
      'Sign in again first, then you can delete the account.';

  @override
  String get mfaResetAction => 'Reset two-factor';

  @override
  String get mfaResetConfirmTitle => 'Reset two-factor?';

  @override
  String mfaResetConfirmBody(String name) {
    return '$name can sign in without a second factor afterwards and set it up again.';
  }

  @override
  String get mfaResetConfirm => 'Reset';

  @override
  String mfaResetDone(String name) {
    return '$name\'s second factor is reset.';
  }

  @override
  String get serverTitle => 'Which server?';

  @override
  String get serverLead =>
      'WuselWall keeps your family\'s data on your family\'s own server. Enter its address, or scan its QR code. Got an invitation? Paste the link, or the code together with the server, like K7QM3XRP@api.example.org.';

  @override
  String get serverAddressLabel => 'Server address';

  @override
  String get serverAddressHint => 'e.g. api.example.org';

  @override
  String get serverConnect => 'Connect';

  @override
  String get serverScan => 'Scan QR code';

  @override
  String get serverScanTitle => 'Scan the server\'s QR code';

  @override
  String get serverDemo => 'Try it without a server';

  @override
  String get serverDemoHint =>
      'With an example family. Nothing leaves this device.';

  @override
  String get serverHelp =>
      'No server yet? The guide at wuselwall.app/docs shows how to set one up.';

  @override
  String get serverInvalid => 'That is not a server address.';

  @override
  String get serverUnreachable =>
      'The server does not answer. Is the address right, and are you online?';

  @override
  String get serverNotWuselwall =>
      'There is no WuselWall server at this address.';

  @override
  String get serverTooOld =>
      'This server needs an update. Ask whoever runs it to update WuselWall.';

  @override
  String get serverAppTooOld =>
      'This server needs a newer version of the app. Please update WuselWall.';

  @override
  String get serverLinkWithoutServer =>
      'This link does not say which server it belongs to. Enter the server\'s address above, then the code.';

  @override
  String inviteResultServer(String server) {
    return 'Server: $server';
  }

  @override
  String get linkOtherServerTitle => 'This link belongs to another server';

  @override
  String linkSwitchBody(String host, String current) {
    return 'The link points to $host, but this app is connected to $current. Switch to $host?';
  }

  @override
  String get linkSwitchAction => 'Switch server';

  @override
  String linkOtherServerBody(String host, String current) {
    return 'The link points to $host, but you are signed in on $current. Sign out first (Settings → Change server), then open the link again.';
  }

  @override
  String get serverIncompatibleTitle => 'Server and app don\'t fit together';

  @override
  String get serverChooseOther => 'Choose another server';

  @override
  String get demoBanner => 'Example family: nothing is saved';

  @override
  String get demoExit => 'Exit';

  @override
  String get settingsServer => 'Server';

  @override
  String settingsServerBody(String address) {
    return 'This app talks to $address. Scan this code with the WuselWall app on another device to connect it to the same server.';
  }

  @override
  String get settingsServerSwitch => 'Change server';

  @override
  String get settingsServerSwitchConfirm =>
      'This device will be signed out and forget everything stored on it. Then you can choose another server.';

  @override
  String get setupPhoneTitle => 'Continue on your phone';

  @override
  String get setupPhoneBody =>
      'Open the WuselWall app on your phone, choose this server by scanning the code, then sign in there.';

  @override
  String get shortcutTitle => 'Apps and automations';

  @override
  String get shortcutIntro =>
      'A key lets another app use WuselWall as one person. An automation key, for example for a shortcut with Siri on the iPhone or any other app that can call a web address, reads and adds: it puts things on the shopping list and tells you what is on today, what there is to eat or who has PE tomorrow. It cannot delete or manage anything.';

  @override
  String get shortcutEmpty => 'No keys yet.';

  @override
  String get shortcutKioskNote =>
      'Keys are created on a personal phone, not on the wall display.';

  @override
  String get shortcutNew => 'New key';

  @override
  String get shortcutLabelField => 'Name';

  @override
  String get shortcutLabelHint => 'e.g. iPhone';

  @override
  String get shortcutForWhom => 'For whom?';

  @override
  String get shortcutForWhomHelp =>
      'The shortcut acts as this person: it ticks their tasks and tells their points.';

  @override
  String get shortcutCreate => 'Create key';

  @override
  String shortcutKeyTitle(String name) {
    return 'Key for $name';
  }

  @override
  String shortcutKeyOnce(String name) {
    return 'This key is shown only now. Whoever has it can read and add as $name, so treat it like a password. In Apple’s Shortcuts app it syncs through iCloud.';
  }

  @override
  String get shortcutCopyKey => 'Copy key';

  @override
  String get shortcutAddressLabel => 'Address';

  @override
  String get shortcutCopyAddress => 'Copy address';

  @override
  String get shortcutCopied => 'Copied.';

  @override
  String get shortcutHowTitle => 'How it works';

  @override
  String get shortcutHowSteps =>
      'Any app sends the same request. With Apple Shortcuts, create a shortcut with the action “Get Contents of URL”: the address with /today at the end, and a header “Authorization” with “Bearer ”, a space and the key. Then add “Show Result” or “Speak Text”. The guide at wuselwall.app/docs/en/settings/shortcuts shows every shortcut.';

  @override
  String shortcutLastUsed(String when) {
    return 'Last used: $when';
  }

  @override
  String get shortcutNeverUsed => 'Never used';

  @override
  String shortcutUseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests',
      one: '1 request',
    );
    return '$_temp0';
  }

  @override
  String get shortcutRevoked => 'Revoked';

  @override
  String get shortcutRevokeAction => 'Revoke';

  @override
  String shortcutRevokeConfirm(String label) {
    return 'Revoke “$label”? The shortcut stops working at once.';
  }

  @override
  String get shortcutErrLabel =>
      'Please enter a name of at most 60 characters.';

  @override
  String get shortcutErrLimit =>
      'This person already has ten keys. Please revoke one first.';

  @override
  String get shortcutSectionAutomations => 'Automations';

  @override
  String get shortcutSectionAssistants => 'AI assistants';

  @override
  String get shortcutKindShortcut => 'Automation';

  @override
  String get shortcutKindAssistant => 'AI assistant';

  @override
  String get shortcutKindShortcutHelp =>
      'For Siri and Apple Shortcuts, or any app that can call a web address: it reads and adds, for example to the shopping list.';

  @override
  String get shortcutKindAssistantHelp =>
      'For an AI assistant that speaks MCP, such as Claude: it only reads, and only adults get one.';

  @override
  String get shortcutAssistantLabelHint => 'e.g. Claude on the laptop';

  @override
  String shortcutAssistantKeyOnce(String name) {
    return 'This key is shown only now. With it, an assistant reads the whole family\'s week as $name: appointments, who is away, the children\'s timetables, tasks, meals and the shopping list. What it reads goes to the assistant\'s provider. Treat the key like a password.';
  }

  @override
  String get shortcutAssistantHowSteps =>
      'Add the address as an MCP server in your assistant and send the key as the header “Authorization” with “Bearer ”, a space and the key. The guide at wuselwall.app/docs/en/settings/shortcuts shows how for some assistants.';

  @override
  String get shortcutErrAdultOnly => 'Only adults get a key for an assistant.';

  @override
  String get reminderPackTitle => 'Pack for tomorrow';

  @override
  String reminderPackChild(String name, String items) {
    return '$name: $items';
  }

  @override
  String get settingNotifyPackingTitle => 'Packing reminder the evening before';

  @override
  String get settingNotifyPackingHelp =>
      'At this time your phone says what has to go in the school bag for tomorrow, from the timetables (for example PE kit). Only when there is something to pack.';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceSystem => 'Automatic';

  @override
  String get appearanceSystemHelp => 'Light or dark, as set on this device';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceNightNote =>
      'At night the wall display always shows its night view.';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'Automatic';

  @override
  String languageSystemCurrent(String name) {
    return 'Automatic: $name';
  }

  @override
  String get languageSystemHelp =>
      'The language of this device; German when the app does not have it';

  @override
  String get languageNameDe => 'Deutsch';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageNameFr => 'Français';

  @override
  String get languageNameEs => 'Español';

  @override
  String get settingsViewLabel => 'Which settings to show';

  @override
  String get settingsViewAdvanced => 'Advanced';

  @override
  String get settingsViewMoreHint =>
      'More settings are under Advanced. Hidden settings still apply.';

  @override
  String get settingsViewShowAll => 'Show all settings';

  @override
  String get schoolTimetableNeedsTerm =>
      'The week shown is not in any term yet. Add the term it belongs to, then enter the lessons.';

  @override
  String get schoolTermContinue => 'Save term and continue';

  @override
  String get schoolSetupFirstHint =>
      'Bell times (from 8:00, 45 minutes) and a subject list are proposed. Both can be adjusted afterwards.';

  @override
  String get schoolSetupCreate => 'Add school';

  @override
  String get schoolNextSteps => 'Next steps';

  @override
  String schoolNextStepEnter(String name) {
    return 'Enter $name’s timetable';
  }

  @override
  String get schoolTermProposedHint =>
      'Proposed: the current school year. Adjust the name and dates if your school counts differently.';

  @override
  String schoolYearName(String from, String to) {
    return 'School year $from/$to';
  }

  @override
  String schoolCreateSubject(String name) {
    return 'Add “$name” as a subject';
  }

  @override
  String get schoolImportAction => 'Read in…';

  @override
  String get schoolImportFromText => 'Paste as text';

  @override
  String get schoolImportFromPhoto => 'Scan a photo';

  @override
  String get schoolImportTitle => 'Read in a timetable';

  @override
  String schoolImportProposedBy(String assistant) {
    return 'Proposed by $assistant';
  }

  @override
  String schoolImportLessons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons',
      one: '1 lesson',
    );
    return '$_temp0';
  }

  @override
  String schoolImportTermNew(String name) {
    return 'Term: $name (will be created)';
  }

  @override
  String schoolImportTermExisting(String name) {
    return 'Term: $name';
  }

  @override
  String schoolImportReplaces(String name, int count) {
    return 'Replaces $name’s existing timetable ($count lessons).';
  }

  @override
  String get schoolImportNewSubjects => 'New subjects';

  @override
  String get schoolImportCreateSubjects => 'Create the new subjects';

  @override
  String get schoolImportSkipNewSubjects =>
      'Lessons with new subjects are left out.';

  @override
  String get schoolImportCreateNew => 'Create new';

  @override
  String get schoolImportMergeHint =>
      'Already have this subject? Pick it, and WuselWall remembers the sheet\'s word.';

  @override
  String schoolImportWarnUnmatchedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons match no bell time and are left out.',
      one: '1 lesson matches no bell time and is left out.',
    );
    return '$_temp0';
  }

  @override
  String schoolImportWarnPeriodsExtended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The bell times get $count more lessons.',
      one: 'The bell times get 1 more lesson.',
    );
    return '$_temp0';
  }

  @override
  String get schoolImportWarnPeriodsDiffer =>
      'The bell times on the sheet differ from the school’s; the school’s stay.';

  @override
  String schoolImportWarnSchoolDiffers(String name) {
    return 'The sheet names another school: $name.';
  }

  @override
  String get schoolImportApply => 'Apply';

  @override
  String get schoolImportDiscard => 'Discard';

  @override
  String get schoolImportApplied => 'Timetable applied.';

  @override
  String get schoolImportDiscarded => 'Proposal discarded.';

  @override
  String get schoolImportNoChild => 'Add a child under Members first.';

  @override
  String get schoolImportPasteTitle => 'Read in from text';

  @override
  String get schoolImportPasteIntro =>
      'Paste a timetable as JSON in the WuselWall format. You see a preview before anything is saved.';

  @override
  String get schoolImportCopyPrompt =>
      'Copy the instructions for the assistant';

  @override
  String get schoolImportPromptCopied => 'Instructions copied.';

  @override
  String get schoolImportPrompt =>
      'Please read the timetable in the photo and return it as JSON in the format below, with no other text. Days as Mo, Tu, We, Th, Fr; periods as a number (1 = first lesson) or with start and end times; subjects with the short code on the sheet and, if known, the full name. Leave empty cells out. For A and B weeks set week: a or b. After-school care goes under care.';

  @override
  String get schoolImportPasteHint => 'Paste timetable JSON here';

  @override
  String get schoolImportRead => 'Read in';

  @override
  String get schoolImportErrNotJson =>
      'That is not a timetable in the WuselWall format. Paste the complete JSON text.';

  @override
  String get schoolImportErrNoLessons => 'The text contains no lessons.';

  @override
  String get schoolImportErrTooMany =>
      'That is more entries than a timetable can have.';

  @override
  String get schoolImportErrBadLesson =>
      'A lesson has no day, no period or no subject.';

  @override
  String schoolImportErrBadDay(String value) {
    return '“$value” is no weekday.';
  }

  @override
  String schoolImportErrBadTime(String value) {
    return '“$value” is no time of day.';
  }

  @override
  String schoolProposalTitle(String assistant) {
    return 'Proposal from $assistant';
  }

  @override
  String schoolProposalSummary(String name, int count) {
    return 'Timetable for $name, $count lessons';
  }

  @override
  String get schoolProposalReview => 'Review';

  @override
  String get schoolProposalUnreadable =>
      'This proposal has a format this app version cannot read.';

  @override
  String get schoolProposalErrInvalid => 'The proposal has an invalid format.';

  @override
  String get schoolProposalErrLimit =>
      'Five proposals are already waiting. Review or discard them first.';

  @override
  String get schoolProposalErrGone =>
      'This proposal is already settled or has expired.';

  @override
  String get schoolScanIntro =>
      'Your server reads the photo or the PDF; nothing leaves your home. A straight, bright photo of the whole sheet works best; the school\'s PDF is the most exact.';

  @override
  String get schoolScanCamera => 'Take a photo';

  @override
  String get schoolScanPick => 'Choose a photo';

  @override
  String get schoolScanBusy => 'Reading the sheet…';

  @override
  String get schoolScanNotConfigured =>
      'Your server has no text recognition set up. The guide’s “Extras for the server” says how to add it. Until then: read in from text.';

  @override
  String get schoolScanNothingFound =>
      'No timetable was found in the photo. Try a straighter, brighter photo, or read the plan in from text.';

  @override
  String get schoolScanTooLarge => 'The photo is too large (6 MB at most).';

  @override
  String get schoolScanFailed =>
      'The server’s text recognition did not answer. Try again later.';

  @override
  String schoolScanWarnUnplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count pieces of text fit no cell. Compare the preview with the sheet.',
      one: '1 piece of text fit no cell. Compare the preview with the sheet.',
    );
    return '$_temp0';
  }

  @override
  String get savedMessage => 'Saved.';

  @override
  String get settingsSectionThisDevice => 'This device';

  @override
  String get settingsSectionConnect => 'Sharing and connections';

  @override
  String get settingsMembersHint =>
      'Tap a person to change their name, colour, picture or role. Drag the handle to change the order on the wall.';

  @override
  String get familyTitle => 'Family';

  @override
  String get familySettingsSubtitle => 'Name, time zone, data export, delete';

  @override
  String get familyTimezone => 'Time zone';

  @override
  String get familyTimezoneHelp => 'The wall and reminders follow this zone.';

  @override
  String get familyTimezoneSearch => 'Search time zone';

  @override
  String get familyLocale => 'Language on the wall';

  @override
  String get familyLocaleHelp =>
      'Public holidays on the wall display are named in this language.';

  @override
  String get familyErrTimezone => 'Unknown time zone.';

  @override
  String get memberColour => 'Colour';

  @override
  String get memberAvatar => 'Picture';

  @override
  String get memberAvatarInitial => 'Initial';

  @override
  String get memberKind => 'Child or adult';

  @override
  String get memberRole => 'Role';

  @override
  String get memberRoleHelp =>
      'Guardians see everything and approve rewards. Members tick off tasks.';

  @override
  String get memberReadOnlyHint =>
      'Only guardians change other people. You can change your own name, colour and picture.';

  @override
  String get memberKioskReadOnly =>
      'Nobody is changed on the wall display. Change names, colours, pictures and birthdays in the app on a phone or tablet.';

  @override
  String get memberInactive => 'No longer with us';

  @override
  String get memberInactiveBody =>
      'Off the wall, the avatar rows and new chores. History and points stay.';

  @override
  String get memberDeactivate => 'No longer with us';

  @override
  String memberDeactivateBody(String name) {
    return '$name disappears from the wall, the avatar rows and new chores. History and points stay, and you can bring the person back here.';
  }

  @override
  String memberDeactivateConfirm(String name) {
    return 'Remove $name from the family\'s screens? History and points stay.';
  }

  @override
  String get memberReactivate => 'Back with us';

  @override
  String memberHasAccountHint(String name) {
    return '$name has an account and leaves the family from their own phone (Settings → Leave family).';
  }

  @override
  String get memberReorderHandle => 'Change order';

  @override
  String get memberErrKindAdult =>
      'A guardian, or someone with an account, is an adult.';

  @override
  String get memberErrRoleChild =>
      'A child cannot be a guardian. Make the person an adult first.';

  @override
  String get memberErrSelf =>
      'You cannot remove yourself. Another guardian can.';

  @override
  String get memberErrHasAccount =>
      'This person has an account and leaves from their own phone.';

  @override
  String get deviceRename => 'Rename device';

  @override
  String deviceLastSeen(String ago) {
    return 'last active $ago';
  }

  @override
  String get deviceNeverSeen => 'not active yet';

  @override
  String get shoppingEditList => 'Edit list';

  @override
  String get shoppingListDefault => 'Default list';

  @override
  String get shoppingListDefaultHelp =>
      'The wall display writes to the default list.';

  @override
  String get shoppingCategories => 'Categories';

  @override
  String get shoppingCategoriesHelp =>
      'In the order you walk through the shop. Drag the handle to reorder.';

  @override
  String get shoppingCategoryAdd => 'Add category';

  @override
  String get shoppingCategoryRename => 'Rename category';

  @override
  String get shoppingCategoryName => 'Category name';

  @override
  String shoppingCategoryDeleteConfirm(String name) {
    return 'Remove “$name”? Its items stay on the list without a category.';
  }

  @override
  String get shoppingListDelete => 'Delete list';

  @override
  String shoppingListDeleteConfirm(String name) {
    return 'Delete “$name”? Open items move to the default list; its history and tiles are gone.';
  }

  @override
  String get shoppingErrListDefault =>
      'The default list cannot be deleted. Make another list the default first.';

  @override
  String get shoppingErrTileExists => 'A tile with this name already exists.';

  @override
  String get shoppingTileAddEdit => 'Add and edit';

  @override
  String get shoppingTileRename => 'Rename tile';

  @override
  String get shoppingTileForget => 'Don\'t suggest any more';

  @override
  String get shoppingTileForgetHelp => 'The tile goes; the history keeps it.';

  @override
  String shoppingTileForgetConfirm(String name) {
    return 'Remove the tile “$name”? Buying it again brings it back.';
  }

  @override
  String get schoolScanFile => 'Choose a file (PDF or picture)';

  @override
  String get schoolImportPhotoUnavailable =>
      'Your server can\'t read photos yet.';

  @override
  String get settingsVersions => 'Versions';

  @override
  String settingsVersionsLine(String app, String server, String api) {
    return 'App $app · Server $server · API $api';
  }

  @override
  String get settingsVersionUnknown => 'unknown';

  @override
  String get settingMemberWuselTitle => 'Wusel';

  @override
  String get settingMemberWuselHelp =>
      'How much Wusel shows up for you. Automatic: lively for children, quiet for adults.';

  @override
  String get settingMemberWuselOutfitTitle => 'Wusel\'s outfit';

  @override
  String get settingMemberWuselOutfitHelp =>
      'What Wusel wears when talking to you. Every outfit is there from the start.';

  @override
  String get settingDeviceWuselTitle => 'Wusel on this device';

  @override
  String get settingDeviceWuselHelp =>
      'How lively Wusel is here while nobody is chosen. A person\'s own setting wins while they are chosen.';

  @override
  String get settingDeviceSoundsTitle => 'Sounds on this device';

  @override
  String get settingDeviceSoundsHelp =>
      'Automatic: off on the wall, on elsewhere. Never at night.';

  @override
  String get settingDeviceSkyTitle => 'Sky in the header';

  @override
  String get settingDeviceSkyHelp =>
      'The header shows a sky that changes with the time of day.';

  @override
  String get settingDevicePixelShiftTitle => 'Protect the screen from burn-in';

  @override
  String get settingDevicePixelShiftHelp =>
      'Moves everything by up to 2 pixels every 10 minutes, for OLED screens that stay on. Automatic: on for the wall.';

  @override
  String get settingAmbienceSeasonTitle => 'Seasons';

  @override
  String get settingAmbienceSeasonHelp =>
      'Blossom, sun, leaves or snowflakes in the sky.';

  @override
  String get settingAmbienceBirthdaysTitle => 'Birthdays';

  @override
  String get settingAmbienceBirthdaysHelp =>
      'Bunting in the member\'s colour and a party hat for Wusel on their birthday.';

  @override
  String get settingAmbienceFerienTitle => 'School holidays';

  @override
  String get settingAmbienceFerienHelp =>
      'A ribbon on the first and the last day of the holidays.';

  @override
  String get settingAmbienceAdventTitle => 'Advent';

  @override
  String get settingAmbienceAdventHelp =>
      'Candles in the header, one more on each of the four Sundays before Christmas. Automatic: by your region.';

  @override
  String get settingAmbienceEasterWesternTitle => 'Easter';

  @override
  String get settingAmbienceEasterWesternHelp =>
      'Eggs in the hills from two days before to two days after Easter Sunday. Automatic: by your region.';

  @override
  String get settingAmbienceEasterOrthodoxTitle => 'Orthodox Easter';

  @override
  String get settingAmbienceEasterOrthodoxHelp =>
      'The same eggs on the Orthodox date, which is calculated for every year. Automatic: by your region.';

  @override
  String get settingAmbienceNewYearTitle => 'New Year\'s Eve';

  @override
  String get settingAmbienceNewYearHelp =>
      'Small fireworks in the night sky on 31 December and 1 January.';

  @override
  String get settingRitualsCountdownDaysTitle => 'Start looking forward';

  @override
  String get settingRitualsCountdownDaysHelp =>
      'How many days before a birthday, the holidays or a marked event the countdown appears.';

  @override
  String get settingRitualsCountdownReturnTitle =>
      'Count down to a parent\'s return';

  @override
  String get settingRitualsCountdownReturnHelp =>
      '\"Back in 2 sleeps\" when an adult travels for two nights or more.';

  @override
  String get settingMealsWishesTitle => 'Meal wishes';

  @override
  String get settingMealsWishesHelp =>
      'Who may wish for a meal. A wish is never turned down in the app; it waits until it is planned.';

  @override
  String get settingMealsWishesPerWeekTitle => 'Open wishes per person';

  @override
  String get settingMealsWishesPerWeekHelp =>
      'How many wishes each person may have waiting at once.';

  @override
  String get settingTableQuestionTitle => 'Question at the table';

  @override
  String get settingTableQuestionHelp =>
      'A conversation question on the wall and in the app during the meal. It is answered aloud and nothing is recorded.';

  @override
  String get settingTableQuestionLunchTitle => 'Question at lunch';

  @override
  String get settingTableQuestionLunchHelp =>
      'When the question shows at lunch.';

  @override
  String get settingTableQuestionDinnerTitle => 'Question at dinner';

  @override
  String get settingTableQuestionDinnerHelp =>
      'When the question shows at dinner.';

  @override
  String get settingTableQuestionDeckTitle => 'Questions for';

  @override
  String get settingTableQuestionDeckHelp =>
      'All ages works for a five-year-old; older children adds deeper questions for 8 and over.';

  @override
  String get settingWeekReviewTitle => 'Our week';

  @override
  String get settingWeekReviewHelp =>
      'When the look back at the week appears. It stays until the next morning.';

  @override
  String get settingValueAuto => 'Automatic';

  @override
  String get settingValueLively => 'Lively';

  @override
  String get settingValueQuiet => 'Quiet';

  @override
  String get settingValueOn => 'On';

  @override
  String get settingValueOff => 'Off';

  @override
  String get settingValueChildren => 'Children';

  @override
  String get settingValueEveryone => 'Everyone';

  @override
  String get settingValueWarmMeal => 'Warm meal';

  @override
  String get settingValueMainMeals => 'Lunch and dinner';

  @override
  String get settingValueAllAges => 'All ages';

  @override
  String get settingValueOlderChildren => 'Older children too';

  @override
  String settingUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get wuselOutfitNone => 'Nothing';

  @override
  String get wuselOutfitParty => 'Party hat';

  @override
  String get wuselOutfitCrown => 'Crown';

  @override
  String get wuselOutfitWizard => 'Wizard hat';

  @override
  String get wuselOutfitWreath => 'Flower wreath';

  @override
  String get wuselOutfitSunglasses => 'Sunglasses';

  @override
  String get wuselOutfitScarf => 'Scarf';

  @override
  String get wuselOutfitHeadphones => 'Headphones';

  @override
  String get wuselOutfitBow => 'Bow';

  @override
  String wuselHelloMorning1(String name) {
    return 'Good morning, $name!';
  }

  @override
  String wuselHelloMorning2(String name) {
    return 'Morning, $name! A new day.';
  }

  @override
  String wuselHelloMorning3(String name) {
    return 'Hello $name, nice that you are up.';
  }

  @override
  String wuselHelloDay1(String name) {
    return 'Hi $name!';
  }

  @override
  String wuselHelloDay2(String name) {
    return 'There you are, $name!';
  }

  @override
  String wuselHelloDay3(String name) {
    return 'Nice to see you, $name.';
  }

  @override
  String wuselHelloEvening1(String name) {
    return 'Good evening, $name!';
  }

  @override
  String wuselHelloEvening2(String name) {
    return 'Evening, $name! What a day.';
  }

  @override
  String wuselHelloEvening3(String name) {
    return 'Hi $name! Time to rest soon.';
  }

  @override
  String wuselHelloNight(String name) {
    return 'Sleep well, $name.';
  }

  @override
  String get wuselFactBirthdayYou => 'Happy birthday!';

  @override
  String wuselFactBirthday(String name) {
    return 'It\'s $name\'s birthday!';
  }

  @override
  String wuselFactFirstLesson(String subject) {
    return 'Today you start with $subject.';
  }

  @override
  String wuselFactTradition(String tradition) {
    return 'Today is $tradition!';
  }

  @override
  String wuselFactMealDinner(String dish) {
    return 'Tonight there\'s $dish.';
  }

  @override
  String wuselFactMealLunch(String dish) {
    return 'For lunch there\'s $dish.';
  }

  @override
  String wuselFactCountdown(String what, String when) {
    return '$what: $when';
  }

  @override
  String wuselBirthdayCheer(String name) {
    return 'Happy birthday, $name!';
  }

  @override
  String get wuselAllDone1 => 'All done. That went well!';

  @override
  String get wuselAllDone2 => 'Everything\'s ticked off. Thank you!';

  @override
  String get wuselAllDone3 => 'Done for today. The house says thanks!';

  @override
  String get wuselAllDone4 => 'Your list is empty. Time to play!';

  @override
  String get wuselRewardSent1 => 'Sent! A grown-up will decide.';

  @override
  String get wuselRewardSent2 => 'Your wish is on its way.';

  @override
  String get wuselRewardSent3 => 'Wish sent! Now a grown-up takes a look.';

  @override
  String wuselBadge(String badge) {
    return 'A new badge: $badge!';
  }

  @override
  String get wuselWaiting => 'Just a moment…';

  @override
  String get wuselOffline => 'Hang on, looking for the internet…';

  @override
  String get wuselWallMorning1 => 'Good morning, everyone!';

  @override
  String get wuselWallMorning2 => 'Rise and shine, family!';

  @override
  String get wuselWallMorning3 => 'A new day for all of us.';

  @override
  String wuselWallMemberDone1(String name) {
    return '$name has done everything for today!';
  }

  @override
  String wuselWallMemberDone2(String name) {
    return 'All ticked off, $name. Thanks!';
  }

  @override
  String wuselWallMemberDone3(String name) {
    return '$name\'s tasks are all done today!';
  }

  @override
  String wuselWallTradition1(String name) {
    return 'It\'s $name today!';
  }

  @override
  String wuselWallTradition2(String name) {
    return 'Hooray, today is $name!';
  }

  @override
  String wuselWallTradition3(String name) {
    return 'Good morning! Today is $name.';
  }

  @override
  String get wuselSetupDone => 'That\'s everything set up. Welcome home!';

  @override
  String get wuselHideLine => 'Hide what Wusel says';

  @override
  String get wuselFerienFirst1 =>
      'The holidays start today. Enjoy the time off!';

  @override
  String get wuselFerienFirst2 => 'Holidays! The free days begin today.';

  @override
  String get wuselFerienFirst3 =>
      'First day of the holidays. Enjoy it together!';

  @override
  String get ambienceFerienFirst => 'Holidays!';

  @override
  String get ambienceFerienLast => 'School again tomorrow';

  @override
  String get shoppingEmptyTapTile => 'Nothing on the list yet. Tap a tile.';

  @override
  String get memberBirthday => 'Birthday';

  @override
  String get memberBirthdayHelp =>
      'Shown on the wall on the day, and counted down to before it.';

  @override
  String get memberBirthdayPick => 'Choose a date';

  @override
  String get memberBirthdayClear => 'Remove the birthday';

  @override
  String countdownBirthdayOf(String name) {
    return '$name\'s birthday';
  }

  @override
  String countdownBirthdayTurns(String name, int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$name turns $age',
      one: '$name turns 1',
    );
    return '$_temp0';
  }

  @override
  String countdownHomecoming(String name) {
    return '$name comes home';
  }

  @override
  String countdownSleeps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more sleeps',
      one: '1 more sleep',
    );
    return '$_temp0';
  }

  @override
  String countdownDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more days',
      one: '1 more day',
    );
    return '$_temp0';
  }

  @override
  String countdownInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get countdownTomorrow => 'Tomorrow!';

  @override
  String get countdownToday => 'Today!';

  @override
  String get kidLookingForward => 'Looking forward to';

  @override
  String get todayLookingForward => 'Looking forward';

  @override
  String get eventIconNone => 'No picture';

  @override
  String get eventIconLabel => 'Picture';

  @override
  String get eventCountdownTitle => 'We are looking forward to it';

  @override
  String get eventCountdownHelp =>
      'Counts down on the wall and on the children\'s tablet.';

  @override
  String get eventTraditionTitle => 'Family tradition';

  @override
  String get eventTraditionHelp =>
      'Something the family does again and again. Always on the wall, with a ribbon.';

  @override
  String get eventTraditionMeal => 'With a meal';

  @override
  String get eventTraditionMealHint => 'e.g. pizza';

  @override
  String get calendarNewTradition => 'New tradition';

  @override
  String get traditionStartersHelp =>
      'Pick one to start with. You can change the day and time next.';

  @override
  String get traditionStarterGameNight => 'Game night';

  @override
  String get traditionStarterPizzaFriday => 'Pizza Friday';

  @override
  String get traditionStarterFilmNight => 'Film night';

  @override
  String get traditionStarterSundayBreakfast => 'Sunday breakfast';

  @override
  String get traditionStarterStoryTime => 'Story time';

  @override
  String get traditionStarterDayOut => 'Day out';

  @override
  String get traditionStarterPizzaMeal => 'Pizza';

  @override
  String get traditionStarterOwn => 'Your own tradition';

  @override
  String get traditionStarterOwnHelp => 'You choose the name, picture and day.';

  @override
  String traditionStarterWhen(String weekday, String time) {
    return 'Every $weekday, $time';
  }

  @override
  String traditionStarterWhenAllDay(String weekday) {
    return 'Every $weekday, all day';
  }

  @override
  String get eventIcon_cake => 'Birthday cake';

  @override
  String get eventIcon_game_die => 'Game';

  @override
  String get eventIcon_pizza => 'Pizza';

  @override
  String get eventIcon_cinema => 'Film';

  @override
  String get eventIcon_croissant => 'Breakfast';

  @override
  String get eventIcon_book => 'Reading';

  @override
  String get eventIcon_hiking => 'Walk';

  @override
  String get eventIcon_beach => 'Holidays';

  @override
  String get eventIcon_plane => 'Trip';

  @override
  String get eventIcon_zoo => 'Zoo';

  @override
  String get eventIcon_tent => 'Camping';

  @override
  String get eventIcon_football => 'Sport';

  @override
  String get eventIcon_music => 'Music';

  @override
  String get eventIcon_gift => 'Present';

  @override
  String get eventIcon_balloon => 'Party';

  @override
  String get eventIcon_backpack => 'School';

  @override
  String get eventIcon_swim => 'Swimming';

  @override
  String get eventIcon_ferris => 'Fair';

  @override
  String get eventIcon_house => 'Home';

  @override
  String get eventIcon_star => 'Special';

  @override
  String get kidWishTitle => 'Your meal wish';

  @override
  String get kidWishInvite => 'What would you like to eat this week?';

  @override
  String kidWishWaiting(String title) {
    return 'You wished for $title. A grown-up will find a day.';
  }

  @override
  String kidWishPlanned(String title, String day) {
    return 'Your wish $title is on $day!';
  }

  @override
  String get kidWishMake => 'Wish';

  @override
  String get kidWishChange => 'Change';

  @override
  String get kidWishSent => 'Your wish is on its way.';

  @override
  String get wishPickerTitle => 'What would you like to eat?';

  @override
  String get wishPickerOwn => 'Something else';

  @override
  String get wishPickerOwnHint => 'e.g. pancakes';

  @override
  String get wishPickerSend => 'Wish for this';

  @override
  String get wishPickerRecipes => 'Our recipes';

  @override
  String get wishPickerSearch => 'Find a recipe';

  @override
  String get wishPickerNoMatch => 'No recipe by that name. Wish for it below.';

  @override
  String get wishPickerIcon => 'Pick a picture';

  @override
  String get mealsWishEarlier => 'from last week';

  @override
  String get mealsWishOlder => 'from a few weeks ago';

  @override
  String get mealsWishMine => 'Make a wish';

  @override
  String get mealsWishMineChange => 'Change my wish';

  @override
  String get mealIcon_pizza => 'Pizza';

  @override
  String get mealIcon_pasta => 'Pasta';

  @override
  String get mealIcon_pancakes => 'Pancakes';

  @override
  String get mealIcon_waffle => 'Waffles';

  @override
  String get mealIcon_burger => 'Burger';

  @override
  String get mealIcon_fries => 'Chips';

  @override
  String get mealIcon_hotdog => 'Hot dog';

  @override
  String get mealIcon_sandwich => 'Sandwich';

  @override
  String get mealIcon_taco => 'Tacos';

  @override
  String get mealIcon_burrito => 'Wrap';

  @override
  String get mealIcon_kebab => 'Kebab';

  @override
  String get mealIcon_curry => 'Curry';

  @override
  String get mealIcon_rice => 'Rice';

  @override
  String get mealIcon_noodles => 'Noodle soup';

  @override
  String get mealIcon_soup => 'Soup or stew';

  @override
  String get mealIcon_paella => 'Paella';

  @override
  String get mealIcon_salad => 'Salad';

  @override
  String get mealIcon_sushi => 'Sushi';

  @override
  String get mealIcon_dumpling => 'Dumplings';

  @override
  String get mealIcon_chicken => 'Chicken';

  @override
  String get mealIcon_fish => 'Fish';

  @override
  String get mealIcon_meat => 'Meat';

  @override
  String get mealIcon_egg => 'Eggs';

  @override
  String get mealIcon_falafel => 'Falafel';

  @override
  String get mealIcon_fondue => 'Fondue';

  @override
  String get mealIcon_pie => 'Pie or quiche';

  @override
  String get mealIcon_cake => 'Cake';

  @override
  String get mealIcon_ice_cream => 'Ice cream';

  @override
  String get mealIcon_bread => 'Bread';

  @override
  String get mealIcon_pretzel => 'Pretzel';

  @override
  String get mealIcon_croissant => 'Croissant';

  @override
  String get mealIcon_potato => 'Potatoes';

  @override
  String get mealIcon_cheese => 'Cheese';

  @override
  String get mealIcon_porridge => 'Porridge';

  @override
  String get mealIcon_vegetables => 'Vegetables';

  @override
  String get mealsWishesTray => 'Wishes';

  @override
  String mealsWishChip(String name, String title) {
    return '$name: $title';
  }

  @override
  String get mealsWishPlan => 'Put on the plan';

  @override
  String get mealsWishRemove => 'Remove the wish';

  @override
  String mealsWishedBy(String name) {
    return '$name\'s wish';
  }

  @override
  String mealsTraditionSuggestion(String meal, String tradition) {
    return 'Plan $meal ($tradition)';
  }

  @override
  String get tableQuestionTitle => 'Question at the table';

  @override
  String get tableQuestionNext => 'Another question';

  @override
  String get tableQuestionAnswer => 'Show the answer';

  @override
  String tableQuestionFrom(String name) {
    return 'Question from $name';
  }

  @override
  String get tableQuestionsManage => 'Our questions';

  @override
  String get tableQuestionAdd => 'Add a question';

  @override
  String get tableQuestionAddHint => 'What would you like to ask at the table?';

  @override
  String get tableQuestionHide => 'Don\'t ask this one again';

  @override
  String get tableQuestionRemove => 'Remove the question';

  @override
  String get tableQuestionsHidden => 'Questions we left out';

  @override
  String get tableQuestionShowAgain => 'Ask again';

  @override
  String get kidWishWithdraw => 'Take back';

  @override
  String get kidWishAnother => 'Wish for another';

  @override
  String get mealsWishSlotFree => 'Nothing planned yet';

  @override
  String get mealsWishReplaceTitle => 'Replace the meal?';

  @override
  String mealsWishReplaceBody(
    String dish,
    String slot,
    String day,
    String wish,
  ) {
    return 'Already planned: $dish ($slot, $day). Plan the wish $wish instead? The cook, the time and the servings stay.';
  }

  @override
  String get mealsWishReplace => 'Replace';

  @override
  String get errSlotTaken => 'Something is already planned for that meal.';

  @override
  String get tableQuestionDismiss => 'Hide for this meal';

  @override
  String get weekReviewTitle => 'Our week';

  @override
  String get weekReviewOpen => 'Look back at our week';

  @override
  String get weekReviewTogether => 'What we did together';

  @override
  String weekReviewChores(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chores done',
      one: '1 chore done',
      zero: 'A week to catch our breath',
    );
    return '$_temp0';
  }

  @override
  String get weekReviewMoments => 'Everyone had a moment';

  @override
  String get weekReviewMeals => 'Yum';

  @override
  String get weekReviewNewRecipe => 'new';

  @override
  String get weekReviewTraditions => 'Our traditions';

  @override
  String get weekReviewNext => 'Next week we look forward to';

  @override
  String get weekReviewCalmAhead => 'A calm week ahead.';

  @override
  String weekReviewCardOf(int index, int count) {
    return 'Card $index of $count';
  }

  @override
  String get weekReviewNextCard => 'Next card';

  @override
  String get weekReviewPreviousCard => 'Previous card';

  @override
  String weekHighlightBadge(String title) {
    return 'New badge: $title';
  }

  @override
  String weekHighlightStreak(String title) {
    return '$title, every day';
  }

  @override
  String get weekHighlightAllDone => 'had a day with everything ticked off';

  @override
  String weekHighlightReward(String title) {
    return 'Reward: $title';
  }

  @override
  String weekHighlightWish(String title) {
    return 'Wish on the table: $title';
  }

  @override
  String weekHighlightCooked(String title) {
    return 'cooked $title';
  }

  @override
  String weekHighlightAttended(String title) {
    return 'was there for $title';
  }

  @override
  String get weekHighlightHelped => 'helped with the chores';

  @override
  String get weekHighlightHere => 'was part of our week';

  @override
  String settingsOwnTitle(String name) {
    return 'Settings for $name';
  }

  @override
  String get settingsGroupPersonalTitle => 'Personal';

  @override
  String get settingsGroupPersonalSubtitle =>
      'Wusel, sounds and reminders for you';

  @override
  String get settingsGroupFamilyTitle => 'Family';

  @override
  String get settingsGroupFamilySubtitle =>
      'Name, time zone, members and the usual week';

  @override
  String get settingsGroupTasksTitle => 'Tasks & rewards';

  @override
  String get settingsGroupTasksSubtitle =>
      'Points, streak jokers and approvals';

  @override
  String get settingsGroupCalendarTitle => 'Calendar & school';

  @override
  String get settingsGroupCalendarSubtitle =>
      'Events, timetable changes and sharing';

  @override
  String get settingsGroupMealsTitle => 'Meals';

  @override
  String get settingsGroupMealsSubtitle =>
      'Warm meals, meal wishes and care lunch';

  @override
  String get settingsGroupRitualsTitle => 'Rituals';

  @override
  String get settingsGroupRitualsSubtitle =>
      'Question at the table, our week, countdowns';

  @override
  String get settingsGroupCelebrationsTitle => 'Celebrations & seasons';

  @override
  String get settingsGroupCelebrationsSubtitle =>
      'Advent, Easter, New Year, birthdays and the seasons';

  @override
  String get settingsGroupKitchenTitle => 'Kitchen wall';

  @override
  String get settingsGroupKitchenSubtitle =>
      'Names, the change of week and the parts of the day';

  @override
  String get settingsGroupDevicesTitle => 'Devices';

  @override
  String get settingsGroupDevicesSubtitle =>
      'This device and every device of the family';

  @override
  String get settingsGroupAccountTitle => 'Account & security';

  @override
  String get settingsGroupAccountSubtitle =>
      'Sign-in, password, two-factor, leaving the family';

  @override
  String get settingsGroupServerTitle => 'Server';

  @override
  String get settingsGroupServerSubtitle =>
      'Address, QR code and changing the server';

  @override
  String get settingsGroupHelpTitle => 'Help & about';

  @override
  String get settingsGroupHelpSubtitle => 'Getting started, versions, licenses';

  @override
  String get settingsSectionWusel => 'Wusel';

  @override
  String get settingsSectionSound => 'Sound';

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsSectionTableQuestion => 'Question at the table';

  @override
  String get settingsSectionWeekReview => 'Week review';

  @override
  String get settingsSectionCountdowns => 'Countdowns';

  @override
  String get settingsSectionHolidays => 'Holiday celebrations';

  @override
  String get settingsSectionThroughYear => 'Through the year';

  @override
  String get settingsSectionAllDevices => 'All devices';

  @override
  String get settingsSectionLeave => 'Leave or delete';

  @override
  String get settingsSectionOther => 'Other settings';

  @override
  String get familyProfileTitle => 'Family profile';

  @override
  String get settingsMembersSubtitle =>
      'Names, colours, roles and the order on the wall';

  @override
  String get calendarMonth => 'Month';

  @override
  String get calendarWeekNumberShort => 'Wk';

  @override
  String calendarWeekNumberLabel(int week) {
    return 'Week $week';
  }

  @override
  String calendarMonthMore(int count) {
    return '+$count';
  }

  @override
  String calendarMonthOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more appointments',
      one: '1 more appointment',
    );
    return '$_temp0';
  }

  @override
  String calendarMonthFerien(String name) {
    return 'School holidays: $name';
  }

  @override
  String get calendarMonthOpenDay => 'Open the day';
}

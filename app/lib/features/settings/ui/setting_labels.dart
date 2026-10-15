import 'package:wuselwall/core/l10n/l10n.dart';

/// Title and one-line explanation of a catalogue setting (specs/21, the Context column).
typedef SettingText = ({String title, String help});

/// The texts of [key]. An unknown key shows its own name, so a new catalogue entry is
/// visible (and visibly unlabelled) before the app has its strings.
SettingText settingText(AppLocalizations l10n, String key) => switch (key) {
  'household.region' => (
    title: l10n.regionSettingTitle,
    help: l10n.regionSettingHelp,
  ),
  'board.member_label' => (
    title: l10n.settingBoardMemberLabelTitle,
    help: l10n.settingBoardMemberLabelHelp,
  ),
  'tasks.points.duty_default' => (
    title: l10n.settingTasksDutyPointsTitle,
    help: l10n.settingTasksDutyPointsHelp,
  ),
  'tasks.points.bonus_default' => (
    title: l10n.settingTasksBonusPointsTitle,
    help: l10n.settingTasksBonusPointsHelp,
  ),
  'tasks.kind_default' => (
    title: l10n.settingTasksKindTitle,
    help: l10n.settingTasksKindHelp,
  ),
  'tasks.verification_default' => (
    title: l10n.settingTasksVerificationTitle,
    help: l10n.settingTasksVerificationHelp,
  ),
  'tasks.jokers_per_month' => (
    title: l10n.settingTasksJokersTitle,
    help: l10n.settingTasksJokersHelp,
  ),
  'tasks.reward_approval_default' => (
    title: l10n.settingTasksRewardApprovalTitle,
    help: l10n.settingTasksRewardApprovalHelp,
  ),
  'calendar.members_edit_own_events' => (
    title: l10n.settingCalendarMembersEditTitle,
    help: l10n.settingCalendarMembersEditHelp,
  ),
  'calendar.key_default' => (
    title: l10n.settingCalendarKeyDefaultTitle,
    help: l10n.settingCalendarKeyDefaultHelp,
  ),
  'school.members_report_changes' => (
    title: l10n.settingSchoolReportTitle,
    help: l10n.settingSchoolReportHelp,
  ),
  'school.equipment_hint' => (
    title: l10n.settingSchoolEquipmentTitle,
    help: l10n.settingSchoolEquipmentHelp,
  ),
  'meals.warm_meal.school_day' => (
    title: l10n.settingMealsSchoolDayTitle,
    help: l10n.settingMealsSchoolDayHelp,
  ),
  'meals.warm_meal.free_day' => (
    title: l10n.settingMealsFreeDayTitle,
    help: l10n.settingMealsFreeDayHelp,
  ),
  'meals.away_means_not_eating' => (
    title: l10n.settingMealsAwayTitle,
    help: l10n.settingMealsAwayHelp,
  ),
  'meals.care_lunch_cutoff' => (
    title: l10n.settingMealsCareCutoffTitle,
    help: l10n.settingMealsCareCutoffHelp,
  ),
  'board.rollover' => (
    title: l10n.settingBoardRolloverTitle,
    help: l10n.settingBoardRolloverHelp,
  ),
  'board.day_parts' => (
    title: l10n.settingBoardDayPartsTitle,
    help: l10n.settingBoardDayPartsHelp,
  ),
  'device.night_hours' => (
    title: l10n.settingDeviceNightHoursTitle,
    help: l10n.settingDeviceNightHoursHelp,
  ),
  'device.idle_revert_seconds' => (
    title: l10n.settingDeviceIdleRevertTitle,
    help: l10n.settingDeviceIdleRevertHelp,
  ),
  'member.completion_sound' => (
    title: l10n.settingMemberCompletionSoundTitle,
    help: l10n.settingMemberCompletionSoundHelp,
  ),
  'calendar.tentative_nudge' => (
    title: l10n.settingCalendarTentativeTitle,
    help: l10n.settingCalendarTentativeHelp,
  ),
  'notify.morning_summary' => (
    title: l10n.settingNotifyMorningTitle,
    help: l10n.settingNotifyMorningHelp,
  ),
  'notify.event_reminder' => (
    title: l10n.settingNotifyEventReminderTitle,
    help: l10n.settingNotifyEventReminderHelp,
  ),
  'notify.task_verified' => (
    title: l10n.settingNotifyTaskVerifiedTitle,
    help: l10n.settingNotifyTaskVerifiedHelp,
  ),
  'notify.redemption_request' => (
    title: l10n.settingNotifyRedemptionTitle,
    help: l10n.settingNotifyRedemptionHelp,
  ),
  _ => (title: key, help: ''),
};

/// The label of an enum value (`values` in the catalogue).
String settingValueLabel(AppLocalizations l10n, String value) =>
    switch (value) {
      'name' => l10n.settingValueName,
      'initial' => l10n.settingValueInitial,
      'duty' => l10n.settingValueDuty,
      'bonus' => l10n.settingValueBonus,
      'required' => l10n.settingValueRequired,
      'self_serve' => l10n.settingValueSelfServe,
      'whole_family' => l10n.settingValueWholeFamily,
      'all' => l10n.settingValueAll,
      'none' => l10n.settingValueNone,
      'lunch' => l10n.settingValueLunch,
      'dinner' => l10n.settingValueDinner,
      _ => value,
    };

/// An integer with its unit: points, minutes or seconds where the setting has one.
String settingIntegerLabel(AppLocalizations l10n, String key, int n) =>
    switch (key) {
      'tasks.points.duty_default' ||
      'tasks.points.bonus_default' => l10n.settingUnitPoints(n),
      'notify.event_reminder' => l10n.settingUnitMinutes(n),
      'device.idle_revert_seconds' => l10n.settingUnitSeconds(n),
      _ => '$n',
    };

import 'package:flutter/material.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';

/// How a group looks on the top page and where its page lives.
extension SettingsGroupPresentation on SettingsGroup {
  String get route => switch (this) {
    SettingsGroup.personal => Routes.settingsPersonal,
    SettingsGroup.family => Routes.settingsFamily,
    SettingsGroup.tasks => Routes.settingsTasks,
    SettingsGroup.calendar => Routes.settingsCalendar,
    SettingsGroup.meals => Routes.settingsMeals,
    SettingsGroup.rituals => Routes.settingsRituals,
    SettingsGroup.celebrations => Routes.settingsCelebrations,
    SettingsGroup.kitchen => Routes.settingsKitchen,
    SettingsGroup.devices => Routes.settingsDevices,
    SettingsGroup.account => Routes.settingsAccount,
    SettingsGroup.server => Routes.settingsServer,
    SettingsGroup.help => Routes.settingsHelp,
  };

  IconData get icon => switch (this) {
    SettingsGroup.personal => Icons.person_outline,
    SettingsGroup.family => Icons.family_restroom_outlined,
    SettingsGroup.tasks => Icons.task_alt,
    SettingsGroup.calendar => Icons.calendar_month_outlined,
    SettingsGroup.meals => Icons.restaurant_outlined,
    SettingsGroup.rituals => Icons.forum_outlined,
    SettingsGroup.celebrations => Icons.celebration_outlined,
    SettingsGroup.kitchen => Icons.tv_outlined,
    SettingsGroup.devices => Icons.devices_outlined,
    SettingsGroup.account => Icons.manage_accounts_outlined,
    SettingsGroup.server => Icons.dns_outlined,
    SettingsGroup.help => Icons.help_outline,
  };

  String title(AppLocalizations l10n) => switch (this) {
    SettingsGroup.personal => l10n.settingsGroupPersonalTitle,
    SettingsGroup.family => l10n.settingsGroupFamilyTitle,
    SettingsGroup.tasks => l10n.settingsGroupTasksTitle,
    SettingsGroup.calendar => l10n.settingsGroupCalendarTitle,
    SettingsGroup.meals => l10n.settingsGroupMealsTitle,
    SettingsGroup.rituals => l10n.settingsGroupRitualsTitle,
    SettingsGroup.celebrations => l10n.settingsGroupCelebrationsTitle,
    SettingsGroup.kitchen => l10n.settingsGroupKitchenTitle,
    SettingsGroup.devices => l10n.settingsGroupDevicesTitle,
    SettingsGroup.account => l10n.settingsGroupAccountTitle,
    SettingsGroup.server => l10n.settingsGroupServerTitle,
    SettingsGroup.help => l10n.settingsGroupHelpTitle,
  };

  String subtitle(AppLocalizations l10n) => switch (this) {
    SettingsGroup.personal => l10n.settingsGroupPersonalSubtitle,
    SettingsGroup.family => l10n.settingsGroupFamilySubtitle,
    SettingsGroup.tasks => l10n.settingsGroupTasksSubtitle,
    SettingsGroup.calendar => l10n.settingsGroupCalendarSubtitle,
    SettingsGroup.meals => l10n.settingsGroupMealsSubtitle,
    SettingsGroup.rituals => l10n.settingsGroupRitualsSubtitle,
    SettingsGroup.celebrations => l10n.settingsGroupCelebrationsSubtitle,
    SettingsGroup.kitchen => l10n.settingsGroupKitchenSubtitle,
    SettingsGroup.devices => l10n.settingsGroupDevicesSubtitle,
    SettingsGroup.account => l10n.settingsGroupAccountSubtitle,
    SettingsGroup.server => l10n.settingsGroupServerSubtitle,
    SettingsGroup.help => l10n.settingsGroupHelpSubtitle,
  };
}

/// The heading of a section inside a group page; null for a section without one.
String? settingsSectionTitle(AppLocalizations l10n, SettingsSectionId id) =>
    switch (id) {
      SettingsSectionId.none => null,
      SettingsSectionId.wusel => l10n.settingsSectionWusel,
      SettingsSectionId.sound => l10n.settingsSectionSound,
      SettingsSectionId.notifications => l10n.settingsSectionNotifications,
      SettingsSectionId.tableQuestion => l10n.settingsSectionTableQuestion,
      SettingsSectionId.weekReview => l10n.settingsSectionWeekReview,
      SettingsSectionId.countdowns => l10n.settingsSectionCountdowns,
      SettingsSectionId.holidays => l10n.settingsSectionHolidays,
      SettingsSectionId.throughTheYear => l10n.settingsSectionThroughYear,
      SettingsSectionId.connections => l10n.settingsSectionConnect,
      SettingsSectionId.thisDevice => l10n.settingsSectionThisDevice,
      SettingsSectionId.allDevices => l10n.settingsSectionAllDevices,
      SettingsSectionId.signIn => l10n.signInMethodsTitle,
      SettingsSectionId.security => l10n.settingsSecurity,
      SettingsSectionId.leave => l10n.settingsSectionLeave,
      SettingsSectionId.other => l10n.settingsSectionOther,
    };

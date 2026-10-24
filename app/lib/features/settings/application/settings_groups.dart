import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

/// Einstellungen is a short page of groups; each group opens its own page of sections
/// (specs/21, "Where the settings live"). This file is the map: which group holds which
/// catalogue key and which other row, and what a device shows of it in Basic and Advanced.
/// The pages only draw what this says, so a group with nothing to show has no tile.
enum SettingsGroup {
  personal,
  family,
  tasks,
  calendar,
  meals,
  rituals,
  celebrations,
  kitchen,
  devices,
  account,
  server,
  help,
}

/// The headings inside a group page. [none] is a section without a heading.
enum SettingsSectionId {
  none,
  wusel,
  sound,
  notifications,
  tableQuestion,
  weekReview,
  countdowns,
  holidays,
  throughTheYear,
  connections,
  thisDevice,
  allDevices,
  signIn,
  security,
  leave,
  other,
}

/// A row of a group page that is not a catalogue setting: a link to a page, a tile with
/// its own control, or a list.
enum SettingsTile {
  familyProfile,
  members,
  baselines,
  reminders,
  familyQuestions,
  language,
  appearance,
  devices,
  feedTokens,
  externalCalendars,
  signInMethods,
  security,
  leaveFamily,
  deleteAccount,
  server,
  gettingStarted,
  versions,
  licences;

  /// Whether Basic shows it. Hiding changes nothing it controls.
  bool get basic => switch (this) {
    feedTokens ||
    externalCalendars ||
    signInMethods ||
    security ||
    leaveFamily ||
    server => false,
    _ => true,
  };

  bool visible(SettingsEnv env) => switch (this) {
    reminders => env.personalPhone && env.notificationsAvailable,
    // The way to the family's own questions belongs to the question setting.
    familyQuestions => env.resolve('rituals.table_question') != null,
    signInMethods ||
    security ||
    leaveFamily ||
    deleteAccount => env.personalPhone,
    server => env.hasServer,
    _ => true,
  };
}

sealed class SettingsItem {
  const SettingsItem();
}

/// A catalogue setting, drawn as a [SettingRow].
final class SettingKey extends SettingsItem {
  const SettingKey(this.key);

  final String key;
}

final class SettingTileItem extends SettingsItem {
  const SettingTileItem(this.tile);

  final SettingsTile tile;
}

class SettingsSection {
  const SettingsSection(this.id, this.items, {this.gate});

  final SettingsSectionId id;
  final List<SettingsItem> items;

  /// Further condition on the whole section, such as "on a personal phone".
  final bool Function(SettingsEnv env)? gate;
}

bool _personalPhone(SettingsEnv env) => env.personalPhone;

const _device = SettingsSectionId.thisDevice;

/// The groups in the order of the top page, and for each the sections of its page.
const settingsGroupSections = <SettingsGroup, List<SettingsSection>>{
  SettingsGroup.personal: [
    SettingsSection(SettingsSectionId.wusel, [
      SettingKey('member.wusel'),
      SettingKey('member.wusel_outfit'),
    ]),
    SettingsSection(SettingsSectionId.sound, [
      SettingKey('member.completion_sound'),
    ]),
    SettingsSection(SettingsSectionId.notifications, [
      SettingTileItem(SettingsTile.reminders),
      SettingKey('notify.morning_summary'),
      SettingKey('notify.event_reminder'),
      SettingKey('notify.packing_reminder'),
      SettingKey('calendar.tentative_nudge'),
    ], gate: _personalPhone),
  ],
  SettingsGroup.family: [
    SettingsSection(SettingsSectionId.none, [
      SettingTileItem(SettingsTile.familyProfile),
      SettingKey('household.region'),
      SettingTileItem(SettingsTile.members),
      SettingTileItem(SettingsTile.baselines),
    ]),
  ],
  SettingsGroup.tasks: [
    SettingsSection(SettingsSectionId.none, [
      SettingKey('tasks.points.duty_default'),
      SettingKey('tasks.points.bonus_default'),
      SettingKey('tasks.kind_default'),
      SettingKey('tasks.verification_default'),
      SettingKey('tasks.jokers_per_month'),
      SettingKey('tasks.reward_approval_default'),
    ]),
  ],
  SettingsGroup.calendar: [
    SettingsSection(SettingsSectionId.none, [
      SettingKey('calendar.members_edit_own_events'),
      SettingKey('calendar.key_default'),
      SettingKey('school.members_report_changes'),
      SettingKey('school.equipment_hint'),
    ]),
    SettingsSection(SettingsSectionId.connections, [
      SettingTileItem(SettingsTile.feedTokens),
      SettingTileItem(SettingsTile.externalCalendars),
    ]),
  ],
  SettingsGroup.meals: [
    SettingsSection(SettingsSectionId.none, [
      SettingKey('meals.warm_meal.school_day'),
      SettingKey('meals.warm_meal.free_day'),
      SettingKey('meals.away_means_not_eating'),
      SettingKey('meals.care_lunch_cutoff'),
      SettingKey('meals.wishes'),
      SettingKey('meals.wishes_per_week'),
    ]),
  ],
  SettingsGroup.rituals: [
    SettingsSection(SettingsSectionId.tableQuestion, [
      SettingKey('rituals.table_question'),
      SettingKey('rituals.table_question.lunch'),
      SettingKey('rituals.table_question.dinner'),
      SettingKey('rituals.table_question_deck'),
      SettingTileItem(SettingsTile.familyQuestions),
    ]),
    SettingsSection(SettingsSectionId.weekReview, [
      SettingKey('rituals.week_review'),
    ]),
    SettingsSection(SettingsSectionId.countdowns, [
      SettingKey('rituals.countdown_days'),
      SettingKey('rituals.countdown_return'),
    ]),
  ],
  SettingsGroup.celebrations: [
    SettingsSection(SettingsSectionId.holidays, [
      SettingKey('ambience.advent'),
      SettingKey('ambience.easter_western'),
      SettingKey('ambience.easter_orthodox'),
      SettingKey('ambience.new_year'),
    ]),
    SettingsSection(SettingsSectionId.throughTheYear, [
      SettingKey('ambience.season'),
      SettingKey('ambience.ferien'),
      SettingKey('ambience.birthdays'),
    ]),
  ],
  SettingsGroup.kitchen: [
    SettingsSection(SettingsSectionId.none, [
      SettingKey('board.member_label'),
      SettingKey('board.rollover'),
      SettingKey('board.day_parts'),
    ]),
  ],
  SettingsGroup.devices: [
    SettingsSection(_device, [
      SettingTileItem(SettingsTile.language),
      SettingTileItem(SettingsTile.appearance),
      SettingKey('device.night_hours'),
      SettingKey('device.sky'),
      SettingKey('device.sounds'),
      SettingKey('device.wusel'),
      SettingKey('device.pixel_shift'),
    ]),
    SettingsSection(SettingsSectionId.allDevices, [
      SettingTileItem(SettingsTile.devices),
    ]),
  ],
  SettingsGroup.account: [
    SettingsSection(SettingsSectionId.signIn, [
      SettingTileItem(SettingsTile.signInMethods),
    ]),
    SettingsSection(SettingsSectionId.security, [
      SettingTileItem(SettingsTile.security),
    ]),
    SettingsSection(SettingsSectionId.leave, [
      SettingTileItem(SettingsTile.leaveFamily),
      SettingTileItem(SettingsTile.deleteAccount),
    ]),
  ],
  SettingsGroup.server: [
    SettingsSection(SettingsSectionId.none, [
      SettingTileItem(SettingsTile.server),
    ]),
  ],
  SettingsGroup.help: [
    SettingsSection(SettingsSectionId.none, [
      SettingTileItem(SettingsTile.gettingStarted),
      SettingTileItem(SettingsTile.versions),
      SettingTileItem(SettingsTile.licences),
    ]),
  ],
};

/// In the catalogue but read by nothing yet, so not offered: the idle return is fixed at
/// 60 s, and the two notifications wait for #143. They come back here once something
/// applies them.
const unusedSettingKeys = {
  'device.idle_revert_seconds',
  'notify.task_verified',
  'notify.redemption_request',
};

/// The settings Basic shows: what most families decide once. Everything else, and any
/// setting a newer catalogue adds, waits under Advanced and applies all the same.
const basicSettingKeys = {
  'household.region',
  'tasks.jokers_per_month',
  'tasks.reward_approval_default',
  'calendar.members_edit_own_events',
  'meals.warm_meal.school_day',
  'meals.warm_meal.free_day',
  'device.night_hours',
  'member.completion_sound',
  'notify.morning_summary',
  'notify.event_reminder',
  // A lighter day (specs/21): switching Wusel off must be easy to find.
  'member.wusel',
  'rituals.table_question',
  'meals.wishes',
  'rituals.week_review',
};

/// Every catalogue key the groups place, in page order.
Iterable<String> get placedSettingKeys sync* {
  for (final sections in settingsGroupSections.values) {
    for (final section in sections) {
      for (final item in section.items) {
        if (item case SettingKey(:final key)) yield key;
      }
    }
  }
}

/// The group a setting this app does not know belongs to, judging by its key's prefix;
/// null when the prefix says nothing (those wait in "Other" under Help and about).
SettingsGroup? groupForUnknownKey(String key) {
  final prefix = key.split('.').first;
  return switch (prefix) {
    'member' || 'notify' => SettingsGroup.personal,
    'household' => SettingsGroup.family,
    'tasks' => SettingsGroup.tasks,
    'calendar' || 'school' => SettingsGroup.calendar,
    'meals' => SettingsGroup.meals,
    'rituals' => SettingsGroup.rituals,
    'ambience' => SettingsGroup.celebrations,
    'board' => SettingsGroup.kitchen,
    'device' => SettingsGroup.devices,
    _ => null,
  };
}

/// What the groups need to know about this device and the moment: the view, who is
/// acting, what the device is, and the catalogue the server sent.
class SettingsEnv {
  const SettingsEnv({
    required this.entries,
    this.advanced = false,
    this.deviceClass,
    this.deviceId,
    this.acting,
    this.notificationsAvailable = false,
    this.hasServer = false,
  });

  final List<SettingEntry> entries;
  final bool advanced;
  final DeviceClass? deviceClass;
  final String? deviceId;
  final String? acting;
  final bool notificationsAvailable;
  final bool hasServer;

  bool get personalPhone => deviceClass == DeviceClass.personal;

  SettingsEnv copyWith({bool? advanced}) => SettingsEnv(
    entries: entries,
    advanced: advanced ?? this.advanced,
    deviceClass: deviceClass,
    deviceId: deviceId,
    acting: acting,
    notificationsAvailable: notificationsAvailable,
    hasServer: hasServer,
  );

  /// The definition of [key] in the catalogue, or null on a server without it.
  SettingEntry? resolve(String key) => resolveSetting(entries, key);

  /// Whether the page draws a row for [key]: the server has it, this view shows it, and
  /// the target it needs exists (a member's setting needs someone acting, a device's
  /// setting a device).
  bool showsKey(String key) {
    if (unusedSettingKeys.contains(key)) return false;
    final definition = resolve(key);
    if (definition == null) return false;
    if (!advanced && !basicSettingKeys.contains(key)) return false;
    return switch (definition.scope) {
      SettingScope.member => acting != null,
      SettingScope.device => deviceId != null,
      SettingScope.household => true,
    };
  }

  /// Catalogue keys no group places and the app does not hide: a newer server's
  /// settings. They show under Advanced.
  List<String> get unplacedKeys {
    final placed = placedSettingKeys.toSet();
    return [
      for (final key in {for (final e in entries) e.key})
        if (!placed.contains(key) && !unusedSettingKeys.contains(key)) key,
    ];
  }
}

/// A section as one device draws it: the headings and rows left after the view, the
/// server and the device have had their say.
class VisibleSection {
  const VisibleSection(this.id, this.items);

  final SettingsSectionId id;
  final List<SettingsItem> items;
}

/// The sections of [group] for [env], without any that would be empty. Unknown settings
/// of a newer server join the end of the group their prefix names (Advanced only), or
/// Help and about's "Other".
List<VisibleSection> visibleSections(SettingsGroup group, SettingsEnv env) {
  if (group == SettingsGroup.personal && env.acting == null) return const [];
  final result = <VisibleSection>[];
  for (final section in settingsGroupSections[group]!) {
    if (section.gate case final gate? when !gate(env)) continue;
    final items = [
      for (final item in section.items)
        if (switch (item) {
          SettingKey(:final key) => env.showsKey(key),
          SettingTileItem(:final tile) =>
            (env.advanced || tile.basic) && tile.visible(env),
        })
          item,
    ];
    if (items.isNotEmpty) result.add(VisibleSection(section.id, items));
  }
  if (env.advanced) {
    final other = [
      for (final key in env.unplacedKeys)
        if ((groupForUnknownKey(key) ?? SettingsGroup.help) == group &&
            env.showsKey(key))
          SettingKey(key),
    ];
    if (other.isNotEmpty) {
      result.add(VisibleSection(SettingsSectionId.other, other));
    }
  }
  return result;
}

/// How many rows [group] shows in [env]; zero hides the group's tile.
int visibleItemCount(SettingsGroup group, SettingsEnv env) =>
    [for (final section in visibleSections(group, env)) ...section.items]
        .length;

/// The groups the top page lists for [env], in order.
List<SettingsGroup> visibleGroups(SettingsEnv env) => [
  for (final group in SettingsGroup.values)
    if (visibleItemCount(group, env) > 0) group,
];

/// Whether Advanced would show more than [env] does, here in [group] (or, with a null
/// [group], on the top page): the cue for the "more under Advanced" hint.
bool hasHiddenSettings(SettingsEnv env, {SettingsGroup? group}) {
  if (env.advanced) return false;
  final all = env.copyWith(advanced: true);
  final groups = group == null ? SettingsGroup.values : [group];
  return groups.any((g) => visibleItemCount(g, all) > visibleItemCount(g, env));
}

/// The environment of this device now. The catalogue is empty while it loads or when the
/// server did not answer; a group that only holds settings then has no tile, the others
/// stay.
final settingsEnvProvider = Provider.autoDispose<SettingsEnv>((ref) {
  final device = ref.watch(deviceProvider).value;
  return SettingsEnv(
    entries: ref.watch(householdSettingsProvider).value ?? const [],
    advanced: ref.watch(showAdvancedSettingsProvider),
    deviceClass: device?.deviceClass,
    deviceId: device?.deviceId,
    acting: ref.watch(actingProfileProvider),
    notificationsAvailable: ref.watch(notificationSchedulerProvider).available,
    hasServer: ref.watch(appConfigProvider).server != null,
  );
});

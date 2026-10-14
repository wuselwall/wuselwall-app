import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/settings/ui/setting_controls.dart';

/// The household's defaults (specs/21), grouped by what they tune. Household and device
/// settings are guardian actions; a member's own settings are not.
class HouseholdSettingsPage extends ConsumerWidget {
  const HouseholdSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(householdSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.householdSettingsTitle),
        leading: BackButton(onPressed: () => context.go(Routes.settings)),
      ),
      body: AsyncValueView<List<SettingEntry>>(
        value: settings,
        onRetry: () => ref.invalidate(householdSettingsProvider),
        data: (entries) => _SettingsList(entries: entries),
      ),
    );
  }
}

class _SectionSpec {
  const _SectionSpec(this.title, this.keys, {this.personal = false});

  final String title;
  final List<String> keys;

  /// Settings of the person at the device; nothing to show until someone is chosen.
  final bool personal;
}

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.entries});

  final List<SettingEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final deviceId = ref.watch(deviceProvider).value?.deviceId;
    final acting = ref.watch(actingProfileProvider);

    final sections = [
      _SectionSpec(l10n.settingsSectionHousehold, const [
        'household.region',
        'board.member_label',
      ]),
      _SectionSpec(l10n.settingsSectionTasks, const [
        'tasks.points.duty_default',
        'tasks.points.bonus_default',
        'tasks.kind_default',
        'tasks.verification_default',
        'tasks.jokers_per_month',
        'tasks.reward_approval_default',
      ]),
      _SectionSpec(l10n.settingsSectionCalendar, const [
        'calendar.members_edit_own_events',
        'calendar.key_default',
        'school.members_report_changes',
        'school.equipment_hint',
      ]),
      _SectionSpec(l10n.settingsSectionMeals, const [
        'meals.warm_meal.school_day',
        'meals.warm_meal.free_day',
        'meals.away_means_not_eating',
        'meals.care_lunch_cutoff',
      ]),
      _SectionSpec(l10n.settingsSectionKitchen, const [
        'board.rollover',
        'board.day_parts',
      ]),
      _SectionSpec(l10n.settingsSectionDevice, const [
        'device.night_hours',
        'device.idle_revert_seconds',
      ]),
      _SectionSpec(l10n.settingsSectionMine, const [
        'member.completion_sound',
        'calendar.tentative_nudge',
        'notify.morning_summary',
        'notify.event_reminder',
        'notify.task_verified',
        'notify.redemption_request',
      ], personal: true),
    ];

    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: Tokens.space4,
              bottom: Tokens.space2,
            ),
            child: Semantics(
              header: true,
              child: Text(
                section.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (section.personal && acting == null)
            Text(l10n.settingPickPersonFirst)
          else
            for (final key in section.keys)
              ..._rowFor(context, ref, key, deviceId, acting),
        ],
      ],
    );
  }

  /// The row for [key] as seen by the current device or acting person. Empty when the
  /// target is unknown (no device yet, or nobody at a shared device).
  List<Widget> _rowFor(
    BuildContext context,
    WidgetRef ref,
    String key,
    String? deviceId,
    String? acting,
  ) {
    final definition = resolveSetting(entries, key);
    if (definition == null) return const [];
    final isMember = definition.scope == SettingScope.member;
    final isDevice = definition.scope == SettingScope.device;
    if (isMember && acting == null) return const [];
    if (isDevice && deviceId == null) return const [];

    final profileId = isMember ? acting : null;
    final scopedDeviceId = isDevice ? deviceId : null;
    final entry = resolveSetting(
      entries,
      key,
      profileId: profileId,
      deviceId: scopedDeviceId,
    );
    if (entry == null) return const [];

    return [
      SettingRow(
        entry: entry,
        onChanged: (value) => _save(
          context,
          ref,
          definition,
          profileId: profileId,
          deviceId: scopedDeviceId,
          value: value,
        ),
        onReset: entry.isDefault
            ? null
            : () => _reset(
                context,
                ref,
                definition,
                profileId: profileId,
                deviceId: scopedDeviceId,
              ),
      ),
    ];
  }
}

/// Writes one setting. Household and device scopes need a guardian (PIN step-up on
/// shared devices); a member's own settings go through without one.
Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  SettingEntry definition, {
  required String? profileId,
  required String? deviceId,
  required Object? value,
}) async {
  if (definition.scope != SettingScope.member &&
      !await ensureGuardian(context, ref)) {
    return;
  }
  if (!context.mounted) return;
  final result = await ref
      .read(householdSettingsRepositoryProvider)
      .set(
        actor: ref.read(actingProfileProvider),
        key: definition.key,
        value: value,
        profileId: profileId,
        deviceId: deviceId,
      );
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      ref.invalidate(householdSettingsProvider);
    case Err(:final failure):
      context.showMessage(failure.message(context.l10n));
  }
}

/// Removes an override (or, for the household row, sets the default back).
Future<void> _reset(
  BuildContext context,
  WidgetRef ref,
  SettingEntry definition, {
  required String? profileId,
  required String? deviceId,
}) async {
  if (definition.scope != SettingScope.member &&
      !await ensureGuardian(context, ref)) {
    return;
  }
  if (!context.mounted) return;
  final result = await ref
      .read(householdSettingsRepositoryProvider)
      .reset(
        actor: ref.read(actingProfileProvider),
        key: definition.key,
        profileId: profileId,
        deviceId: deviceId,
      );
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      ref.invalidate(householdSettingsProvider);
    case Err(:final failure):
      context.showMessage(failure.message(context.l10n));
  }
}

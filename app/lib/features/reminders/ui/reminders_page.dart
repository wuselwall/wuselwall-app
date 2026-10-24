import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/reminders/application/reminder_providers.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/settings/ui/setting_controls.dart';

/// Einstellungen → Erinnerungen (specs/21, Notifications). The three member settings the
/// phone turns into local notifications, and the permission they need.
class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  static const _keys = [
    'notify.morning_summary',
    'notify.event_reminder',
    'notify.packing_reminder',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final device = ref.watch(deviceProvider).value;
    final personal = device?.deviceClass == DeviceClass.personal;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reminderSettingsTitle),
        leading: BackButton(
          onPressed: () => context.go(Routes.settingsPersonal),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space4),
        children: [
          if (!personal)
            Text(l10n.reminderOnlyPersonal)
          else ...[
            _PermissionCard(),
            const SizedBox(height: Tokens.space2),
            Text(
              l10n.reminderLocalNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: Tokens.space4,
                bottom: Tokens.space2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.reminderSettingsSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            AsyncValueView<List<SettingEntry>>(
              value: ref.watch(householdSettingsProvider),
              onRetry: () => ref.invalidate(householdSettingsProvider),
              data: (entries) => _Rows(entries: entries),
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheduler = ref.watch(notificationSchedulerProvider);
    final granted = ref.watch(notificationPermissionProvider).value ?? false;
    final theme = Theme.of(context);
    if (!scheduler.available) {
      return Text(l10n.reminderStatusUnavailable);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          granted ? l10n.reminderStatusOn : l10n.reminderStatusOff,
          style: theme.textTheme.titleSmall,
        ),
        if (!granted) ...[
          const SizedBox(height: Tokens.space2),
          FilledButton(
            onPressed: () => _enable(context, ref),
            child: Text(l10n.reminderEnableAction),
          ),
        ],
      ],
    );
  }
}

Future<void> _enable(BuildContext context, WidgetRef ref) async {
  final granted = await enableReminders(ref);
  if (!context.mounted || granted) return;
  context.showMessage(context.l10n.reminderDeniedNote);
}

class _Rows extends ConsumerWidget {
  const _Rows({required this.entries});

  final List<SettingEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(actingProfileProvider);
    if (actor == null) return const SizedBox.shrink();
    return Column(
      children: [
        for (final key in RemindersPage._keys)
          ..._row(context, ref, key, actor),
      ],
    );
  }

  List<Widget> _row(
    BuildContext context,
    WidgetRef ref,
    String key,
    String actor,
  ) {
    // Member settings are per person, so the lookup carries no device.
    final entry = resolveSetting(entries, key, profileId: actor);
    if (entry == null) return const [];
    return [
      SettingRow(
        entry: entry,
        onChanged: (value) => _write(context, ref, key, actor, value: value),
        onReset: entry.isDefault
            ? null
            : () => _write(context, ref, key, actor, reset: true),
      ),
    ];
  }
}

/// Writes one member setting: no guardian is needed for one's own settings (specs/21).
Future<void> _write(
  BuildContext context,
  WidgetRef ref,
  String key,
  String actor, {
  Object? value,
  bool reset = false,
}) async {
  final repository = ref.read(householdSettingsRepositoryProvider);
  final result = reset
      ? await repository.reset(actor: actor, key: key, profileId: actor)
      : await repository.set(
          actor: actor,
          key: key,
          value: value,
          profileId: actor,
        );
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      ref.invalidate(householdSettingsProvider);
    case Err(:final failure):
      context.showMessage(failure.message(context.l10n));
  }
}

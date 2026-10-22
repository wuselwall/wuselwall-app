import 'dart:async';

import 'package:flutter/widgets.dart' show Locale, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/app_language.dart';
import 'package:wuselwall/core/l10n/app_locale.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/notifications/notification_scheduler.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/reminders/data/reminder_dismissal_store.dart';
import 'package:wuselwall/features/reminders/domain/reminder_plan.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

/// The strings of the reminders: the language chosen on this device, else the device
/// language, German when the app does not ship it (specs/09: German is the fallback).
AppLocalizations reminderL10n([Locale? chosen]) {
  // The first of the device's languages the app ships, as MaterialApp resolves it.
  final locale =
      chosen ??
      resolveAppLocale(WidgetsBinding.instance.platformDispatcher.locales);
  return lookupAppLocalizations(locale);
}

/// How long the plan must stay unchanged before the phone reschedules (calendar edits
/// often come in bursts).
final reminderDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 800),
);

/// What the phone should show for the acting person. Nothing unless this is a personal
/// device with someone at it and the platform can show notifications.
final reminderPlanProvider = FutureProvider.autoDispose<ReminderPlan>((
  ref,
) async {
  ref.watch(deviceKeyProvider);
  final device = ref.watch(deviceProvider).value;
  final actor = ref.watch(actingProfileProvider);
  final scheduler = ref.watch(notificationSchedulerProvider);
  if (device == null ||
      actor == null ||
      !scheduler.available ||
      device.deviceClass != DeviceClass.personal) {
    return ReminderPlan.none;
  }
  refreshOnInvalidation(ref, householdId: device.householdId, topic: 'tasks');

  // Member settings are per person: no device in the lookup (see the settings page).
  final settings = await ref.watch(householdSettingsProvider.future);
  final morning = resolveSetting(
    settings,
    'notify.morning_summary',
    profileId: actor,
  );
  final event = resolveSetting(
    settings,
    'notify.event_reminder',
    profileId: actor,
  );
  final packing = resolveSetting(
    settings,
    'notify.packing_reminder',
    profileId: actor,
  );

  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);
  final to = DateTime(from.year, from.month, from.day + planDays - 1);
  final window = await ref.watch(
    occurrencesProvider((from: from, to: to)).future,
  );

  final repository = ref.watch(tasksRepositoryProvider);
  final tasks = <TaskInstance>[];
  for (var i = 0; i < planDays; i++) {
    final day = DateTime(from.year, from.month, from.day + i);
    tasks.addAll((await repository.instancesOn(day)).unwrap());
  }

  final packingAt = morningTimeOf(packing?.value);
  final packs = packingAt == null
      ? const <PackList>[]
      : await _packLists(ref, actor, from);

  return planReminders(
    now: now,
    l10n: reminderL10n(ref.watch(appLanguageProvider).value),
    actor: actor,
    morningAt: morningTimeOf(morning?.value),
    eventMinutes: (event?.value as num?)?.toInt(),
    occurrences: window.occurrences,
    tasks: tasks,
    packingAt: packingAt,
    packs: packs,
  );
});

/// What the children pack for each school day from tomorrow through the plan's last
/// evening: a child's own phone covers that child, an adult's every child. A server or
/// household without the school module simply gives none.
Future<List<PackList>> _packLists(Ref ref, String actor, DateTime today) async {
  final members = await ref.watch(membersProvider.future);
  final me = members.where((m) => m.id == actor).firstOrNull;
  final children = me != null && me.isChild
      ? [me]
      : members.where((m) => m.isChild && m.active).toList();
  if (children.isEmpty) return const [];
  final first = DateTime(today.year, today.month, today.day + 1);
  final last = DateTime(today.year, today.month, today.day + planDays);
  try {
    final week = await ref.watch(schoolWeekProvider((first, last)).future);
    return [
      for (
        var d = first;
        !d.isAfter(last);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        for (final child in children)
          if (week.dayOf(child.id, d)?.equipment case final items?
              when items.isNotEmpty)
            PackList(
              day: d,
              profileId: child.id,
              name: child.displayName,
              items: items,
            ),
    ];
  } on Object catch (error, stack) {
    logError('Packing reminders skipped', error: error, stackTrace: stack);
    return const [];
  }
}

/// Whether the OS currently lets the app show notifications.
final notificationPermissionProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final scheduler = ref.watch(notificationSchedulerProvider);
  if (!scheduler.available) return false;
  await scheduler.init(
    channelName: reminderL10n(ref.read(appLanguageProvider).value)
        .reminderChannelName,
  );
  return scheduler.permissionGranted();
});

/// Whether Today shows the "Erinnerungen einschalten" row: a guardian on a personal
/// device, a platform that can show reminders, no permission yet, and not dismissed.
final reminderCardProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(deviceKeyProvider);
  final device = ref.watch(deviceProvider).value;
  final actor = ref.watch(actingProfileProvider);
  final scheduler = ref.watch(notificationSchedulerProvider);
  if (device == null ||
      actor == null ||
      !scheduler.available ||
      device.deviceClass != DeviceClass.personal) {
    return false;
  }
  final members = await ref.watch(membersProvider.future);
  final isGuardian =
      members.where((m) => m.id == actor).firstOrNull?.isGuardian ?? false;
  if (!isGuardian) return false;
  if (await ref.watch(notificationPermissionProvider.future)) return false;
  return !await ref.watch(reminderDismissalStoreProvider).dismissed();
});

/// Keeps the phone's scheduled notifications in step with the plan. Read once at app
/// start; it stays alive through its listener. Each new plan replaces the whole set,
/// after a short debounce.
final reminderSyncProvider = Provider<void>((ref) {
  final scheduler = ref.read(notificationSchedulerProvider);
  final debounce = ref.read(reminderDebounceProvider);
  Timer? timer;
  ref.onDispose(() => timer?.cancel());
  ref.listen(reminderPlanProvider, (_, next) {
    final plan = switch (next) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (plan == null) return;
    timer?.cancel();
    // The channel's name in the language the plan was made in.
    final channelName = reminderL10n(ref.read(appLanguageProvider).value)
        .reminderChannelName;
    // No debounce means no timer at all (tests): apply straight away.
    if (debounce == Duration.zero) {
      unawaited(_apply(scheduler, plan, channelName));
      return;
    }
    timer = Timer(
      debounce,
      () => unawaited(_apply(scheduler, plan, channelName)),
    );
  });
});

Future<void> _apply(
  NotificationScheduler scheduler,
  ReminderPlan plan,
  String channelName,
) async {
  try {
    await scheduler.init(channelName: channelName);
    await scheduler.cancelAll();
    if (!plan.active || !await scheduler.permissionGranted()) return;
    var id = 0;
    for (final reminder in plan.reminders) {
      await scheduler.schedule(
        id: id++,
        when: reminder.when,
        title: reminder.title,
        body: reminder.body,
      );
    }
  } on Object catch (error, stack) {
    logError(
      'Reminders could not be scheduled',
      error: error,
      stackTrace: stack,
    );
  }
}

/// The user tapped "Erinnerungen einschalten": asks the OS, then refreshes everything
/// that depends on the answer. Returns whether the permission was granted.
Future<bool> enableReminders(WidgetRef ref) async {
  final scheduler = ref.read(notificationSchedulerProvider);
  await scheduler.init(
    channelName: reminderL10n(ref.read(appLanguageProvider).value)
        .reminderChannelName,
  );
  final granted = await scheduler.requestPermission();
  ref
    ..invalidate(notificationPermissionProvider)
    ..invalidate(reminderCardProvider)
    ..invalidate(reminderPlanProvider);
  return granted;
}

/// The row's "Brauchen wir nicht": hides it on this phone for good.
Future<void> dismissReminderCard(WidgetRef ref) async {
  await ref.read(reminderDismissalStoreProvider).dismiss();
  ref.invalidate(reminderCardProvider);
}

import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

/// The strings of the reminders: the device language, German unless it is English
/// (specs/09, CLAUDE.md: German is the fallback).
AppLocalizations reminderL10n() {
  // The first of the device's languages the app ships, as MaterialApp resolves it.
  final codes = WidgetsBinding.instance.platformDispatcher.locales.map(
    (locale) => locale.languageCode,
  );
  final code = codes.firstWhere(
    (c) => c == 'en' || c == 'de',
    orElse: () => 'de',
  );
  return lookupAppLocalizations(Locale(code));
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

  return planReminders(
    now: now,
    l10n: reminderL10n(),
    actor: actor,
    morningAt: morningTimeOf(morning?.value),
    eventMinutes: (event?.value as num?)?.toInt(),
    occurrences: window.occurrences,
    tasks: tasks,
  );
});

/// Whether the OS currently lets the app show notifications.
final notificationPermissionProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final scheduler = ref.watch(notificationSchedulerProvider);
  if (!scheduler.available) return false;
  await scheduler.init(channelName: reminderL10n().reminderChannelName);
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
    // No debounce means no timer at all (tests): apply straight away.
    if (debounce == Duration.zero) {
      unawaited(_apply(scheduler, plan));
      return;
    }
    timer = Timer(debounce, () => unawaited(_apply(scheduler, plan)));
  });
});

Future<void> _apply(NotificationScheduler scheduler, ReminderPlan plan) async {
  try {
    await scheduler.init(channelName: reminderL10n().reminderChannelName);
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
  await scheduler.init(channelName: reminderL10n().reminderChannelName);
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

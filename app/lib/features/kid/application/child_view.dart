import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';

/// Who is looking at this device, as far as the children's limits care (specs/09 "What a
/// child sees"). Attribution on a shared device is cooperative, so this decides what the
/// app offers, not what the server allows.
enum Viewer {
  /// An adult, or a personal device before its members are known.
  adult,

  /// A shared device or the wall with nobody chosen: a child may be standing there.
  nobody,

  /// A child of twelve or older: the device's own register, within the limits.
  olderChild,

  /// A child under twelve (or without a birthday): the simple view.
  youngChild;

  bool get isChild => this == olderChild || this == youngChild;
}

final viewerProvider = Provider<Viewer>((ref) {
  final member = ref.watch(actingMemberProvider);
  if (member == null) {
    final shared =
        ref.watch(deviceKeyProvider).deviceClass?.isTapToSwitch ?? false;
    return shared ? Viewer.nobody : Viewer.adult;
  }
  if (!member.isChild) return Viewer.adult;
  return ref.watch(youngChildActingProvider)
      ? Viewer.youngChild
      : Viewer.olderChild;
});

/// One of the family's two switches for children: `household.kid_shopping` and
/// `household.kid_calendar`. A server older than the switch has no row and keeps the
/// view; so does a device that cannot read the settings. While they load the view waits,
/// so a family without it never sees it come and go.
final childSwitchProvider = Provider.family<bool, String>((ref, key) {
  final settings = ref.watch(householdSettingsProvider);
  final entries = settings.value;
  if (entries == null) return settings.hasError;
  return switch (resolveSetting(entries, key)) {
    null => true,
    final entry => entry.value == true,
  };
});

const kidShoppingKey = 'household.kid_shopping';
const kidCalendarKey = 'household.kid_calendar';

/// Whether whoever is at the device is offered the shopping list: an adult always, a
/// child and a shared device with nobody chosen only where the family switched it on.
final shoppingOfferedProvider = Provider<bool>(
  (ref) =>
      ref.watch(viewerProvider) == Viewer.adult ||
      ref.watch(childSwitchProvider(kidShoppingKey)),
);

/// Whether whoever is at the device is offered a calendar: the adult calendar, or for a
/// child the look ahead to the next days.
final calendarOfferedProvider = Provider<bool>(
  (ref) =>
      ref.watch(viewerProvider) == Viewer.adult ||
      ref.watch(childSwitchProvider(kidCalendarKey)),
);

/// How many days a child sees: today and the next three.
const childHorizonDays = 4;

/// The days a child may look at, today first: four with the calendar switched on, only
/// today without. Null for everyone who is not a child.
final childDaysProvider = Provider<List<DateTime>?>((ref) {
  if (!ref.watch(viewerProvider).isChild) return null;
  final today = ref.watch(todayProvider);
  final count = ref.watch(childSwitchProvider(kidCalendarKey))
      ? childHorizonDays
      : 1;
  return [
    for (var i = 0; i < count; i++)
      DateTime(today.year, today.month, today.day + i),
  ];
});

/// The calendar of a child in the adult register (twelve or older): whose it is and
/// its first day. Null for everyone else, who has the whole calendar.
final childCalendarProvider = Provider<({String id, DateTime from})?>((ref) {
  final days = ref.watch(childDaysProvider);
  final id = ref.watch(actingMemberProvider)?.id;
  if (days == null || id == null) return null;
  return (id: id, from: days.first);
});

/// What of [window] concerns [childId]: the appointments and absences the child is in.
/// Everyone else's are left out, so a child's calendar is the child's own.
OccurrenceWindow occurrencesOfChild(OccurrenceWindow window, String childId) =>
    OccurrenceWindow(
      timezone: window.timezone,
      occurrences: [
        for (final o in window.occurrences)
          if (o.attendeeIds.contains(childId)) o,
      ],
      busyUntil: {
        for (final e in window.busyUntil.entries)
          if (e.key.profileId == childId) e.key: e.value,
      },
      publicHolidays: window.publicHolidays,
    );

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/features/board/domain/week_board.dart' show parseTime;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/event_reminder.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

/// One notification the phone will show (specs/09 "Realtime and notifications").
class Reminder {
  const Reminder({required this.when, required this.title, required this.body});

  /// Local time the notification is shown.
  final DateTime when;
  final String title;
  final String body;
}

/// What the phone should show for the next days. [active] is false when reminders do
/// not apply to this device at all (shared, kiosk, nobody at it): then nothing is kept.
class ReminderPlan {
  const ReminderPlan({required this.active, this.reminders = const []});

  static const none = ReminderPlan(active: false);

  final bool active;
  final List<Reminder> reminders;
}

/// What one child is to pack for a school day: the equipment of that day's lessons
/// (FR-7.12, the projection's `equipment`), already empty when the household switched
/// the hint off.
class PackList {
  const PackList({
    required this.day,
    required this.profileId,
    required this.name,
    required this.items,
  });

  /// The school day the things are for.
  final DateTime day;
  final String profileId;
  final String name;
  final List<String> items;
}

/// Most notifications kept at once. iOS keeps only the 64 that come soonest, so the plan
/// stays under that and the rest is filled in on the next reschedule.
const maxReminders = 60;

/// Days ahead the plan covers, counted from today.
const planDays = 7;

/// Days of appointments the plan needs: an event's own reminder may come up to
/// [longestReminderChoice] before its start, so the events of the week after the plan
/// can already remind inside it.
final reminderWindowDays = planDays + longestReminderChoice.inDays;

/// The morning summary and the event reminders for [actor] (specs/21, Notifications),
/// computed from what the app already has: the calendar window and the open chores.
///
/// [occurrences] covers today through [reminderWindowDays]; [tasks] is every instance of
/// the [planDays]. A null [morningAt] switches the summary off. [eventMinutes] is the
/// person's lead time for every appointment, null for none; an event that carries a
/// reminder of its own (specs/05 "A reminder for one event") uses that instead, whatever
/// the person chose, and an all-day event with one reminds at [allDayReminderAt].
/// [packingAt] is the evening "Für morgen einpacken" (`notify.packing_reminder`): on the
/// evening before each day of [packs] that has something to pack; a null switches it off.
/// [pendingApprovals] is what waited for [actor] as a guardian when the plan was made
/// (zero for anyone else): only the next morning summary names it, since a later one
/// would be guessing (specs/16 step 10.5), and that summary comes even on an empty day.
/// Presence entries and cancelled events get no event reminder, and all-day events only
/// their own; an event counts for [actor] when it is theirs or for the whole family.
ReminderPlan planReminders({
  required DateTime now,
  required AppLocalizations l10n,
  required String actor,
  required TimeOfDay? morningAt,
  required int? eventMinutes,
  required List<Occurrence> occurrences,
  required List<TaskInstance> tasks,
  TimeOfDay? packingAt,
  List<PackList> packs = const [],
  int pendingApprovals = 0,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final end = DateTime(today.year, today.month, today.day + planDays);
  final reminders = <Reminder>[];

  final mine = [
    for (final o in occurrences)
      if (_concerns(o, actor)) o,
  ];

  if (morningAt != null) {
    var approvals = pendingApprovals;
    for (var i = 0; i < planDays; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      final at = DateTime(
        day.year,
        day.month,
        day.day,
        morningAt.hour,
        morningAt.minute,
      );
      if (!at.isAfter(now)) continue;
      final dayEvents = [
        for (final o in mine)
          if (!o.localStartDate.isAfter(day) && !o.localEndDate.isBefore(day))
            o,
      ]..sort(_byStart);
      final openChores = [
        for (final t in tasks)
          if (t.assignedProfileId == actor &&
              t.isOpen &&
              _sameDay(t.dueOn, day))
            t,
      ];
      final waiting = approvals;
      approvals = 0;
      final busy = dayEvents.isNotEmpty || openChores.isNotEmpty;
      if (!busy && waiting == 0) continue;
      final firstLine = dayEvents.isEmpty
          ? l10n.reminderMorningNoEvents
          : _firstLine(l10n, dayEvents.first);
      // "2 Freigaben warten" leads an empty day and follows the first line of a busy one.
      reminders.add(
        Reminder(
          when: at,
          title: busy
              ? _morningTitle(l10n, dayEvents.length, openChores.length)
              : l10n.reminderMorningApprovals(waiting),
          body: busy && waiting > 0
              ? '$firstLine · ${l10n.reminderMorningApprovals(waiting)}'
              : firstLine,
        ),
      );
    }
  }

  for (final o in mine) {
    final when = _eventReminderAt(o, eventMinutes);
    if (when == null || !when.isAfter(now) || !when.isBefore(end)) continue;
    reminders.add(
      Reminder(when: when, title: o.title, body: _eventBody(l10n, o, when)),
    );
  }

  if (packingAt != null) {
    final byDay = <DateTime, List<PackList>>{};
    for (final p in packs) {
      if (p.items.isEmpty) continue;
      final day = DateTime(p.day.year, p.day.month, p.day.day);
      (byDay[day] ??= []).add(p);
    }
    for (final MapEntry(key: day, value: lists) in byDay.entries) {
      final at = DateTime(
        day.year,
        day.month,
        day.day - 1,
        packingAt.hour,
        packingAt.minute,
      );
      if (!at.isAfter(now) || !at.isBefore(end)) continue;
      // A child's own phone lists the things; a parent's names each child.
      final own = lists.length == 1 && lists.single.profileId == actor;
      reminders.add(
        Reminder(
          when: at,
          title: l10n.reminderPackTitle,
          body: own
              ? lists.single.items.join(', ')
              : lists
                    .map(
                      (p) => l10n.reminderPackChild(p.name, p.items.join(', ')),
                    )
                    .join(' · '),
        ),
      );
    }
  }

  reminders.sort((a, b) => a.when.compareTo(b.when));
  return ReminderPlan(
    active: true,
    reminders: reminders.take(maxReminders).toList(growable: false),
  );
}

/// When [o] reminds: at its own lead time when it has one, else at the person's
/// [general] one. Null when it does not remind at all.
DateTime? _eventReminderAt(Occurrence o, int? general) {
  final own = o.reminderMinutes;
  if (o.allDay) {
    // No clock time to count back from: whole days before, in the morning.
    if (own == null || !isWholeDays(own)) return null;
    final day = o.localStartDate;
    return DateTime(
      day.year,
      day.month,
      day.day - own ~/ Duration.minutesPerDay,
      allDayReminderAt.hour,
      allDayReminderAt.minute,
    );
  }
  final minutes = own ?? general;
  if (minutes == null || o.localStarts == null) return null;
  // Whole days are counted on the calendar, so "a day before" keeps the event's clock
  // time across a summer-time change; only the rest is counted in minutes.
  final days = minutes ~/ Duration.minutesPerDay;
  final start = o.start;
  final sameClock = days == 0
      ? start
      : DateTime(
          start.year,
          start.month,
          start.day - days,
          start.hour,
          start.minute,
        );
  return sameClock.subtract(
    Duration(minutes: minutes % Duration.minutesPerDay),
  );
}

/// "Beginnt um 08:30" on the day itself, "Morgen um 08:30" or "In 2 Tagen um 08:30"
/// when the reminder comes on an earlier day.
String _eventBody(AppLocalizations l10n, Occurrence o, DateTime when) {
  final startDay = o.allDay ? o.localStartDate : o.start;
  // Whole days between two local midnights; a summer-time change makes one of them
  // 23 or 25 hours long.
  final hours = DateTime(
    startDay.year,
    startDay.month,
    startDay.day,
  ).difference(DateTime(when.year, when.month, when.day)).inHours;
  final ahead = (hours / Duration.hoursPerDay).round();
  if (o.allDay) return l10n.reminderEventBodyAheadAllDay(ahead);
  final clock = _clock(o.localStarts!);
  return ahead <= 0
      ? l10n.reminderEventBody(clock)
      : l10n.reminderEventBodyAhead(ahead, clock);
}

bool _concerns(Occurrence o, String actor) =>
    !o.isPresence &&
    o.status != EventStatus.cancelled &&
    (o.attendeeIds.isEmpty || o.attendeeIds.contains(actor));

int _byStart(Occurrence a, Occurrence b) {
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  return a.start.compareTo(b.start);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _morningTitle(AppLocalizations l10n, int events, int chores) {
  if (events > 0 && chores > 0) {
    return l10n.reminderMorningEventsAndTasks(events, chores);
  }
  if (events > 0) return l10n.reminderMorningEventsOnly(events);
  return l10n.reminderMorningTasksOnly(chores);
}

String _firstLine(AppLocalizations l10n, Occurrence o) => o.allDay
    ? l10n.reminderMorningAllDay(o.title)
    : l10n.reminderMorningFirst(_clock(o.localStarts!), o.title);

/// `08:30`, the form the app shows for times everywhere.
String _clock(TimeOfDay t) => clockOf(t);

/// Parses the `HH:MM` value of `notify.morning_summary`.
TimeOfDay? morningTimeOf(Object? value) =>
    value is String ? parseTime(value) : null;

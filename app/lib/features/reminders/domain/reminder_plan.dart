import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/features/board/domain/week_board.dart' show parseTime;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
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

/// The morning summary and the event reminders for [actor] (specs/21, Notifications),
/// computed from what the app already has: the calendar window and the open chores.
///
/// [occurrences] covers today through [planDays]; [tasks] is every instance in that span.
/// A null [morningAt] switches the summary off, a null [eventMinutes] the reminders.
/// [packingAt] is the evening "Für morgen einpacken" (`notify.packing_reminder`): on the
/// evening before each day of [packs] that has something to pack; a null switches it off.
/// [pendingApprovals] is what waited for [actor] as a guardian when the plan was made
/// (zero for anyone else): only the next morning summary names it, since a later one
/// would be guessing (specs/16 step 10.5), and that summary comes even on an empty day.
/// Presence entries, cancelled events and all-day events get no event reminder; an
/// event counts for [actor] when it is theirs or for the whole family.
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

  if (eventMinutes != null) {
    for (final o in mine) {
      final start = o.start;
      if (o.allDay || o.localStarts == null) continue;
      if (!start.isBefore(end)) continue;
      final when = start.subtract(Duration(minutes: eventMinutes));
      if (!when.isAfter(now)) continue;
      reminders.add(
        Reminder(
          when: when,
          title: o.title,
          body: l10n.reminderEventBody(_clock(o.localStarts!)),
        ),
      );
    }
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

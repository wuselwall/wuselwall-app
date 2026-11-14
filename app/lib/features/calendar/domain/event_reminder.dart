import 'package:flutter/material.dart' show TimeOfDay;

/// An event's own reminder (specs/05 "A reminder for one event"): one lead time in
/// minutes before the start, saved with the event, so everyone it concerns gets it.

const _hour = 60;
const _day = 24 * _hour;
const _week = 7 * _day;

/// The lead times the editor offers for a timed event, shortest first.
const reminderChoices = [15, 30, _hour, 2 * _hour, _day, 2 * _day, _week];

/// The longest lead time the editor offers. The phone plans its notifications this far
/// past its planning week, so a reminder a week ahead is not lost.
const longestReminderChoice = Duration(minutes: _week);

/// An all-day event has no clock time to count back from: its reminder comes at this
/// time, whole days before.
const allDayReminderAt = TimeOfDay(hour: 9, minute: 0);

/// Whether an all-day event can carry [minutes]: whole days, at least one.
bool isWholeDays(int minutes) => minutes >= _day && minutes % _day == 0;

/// What the editor offers: [reminderChoices], only the whole days for an all-day event,
/// and [current] among them when it is a value the list does not have (set by another
/// app or an older choice), so opening an event never changes its reminder.
List<int> reminderChoicesFor({required bool allDay, int? current}) {
  final choices = {
    for (final m in reminderChoices)
      if (!allDay || isWholeDays(m)) m,
    if (current != null && (!allDay || isWholeDays(current))) current,
  }.toList()..sort();
  return choices;
}

/// How a lead time is said: the largest unit that divides it.
enum ReminderUnit { minutes, hours, days, weeks }

/// [minutes] as a count of its largest whole unit: 120 is two hours, 90 is ninety
/// minutes, 10080 is one week.
({ReminderUnit unit, int count}) reminderParts(int minutes) {
  if (minutes > 0 && minutes % _week == 0) {
    return (unit: ReminderUnit.weeks, count: minutes ~/ _week);
  }
  if (minutes > 0 && minutes % _day == 0) {
    return (unit: ReminderUnit.days, count: minutes ~/ _day);
  }
  if (minutes > 0 && minutes % _hour == 0) {
    return (unit: ReminderUnit.hours, count: minutes ~/ _hour);
  }
  return (unit: ReminderUnit.minutes, count: minutes);
}

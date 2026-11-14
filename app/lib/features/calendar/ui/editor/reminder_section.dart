import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/domain/event_reminder.dart';

/// The menu's value for "Keine": a lead time is never negative.
const _none = -1;

/// The "Erinnerung vorher" field of the editor (specs/05 "A reminder for one event"):
/// one menu with none or one lead time. An all-day event offers only whole days, which
/// remind at [allDayReminderAt].
class ReminderSection extends StatelessWidget {
  const ReminderSection({
    required this.minutes,
    required this.allDay,
    required this.onChanged,
    super.key,
  });

  /// The reminder the event is saved with; null for none.
  final int? minutes;
  final bool allDay;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          // The field keeps its own value once built: a new one when the event's
          // reminder or the choices change from outside (all day switched on or off).
          key: ValueKey('event-reminder-$allDay-${minutes ?? _none}'),
          initialValue: minutes ?? _none,
          decoration: InputDecoration(labelText: l10n.eventReminder),
          items: [
            DropdownMenuItem(value: _none, child: Text(l10n.eventReminderNone)),
            for (final choice in reminderChoicesFor(
              allDay: allDay,
              current: minutes,
            ))
              DropdownMenuItem(
                value: choice,
                child: Text(reminderLabel(l10n, choice)),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value == _none ? null : value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          allDay
              ? l10n.eventReminderAllDayHelp(context.time(allDayReminderAt))
              : l10n.eventReminderHelp,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// "15 minutes", "1 hour", "2 days", "1 week": a lead time in its largest whole unit.
String reminderLabel(AppLocalizations l10n, int minutes) {
  final (:unit, :count) = reminderParts(minutes);
  return switch (unit) {
    ReminderUnit.minutes => l10n.eventReminderMinutes(count),
    ReminderUnit.hours => l10n.eventReminderHours(count),
    ReminderUnit.days => l10n.eventReminderDays(count),
    ReminderUnit.weeks => l10n.eventReminderWeeks(count),
  };
}

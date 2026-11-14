import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/domain/event_reminder.dart';

/// The "Erinnerung vorher" block of the editor (specs/05 "A reminder for one event"):
/// none or one lead time. An all-day event offers only whole days, which remind at
/// [allDayReminderAt].
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
        Text(l10n.eventReminder, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('event-reminder-none'),
              label: Text(l10n.eventReminderNone),
              selected: minutes == null,
              onSelected: (_) => onChanged(null),
            ),
            for (final choice in reminderChoicesFor(
              allDay: allDay,
              current: minutes,
            ))
              ChoiceChip(
                key: ValueKey('event-reminder-$choice'),
                label: Text(reminderLabel(l10n, choice)),
                selected: minutes == choice,
                onSelected: (_) => onChanged(choice),
              ),
          ],
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

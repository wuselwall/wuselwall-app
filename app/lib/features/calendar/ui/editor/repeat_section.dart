import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/ui/editor/dienstplan_grid.dart';
import 'package:wuselwall/features/calendar/ui/editor/recurrence.dart';

/// The "Wiederholung" block of the editor: the repeat kind, its weekday, month-day or
/// date choices, and when the series ends. Builds [Recurrence] values only; the
/// editor turns them into the rule when it saves.
class RepeatSection extends StatelessWidget {
  const RepeatSection({
    required this.recurrence,
    required this.start,
    required this.onChanged,
    this.weekdaysError = false,
    super.key,
  });

  final Recurrence recurrence;

  /// The event's start: the default weekday, the month day and the first Dienstplan day.
  final DateTime start;
  final ValueChanged<Recurrence> onChanged;
  final bool weekdaysError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final kind = recurrence.kind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.eventRepeat, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in _choices)
              ChoiceChip(
                label: Text(_kindLabel(l10n, choice)),
                selected: kind == choice,
                onSelected: (_) => onChanged(_choose(choice)),
              ),
          ],
        ),
        if (kind == RepeatKind.custom) ...[
          const SizedBox(height: 12),
          Text(
            l10n.eventCustomRule,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(l10n.eventCustomRuleHelp),
        ],
        if (kind == RepeatKind.weekly || kind == RepeatKind.biweekly) ...[
          const SizedBox(height: 12),
          _weekdays(context),
          if (weekdaysError)
            Text(
              l10n.eventWeekdaysRequired,
              style: TextStyle(color: scheme.error),
            ),
        ],
        if (kind == RepeatKind.monthly) ...[
          const SizedBox(height: 12),
          _monthly(context),
        ],
        if (kind == RepeatKind.specificDays) ...[
          const SizedBox(height: 12),
          Text(l10n.eventDienstplanHelp),
          const SizedBox(height: 8),
          DienstplanGrid(
            start: start,
            days: recurrence.days,
            onChanged: (days) => onChanged(recurrence.copyWith(days: days)),
          ),
          Text(
            l10n.eventDaysPicked(_pickedCount),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
        if (recurrence.hasEnd) ...[const SizedBox(height: 12), _ends(context)],
      ],
    );
  }

  /// The start day counts whether or not the stored set lists it.
  int get _pickedCount =>
      {...recurrence.days, DateTime(start.year, start.month, start.day)}.length;

  static const _choices = [
    RepeatKind.never,
    RepeatKind.daily,
    RepeatKind.weekly,
    RepeatKind.biweekly,
    RepeatKind.monthly,
    RepeatKind.specificDays,
  ];

  String _kindLabel(AppLocalizations l10n, RepeatKind kind) => switch (kind) {
    RepeatKind.never => l10n.eventRepeatNever,
    RepeatKind.daily => l10n.eventRepeatDaily,
    RepeatKind.weekly => l10n.eventRepeatWeekly,
    RepeatKind.biweekly => l10n.eventRepeatBiweekly,
    RepeatKind.monthly => l10n.eventRepeatMonthly,
    RepeatKind.specificDays => l10n.eventRepeatSpecificDays,
    RepeatKind.custom => l10n.eventCustomRule,
  };

  /// Switching fills the defaults the choice needs: the start's weekday, the start day.
  Recurrence _choose(RepeatKind kind) {
    final next = recurrence.copyWith(kind: kind);
    return switch (kind) {
      RepeatKind.weekly || RepeatKind.biweekly
          when recurrence.weekdays.isEmpty =>
        next.copyWith(weekdays: {start.weekday}),
      RepeatKind.never => next.copyWith(end: RepeatEnd.never),
      _ => next,
    };
  }

  Widget _weekdays(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (var i = 0; i < 7; i++)
        FilterChip(
          label: Text(context.weekdayShort(DateTime(2024, 1, 1 + i))),
          selected: recurrence.weekdays.contains(i + 1),
          onSelected: (on) {
            final days = Set<int>.of(recurrence.weekdays);
            if (on) {
              days.add(i + 1);
            } else {
              days.remove(i + 1);
            }
            onChanged(recurrence.copyWith(weekdays: days));
          },
        ),
    ],
  );

  Widget _monthly(BuildContext context) {
    final l10n = context.l10n;
    final weekday = context.weekdayLong(start);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text(l10n.eventRepeatMonthlyDay(start.day)),
          selected: recurrence.monthly == MonthlyMode.dayOfMonth,
          onSelected: (_) =>
              onChanged(recurrence.copyWith(monthly: MonthlyMode.dayOfMonth)),
        ),
        ChoiceChip(
          label: Text(l10n.eventRepeatMonthlyNth(nthOf(start), weekday)),
          selected: recurrence.monthly == MonthlyMode.nthWeekday,
          onSelected: (_) =>
              onChanged(recurrence.copyWith(monthly: MonthlyMode.nthWeekday)),
        ),
        if (isLastWeekdayOf(start))
          ChoiceChip(
            label: Text(l10n.eventRepeatMonthlyLast(weekday)),
            selected: recurrence.monthly == MonthlyMode.lastWeekday,
            onSelected: (_) => onChanged(
              recurrence.copyWith(monthly: MonthlyMode.lastWeekday),
            ),
          ),
      ],
    );
  }

  Widget _ends(BuildContext context) {
    final l10n = context.l10n;
    final end = recurrence.end;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.eventRepeatEnds,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: Text(l10n.eventRepeatNever),
              selected: end == RepeatEnd.never,
              onSelected: (_) =>
                  onChanged(recurrence.copyWith(end: RepeatEnd.never)),
            ),
            ChoiceChip(
              label: Text(l10n.eventRepeatUntil),
              selected: end == RepeatEnd.until,
              onSelected: (_) =>
                  onChanged(recurrence.copyWith(end: RepeatEnd.until)),
            ),
            if (end == RepeatEnd.until)
              OutlinedButton(
                onPressed: () => _pickUntil(context),
                child: Text(context.fullDate(recurrence.until ?? start)),
              ),
            ChoiceChip(
              label: Text(l10n.eventRepeatCount(recurrence.count)),
              selected: end == RepeatEnd.count,
              onSelected: (_) =>
                  onChanged(recurrence.copyWith(end: RepeatEnd.count)),
            ),
            if (end == RepeatEnd.count) ...[
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: recurrence.count > 2
                    ? () => onChanged(
                        recurrence.copyWith(count: recurrence.count - 1),
                      )
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: recurrence.count < 365
                    ? () => onChanged(
                        recurrence.copyWith(count: recurrence.count + 1),
                      )
                    : null,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _pickUntil(BuildContext context) async {
    final first = recurrence.until ?? start;
    final picked = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: start,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    onChanged(
      recurrence.copyWith(
        end: RepeatEnd.until,
        until: DateTime(picked.year, picked.month, picked.day),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/swipe_stepper.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';

/// A month of tappable days for a shift plan ("Bestimmte Tage", specs/15): Monday
/// first, one tap per working day. The start day is always selected and cannot be
/// dropped; it is the first occurrence and the server adds it itself.
class DienstplanGrid extends StatefulWidget {
  const DienstplanGrid({
    required this.start,
    required this.days,
    required this.onChanged,
    super.key,
  });

  final DateTime start;

  /// The selected days (local dates), the start day included or not.
  final Set<DateTime> days;
  final ValueChanged<Set<DateTime>> onChanged;

  @override
  State<DienstplanGrid> createState() => _DienstplanGridState();
}

class _DienstplanGridState extends State<DienstplanGrid> {
  late DateTime _month = DateTime(widget.start.year, widget.start.month);

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  void _toggle(DateTime day) {
    if (day == _startDay) return;
    final next = Set.of(widget.days);
    if (!next.remove(day)) next.add(day);
    widget.onChanged(next);
  }

  DateTime get _startDay =>
      DateTime(widget.start.year, widget.start.month, widget.start.day);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final leading = _month.weekday - DateTime.monday;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = ((leading + daysInMonth + 6) ~/ 7) * 7;

    // The arrow keys stay with the editor's fields around it.
    return SwipeStepper(
      onPrevious: () => _shift(-1),
      onNext: () => _shift(1),
      arrowKeys: false,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l10n.calendarPrevious,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM(locale).format(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: l10n.calendarNext,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(1),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    context.weekdayShort(DateTime(2024, 1, 1 + i)),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            children: [
              for (var i = 0; i < cells; i++)
                _cell(context, i - leading, daysInMonth, scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    int index,
    int daysInMonth,
    ColorScheme scheme,
  ) {
    if (index < 0 || index >= daysInMonth) return const SizedBox.shrink();
    final day = DateTime(_month.year, _month.month, index + 1);
    final isStart = day == _startDay;
    final selected = isStart || widget.days.contains(day);
    final ink = selected ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: context.fullDate(day),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: isStart ? null : () => _toggle(day),
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontFamily: Tokens.fontNumeric,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: ink,
                    fontWeight: isStart ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

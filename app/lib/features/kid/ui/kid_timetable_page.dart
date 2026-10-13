import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/kid/application/kid_providers.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/ui/school_icons.dart';

/// "Mein Stundenplan": the week, Monday to Friday, one day at a time. The kid-sized
/// variant of the paper grid: a phone is too narrow for five columns of subjects at 19
/// px, so the days are a strip and today's lessons are large cards (specs/15).
class KidTimetablePage extends ConsumerStatefulWidget {
  const KidTimetablePage({required this.actor, super.key});

  final String actor;

  @override
  ConsumerState<KidTimetablePage> createState() => _KidTimetablePageState();
}

class _KidTimetablePageState extends ConsumerState<KidTimetablePage> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = ref.watch(kidTodayProvider);
    final minutes = ref.watch(kidMinutesProvider);
    final monday = mondayOf(today);
    final dates = [
      for (var i = 0; i < 5; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
    final todayIndex = dates.indexOf(today);
    final selected = _selected ?? (todayIndex >= 0 ? todayIndex : 0);
    final week = ref.watch(schoolWeekProvider((dates.first, dates.last)));
    final data = ref.watch(schoolDataProvider).value;

    return AsyncValueView<SchoolWeek>(
      value: week,
      onRetry: () =>
          ref.invalidate(schoolWeekProvider((dates.first, dates.last))),
      data: (w) {
        if (w.timetableOf(widget.actor) == null) {
          return Padding(
            padding: const EdgeInsets.all(Tokens.space4),
            child: KidCard(
              child: Text(
                l10n.kidNoTimetable,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(Tokens.space4),
          children: [
            KidSectionTitle(l10n.kidTimetableTitle),
            Row(
              children: [
                for (var i = 0; i < dates.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.space1,
                      ),
                      child: _DayTab(
                        key: ValueKey('kid-day-$i'),
                        date: dates[i],
                        isToday: i == todayIndex,
                        selected: i == selected,
                        onTap: () => setState(() => _selected = i),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Tokens.space4),
            KidDayLessons(
              day: w.dayOf(widget.actor, dates[selected]),
              iconOf: (subject) => schoolIcon(data?.iconKeyFor(subject)),
              minutesNow: selected == todayIndex ? minutes : null,
            ),
          ],
        );
      },
    );
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.date,
    required this.isToday,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final DateTime date;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: context.fullDate(date),
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isToday ? scheme.primary : context.ww.line,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 88,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.weekdayShort(date),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  context.dayMonth(date),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: Tokens.fontNumeric,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (isToday)
                  Text(
                    l10n.kidTodayMarker,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

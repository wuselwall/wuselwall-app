import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/swipe_stepper.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/home/application/home_section.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/ui/lesson_sheet.dart';
import 'package:wuselwall/features/school/ui/open_timetable_editor.dart';
import 'package:wuselwall/features/school/ui/school_week_grid.dart';
import 'package:wuselwall/features/school/ui/timetable_import_menu.dart';

/// The adult home's Stundenplan (specs/15 "Views", specs/09): a child switcher, the
/// week for the chosen child as a paper grid, and the line for tomorrow's things.
final scheduleSection = HomeSection(
  icon: Icons.school_outlined,
  label: (l10n) => l10n.scheduleTitle,
  body: const ContentWidth(child: ScheduleBody()),
);

/// The section's body. Empty states lead to the setup page or the editor.
class ScheduleBody extends ConsumerWidget {
  const ScheduleBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(schoolDataProvider);
    return AsyncValueView(
      value: data,
      onRetry: () => ref.invalidate(schoolDataProvider),
      data: (d) {
        if (!d.hasSchool) return const _SetupCard();
        return _Children(data: d);
      },
    );
  }
}

class _Children extends ConsumerWidget {
  const _Children({required this.data});

  final SchoolData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final children = ref.watch(schoolChildrenProvider);
    return AsyncValueView(
      value: children,
      onRetry: () => ref.invalidate(membersProvider),
      data: (kids) {
        if (kids.isEmpty) {
          return EmptyView(message: l10n.schoolNoChildren);
        }
        final picked = ref.watch(selectedChildIdProvider);
        final child =
            kids.where((k) => k.id == picked).firstOrNull ?? kids.first;
        final choices = <Widget>[
          for (final k in kids)
            ChoiceChip(
              showCheckmark: false,
              avatar: MemberAvatar(member: _boardMember(context, k), size: 24),
              selectedColor: context.ww.member(k.color).tint,
              backgroundColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: k.id == child.id
                    ? context.ww.member(k.color).ink
                    : Theme.of(context).colorScheme.outline,
                width: k.id == child.id ? 2 : 1,
              ),
              labelStyle: TextStyle(
                color: k.id == child.id
                    ? context.ww.member(k.color).ink
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: k.id == child.id
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(k.displayName, overflow: TextOverflow.ellipsis),
                  ),
                  if (k.id == child.id) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check,
                      size: 18,
                      color: context.ww.member(k.color).ink,
                    ),
                  ],
                ],
              ),
              selected: k.id == child.id,
              onSelected: (_) =>
                  ref.read(selectedChildIdProvider.notifier).select(k.id),
            ),
        ];
        final thisWeek = TextButton(
          onPressed: ref.read(selectedWeekProvider.notifier).thisWeek,
          child: Text(l10n.schoolThisWeek),
        );
        final actions = <Widget>[
          Tooltip(
            message: l10n.schoolEditSchool,
            child: TextButton.icon(
              icon: const Icon(Icons.school_outlined),
              label: Text(l10n.schoolEditSchool),
              onPressed: () async {
                if (await ensureGuardian(context, ref) && context.mounted) {
                  unawaited(context.push(Routes.schoolSetup));
                }
              },
            ),
          ),
          Tooltip(
            message: l10n.schoolEditTimetable,
            child: TextButton.icon(
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text(l10n.schoolEditTimetable),
              onPressed: () => openTimetableEditor(
                context,
                ref,
                data: data,
                profileId: child.id,
              ),
            ),
          ),
          TimetableImportMenu(profileId: child.id),
        ];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final selection = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: choices,
                );
                final editing = Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                );
                final wide =
                    constraints.maxWidth /
                        MediaQuery.textScalerOf(context).scale(1) >=
                    800;
                final toolbar = Row(
                  children: [
                    Expanded(child: selection),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: thisWeek,
                    ),
                    Expanded(child: wide ? editing : const SizedBox.shrink()),
                  ],
                );
                if (wide) return toolbar;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    selection,
                    Center(child: thisWeek),
                    editing,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _Week(data: data, child: child),
          ],
        );
      },
    );
  }
}

/// The identity member as the board's member (for its avatar): a child by definition
/// here, since only children are shown.
BoardMember _boardMember(BuildContext context, Member m) => BoardMember(
  id: m.id,
  displayName: m.displayName,
  color: m.color,
  kind: MemberKind.child,
);

class _Week extends ConsumerWidget {
  const _Week({required this.data, required this.child});

  final SchoolData data;
  final Member child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final monday = ref.watch(selectedWeekProvider);
    final sunday = monday.add(const Duration(days: 6));
    final week = ref.watch(schoolWeekProvider((monday, sunday)));
    final dates = [for (var i = 0; i < 5; i++) monday.add(Duration(days: i))];
    final navigation = ref.read(selectedWeekProvider.notifier);
    final now = ref.watch(nowProvider);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final pack = ref.watch(schoolWeekProvider((tomorrow, tomorrow)));
    final tomorrowItems =
        pack.value?.dayOf(child.id, tomorrow)?.equipment ?? const <String>[];

    // A swipe is the header's week before and after (specs/09 "Gestures").
    return SwipeStepper(
      onPrevious: navigation.previous,
      onNext: navigation.next,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SchoolWeekHeader(
            dates: dates,
            raisedIndex: _raisedIndex([
              for (final date in dates) week.value?.dayOf(child.id, date),
            ], dates.indexWhere((date) => _sameDay(date, now))),
            onPrevious: navigation.previous,
            onNext: navigation.next,
          ),
          const SizedBox(height: 4),
          AsyncValueView(
            value: week,
            onRetry: () => ref.invalidate(schoolWeekProvider),
            data: (w) {
              final timetable = w.timetableOf(child.id);
              if (timetable == null) {
                return _EnterCard(data: data, child: child, monday: monday);
              }
              final days = [for (final d in dates) w.dayOf(child.id, d)];
              final allHoliday = days.every(
                (d) => d?.free == FreeReason.holiday,
              );
              if (allHoliday) {
                final first = days.first!;
                return _HolidayBand(
                  data: data,
                  name: first.holidayName ?? '',
                  monday: monday,
                  sunday: sunday,
                );
              }
              final todayIndex = dates.indexWhere((d) => _sameDay(d, now));
              final raised = _raisedIndex(days, todayIndex);
              final isTodayRaised = raised != null && raised == todayIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 48),
                child: SchoolWeekGrid(
                  showHeader: false,
                  timetable: timetable,
                  dates: dates,
                  days: days,
                  raisedIndex: raised,
                  nowMinutes: isTodayRaised ? now.hour * 60 + now.minute : null,
                  iconKeyOf: data.iconKeyFor,
                  onLesson: (i, lesson) =>
                      _openSheet(context, ref, dates[i], lesson),
                ),
              );
            },
          ),
          if (tomorrowItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.boardPackTomorrow(tomorrowItems.join(', ')),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }

  /// Today's column when today is a school day, else the next school day of the week.
  static int? _raisedIndex(List<SchoolDay?> days, int todayIndex) {
    final from = todayIndex < 0 ? 0 : todayIndex;
    for (var i = from; i < days.length; i++) {
      if (days[i]?.hasSchool ?? false) return i;
    }
    return null;
  }

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    Lesson lesson,
  ) async {
    final timetable = data.timetables
        .where(
          (t) =>
              t.profileId == child.id &&
              !date.isBefore(t.validFrom) &&
              (t.validTo == null || !date.isAfter(t.validTo!)),
        )
        .firstOrNull;
    if (timetable == null) return;
    await showLessonSheet(
      context,
      data: data,
      timetable: timetable,
      date: date,
      lesson: lesson,
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Ferien over the whole week: one wide band, the name and its dates, nothing else.
class _HolidayBand extends StatelessWidget {
  const _HolidayBand({
    required this.data,
    required this.name,
    required this.monday,
    required this.sunday,
  });

  final SchoolData data;
  final String name;
  final DateTime monday;
  final DateTime sunday;

  @override
  Widget build(BuildContext context) {
    final holiday = data.holidays
        .where((h) => h.name == name && h.overlaps(monday, sunday))
        .firstOrNull;
    final range = holiday == null
        ? ''
        : _range(holiday.startsOn, holiday.endsOn);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.l10n.schoolHolidayBand(name, range),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  /// "12.–24.10." within one month, "30.9.–2.10." across two.
  static String _range(DateTime a, DateTime b) => a.month == b.month
      ? '${a.day}.–${b.day}.${b.month}.'
      : '${a.day}.${a.month}.–${b.day}.${b.month}.';
}

class _SetupCard extends ConsumerWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Card(
    title: context.l10n.schoolSetupCardTitle,
    body: context.l10n.schoolSetupCardBody,
    action: context.l10n.schoolSetupAction,
    onPressed: () async {
      if (await ensureGuardian(context, ref) && context.mounted) {
        unawaited(context.push(Routes.schoolSetup));
      }
    },
  );
}

class _EnterCard extends ConsumerWidget {
  const _EnterCard({
    required this.data,
    required this.child,
    required this.monday,
  });

  final SchoolData data;
  final Member child;
  final DateTime monday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Card(
      body: l10n.schoolEnterTimetableBody(child.displayName),
      action: l10n.schoolEnterTimetableAction,
      onPressed: () async {
        await openTimetableEditor(
          context,
          ref,
          data: data,
          profileId: child.id,
          monday: monday,
        );
      },
      secondary: OutlinedButton.icon(
        onPressed: () =>
            showTimetableImportMenu(context, ref, profileId: child.id),
        icon: const Icon(Icons.upload_file_outlined),
        label: Text(l10n.schoolImportAction),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    this.title,
    required this.body,
    required this.action,
    required this.onPressed,
    this.secondary,
  });

  final String? title;
  final String body;
  final String action;
  final VoidCallback onPressed;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) => EmptyView(
    title: title,
    message: body,
    actions: [
      FilledButton(onPressed: onPressed, child: Text(action)),
      ?secondary,
    ],
  );
}

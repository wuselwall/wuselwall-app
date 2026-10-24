import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/ui/calendar_page.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/calendar/ui/new_tradition_sheet.dart';
import 'package:wuselwall/features/home/application/home_section.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// The adult home's calendar destination.
final calendarSection = HomeSection(
  icon: Icons.calendar_month,
  label: (l10n) => l10n.calendarTitle,
  body: const CalendarPage(),
  appBar: (context, actions) {
    final wide = homeBarIsWide(context);
    return AppBar(
      centerTitle: false,
      titleSpacing: 12,
      title: Row(
        children: [
          if (wide) ...[
            Text(context.l10n.calendarTitle),
            const SizedBox(width: 24),
          ],
          Expanded(child: CalendarToolbar(compact: !wide)),
        ],
      ),
      actions: actions,
    );
  },
  fab: (context) => const CalendarFab(),
);

/// The calendar's buttons: a new event, and above it a new family tradition (specs/27
/// "Familientraditionen"), only where the server knows traditions.
class CalendarFab extends ConsumerWidget {
  const CalendarFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // A new event starts on the day in view, not always today.
    DateTime day() =>
        ref.read(calendarViewProvider).newEventDay(ref.read(nowProvider));
    final newEvent = FloatingActionButton.extended(
      onPressed: () =>
          context.push(Routes.eventNew, extra: EventEditArgs(date: day())),
      icon: const Icon(Icons.add),
      label: Text(l10n.calendarNewEvent),
    );
    if (!ref.watch(lighterDaySupportedProvider)) return newEvent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'calendar-new-tradition',
          tooltip: l10n.calendarNewTradition,
          onPressed: () {
            final now = ref.read(nowProvider);
            final today = DateTime(now.year, now.month, now.day);
            final inView = day();
            // A tradition starts from now on, even when an earlier week is in view.
            final from = inView.isBefore(today) ? today : inView;
            unawaited(
              showNewTraditionSheet(
                context,
                from: from,
                ownStart: DateTime(
                  from.year,
                  from.month,
                  from.day,
                  math.min(now.hour + 1, 23),
                ),
              ),
            );
          },
          child: const Icon(Icons.celebration_outlined),
        ),
        const SizedBox(height: 12),
        newEvent,
      ],
    );
  }
}

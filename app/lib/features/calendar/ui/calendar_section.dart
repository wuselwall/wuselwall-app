import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/ui/calendar_page.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/home/application/home_section.dart';

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
  fab: (context) => FloatingActionButton.extended(
    // A new event starts on the day in view, not always today.
    onPressed: () {
      final container = ProviderScope.containerOf(context);
      final day = container
          .read(calendarViewProvider)
          .newEventDay(container.read(nowProvider));
      context.push(Routes.eventNew, extra: EventEditArgs(date: day));
    },
    icon: const Icon(Icons.add),
    label: Text(context.l10n.calendarNewEvent),
  ),
);

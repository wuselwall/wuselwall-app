import 'dart:async';

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
/// "Familientraditionen"), only where the server knows traditions. A phone keeps the
/// one button, so less of the grid is covered; the tradition starts from a tile on the
/// *Neuer Termin* page there.
class CalendarFab extends ConsumerWidget {
  const CalendarFab({super.key});

  /// Below this width only "Neuer Termin" floats.
  static const phoneWidth = 600.0;

  /// Whether the small tradition button floats above "Neuer Termin" in this [context].
  static bool showsTradition(BuildContext context, WidgetRef ref) =>
      ref.watch(lighterDaySupportedProvider) &&
      MediaQuery.sizeOf(context).width >= phoneWidth;

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
    if (!showsTradition(context, ref)) return newEvent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'calendar-new-tradition',
          tooltip: l10n.calendarNewTradition,
          onPressed: () => unawaited(
            openNewTradition(
              context,
              inView: day(),
              now: ref.read(nowProvider),
            ),
          ),
          child: const Icon(Icons.celebration_outlined),
        ),
        const SizedBox(height: 12),
        newEvent,
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/domain/tradition_starters.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/rituals/domain/event_icons.dart';

/// A starter's name in the household's language.
String traditionStarterName(AppLocalizations l10n, TraditionStarter s) =>
    switch (s) {
      TraditionStarter.gameNight => l10n.traditionStarterGameNight,
      TraditionStarter.pizzaFriday => l10n.traditionStarterPizzaFriday,
      TraditionStarter.filmNight => l10n.traditionStarterFilmNight,
      TraditionStarter.sundayBreakfast => l10n.traditionStarterSundayBreakfast,
      TraditionStarter.storyTime => l10n.traditionStarterStoryTime,
      TraditionStarter.dayOut => l10n.traditionStarterDayOut,
    };

/// Kalender → *Neue Tradition* (specs/27 "Familientraditionen"): the six starters and
/// the family's own. A choice opens the ordinary editor with a weekly, whole-family
/// tradition filled in, so the day and the time are changed there before anything is
/// saved. [from] is the first day the tradition may start on; [ownStart] is where the
/// family's own one begins.
Future<void> showNewTraditionSheet(
  BuildContext context, {
  required DateTime from,
  required DateTime ownStart,
}) async {
  final template = await showModalBottomSheet<TraditionTemplate>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _NewTraditionSheet(from: from, ownStart: ownStart),
  );
  if (template == null || !context.mounted) return;
  // The push completes when the editor closes; nothing waits for it.
  unawaited(
    context.push(Routes.eventNew, extra: EventEditArgs(tradition: template)),
  );
}

class _NewTraditionSheet extends StatelessWidget {
  const _NewTraditionSheet({required this.from, required this.ownStart});

  final DateTime from;
  final DateTime ownStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    String when(TraditionTemplate t) {
      final weekday = context.weekdayLong(t.start);
      return t.allDay
          ? l10n.traditionStarterWhenAllDay(weekday)
          : l10n.traditionStarterWhen(
              weekday,
              context.time(TimeOfDay.fromDateTime(t.start)),
            );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Tokens.space3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space4,
                0,
                Tokens.space4,
                Tokens.space2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.calendarNewTradition,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: Tokens.space1),
                  Text(l10n.traditionStartersHelp),
                ],
              ),
            ),
            for (final s in TraditionStarter.values)
              Builder(
                builder: (context) {
                  final t = s.template(
                    title: traditionStarterName(l10n, s),
                    from: from,
                    mealWords: l10n.traditionStarterPizzaMeal,
                  );
                  return ListTile(
                    key: ValueKey('tradition-starter-${s.name}'),
                    leading: EmojiPicture(eventIconAsset(s.iconKey)!, size: 36),
                    title: Text(t.title),
                    subtitle: Text(when(t)),
                    onTap: () => Navigator.of(context).pop(t),
                  );
                },
              ),
            const Divider(),
            ListTile(
              key: const ValueKey('tradition-starter-own'),
              leading: const SizedBox(
                width: 36,
                child: Icon(Icons.edit_outlined),
              ),
              title: Text(l10n.traditionStarterOwn),
              subtitle: Text(l10n.traditionStarterOwnHelp),
              onTap: () =>
                  Navigator.of(context).pop(TraditionTemplate.own(ownStart)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/application/event_template_providers.dart';
import 'package:wuselwall/features/calendar/data/event_templates_repository.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/event_templates.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/calendar/ui/new_tradition_sheet.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/domain/event_icons.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// A built-in template's name in the household's language.
String eventStarterName(AppLocalizations l10n, EventStarter s) => switch (s) {
  EventStarter.birthday => l10n.eventStarterBirthday,
  EventStarter.guestDinner => l10n.eventStarterGuestDinner,
  EventStarter.kidsParty => l10n.eventStarterKidsParty,
  EventStarter.sportsEvent => l10n.eventStarterSportsEvent,
  EventStarter.doctor => l10n.eventStarterDoctor,
  EventStarter.performance => l10n.eventStarterPerformance,
  EventStarter.dayOut => l10n.eventStarterDayOut,
  EventStarter.holiday => l10n.eventStarterHoliday,
};

/// Kalender → *Neuer Termin* (specs/28): tiles to start from, the family's frequent
/// events and saved templates first, then the built-in ones with *Ohne Vorlage*. A
/// tile opens the ordinary editor filled in; saving there closes this page too.
class EventTemplatePage extends ConsumerWidget {
  const EventTemplatePage({this.args, super.key});

  /// The day the new event is for ([EventEditArgs.date]); the rest is ignored.
  final EventEditArgs? args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(nowProvider);
    final day = dateOnly(args?.date ?? now);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final actor = ref.watch(actingProfileProvider);
    final active = [
      for (final m in members)
        if (m.active) (id: m.id, isChild: m.isChild),
    ];
    // Optional extras: when they fail or the server lacks them, the built-in tiles
    // still start every event.
    final suggestions = ref.watch(eventSuggestionsProvider(day)).value ?? [];
    final saved = ref.watch(eventTemplatesProvider).value ?? [];

    Widget section(String title, List<Widget> tiles) => SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space4,
            Tokens.space4,
            Tokens.space4,
            Tokens.space2,
          ),
          sliver: SliverToBoxAdapter(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
          // A fixed height: room for a picture, a two-line name and one line.
          sliver: SliverGrid.list(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisExtent: 140,
              mainAxisSpacing: Tokens.space2,
              crossAxisSpacing: Tokens.space2,
            ),
            children: tiles,
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarNewEvent)),
      body: ContentWidth(
        child: SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.space4,
                  Tokens.space3,
                  Tokens.space4,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(l10n.eventTemplatesIntro),
                ),
              ),
              if (suggestions.isNotEmpty)
                section(l10n.eventTemplatesSuggested, [
                  for (final t in suggestions)
                    _TemplateTile(
                      key: ValueKey('event-template-suggested-${t.signature}'),
                      template: t,
                      onTap: () => unawaited(_open(context, t)),
                      menu: [
                        (
                          label: l10n.eventTemplateKeep,
                          icon: Icons.bookmark_add_outlined,
                          run: () => unawaited(_keep(context, ref, t)),
                        ),
                        (
                          label: l10n.eventTemplateHide,
                          icon: Icons.visibility_off_outlined,
                          run: () => unawaited(_hide(context, ref, t)),
                        ),
                      ],
                    ),
                ]),
              if (saved.isNotEmpty)
                section(l10n.eventTemplatesSaved, [
                  for (final t in saved)
                    _TemplateTile(
                      key: ValueKey('event-template-saved-${t.id}'),
                      template: t,
                      onTap: () => unawaited(_open(context, t)),
                      menu: [
                        (
                          label: l10n.eventTemplateDelete,
                          icon: Icons.delete_outline,
                          run: () => unawaited(_delete(context, ref, t)),
                        ),
                      ],
                    ),
                ]),
              // Below the family's own tiles the built-in ones are the "more"; alone,
              // they are simply the templates.
              section(
                suggestions.isEmpty && saved.isEmpty
                    ? l10n.eventTemplatesBuiltIn
                    : l10n.eventTemplatesBuiltInMore,
                [
                  _TemplateTile(
                    key: const ValueKey('event-template-blank'),
                    title: l10n.eventTemplateBlank,
                    line: l10n.eventTemplateBlankHelp,
                    icon: Icons.edit_outlined,
                    onTap: () => unawaited(_open(context, null)),
                  ),
                  // A weekly family tradition starts here too (specs/27), so a phone
                  // needs no second floating button over the calendar.
                  if (ref.watch(lighterDaySupportedProvider))
                    _TemplateTile(
                      key: const ValueKey('event-template-tradition'),
                      title: l10n.calendarNewTradition,
                      // One example: a second one no longer fits a phone's tile.
                      line: '${l10n.traditionStarterGameNight}, …',
                      icon: Icons.celebration_outlined,
                      onTap: () => unawaited(
                        openNewTradition(context, inView: day, now: now),
                      ),
                    ),
                  for (final s in EventStarter.values)
                    Builder(
                      builder: (context) {
                        final t = s.template(
                          title: eventStarterName(l10n, s),
                          members: active,
                          actor: actor,
                        );
                        return _TemplateTile(
                          key: ValueKey('event-template-builtin-${s.name}'),
                          template: t,
                          icon: s == EventStarter.doctor
                              ? Icons.medical_services_outlined
                              : null,
                          onTap: () => unawaited(_open(context, t)),
                        );
                      },
                    ),
                ],
              ),
              const SliverToBoxAdapter(child: SizedBox(height: Tokens.space6)),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the editor; when it saved, this page closes as well.
  Future<void> _open(BuildContext context, EventTemplate? template) async {
    final saved = await context.push<bool>(
      Routes.eventEdit,
      extra: EventEditArgs(date: args?.date, template: template),
    );
    if (saved == true && context.mounted) context.pop(true);
  }

  Future<void> _keep(
    BuildContext context,
    WidgetRef ref,
    EventTemplate t,
  ) async {
    final result = await ref
        .read(eventTemplatesRepositoryProvider)
        .save(actor: ref.read(actingProfileProvider), template: t);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ref
          ..invalidate(eventTemplatesProvider)
          ..invalidate(eventSuggestionsProvider);
        context.showMessage(context.l10n.eventTemplateSavedNote);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _hide(
    BuildContext context,
    WidgetRef ref,
    EventTemplate t,
  ) async {
    final result = await ref
        .read(eventTemplatesRepositoryProvider)
        .hideSuggestion(
          actor: ref.read(actingProfileProvider),
          signature: t.signature!,
        );
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(eventSuggestionsProvider);
        context.showMessage(context.l10n.eventTemplateHidden);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    EventTemplate t,
  ) async {
    final result = await ref
        .read(eventTemplatesRepositoryProvider)
        .delete(actor: ref.read(actingProfileProvider), id: t.id!);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ref
          ..invalidate(eventTemplatesProvider)
          ..invalidate(eventSuggestionsProvider);
        context.showMessage(context.l10n.eventTemplateDeleted);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }
}

typedef _MenuEntry = ({String label, IconData icon, VoidCallback run});

/// One tile: a picture, the name and when and how long. A tile with a [menu] opens it
/// from its ⋮ button or a long press.
class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.onTap,
    this.template,
    this.title,
    this.line,
    this.icon,
    this.menu = const [],
    super.key,
  });

  final EventTemplate? template;

  /// Overrides for a tile without a template (*Ohne Vorlage*).
  final String? title;
  final String? line;

  /// Shown when the template has no picture.
  final IconData? icon;
  final VoidCallback onTap;
  final List<_MenuEntry> menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = template;
    final name = title ?? t?.title ?? '';
    final asset = eventIconAsset(t?.iconKey);
    final menuButton = GlobalKey<PopupMenuButtonState<int>>();
    final lineStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: menu.isEmpty
            ? null
            : () => menuButton.currentState?.showButtonMenu(),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(Tokens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 40,
                    child: asset != null
                        ? EmojiPicture(asset, size: 40)
                        : Icon(
                            icon ??
                                (t?.kind == EventKind.presence
                                    ? Icons.place_outlined
                                    : Icons.event_outlined),
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                  ),
                  const Spacer(),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: Tokens.space1),
                  if (line != null || t == null)
                    Text(
                      line ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: lineStyle,
                    )
                  else
                    _TemplateLine(template: t, style: lineStyle),
                ],
              ),
            ),
            if (menu.isNotEmpty)
              Positioned(
                top: 0,
                right: 0,
                child: PopupMenuButton<int>(
                  key: menuButton,
                  tooltip: context.l10n.eventTemplateMenu(name),
                  icon: const Icon(Icons.more_vert),
                  onSelected: (i) => menu[i].run(),
                  itemBuilder: (context) => [
                    for (final (i, entry) in menu.indexed)
                      PopupMenuItem(
                        value: i,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(entry.icon),
                          title: Text(entry.label),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A template's line on its tile: the long form ("15:00 · 3 Std. · 6× benutzt") where
/// it fits the tile, else the count short ("… · 6×") with the long form as its tooltip,
/// so the caption never ends in "6× benu…".
class _TemplateLine extends StatelessWidget {
  const _TemplateLine({required this.template, required this.style});

  final EventTemplate template;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final long = templateLine(context, template);
      final text = Text(
        long,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
      if (template.count == null) return text;
      // Measured as the Text draws it: the inherited style (the app's font) under it.
      final painter = TextPainter(
        text: TextSpan(
          text: long,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final fits = painter.width <= box.maxWidth;
      painter.dispose();
      if (fits) return text;
      return Tooltip(
        message: long,
        child: Text(
          templateLine(context, template, shortCount: true),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          semanticsLabel: long,
          style: style,
        ),
      );
    },
  );
}

/// A tile's line: when and how long, a yearly repeat, and how often a suggestion was
/// entered ("18:30 · 3 Std.", "Ganztägig · Jährlich", "6× benutzt", or with
/// [shortCount] only "6×").
String templateLine(
  BuildContext context,
  EventTemplate t, {
  bool shortCount = false,
}) {
  final l10n = context.l10n;
  final minute = t.startMinute;
  final days = t.days ?? 1;
  return [
    if (t.allDay)
      days > 1 ? l10n.eventTemplateDays(days) : l10n.eventTemplateAllDay
    else ...[
      if (minute != null)
        context.time(TimeOfDay(hour: minute ~/ 60, minute: minute % 60)),
      if (t.durationMinutes case final length?) templateLength(l10n, length),
    ],
    if (t.yearly) l10n.eventRepeatYearly,
    if (t.count case final count?)
      shortCount
          ? l10n.eventTemplateCountShort(count)
          : l10n.eventTemplateCount(count),
  ].join(' · ');
}

/// "3 Std.", "1 Std. 30 Min." or "45 Min.".
String templateLength(AppLocalizations l10n, int minutes) {
  if (minutes < 60) return l10n.eventTemplateMinutes(minutes);
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0
      ? l10n.eventTemplateHours(hours)
      : l10n.eventTemplateHoursMinutes(hours, rest);
}

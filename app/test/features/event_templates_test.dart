import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/calendar/application/event_template_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/event_templates.dart';
import 'package:wuselwall/features/calendar/ui/editor/event_draft.dart';
import 'package:wuselwall/features/calendar/ui/editor/recurrence.dart';
import 'package:wuselwall/features/calendar/ui/event_editor_page.dart';
import 'package:wuselwall/features/calendar/ui/event_template_page.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_event_templates.dart';
import '../support/fakes.dart';

// Kalender → Neuer Termin starts on tiles (specs/28): built-in templates, the family's
// saved ones and suggestions from its history. Test data only.

final _de = AppLocalizationsDe();

final _day = DateTime(2026, 10, 14); // a Wednesday

const _family = [
  (id: 'p-1', isChild: false),
  (id: 'p-2', isChild: false),
  (id: 'p-3', isChild: true),
];

/// Today at 09:30, so the calendar's own "today" and the app clock agree.
DateTime _todayMorning() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 9, 30);
}

Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

/// The calendar tab with [templates] as the server's saved templates and suggestions.
Future<FakeCalendarRepository> _calendarTab(
  WidgetTester t, {
  FakeEventTemplatesRepository? templates,
  bool supported = true,
  Locale locale = const Locale('de'),
  Size? size,
}) async {
  final cal = FakeCalendarRepository();
  await pumpApp(
    t,
    size: size ?? const Size(1000, 1600),
    overrides: [
      ...baseOverrides(
        identity: FakeIdentityRepository(current: device()),
        now: _todayMorning(),
      ),
      if (!supported)
        eventTemplatesSupportedProvider.overrideWith((ref) => false),
    ],
    calendar: cal,
    eventTemplates: templates,
    locale: locale,
  );
  await openTab(t, lookupAppLocalizations(locale).calendarTitle);
  return cal;
}

Future<void> _newEvent(WidgetTester t, {String label = 'Neuer Termin'}) =>
    _tap(t, find.widgetWithText(FloatingActionButton, label));

void main() {
  group('built-in templates', () {
    test('the birthday is all day, yearly, a countdown, for the family', () {
      final t = EventStarter.birthday.template(
        title: 'Geburtstag',
        members: _family,
        actor: 'p-1',
      );
      final draft = EventDraft.fromTemplate(
        t,
        day: _day,
        defaultHour: 10,
        activeMembers: {'p-1', 'p-2', 'p-3'},
      );
      expect(draft.isAllDay, isTrue);
      expect(draft.start, _day);
      expect(draft.end, _day);
      expect(draft.recurrence.kind, RepeatKind.yearly);
      expect(draft.recurrence.toRrule(draft.start), 'FREQ=YEARLY');
      expect(draft.countdown, isTrue);
      expect(draft.iconKey, 'cake');
      expect(draft.attendeeIds, {'p-1', 'p-2', 'p-3'});
      expect(draft.keyTouched, isFalse);
    });

    test('guests for dinner start at 18:30 and last three hours', () {
      final t = EventStarter.guestDinner.template(
        title: 'Gäste',
        members: _family,
        actor: 'p-1',
      );
      final draft = EventDraft.fromTemplate(
        t,
        day: _day,
        defaultHour: 10,
        activeMembers: {'p-1', 'p-2', 'p-3'},
      );
      expect(draft.start, DateTime(2026, 10, 14, 18, 30));
      expect(draft.end, DateTime(2026, 10, 14, 21, 30));
      expect(draft.recurrence.kind, RepeatKind.never);
    });

    test('a holiday covers seven days', () {
      final t = EventStarter.holiday.template(
        title: 'Ferien',
        members: _family,
        actor: 'p-1',
      );
      final draft = EventDraft.fromTemplate(
        t,
        day: _day,
        defaultHour: 10,
        activeMembers: {'p-1'},
      );
      expect(draft.end, DateTime(2026, 10, 20));
      expect(
        draft.toEvent(attendees: ['p-1'], key: true).endDate,
        DateTime(2026, 10, 20),
      );
    });

    test(
      'the doctor starts at the next full hour, for the person creating it',
      () {
        final t = EventStarter.doctor.template(
          title: 'Arzt',
          members: _family,
          actor: 'p-2',
        );
        final draft = EventDraft.fromTemplate(
          t,
          day: _day,
          defaultHour: 11,
          activeMembers: {'p-1', 'p-2', 'p-3'},
        );
        expect(draft.start, DateTime(2026, 10, 14, 11));
        expect(draft.end, DateTime(2026, 10, 14, 12));
        expect(draft.attendeeIds, {'p-2'});
        expect(draft.iconKey, isNull);
      },
    );

    test(
      "a children's party invites the children, or the actor without any",
      () {
        expect(
          EventStarter.kidsParty
              .template(title: 'x', members: _family, actor: 'p-1')
              .attendeeIds,
          {'p-3'},
        );
        expect(
          EventStarter.kidsParty
              .template(
                title: 'x',
                members: _family.take(2).toList(),
                actor: 'p-1',
              )
              .attendeeIds,
          {'p-1'},
        );
      },
    );
  });

  group('saved templates', () {
    test('a template keeps only active members and its display choice', () {
      const t = EventTemplate(
        id: 't-1',
        title: 'Turnier',
        startMinute: 9 * 60,
        durationMinutes: 300,
        attendeeIds: {'p-1', 'p-gone'},
        location: 'Sportplatz',
        importance: Importance.key,
      );
      final draft = EventDraft.fromTemplate(
        t,
        day: _day,
        defaultHour: 10,
        activeMembers: {'p-1', 'p-2'},
      );
      expect(draft.attendeeIds, {'p-1'});
      expect(draft.location, 'Sportplatz');
      expect(draft.keyTouched, isTrue);
      expect(draft.key, isTrue);
      expect(draft.end, DateTime(2026, 10, 14, 14));
    });

    test('a draft saves its time of day and length, not its date', () {
      final draft =
          EventDraft(
              start: DateTime(2026, 10, 14, 14, 15),
              end: DateTime(2026, 10, 14, 15, 45),
              title: '  Schwimmen ',
              location: 'Hallenbad',
              iconKey: 'swim',
              tentative: true,
              recurrence: const Recurrence(kind: RepeatKind.weekly),
            )
            ..keyTouched = true
            ..key = false;
      final json = draft.toTemplate(attendees: ['p-3', 'p-1']).toJson();
      expect(json, {
        'title': 'Schwimmen',
        'icon_key': 'swim',
        'kind': 'appointment',
        'presence_state': null,
        'is_all_day': false,
        'start_minute': 14 * 60 + 15,
        'duration_minutes': 90,
        'days': null,
        'attendee_ids': ['p-3', 'p-1'],
        'location': 'Hallenbad',
        'description': null,
        'importance': 'normal',
        'countdown': false,
      });
    });

    test('an all-day draft saves its days', () {
      final draft = EventDraft(
        start: DateTime(2026, 10, 14),
        end: DateTime(2026, 10, 16),
        title: 'Lager',
        isAllDay: true,
      );
      final json = draft.toTemplate(attendees: const []).toJson();
      expect(json['days'], 3);
      expect(json['start_minute'], isNull);
      expect(json['importance'], isNull);
    });

    test('rows and suggestions parse', () {
      final row = EventTemplate.fromJson({
        'id': 't-1',
        'title': 'Homeoffice',
        'icon_key': null,
        'kind': 'presence',
        'presence_state': 'home_office',
        'is_all_day': true,
        'start_minute': null,
        'duration_minutes': null,
        'days': 1,
        'attendee_ids': ['p-1'],
        'location': null,
        'description': null,
        'importance': null,
        'countdown': false,
        'created_by_profile_id': 'p-1',
        'created_at': '2026-10-25T10:00:00Z',
        'updated_at': '2026-10-25T10:00:00Z',
      });
      expect(row.kind, EventKind.presence);
      expect(row.isSaved, isTrue);
      expect(row.importance, isNull);

      final s = EventTemplate.fromSuggestion({
        'signature': 'oma kommt',
        'title': 'Oma kommt',
        'icon_key': 'house',
        'kind': 'appointment',
        'presence_state': null,
        'is_all_day': false,
        'start_minute': 900,
        'duration_minutes': 180,
        'days': null,
        'attendee_ids': ['p-1', 'p-2'],
        'location': null,
        'count': 5,
        'last_on': '2026-10-12',
      });
      expect(s.isSuggestion, isTrue);
      expect(s.count, 5);
      // Kept as a template, a suggestion is inserted: it sends no id.
      expect(s.toJson().containsKey('id'), isFalse);
    });
  });

  group('the yearly repeat', () {
    test('reads back from a stored rule', () {
      final start = DateTime(2026, 3, 1);
      final yearly = Recurrence.fromStored(
        start: start,
        rrule: 'FREQ=YEARLY',
        rdates: const [],
      );
      expect(yearly.kind, RepeatKind.yearly);
      final counted = Recurrence.fromStored(
        start: start,
        rrule: 'FREQ=YEARLY;COUNT=5',
        rdates: const [],
      );
      expect(counted.kind, RepeatKind.yearly);
      expect(counted.toRrule(start), 'FREQ=YEARLY;COUNT=5');
      // Anything more stays the family's own rule.
      expect(
        Recurrence.fromStored(
          start: start,
          rrule: 'FREQ=YEARLY;BYMONTH=3',
          rdates: const [],
        ).kind,
        RepeatKind.custom,
      );
    });
  });

  test('lengths read naturally', () {
    expect(templateLength(_de, 45), '45 Min.');
    expect(templateLength(_de, 180), '3 Std.');
    expect(templateLength(_de, 90), '1 Std. 30 Min.');
  });

  group('the new-event page', () {
    testWidgets(
      'a built-in tile opens the editor filled in; saving closes both',
      (t) async {
        final cal = await _calendarTab(t);
        await _newEvent(t);
        expect(find.byType(EventTemplatePage), findsOneWidget);
        expect(find.text(_de.eventTemplatesBuiltIn), findsOneWidget);

        await _tap(
          t,
          find.byKey(const ValueKey('event-template-builtin-birthday')),
        );
        expect(find.byType(EventEditorPage), findsOneWidget);
        expect(
          find.widgetWithText(TextField, _de.eventStarterBirthday),
          findsOneWidget,
        );

        await _tap(t, find.widgetWithText(FilledButton, _de.save));
        expect(find.byType(EventTemplatePage), findsNothing);
        expect(find.byType(EventEditorPage), findsNothing);
        final saved = cal.saved.single;
        expect(saved.title, _de.eventStarterBirthday);
        expect(saved.isAllDay, isTrue);
        expect(saved.rrule, 'FREQ=YEARLY');
        expect(saved.countdown, isTrue);
        expect(saved.iconKey, 'cake');
      },
    );

    testWidgets('back from the editor returns to the tiles', (t) async {
      await _calendarTab(t);
      await _newEvent(t);
      await _tap(
        t,
        find.byKey(const ValueKey('event-template-builtin-dayOut')),
      );
      await _tap(t, find.byType(BackButton));
      expect(find.byType(EventTemplatePage), findsOneWidget);
    });

    testWidgets(
      'a narrow tile says the count short, the long form as tooltip',
      (t) async {
        final templates = FakeEventTemplatesRepository(
          suggested: const [
            EventTemplate(
              signature: 'oma kommt',
              count: 6,
              title: 'Oma & Opa kommen',
              startMinute: 15 * 60,
              durationMinutes: 180,
            ),
          ],
        );
        await _calendarTab(t, templates: templates, size: const Size(360, 640));
        await _newEvent(t);
        // Never "6× benu…": "6×" with the whole line in the tooltip.
        expect(find.byTooltip('15:00 · 3 Std. · 6× benutzt'), findsOneWidget);
        expect(find.text('15:00 · 3 Std. · 6×'), findsOneWidget);
      },
    );

    testWidgets('a family tradition starts from its own tile', (t) async {
      await _calendarTab(t);
      await _newEvent(t);
      final tile = find.byKey(const ValueKey('event-template-tradition'));
      await t.ensureVisible(tile);
      await _tap(t, tile);
      expect(
        find.byKey(const ValueKey('tradition-starter-own')),
        findsOneWidget,
      );
    });

    testWidgets('saved templates and suggestions come first', (t) async {
      final templates = FakeEventTemplatesRepository(
        templates: const [
          EventTemplate(
            id: 't-1',
            title: 'Fußballturnier',
            iconKey: 'football',
            startMinute: 9 * 60,
            durationMinutes: 300,
            attendeeIds: {kidId},
            location: 'Sportplatz Ost',
          ),
        ],
        suggested: const [
          EventTemplate(
            signature: 'oma kommt',
            count: 5,
            title: 'Oma kommt',
            startMinute: 15 * 60,
            durationMinutes: 180,
          ),
        ],
      );
      final cal = await _calendarTab(t, templates: templates);
      await _newEvent(t);
      expect(find.text(_de.eventTemplatesSuggested), findsOneWidget);
      expect(find.text(_de.eventTemplatesSaved), findsOneWidget);
      // The long form where it fits the tile, else "5×" with the long form as tooltip.
      expect(
        find.text('15:00 · 3 Std. · 5× benutzt').evaluate().length +
            find.byTooltip('15:00 · 3 Std. · 5× benutzt').evaluate().length,
        1,
      );
      // Below the family's own tiles the built-in ones are "Weitere Vorlagen".
      expect(find.text(_de.eventTemplatesBuiltInMore), findsOneWidget);
      expect(templates.suggestionDays.single, dateOnly(_todayMorning()));

      await _tap(t, find.byKey(const ValueKey('event-template-saved-t-1')));
      expect(find.widgetWithText(TextField, 'Sportplatz Ost'), findsOneWidget);
      await _tap(t, find.widgetWithText(FilledButton, _de.save));
      final saved = cal.saved.single;
      expect(saved.title, 'Fußballturnier');
      expect(saved.attendeeIds, [kidId]);
      expect(saved.startsAt!.hour, 9);
      expect(saved.endsAt!.difference(saved.startsAt!).inHours, 5);
    });

    testWidgets('a suggestion is hidden or kept from its menu', (t) async {
      final templates = FakeEventTemplatesRepository(
        suggested: const [
          EventTemplate(signature: 'oma kommt', count: 3, title: 'Oma kommt'),
          EventTemplate(signature: 'zahnarzt', count: 4, title: 'Zahnarzt'),
        ],
      );
      await _calendarTab(t, templates: templates);
      await _newEvent(t);

      await _tap(t, find.byTooltip(_de.eventTemplateMenu('Oma kommt')));
      await _tap(t, find.text(_de.eventTemplateHide));
      expect(templates.hidden, ['oma kommt']);
      expect(
        find.byKey(const ValueKey('event-template-suggested-oma kommt')),
        findsNothing,
      );

      await _tap(t, find.byTooltip(_de.eventTemplateMenu('Zahnarzt')));
      await _tap(t, find.text(_de.eventTemplateKeep));
      expect(templates.saved.single.title, 'Zahnarzt');
      expect(
        find.byKey(const ValueKey('event-template-saved-tpl-1')),
        findsOneWidget,
      );
    });

    testWidgets('a saved template is deleted from its menu', (t) async {
      final templates = FakeEventTemplatesRepository(
        templates: const [EventTemplate(id: 't-9', title: 'Elternabend')],
      );
      await _calendarTab(t, templates: templates);
      await _newEvent(t);
      await _tap(t, find.byTooltip(_de.eventTemplateMenu('Elternabend')));
      await _tap(t, find.text(_de.eventTemplateDelete));
      expect(templates.deleted, ['t-9']);
      expect(find.text(_de.eventTemplatesSaved), findsNothing);
    });

    testWidgets('the editor saves what it shows as a template', (t) async {
      final templates = FakeEventTemplatesRepository();
      await _calendarTab(t, templates: templates);
      await _newEvent(t);
      await _tap(t, find.byKey(const ValueKey('event-template-blank')));

      // A template needs a title, as an event does.
      await _tap(t, find.byKey(const ValueKey('event-save-as-template')));
      expect(templates.saved, isEmpty);
      expect(find.text(_de.eventTitleRequired), findsOneWidget);

      await t.enterText(find.byType(TextField).first, 'Elternabend');
      await t.pump();
      await _tap(t, find.byKey(const ValueKey('event-save-as-template')));
      expect(templates.saved.single.title, 'Elternabend');
      expect(templates.saved.single.attendeeIds, {guardianId});
      expect(find.text(_de.eventTemplateSavedNote), findsOneWidget);
    });

    testWidgets('an older server shows only the built-in templates', (t) async {
      final templates = FakeEventTemplatesRepository(
        templates: const [EventTemplate(id: 't-1', title: 'Turnier')],
        suggested: const [
          EventTemplate(signature: 'oma kommt', count: 3, title: 'Oma kommt'),
        ],
      );
      await _calendarTab(t, templates: templates, supported: false);
      await _newEvent(t);
      expect(find.text(_de.eventTemplatesSaved), findsNothing);
      expect(find.text(_de.eventTemplatesSuggested), findsNothing);
      expect(templates.suggestionDays, isEmpty);
      await _tap(t, find.byKey(const ValueKey('event-template-blank')));
      expect(
        find.byKey(const ValueKey('event-save-as-template')),
        findsNothing,
      );
    });

    for (final lang in ['en', 'fr', 'es']) {
      testWidgets('the templates have their own names in $lang', (t) async {
        final l10n = lookupAppLocalizations(Locale(lang));
        await _calendarTab(t, locale: Locale(lang));
        await _newEvent(t, label: l10n.calendarNewEvent);
        expect(find.text(l10n.eventStarterBirthday), findsOneWidget);
        expect(find.text(l10n.eventTemplateBlank), findsOneWidget);
        expect(l10n.eventStarterBirthday, isNot(_de.eventStarterBirthday));
        expect(t.takeException(), isNull);
      });
    }
  });
}

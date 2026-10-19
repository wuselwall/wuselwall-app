import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/data/feed_repository.dart';
import 'package:wuselwall/features/calendar/domain/usual_week.dart';
import 'package:wuselwall/features/calendar/ui/busy_until_sheet.dart';

import '../support/fakes.dart';

/// A week board whose only content is [members] (with their baselines). With [usual],
/// its days carry (empty) usual places, as a server with the usual week sends them.
WeekBoard boardWith(List<Map<String, dynamic>> members, {bool usual = false}) =>
    WeekBoard.fromJson({
      'week_start': '2026-10-12',
      'today': '2026-10-14',
      'generated_at': '2026-10-14T08:00:00Z',
      'members': members,
      'presence': <Map<String, dynamic>>[],
      'timetables': <Map<String, dynamic>>[],
      'days': [
        for (var i = 0; i < 7; i++)
          {
            'date': '2026-10-${12 + i}',
            'events': <Map<String, dynamic>>[],
            'busy_until': <Map<String, dynamic>>[],
            'school': <Map<String, dynamic>>[],
            if (usual) 'usual': <Map<String, dynamic>>[],
          },
      ],
      'open_tasks': <Map<String, dynamic>>[],
      'shopping_count': 0,
    });

const _papaRow = {
  'id': guardianId,
  'display_name': 'Papa',
  'color': '#2E7D6B',
  'kind': 'adult',
};

/// Records every feed call; the token it creates is fixed so the URL is predictable.
class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository({this.tokensList = const []});

  final List<FeedToken> tokensList;
  final created = <({String? actor, String label, FeedFilter filter})>[];
  final revoked = <({String? actor, String id})>[];

  @override
  Future<Result<List<FeedToken>>> tokens() async => Ok(tokensList);

  @override
  Future<Result<CreatedFeedToken>> create({
    required String? actor,
    required String label,
    required FeedFilter filter,
  }) async {
    created.add((actor: actor, label: label, filter: filter));
    return const Ok(CreatedFeedToken(id: 'f-new', token: 'tok123'));
  }

  @override
  Future<Result<void>> revoke({
    required String? actor,
    required String id,
  }) async {
    revoked.add((actor: actor, id: id));
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Records the busy-until, baseline and usual-week writes, and serves [usual]; everything
/// else is the in-memory fake.
class RecordingCalendar extends FakeCalendarRepository {
  RecordingCalendar({this.usual = const []});

  final List<UsualWeek> usual;
  final busy = <({String profileId, DateTime date, TimeOfDay? until})>[];
  final baselines =
      <({String profileId, PresenceState? state, String? label})>[];
  final weeks = <UsualWeek>[];

  @override
  Future<Result<List<UsualWeek>>> usualWeeks() async => Ok(usual);

  @override
  Future<Result<void>> setUsualWeek({
    required String? actor,
    required UsualWeek week,
  }) async {
    weeks.add(week);
    return const Ok(null);
  }

  @override
  Future<Result<void>> setBusyUntil({
    required String? actor,
    required String profileId,
    required DateTime date,
    TimeOfDay? until,
  }) async {
    busy.add((profileId: profileId, date: date, until: until));
    return const Ok(null);
  }

  @override
  Future<Result<void>> setBaseline({
    required String? actor,
    required String profileId,
    PresenceState? state,
    String? label,
  }) async {
    baselines.add((profileId: profileId, state: state, label: label));
    return const Ok(null);
  }
}

FeedToken _token({
  String id = 'f1',
  String label = 'Arbeits-Laptop Outlook',
  DateTime? revokedAt,
}) => FeedToken(
  id: id,
  label: label,
  filter: const FeedFilter(profileIds: [guardianId]),
  createdAt: DateTime(2026, 10, 1),
  lastFetchedAt: DateTime.now().subtract(const Duration(hours: 3)),
  fetchCount: 4,
  revokedAt: revokedAt,
);

void main() {
  group('feed filter JSON', () {
    test('new subscriptions carry appointments only, school off', () {
      expect(const FeedFilter().toJson(), {
        'profile_ids': <String>[],
        'calendar_ids': <String>[],
        'kinds': ['appointment'],
        'school': 'off',
        'subscribed': false,
      });
    });

    test('a token saved before the subscribed key reads as not subscribed', () {
      final filter = FeedFilter.fromJson({
        'profile_ids': <String>[],
        'calendar_ids': <String>[],
        'kinds': ['appointment'],
        'school': 'off',
      });
      expect(filter.subscribed, isFalse);
      expect(
        FeedFilter.fromJson({
          'kinds': ['appointment'],
          'subscribed': true,
        }).subscribed,
        isTrue,
      );
    });

    test('feedAddress and webcalAddress build the subscription URL', () {
      expect(
        feedAddress('https://api.example.org/', 'abc'),
        'https://api.example.org/functions/v1/ics/abc.ics',
      );
      expect(
        webcalAddress('https://api.example.org/functions/v1/ics/abc.ics'),
        'webcal://api.example.org/functions/v1/ics/abc.ics',
      );
    });
  });

  group('Familienkalender teilen', () {
    testWidgets('create sends label and filter, then shows the URL once', (
      tester,
    ) async {
      final feeds = FakeFeedRepository();
      await pumpApp(
        tester,
        overrides: [
          ...baseOverrides(identity: FakeIdentityRepository(current: device())),
          feedRepositoryProvider.overrideWithValue(feeds),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      container.read(routerProvider).go(Routes.feedTokens);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Arbeits-Laptop Outlook',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Abo erstellen'));
      await tester.pumpAndSettle();

      expect(feeds.created, hasLength(1));
      expect(feeds.created.single.actor, guardianId);
      expect(feeds.created.single.label, 'Arbeits-Laptop Outlook');
      expect(feeds.created.single.filter.toJson(), {
        'profile_ids': <String>[],
        'calendar_ids': <String>[],
        'kinds': ['appointment'],
        'school': 'off',
        'subscribed': false,
      });

      const url = 'http://localhost/functions/v1/ics/tok123.ics';
      final shown = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((w) => w.data)
          .toList();
      expect(shown, contains(url));
      expect(shown, contains('webcal://localhost/functions/v1/ics/tok123.ics'));
    });

    testWidgets(
      'the subscribed switch is off by default and sends true when on',
      (tester) async {
        final feeds = FakeFeedRepository();
        await pumpApp(
          tester,
          overrides: [
            ...baseOverrides(
              identity: FakeIdentityRepository(current: device()),
            ),
            feedRepositoryProvider.overrideWithValue(feeds),
          ],
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        );
        container.read(routerProvider).go(Routes.feedTokens);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Mit Vereinen');
        await tester.pumpAndSettle();
        final switchFinder = find.widgetWithText(
          SwitchListTile,
          'Kalender von außen einschließen',
        );
        expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
        expect(
          find.text(
            'Termine aus importierten Kalendern (z. B. Verein, Müllabfuhr) erscheinen auch im Abo.',
          ),
          findsOneWidget,
        );

        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Abo erstellen'));
        await tester.pumpAndSettle();

        expect(feeds.created.single.filter.subscribed, isTrue);
        expect(feeds.created.single.filter.toJson()['subscribed'], isTrue);
      },
    );

    testWidgets('revoke asks for confirmation and revokes that token only', (
      tester,
    ) async {
      final feeds = FakeFeedRepository(tokensList: [_token()]);
      await pumpApp(
        tester,
        overrides: [
          ...baseOverrides(identity: FakeIdentityRepository(current: device())),
          feedRepositoryProvider.overrideWithValue(feeds),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      container.read(routerProvider).go(Routes.feedTokens);
      await tester.pumpAndSettle();

      expect(find.text('Arbeits-Laptop Outlook'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Sperren'));
      await tester.pumpAndSettle();
      expect(feeds.revoked, isEmpty, reason: 'confirmation comes first');

      await tester.tap(find.widgetWithText(FilledButton, 'Sperren'));
      await tester.pumpAndSettle();
      expect(feeds.revoked, [(actor: guardianId, id: 'f1')]);
    });

    testWidgets('a revoked token is shown greyed without a revoke button', (
      tester,
    ) async {
      final feeds = FakeFeedRepository(
        tokensList: [_token(revokedAt: DateTime(2026, 10, 2))],
      );
      await pumpApp(
        tester,
        overrides: [
          ...baseOverrides(identity: FakeIdentityRepository(current: device())),
          feedRepositoryProvider.overrideWithValue(feeds),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      container.read(routerProvider).go(Routes.feedTokens);
      await tester.pumpAndSettle();

      expect(find.textContaining('Gesperrt'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sperren'), findsNothing);
    });
  });

  group('Übliche Woche', () {
    testWidgets(
      'sets Monday, copies it to Tuesday to Friday and keeps week B',
      (tester) async {
        final calendar = RecordingCalendar(
          usual: [
            UsualWeek(
              profileId: guardianId,
              anchor: DateTime(2026, 10, 19),
              slots: const [
                UsualSlot(
                  week: 1,
                  weekday: 1,
                  place: UsualPlace(state: PresenceState.off),
                ),
              ],
            ),
          ],
        );
        await pumpApp(
          tester,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
          ),
          board: FakeBoardRepository(boardWith([_papaRow], usual: true)),
          calendar: calendar,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        );
        container.read(routerProvider).go(Routes.baselines);
        await tester.pumpAndSettle();

        expect(find.text('Nichts eingetragen'), findsNWidgets(7));
        await tester.tap(find.text('Mo'));
        await tester.pumpAndSettle();
        expect(find.text('Papa am Montag'), findsOneWidget);
        await tester.tap(find.text('Homeoffice').last);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Übernehmen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dienstag bis Freitag wie Montag'));
        await tester.pumpAndSettle();
        expect(find.text('Nichts eingetragen'), findsNWidgets(2));
        await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
        await tester.pumpAndSettle();

        final week = calendar.weeks.single;
        expect(week.anchor, DateTime(2026, 10, 19));
        expect(
          [
            for (final s in week.slots.where((s) => s.week == 0))
              (s.weekday, s.place.state),
          ]..sort((a, b) => a.$1.compareTo(b.$1)),
          [for (var d = 1; d <= 5; d++) (d, PresenceState.homeOffice)],
        );
        expect(week.day(1, week: 1).single.state, PresenceState.off);
        expect(calendar.baselines, isEmpty);
        await unmountApp(tester, container);
      },
    );
    Future<(RecordingCalendar, ProviderContainer)> openWeek(
      WidgetTester tester, {
      List<UsualWeek> usual = const [],
    }) async {
      final calendar = RecordingCalendar(usual: usual);
      await pumpApp(
        tester,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        board: FakeBoardRepository(boardWith([_papaRow], usual: true)),
        calendar: calendar,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      container.read(routerProvider).go(Routes.baselines);
      await tester.pumpAndSettle();
      return (calendar, container);
    }

    testWidgets('sets a day in two time slots', (tester) async {
      final (calendar, container) = await openWeek(tester);

      await tester.tap(find.text('Mo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zeitfenster'));
      await tester.pumpAndSettle();
      expect(find.text('Von 8:00'), findsOneWidget);
      await tester.tap(find.text('Zeitfenster hinzufügen'));
      await tester.pumpAndSettle();
      expect(find.text('Von 12:00'), findsOneWidget);
      expect(find.text('Bis 16:00'), findsOneWidget);
      await tester.tap(
        find.byType(DropdownButtonFormField<PresenceState>).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Homeoffice').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Übernehmen'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Übernehmen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();

      final monday = calendar.weeks.single.day(1);
      expect(monday.map((p) => (p.state, p.starts, p.ends)), [
        (
          PresenceState.working,
          const TimeOfDay(hour: 8, minute: 0),
          const TimeOfDay(hour: 12, minute: 0),
        ),
        (
          PresenceState.homeOffice,
          const TimeOfDay(hour: 12, minute: 0),
          const TimeOfDay(hour: 16, minute: 0),
        ),
      ]);
      await unmountApp(tester, container);
    });

    testWidgets('switches on alternating weeks with this week as week B', (
      tester,
    ) async {
      final (calendar, container) = await openWeek(tester);

      await tester.tap(find.text('Abwechselnde Wochen (A/B)'));
      await tester.pumpAndSettle();
      expect(find.text('Welche Woche ist diese Woche?'), findsOneWidget);
      await tester.tap(find.text('Woche B'));
      await tester.pumpAndSettle();
      expect(find.text('Diese Woche ist Woche B.'), findsOneWidget);
      await tester.tap(find.text('Mo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Homeoffice').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Übernehmen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();

      // Today is Wednesday 14 October: week A started on Monday 5 October.
      final week = calendar.weeks.single;
      expect(week.anchor, DateTime(2026, 10, 5));
      expect(week.day(1, week: 1).single.state, PresenceState.homeOffice);
      expect(week.day(1), isEmpty);
      await unmountApp(tester, container);
    });

    testWidgets('switching alternating off keeps week B for later', (
      tester,
    ) async {
      final (calendar, container) = await openWeek(
        tester,
        usual: [
          UsualWeek(
            profileId: guardianId,
            anchor: DateTime(2026, 10, 12),
            slots: const [
              UsualSlot(
                weekday: 2,
                place: UsualPlace(state: PresenceState.working),
              ),
              UsualSlot(
                week: 1,
                weekday: 2,
                place: UsualPlace(state: PresenceState.off),
              ),
            ],
          ),
        ],
      );

      expect(find.text('Diese Woche ist Woche A.'), findsOneWidget);
      await tester.tap(find.text('Abwechselnde Wochen (A/B)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();

      final week = calendar.weeks.single;
      expect(week.anchor, isNull);
      expect(week.slots.map((s) => (s.week, s.weekday)), [(0, 2), (1, 2)]);

      // Switched on again, week B is still there.
      await tester.tap(find.text('Abwechselnde Wochen (A/B)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Woche A').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Woche B'));
      await tester.pumpAndSettle();
      expect(find.text('Nichts eingetragen'), findsNWidgets(6));
      await unmountApp(tester, container);
    });
  });

  // A server without the usual week (its board days carry no usual places).
  group('Grundzustand', () {
    testWidgets('saves the chosen state and own label for a member', (
      tester,
    ) async {
      final calendar = RecordingCalendar();
      final board = boardWith([_papaRow]);
      await pumpApp(
        tester,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        board: FakeBoardRepository(board),
        calendar: calendar,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      container.read(routerProvider).go(Routes.baselines);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Homeoffice').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'zu Hause');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();

      expect(calendar.baselines, [
        (
          profileId: guardianId,
          state: PresenceState.homeOffice,
          label: 'zu Hause',
        ),
      ]);
      await unmountApp(tester, container);
    });

    testWidgets('choosing nothing clears the baseline', (tester) async {
      final calendar = RecordingCalendar();
      await pumpApp(
        tester,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        board: FakeBoardRepository(
          boardWith([
            {
              ..._papaRow,
              'baseline': {'state': 'working', 'label': 'Büro'},
            },
          ]),
        ),
        calendar: calendar,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      container.read(routerProvider).go(Routes.baselines);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nichts eingetragen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();

      expect(calendar.baselines, [
        (profileId: guardianId, state: null, label: null),
      ]);
      await unmountApp(tester, container);
    });
  });

  group('Termine bis', () {
    Future<RecordingCalendar> openSheet(
      WidgetTester tester,
      DateTime day,
    ) async {
      final calendar = RecordingCalendar();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(
              identity: FakeIdentityRepository(current: device()),
            ),
            calendarRepositoryProvider.overrideWithValue(calendar),
          ],
          child: MaterialApp(
            theme: AppTheme.build(UiRegister.adult, Shade.light),
            locale: const Locale('de'),
            supportedLocales: supportedLocales,
            localizationsDelegates: localizationsDelegates,
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showBusyUntilSheet(context, ref, day),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return calendar;
    }

    testWidgets('sets one day', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final day = DateTime(2026, 10, 14);
      final calendar = await openSheet(tester, day);

      await tester.tap(find.text('Uhrzeit wählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Nur diesen Tag'));
      await tester.pumpAndSettle();

      expect(calendar.busy, [
        (
          profileId: guardianId,
          date: day,
          until: const TimeOfDay(hour: 17, minute: 0),
        ),
      ]);
    });

    testWidgets('sets Monday to Friday of the week in five calls', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final calendar = await openSheet(tester, DateTime(2026, 10, 14));

      await tester.tap(find.text('Uhrzeit wählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          OutlinedButton,
          'Für die ganze Woche übernehmen (Mo–Fr)',
        ),
      );
      await tester.pumpAndSettle();

      expect(calendar.busy, hasLength(5));
      expect(calendar.busy.map((c) => c.date), [
        for (var d = 12; d <= 16; d++) DateTime(2026, 10, d),
      ]);
      expect(
        calendar.busy.every(
          (c) => c.until == const TimeOfDay(hour: 17, minute: 0),
        ),
        isTrue,
      );
    });
  });
}

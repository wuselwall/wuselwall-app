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
import 'package:wuselwall/features/calendar/ui/busy_until_sheet.dart';

import '../support/fakes.dart';

/// A week board whose only content is [members] (with their baselines).
WeekBoard boardWith(List<Map<String, dynamic>> members) => WeekBoard.fromJson({
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

/// Records the busy-until and baseline writes; everything else is the in-memory fake.
class RecordingCalendar extends FakeCalendarRepository {
  final busy = <({String profileId, DateTime date, TimeOfDay? until})>[];
  final baselines =
      <({String profileId, PresenceState? state, String? label})>[];

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

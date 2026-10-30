import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/application/kid_logic.dart';
import 'package:wuselwall/features/kid/ui/kid_new_badge.dart';
import 'package:wuselwall/features/kid/ui/kid_today_page.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/wusel/application/celebration.dart';

import '../support/fake_tasks.dart';
import '../support/fakes.dart';

const _emma = 'p-emma';
const _papa = 'p-papa';

Member _emmaMember({DateTime? birthday}) => Member(
  id: _emma,
  displayName: 'Emma',
  color: const Color(0xFFB5306B),
  role: Role.member,
  active: true,
  isChild: true,
  birthday: birthday,
);

const _papaMember = Member(
  id: _papa,
  displayName: 'Papa',
  color: Color(0xFF1D4E89),
  role: Role.guardian,
  active: true,
);

/// A shared kid tablet with Emma and a guardian; on Emma's birthday when [birthday].
class _KidIdentity extends FakeIdentityRepository {
  _KidIdentity({this.birthday = false})
    : super(
        current: device(
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
          profileId: null,
        ),
      );

  final bool birthday;

  @override
  Future<Result<List<Member>>> members({bool includeInactive = false}) async {
    final now = testNow();
    return Ok([
      _emmaMember(
        birthday: birthday ? DateTime(now.year - 8, now.month, now.day) : null,
      ),
      _papaMember,
    ]);
  }
}

/// The `api` layer whose chores answer only when [release] completes.
class _SlowTasksApi extends FakeTasksApi {
  _SlowTasksApi()
    : super(
        tables: {
          'task_instances': [
            instanceRow(id: 'i-1', title: 'Tisch decken', assignee: _emma),
          ],
        },
      );

  final release = Completer<void>();

  @override
  Future<Result<List<T>>> select<T>(
    String view, {
    String columns = '*',
    PostgrestTransformBuilder<PostgrestList> Function(
      PostgrestFilterBuilder<PostgrestList> query,
    )?
    build,
    required T Function(Map<String, dynamic> row) parse,
  }) async {
    if (view == 'task_instances') await release.future;
    return super.select(view, columns: columns, build: build, parse: parse);
  }
}

class _Recorder implements SoundPlayer {
  final played = <Cue>[];

  @override
  Future<void> play(Cue cue) async => played.add(cue);
}

class _Night extends NightNotifier {
  @override
  bool build() => true;
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// This week's board with Pizza for dinner tonight.
WeekBoard _boardWithDinner() {
  final now = testNow();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return WeekBoard.fromJson({
    'week_start': _ymd(monday),
    'today': _ymd(today),
    'generated_at': now.toUtc().toIso8601String(),
    'members': <Map<String, dynamic>>[],
    'presence': <Map<String, dynamic>>[],
    'timetables': <Map<String, dynamic>>[],
    'days': [
      for (var i = 0; i < 7; i++)
        {
          'date': _ymd(DateTime(monday.year, monday.month, monday.day + i)),
          'events': <Map<String, dynamic>>[],
          'busy_until': <Map<String, dynamic>>[],
          'school': <Map<String, dynamic>>[],
          'meal': DateTime(monday.year, monday.month, monday.day + i) == today
              ? {
                  'slot': 'dinner',
                  'time': '18:30',
                  'title': 'Pizza',
                  'cook_id': _papa,
                  'eating': [_emma, _papa],
                  'guests': 0,
                }
              : null,
        },
    ],
    'open_tasks': <Map<String, dynamic>>[],
    'shopping_count': 0,
  });
}

/// Today's "Pizza-Freitag", one of the family's traditions.
Occurrence _traditionToday() {
  final now = testNow();
  final today = DateTime(now.year, now.month, now.day);
  return Occurrence(
    id: 'o-pizza',
    eventId: 'e-pizza',
    calendarId: 'c',
    title: 'Pizza-Freitag',
    kind: EventKind.appointment,
    status: EventStatus.confirmed,
    importance: Importance.normal,
    allDay: true,
    start: today,
    end: today.add(const Duration(days: 1)),
    localStartDate: today,
    localEndDate: today,
    tradition: true,
  );
}

Future<void> _pickEmma(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('kid-pick-$_emma')));
  await tester.pumpAndSettle();
}

/// Picks Emma while her chores still load: the spinner never settles.
Future<void> _pickEmmaWhileLoading(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('kid-pick-$_emma')));
  await tester.pump();
  await tester.pump();
}

Finder _inGreeting(Finder matching) => find.descendant(
  of: find.byKey(const ValueKey('kid-greeting')),
  matching: matching,
);

void main() {
  group('waiting and offline (specs/25: think, only after 2 s)', () {
    testWidgets('a slow day shows the thinking Wusel only after two seconds', (
      tester,
    ) async {
      final api = _SlowTasksApi();
      final container = await pumpApp(
        tester,
        overrides: baseOverrides(identity: _KidIdentity()),
        tasks: api,
      );
      await _pickEmmaWhileLoading(tester);

      expect(find.text('Einen Moment …'), findsNothing);
      expect(
        tester.widget<Wusel>(_inGreeting(find.byType(Wusel))).pose,
        WuselPose.wave,
      );

      await tester.pump(kidThinkAfter - const Duration(milliseconds: 300));
      expect(find.text('Einen Moment …'), findsNothing);

      await tester.pump(const Duration(milliseconds: 400));
      expect(_inGreeting(find.text('Einen Moment …')), findsOneWidget);
      // One Wusel: the thinking one replaces the greeting's.
      expect(_inGreeting(find.byType(Wusel)), findsOneWidget);
      expect(
        tester.widget<Wusel>(_inGreeting(find.byType(Wusel))).pose,
        WuselPose.think,
      );

      // The chores arrive: the greeting comes back.
      api.release.complete();
      await tester.pumpAndSettle();
      expect(find.text('Einen Moment …'), findsNothing);
      expect(_inGreeting(find.textContaining('Emma')), findsOneWidget);
      expect(
        tester.widget<Wusel>(_inGreeting(find.byType(Wusel))).pose,
        WuselPose.wave,
      );
      await unmountApp(tester, container);
    });

    testWidgets('a quick load never shows the thinking Wusel', (tester) async {
      final api = _SlowTasksApi();
      final container = await pumpApp(
        tester,
        overrides: baseOverrides(identity: _KidIdentity()),
        tasks: api,
      );
      await _pickEmmaWhileLoading(tester);
      await tester.pump(const Duration(seconds: 1));
      api.release.complete();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Einen Moment …'), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is Wusel && w.pose == WuselPose.think),
        findsNothing,
      );
      await unmountApp(tester, container);
    });

    testWidgets('offline, Wusel looks for the internet after two seconds', (
      tester,
    ) async {
      final container = await pumpApp(
        tester,
        overrides: baseOverrides(identity: _KidIdentity(), online: false),
        tasks: FakeTasksApi(),
      );
      await _pickEmma(tester);
      expect(find.text('Moment, ich suche das Internet …'), findsNothing);

      await tester.pump(kidThinkAfter);
      expect(
        _inGreeting(find.text('Moment, ich suche das Internet …')),
        findsOneWidget,
      );
      expect(
        tester.widget<Wusel>(_inGreeting(find.byType(Wusel))).pose,
        WuselPose.think,
      );
      await unmountApp(tester, container);
    });
  });

  group('the greeting’s first useful fact (specs/25)', () {
    test('in order: birthday, tradition, first lesson, meal, countdown', () {
      final now = DateTime(2026, 10, 23);
      final school = SchoolDay(
        memberId: _emma,
        starts: const TimeOfDay(hour: 8, minute: 0),
        ends: const TimeOfDay(hour: 13, minute: 0),
        lessons: const [
          Lesson(
            starts: TimeOfDay(hour: 9, minute: 0),
            ends: TimeOfDay(hour: 9, minute: 45),
            subject: 'Sport',
          ),
          Lesson(
            starts: TimeOfDay(hour: 8, minute: 0),
            ends: TimeOfDay(hour: 8, minute: 45),
            subject: 'Mathe',
            status: LessonStatus.cancelled,
          ),
        ],
      );
      const meal = BoardMeal(
        slot: MealSlot.lunch,
        title: 'Nudeln',
        eating: {},
        guests: 0,
      );
      final countdown = Countdown(
        kind: CountdownKind.ferien,
        date: now.add(const Duration(days: 3)),
        title: 'Herbstferien',
      );
      KidFact? at(
        int minutes, {
        bool birthday = false,
        String? tradition,
        SchoolDay? day,
        BoardMeal? lunch,
        Countdown? next,
      }) => kidFirstFact(
        ownBirthday: birthday,
        minutesNow: minutes,
        tradition: tradition,
        school: day,
        meal: lunch,
        countdown: next,
      );

      expect(
        at(
          7 * 60,
          birthday: true,
          tradition: 'Pizza-Freitag',
          day: school,
          lunch: meal,
          next: countdown,
        ),
        isA<KidBirthdayFact>(),
      );
      expect(
        at(7 * 60, tradition: 'Pizza-Freitag', day: school, lunch: meal),
        isA<KidTraditionFact>(),
      );
      // The cancelled first lesson is skipped: school starts with Sport.
      expect(
        (at(7 * 60, day: school, lunch: meal)! as KidFirstLessonFact).subject,
        'Sport',
      );
      // Once school has begun, the meal; lunch only until two.
      expect(at(10 * 60, day: school, lunch: meal), isA<KidMealFact>());
      expect(
        at(15 * 60, day: school, lunch: meal, next: countdown),
        isA<KidCountdownFact>(),
      );
      expect(at(15 * 60, day: school, lunch: meal), isNull);
    });

    testWidgets('tonight’s meal follows the hello', (tester) async {
      final container = await pumpApp(
        tester,
        overrides: baseOverrides(identity: _KidIdentity()),
        tasks: FakeTasksApi(),
        board: FakeBoardRepository(_boardWithDinner()),
      );
      await _pickEmma(tester);
      expect(
        _inGreeting(find.textContaining('Heute Abend gibt es Pizza.')),
        findsOneWidget,
      );
      expect(_inGreeting(find.textContaining('Emma')), findsOneWidget);
      await unmountApp(tester, container);
    });

    testWidgets('today’s tradition comes before the meal', (tester) async {
      final container = await pumpApp(
        tester,
        overrides: baseOverrides(identity: _KidIdentity()),
        tasks: FakeTasksApi(),
        board: FakeBoardRepository(_boardWithDinner()),
        calendar: FakeCalendarRepository([_traditionToday()]),
      );
      await _pickEmma(tester);
      expect(
        _inGreeting(find.textContaining('Heute ist Pizza-Freitag!')),
        findsOneWidget,
      );
      expect(_inGreeting(find.textContaining('Pizza.')), findsNothing);
      await unmountApp(tester, container);
    });
  });

  group('Emma’s birthday, full screen once (specs/25, specs/26)', () {
    Future<(ProviderContainer, _Recorder)> open(
      WidgetTester tester, {
      bool night = false,
    }) async {
      final sounds = _Recorder();
      final container = await pumpApp(
        tester,
        overrides: [
          ...baseOverrides(identity: _KidIdentity(birthday: true))
            ..removeWhere((o) => night && o.origin == nightProvider),
          if (night) nightProvider.overrideWith(_Night.new),
          soundPlayerProvider.overrideWithValue(sounds),
        ],
        tasks: FakeTasksApi(),
      );
      await _pickEmma(tester);
      return (container, sounds);
    }

    testWidgets(
      'the first open celebrates, with the badge sound, then closes',
      (tester) async {
        final (container, sounds) = await open(tester);
        expect(find.byKey(const ValueKey('kid-birthday')), findsOneWidget);
        expect(find.text('Alles Gute zum Geburtstag, Emma!'), findsOneWidget);
        expect(sounds.played, [Cue.badge]);
        final wusel = tester.widget<Wusel>(
          find.descendant(
            of: find.byKey(const ValueKey('kid-birthday')),
            matching: find.byType(Wusel),
          ),
        );
        expect(wusel.pose, WuselPose.cheer);
        expect(wusel.outfit, WuselOutfit.party);

        // Two seconds, then it goes by itself.
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('kid-birthday')), findsNothing);

        // Back on "Mein Tag" later the same day: no second celebration.
        await tester.tap(find.text('Punkte'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mein\u00A0Tag'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('kid-birthday')), findsNothing);
        expect(sounds.played, [Cue.badge]);
        await unmountApp(tester, container);
      },
    );

    testWidgets('a tap skips it', (tester) async {
      final (container, _) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('kid-birthday')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kid-birthday')), findsNothing);
      await unmountApp(tester, container);
    });

    testWidgets('not at night', (tester) async {
      final (container, sounds) = await open(tester, night: true);
      expect(find.byKey(const ValueKey('kid-birthday')), findsNothing);
      expect(sounds.played, isEmpty);
      await unmountApp(tester, container);
    });
  });

  group('the badge (specs/26)', () {
    FakeTasksApi badgeApi() => FakeTasksApi(
      tables: {
        'badge_definitions': [
          {'id': 'b-1', 'title': 'Tischprofi', 'description': null},
        ],
        'badge_awards': [
          {
            'profile_id': _emma,
            'badge_definition_id': 'b-1',
            'awarded_at': testNow().toUtc().toIso8601String(),
          },
        ],
      },
    );

    double scale(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(KidGrowIn),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    testWidgets('grows in from the centre on a spring', (tester) async {
      final container = await pumpApp(
        tester,
        overrides: baseOverrides(identity: _KidIdentity()),
        tasks: badgeApi(),
      );
      // Motion allowed for this test.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      await tester.tap(find.byKey(const ValueKey('kid-pick-$_emma')));
      for (
        var i = 0;
        i < 20 && find.byType(KidGrowIn).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byType(KidGrowIn), findsOneWidget);
      expect(scale(tester), lessThan(0.5));
      await tester.pump(const Duration(milliseconds: 150));
      final early = scale(tester);
      expect(early, greaterThan(0));
      await tester.pumpAndSettle();
      expect(scale(tester), closeTo(1, 0.001));
      await unmountApp(tester, container);
    });

    testWidgets('on Mein Tag the greeting holds up the star: one Wusel', (
      tester,
    ) async {
      final container = await pumpApp(
        tester,
        overrides: baseOverrides(identity: _KidIdentity()),
        tasks: badgeApi(),
      );
      await _pickEmma(tester);
      expect(find.byType(KidGrowIn), findsOneWidget);
      // The card names the badge beside a star, without a Wusel of its own.
      expect(
        find.descendant(
          of: find.byType(KidGrowIn),
          matching: find.byType(Wusel),
        ),
        findsNothing,
      );
      expect(find.byType(Wusel), findsOneWidget);
      expect(
        tester.widget<Wusel>(_inGreeting(find.byType(Wusel))).pose,
        WuselPose.proud,
      );
      await unmountApp(tester, container);
    });

    testWidgets('is there at once under reduced motion', (tester) async {
      final container = await pumpApp(
        tester,
        overrides: baseOverrides(identity: _KidIdentity()),
        tasks: badgeApi(),
      );
      await tester.tap(find.byKey(const ValueKey('kid-pick-$_emma')));
      for (
        var i = 0;
        i < 20 && find.byType(KidGrowIn).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scale(tester), 1);
      await unmountApp(tester, container);
    });
  });

  testWidgets(
    'a reward approved on another device sounds the badge once (specs/26)',
    (tester) async {
      final sounds = _Recorder();
      Map<String, dynamic> redemption(String status) => {
        'id': 'rd-1',
        'reward_id': 'r-film',
        'profile_id': _emma,
        'cost_points': 5,
        'status': status,
        'requested_at': '2026-10-24T08:00:00Z',
      };
      final api = FakeTasksApi(
        tables: {
          'rewards': [
            {
              'id': 'r-film',
              'title': 'Film aussuchen',
              'cost_points': 5,
              'requires_approval': true,
              'is_active': true,
            },
          ],
          'reward_redemptions': [redemption('requested')],
        },
      );
      final container = await pumpApp(
        tester,
        overrides: [
          ...baseOverrides(identity: _KidIdentity()),
          soundPlayerProvider.overrideWithValue(sounds),
        ],
        tasks: api,
      );
      await _pickEmma(tester);
      await tester.tap(find.text('Punkte'));
      await tester.pumpAndSettle();
      expect(sounds.played, isEmpty);

      // A grown-up says yes on their phone; the tasks topic refreshes the list here.
      api.tables['reward_redemptions'] = [redemption('approved')];
      container.invalidate(redemptionsProvider);
      await tester.pumpAndSettle();
      expect(sounds.played, [Cue.badge]);
      expect(find.text('Eingelöst!'), findsOneWidget);

      // Another refresh with nothing new is quiet.
      await tester.pump(const Duration(seconds: 2));
      container.invalidate(redemptionsProvider);
      await tester.pumpAndSettle();
      expect(sounds.played, [Cue.badge]);
      await unmountApp(tester, container);
    },
  );
}

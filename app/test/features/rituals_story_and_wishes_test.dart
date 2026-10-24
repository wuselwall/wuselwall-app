import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/data/rituals_repository.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/rituals/domain/meal_icons.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';
import 'package:wuselwall/features/rituals/ui/meal_wish_widgets.dart';
import 'package:wuselwall/features/rituals/ui/week_review_widgets.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// The week-review story, the wish picker and grown-ups wishing (specs/27).

const _child = Member(
  id: 'm-kid',
  displayName: 'Jack',
  color: Color(0xFFFF8800),
  role: Role.member,
  active: true,
  isChild: true,
);
const _guardian = Member(
  id: 'm-dad',
  displayName: 'David',
  color: Color(0xFF2E7D6B),
  role: Role.guardian,
  active: true,
  sortOrder: 1,
);

/// Monday 19 October 2026; the look-back opens on Sunday the 25th.
final _monday = DateTime(2026, 10, 19);
final _sunday = DateTime(2026, 10, 25);

final _de = lookupAppLocalizations(const Locale('de'));

class _Acting extends ActingProfileNotifier {
  _Acting(this.id);

  final String? id;

  @override
  String? build() => id;
}

/// Remembers what the widgets asked the server to do.
class _FakeRituals implements RitualsRepository {
  final calls = <String>[];

  @override
  Future<Result<void>> setWish({
    required String? actor,
    String? recipeId,
    String? freeText,
    String? iconKey,
    String? wishId,
  }) async {
    calls.add('set $actor $recipeId $freeText $iconKey $wishId');
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WeekReview _review({List<WeekMeal> meals = const []}) => WeekReview(
  weekStart: _monday,
  choresDone: 12,
  members: const [
    WeekHighlight(
      profileId: 'm-kid',
      kind: HighlightKind.badge,
      title: 'Fuchs',
    ),
    WeekHighlight(profileId: 'm-dad', kind: HighlightKind.here),
  ],
  meals: meals,
);

Occurrence _event(
  String title,
  DateTime day, {
  bool tradition = false,
  Importance importance = Importance.normal,
  List<String> attendees = const [],
  EventStatus status = EventStatus.confirmed,
  EventKind kind = EventKind.appointment,
  String? iconKey,
}) => Occurrence(
  id: 'o-$title-${day.day}',
  eventId: 'e-$title',
  calendarId: 'c',
  title: title,
  kind: kind,
  status: status,
  importance: importance,
  allDay: false,
  start: DateTime(day.year, day.month, day.day, 18),
  end: DateTime(day.year, day.month, day.day, 20),
  localStartDate: day,
  localEndDate: day,
  attendeeIds: attendees,
  tradition: tradition,
  iconKey: iconKey,
);

Widget _storyApp({
  WeekReview? review,
  List<Occurrence> occurrences = const [],
  bool reduceMotion = false,
  bool board = false,
  VoidCallback? onClose,
  VoidCallback? onDone,
}) => ProviderScope(
  overrides: [
    membersProvider.overrideWith((ref) async => const [_child, _guardian]),
    weekReviewProvider.overrideWith((ref, week) async => review),
    occurrencesProvider.overrideWith(
      (ref, window) async =>
          OccurrenceWindow(timezone: 'Europe/Berlin', occurrences: occurrences),
    ),
    countdownsProvider.overrideWith((ref) => const <Countdown>[]),
    ritualTodayProvider.overrideWithValue(_sunday),
    lighterDayProvider.overrideWith(
      (ref) => const LighterDay(wusel: WuselPresence.off),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.build(UiRegister.adult, Shade.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('de'),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Scaffold(
          body: WeekReviewStory(
            weekStart: _monday,
            board: board,
            onClose: onClose,
            onDone: onDone,
          ),
        ),
      ),
    ),
  ),
);

Finder _shown(String text) => find.text(text).hitTestable();

Future<void> _tapSide(WidgetTester t, {required bool right}) async {
  final pages = t.getRect(find.byKey(const ValueKey('week-review-pages')));
  await t.tapAt(
    Offset(right ? pages.right - 20 : pages.left + 20, pages.center.dy),
  );
  await t.pumpAndSettle();
}

void main() {
  group('the week-review story', () {
    testWidgets('a tap on the right goes on, on the left goes back', (t) async {
      await t.pumpWidget(
        _storyApp(
          review: _review(
            meals: [WeekMeal(onDate: _monday, slot: 'dinner', title: 'Chili')],
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(_shown(_de.weekReviewTogether), findsOneWidget);
      expect(_shown(_de.weekReviewMoments), findsNothing);

      await _tapSide(t, right: true);
      expect(_shown(_de.weekReviewMoments), findsOneWidget);
      expect(find.textContaining('Neues Abzeichen: Fuchs'), findsOneWidget);

      await _tapSide(t, right: true);
      expect(_shown(_de.weekReviewMeals), findsOneWidget);

      await _tapSide(t, right: false);
      expect(_shown(_de.weekReviewMoments), findsOneWidget);
    });

    testWidgets('a swipe and the arrow keys move it too', (t) async {
      await t.pumpWidget(_storyApp(review: _review()));
      await t.pumpAndSettle();

      await t.fling(
        find.byKey(const ValueKey('week-review-pages')),
        const Offset(-300, 0),
        1000,
      );
      await t.pumpAndSettle();
      expect(_shown(_de.weekReviewMoments), findsOneWidget);

      await t.fling(
        find.byKey(const ValueKey('week-review-pages')),
        const Offset(300, 0),
        1000,
      );
      await t.pumpAndSettle();
      expect(_shown(_de.weekReviewTogether), findsOneWidget);

      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(_shown(_de.weekReviewMoments), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(_shown(_de.weekReviewTogether), findsOneWidget);
    });

    testWidgets('a card with nothing to say is left out, and screen readers '
        'hear which card of how many', (t) async {
      final semantics = t.ensureSemantics();
      // No meals and no traditions: three cards, not five.
      await t.pumpWidget(_storyApp(review: _review()));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel(_de.weekReviewCardOf(1, 3)), findsOneWidget);
      expect(find.text(_de.weekReviewMeals), findsNothing);
      expect(find.text(_de.weekReviewTraditions), findsNothing);

      await t.tap(find.byKey(const ValueKey('week-review-next')));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel(_de.weekReviewCardOf(2, 3)), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('week-review-next')));
      await t.pumpAndSettle();
      expect(_shown(_de.weekReviewNext), findsOneWidget);
      expect(find.bySemanticsLabel(_de.weekReviewCardOf(3, 3)), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a progress segment for every card, filled up to this one', (
      t,
    ) async {
      await t.pumpWidget(_storyApp(review: _review()));
      await t.pumpAndSettle();
      final segments = find.descendant(
        of: find.byType(ExcludeSemantics),
        matching: find.byType(AnimatedContainer),
      );
      expect(segments, findsNWidgets(3));
    });

    testWidgets('under reduced motion a card replaces the one before at once', (
      t,
    ) async {
      await t.pumpWidget(_storyApp(review: _review(), reduceMotion: true));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('week-review-next')));
      // One frame, no time passing: no slide.
      await t.pump();
      expect(_shown(_de.weekReviewMoments), findsOneWidget);
    });

    testWidgets('with motion the next card slides in', (t) async {
      await t.pumpWidget(_storyApp(review: _review()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('week-review-next')));
      await t.pump();
      expect(_shown(_de.weekReviewMoments), findsNothing);
      await t.pumpAndSettle();
      expect(_shown(_de.weekReviewMoments), findsOneWidget);
    });

    testWidgets(
      'closes with its button, with Escape, and after the last card',
      (t) async {
        var closed = 0;
        await t.pumpWidget(
          _storyApp(review: _review(), onClose: () => closed++),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('week-review-close')));
        expect(closed, 1);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(closed, 2);
        for (var i = 0; i < 3; i++) {
          await _tapSide(t, right: true);
        }
        expect(closed, 3);
      },
    );

    testWidgets('on the wall: no close button of its own, and the end returns '
        'to the week', (t) async {
      var done = 0;
      await t.pumpWidget(
        _storyApp(review: _review(), board: true, onDone: () => done++),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('week-review-close')), findsNothing);
      // The wall's targets are 56 px.
      expect(
        t.getSize(find.byKey(const ValueKey('week-review-next'))),
        const Size(56, 56),
      );
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byKey(const ValueKey('week-review-next')));
        await t.pumpAndSettle();
      }
      expect(done, 1);
    });

    testWidgets('a tradition attended is a member\'s moment, and the '
        'traditions that happened get their card', (t) async {
      await t.pumpWidget(
        _storyApp(
          review: _review(),
          occurrences: [
            _event(
              'Spieleabend',
              DateTime(2026, 10, 23),
              tradition: true,
              iconKey: 'game_die',
            ),
          ],
        ),
      );
      await t.pumpAndSettle();
      await _tapSide(t, right: true);
      // David's line was the plain fact; Jack's badge stays first.
      expect(
        find.textContaining(_de.weekHighlightAttended('Spieleabend')),
        findsOneWidget,
      );
      expect(find.textContaining('Neues Abzeichen: Fuchs'), findsOneWidget);
      await _tapSide(t, right: true);
      expect(_shown(_de.weekReviewTraditions), findsOneWidget);
    });
  });

  group('a tradition or key event attended (withEventHighlights)', () {
    const here = WeekHighlight(profileId: 'm-dad', kind: HighlightKind.here);
    const badge = WeekHighlight(
      profileId: 'm-kid',
      kind: HighlightKind.badge,
      title: 'Fuchs',
    );
    List<WeekHighlight> run(List<Occurrence> occ) => withEventHighlights(
      const [badge, here],
      occ,
      weekStart: _monday,
      today: DateTime(2026, 10, 22),
    );

    test('a key event names who was there, never who was not', () {
      final out = run([
        _event(
          'Elternabend',
          DateTime(2026, 10, 20),
          importance: Importance.key,
          attendees: const ['m-dad'],
        ),
      ]);
      expect(out[0].kind, HighlightKind.badge);
      expect(out[1].kind, HighlightKind.attended);
      expect(out[1].title, 'Elternabend');
    });

    test('a tradition without attendees is the whole family\'s, and comes '
        'before a key event', () {
      final out = run([
        _event(
          'Elternabend',
          DateTime(2026, 10, 21),
          importance: Importance.key,
          attendees: const ['m-dad'],
        ),
        _event('Pizza-Freitag', DateTime(2026, 10, 20), tradition: true),
      ]);
      expect(out[1].title, 'Pizza-Freitag');
      // A badge is a bigger moment than an evening at home.
      expect(out[0].kind, HighlightKind.badge);
    });

    test('only what has happened, was not called off and is no presence', () {
      final out = run([
        _event('Zoo', DateTime(2026, 10, 24), tradition: true),
        _event(
          'Spieleabend',
          DateTime(2026, 10, 20),
          tradition: true,
          status: EventStatus.cancelled,
        ),
        _event(
          'Reise',
          DateTime(2026, 10, 20),
          importance: Importance.key,
          attendees: const ['m-dad'],
          kind: EventKind.presence,
        ),
        _event('Vorwoche', DateTime(2026, 10, 18), tradition: true),
        _event('Termin', DateTime(2026, 10, 20), attendees: const ['m-dad']),
      ]);
      expect(out[1].kind, HighlightKind.here);
    });
  });

  group('the wish picker', () {
    final recipes = [
      for (var i = 1; i <= 30; i++)
        Recipe(
          id: 'r-$i',
          title: 'Rezept ${i.toString().padLeft(2, '0')}',
          servingsDefault: 4,
          iconKey: i == 30 ? 'pizza' : null,
        ),
    ];
    final history = [
      MealHistoryEntry(
        title: 'Fischstäbchen',
        times: 6,
        firstOn: DateTime(2026, 5, 1),
        lastOn: DateTime(2026, 10, 20),
        iconKey: 'fish',
      ),
      MealHistoryEntry(
        recipeId: 'r-30',
        title: 'Rezept 30',
        times: 4,
        firstOn: DateTime(2026, 5, 1),
        lastOn: DateTime(2026, 10, 12),
        iconKey: 'pizza',
      ),
    ];

    Widget picker(_FakeRituals repo) => ProviderScope(
      overrides: [
        recipesProvider.overrideWith((ref) async => recipes),
        mealHistoryProvider.overrideWith((ref) async => history),
        ritualTodayProvider.overrideWithValue(_sunday),
        ritualsRepositoryProvider.overrideWithValue(repo),
        mealWishesProvider.overrideWith((ref) async => const <MealWish>[]),
      ],
      child: MaterialApp(
        theme: AppTheme.build(UiRegister.kid, Shade.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showWishPicker(context, ref, 'm-kid'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    testWidgets('offers the family\'s favourites first, with their pictures', (
      t,
    ) async {
      final repo = _FakeRituals();
      await t.pumpWidget(picker(repo));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      final often = t.getTopLeft(find.text(_de.mealsUxSuggestOften));
      final ours = t.getTopLeft(find.text(_de.wishPickerRecipes));
      expect(often.dy, lessThan(ours.dy));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('wish-often-Fischstäbchen')),
          matching: find.byType(EmojiPicture),
        ),
        findsOneWidget,
      );
      // A favourite without a recipe is wished as words, with its picture.
      await t.tap(find.byKey(const ValueKey('wish-often-Fischstäbchen')));
      await t.pumpAndSettle();
      expect(repo.calls, ['set m-kid null Fischstäbchen fish null']);
    });

    testWidgets('every recipe is there, and the search finds one', (t) async {
      final repo = _FakeRituals();
      await t.pumpWidget(picker(repo));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      // More than the first 24.
      expect(find.byKey(const ValueKey('wish-recipe-r-29')), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('wish-search')), '29');
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('wish-recipe-r-28')), findsNothing);
      await t.tap(find.byKey(const ValueKey('wish-recipe-r-29')));
      await t.pumpAndSettle();
      expect(repo.calls, ['set m-kid r-29 null null null']);
    });

    testWidgets('a search without a match says so', (t) async {
      await t.pumpWidget(picker(_FakeRituals()));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('wish-search')),
        'Kaiserschmarrn',
      );
      await t.pumpAndSettle();
      expect(find.text(_de.wishPickerNoMatch), findsOneWidget);
    });

    testWidgets('a wish of one\'s own words carries the picture chosen', (
      t,
    ) async {
      final repo = _FakeRituals();
      await t.pumpWidget(picker(repo));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('wish-text')),
        'Omas Spezial',
      );
      final cake = find.byKey(const ValueKey('wish-icon-cake'));
      await t.ensureVisible(cake);
      await t.pumpAndSettle();
      await t.tap(cake);
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('wish-send')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('wish-send')));
      await t.pumpAndSettle();
      expect(repo.calls, ['set m-kid null Omas Spezial cake null']);
    });

    test('every picture has a name and an asset', () {
      for (final key in mealIconKeys) {
        expect(mealIconAsset(key), 'assets/emoji/meals/$key.png');
        for (final lang in AppLocalizations.supportedLocales) {
          expect(mealIconName(lookupAppLocalizations(lang), key), isNotEmpty);
        }
      }
      expect(mealIconAsset('spaceship'), isNull);
    });
  });

  group('the planner\'s tray', () {
    Widget tray({
      required List<MealWish> wishes,
      String wishesFor = 'children',
      String? acting = 'm-dad',
      _FakeRituals? repo,
    }) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        membersProvider.overrideWith((ref) async => const [_child, _guardian]),
        actingProfileProvider.overrideWith(() => _Acting(acting)),
        lighterDayProvider.overrideWith(
          (ref) => LighterDay(
            values: {'meals.wishes': wishesFor, 'meals.wishes_per_week': 1},
          ),
        ),
        lighterDaySupportedProvider.overrideWith((ref) => true),
        mealWishesProvider.overrideWith((ref) async => wishes),
        ritualTodayProvider.overrideWithValue(DateTime(2026, 10, 28)),
        ritualsRepositoryProvider.overrideWithValue(repo ?? _FakeRituals()),
        recipesProvider.overrideWith((ref) async => const <Recipe>[]),
        mealHistoryProvider.overrideWith(
          (ref) async => const <MealHistoryEntry>[],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.build(UiRegister.adult, Shade.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(body: MealWishTray(weekStart: DateTime(2026, 10, 26))),
      ),
    );

    testWidgets('marks a wish from an earlier week and shows its picture', (
      t,
    ) async {
      await t.pumpWidget(
        tray(
          wishes: [
            MealWish(
              id: 'w-1',
              profileId: 'm-kid',
              title: 'Pfannkuchen',
              iconKey: 'pancakes',
              wishedOn: DateTime(2026, 10, 22),
              earlierWeek: true,
            ),
            MealWish(
              id: 'w-2',
              profileId: 'm-kid',
              title: 'Eis',
              wishedOn: DateTime(2026, 10, 5),
              earlierWeek: true,
            ),
          ],
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('Jack: Pfannkuchen · ${_de.mealsWishEarlier}'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Jack: Eis · ${_de.mealsWishOlder}'),
        findsOneWidget,
      );
      expect(find.byType(EmojiPicture), findsOneWidget);
    });

    testWidgets('a grown-up wishes only when the family says everyone', (
      t,
    ) async {
      await t.pumpWidget(tray(wishes: const []));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('wish-mine')), findsNothing);

      final repo = _FakeRituals();
      await t.pumpWidget(
        tray(wishes: const [], wishesFor: 'everyone', repo: repo),
      );
      await t.pumpAndSettle();
      expect(find.text(_de.mealsWishMine), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('wish-mine')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('wish-text')), 'Steak');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('wish-send')));
      await t.pumpAndSettle();
      expect(repo.calls, ['set m-dad null Steak null null']);

      await t.pumpWidget(tray(wishes: const [], wishesFor: 'off'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('wish-mine')), findsNothing);
    });

    testWidgets('at the limit the grown-up changes their own wish', (t) async {
      final repo = _FakeRituals();
      await t.pumpWidget(
        tray(
          wishes: const [
            MealWish(id: 'w-9', profileId: 'm-dad', title: 'Steak'),
          ],
          wishesFor: 'everyone',
          repo: repo,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(_de.mealsWishMineChange), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('wish-mine')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('wish-text')), 'Fisch');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('wish-send')));
      await t.pumpAndSettle();
      expect(repo.calls, ['set m-dad null Fisch null w-9']);
    });
  });
}

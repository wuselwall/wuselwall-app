import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/data/rituals_repository.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';
import 'package:wuselwall/features/rituals/domain/table_question.dart';
import 'package:wuselwall/features/rituals/ui/meal_wish_widgets.dart';
import 'package:wuselwall/features/rituals/ui/table_question_widgets.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';

/// The wish card, the planning dialog and the table question after the lighter-day
/// review (fixes 1, 2, 4, 5, 6, 8 and 9).

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
);

/// Monday 26 October 2026; "today" is the Wednesday of that week.
final _monday = DateTime(2026, 10, 26);
final _today = DateTime(2026, 10, 28);

class _Acting extends ActingProfileNotifier {
  _Acting(this.id);

  final String id;

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
    calls.add('set $freeText $wishId');
    return const Ok(null);
  }

  @override
  Future<Result<void>> withdrawWish({
    required String? actor,
    required String id,
  }) async {
    calls.add('withdraw $id');
    return const Ok(null);
  }

  @override
  Future<Result<void>> planWish({
    required String? actor,
    required String id,
    required DateTime onDate,
    required String slot,
    bool replace = false,
  }) async {
    calls.add('plan $id ${onDate.day} $slot $replace');
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LighterDay _day({String wishes = 'children', int perWeek = 1}) => LighterDay(
  values: {'meals.wishes': wishes, 'meals.wishes_per_week': perWeek},
);

Widget _app(
  Widget home, {
  List<MealWish> wishes = const [],
  LighterDay? day,
  bool supported = true,
  _FakeRituals? repo,
  List<MealEntry> entries = const [],
  TableMoment? moment,
  UiRegister register = UiRegister.kid,
  String acting = 'm-kid',
}) => ProviderScope(
  overrides: [
    membersProvider.overrideWith((ref) async => const [_child, _guardian]),
    actingProfileProvider.overrideWith(() => _Acting(acting)),
    lighterDayProvider.overrideWith((ref) => day ?? _day()),
    lighterDaySupportedProvider.overrideWith((ref) => supported),
    mealWishesProvider.overrideWith((ref) async => wishes),
    ritualTodayProvider.overrideWithValue(_today),
    ritualsRepositoryProvider.overrideWithValue(repo ?? _FakeRituals()),
    mealEntriesProvider.overrideWith((ref, week) async => entries),
    warmSlotProvider.overrideWith((ref, day) => PlanSlot.dinner),
    tableMomentProvider.overrideWith((ref, lang) => moment),
  ],
  child: MaterialApp(
    theme: AppTheme.build(register, Shade.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('de'),
    home: Scaffold(body: home),
  ),
);

MealWish _wish(String id, String title, {DateTime? plannedOn}) => MealWish(
  id: id,
  profileId: _child.id,
  title: title,
  freeText: title,
  planned: plannedOn != null,
  plannedOn: plannedOn,
  plannedSlot: plannedOn == null ? null : 'dinner',
);

void main() {
  group('the child\'s wish card', () {
    testWidgets('lists every open wish, each to change or take back', (
      t,
    ) async {
      final repo = _FakeRituals();
      await t.pumpWidget(
        _app(
          const SingleChildScrollView(child: KidWishCard(member: _child)),
          day: _day(perWeek: 2),
          wishes: [_wish('w-1', 'Pizza'), _wish('w-2', 'Suppe')],
          repo: repo,
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Pizza'), findsOneWidget);
      expect(find.textContaining('Suppe'), findsOneWidget);
      expect(find.text('Ändern'), findsNWidgets(2));
      expect(find.text('Zurücknehmen'), findsNWidgets(2));
      // Two of two: no room for another.
      expect(find.text('Noch etwas wünschen'), findsNothing);

      await t.tap(find.text('Zurücknehmen').last);
      await t.pumpAndSettle();
      expect(repo.calls, ['withdraw w-2']);
    });

    testWidgets('changing a wish names it, so a second open one is not added', (
      t,
    ) async {
      final repo = _FakeRituals();
      await t.pumpWidget(
        _app(
          const SingleChildScrollView(child: KidWishCard(member: _child)),
          day: _day(perWeek: 2),
          wishes: [_wish('w-1', 'Pizza')],
          repo: repo,
        ),
      );
      await t.pumpAndSettle();
      // One of two open: room for another.
      expect(find.text('Noch etwas wünschen'), findsOneWidget);
      await t.tap(find.text('Ändern'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('wish-text')), 'Nudeln');
      await t.pump();
      await t.tap(find.text('Das wünsche ich mir'));
      await t.pumpAndSettle();
      expect(repo.calls, ['set Nudeln w-1']);
    });

    testWidgets('a planned wish says the weekday, not the full date', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          const SingleChildScrollView(child: KidWishCard(member: _child)),
          wishes: [_wish('w-1', 'Chili', plannedOn: DateTime(2026, 10, 29))],
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Dein Wunsch Chili gibt es am Donnerstag!'),
        findsOneWidget,
      );
    });

    testWidgets('stays away on a server without wishes', (t) async {
      await t.pumpWidget(
        _app(const KidWishCard(member: _child), supported: false),
      );
      await t.pumpAndSettle();
      expect(find.text('Dein Wunschessen'), findsNothing);

      // A server that announces a lighter day but has no meals.wishes setting.
      await t.pumpWidget(
        _app(
          const KidWishCard(member: _child),
          day: const LighterDay(values: {'rituals.table_question': 'off'}),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Dein Wunschessen'), findsNothing);
    });

    testWidgets('the planner\'s tray stays away there too', (t) async {
      await t.pumpWidget(
        _app(
          MealWishTray(weekStart: _monday),
          supported: false,
          wishes: [_wish('w-1', 'Pizza')],
          register: UiRegister.adult,
          acting: 'm-dad',
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Pizza'), findsNothing);
    });
  });

  group('planning a wish', () {
    final chiliToday = MealEntry(
      id: 'e-1',
      onDate: _today,
      slot: PlanSlot.dinner,
      freeText: 'Linsen',
      title: 'Linsen',
    );

    Future<PlannedWish?> open(WidgetTester t) async {
      PlannedWish? picked;
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showDialog<PlannedWish>(
                  context: context,
                  builder: (_) => WishPlanDialog(
                    wish: _wish('w-1', 'Pizza'),
                    weekStart: _monday,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
          entries: [chiliToday],
          register: UiRegister.adult,
          acting: 'm-dad',
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      return picked;
    }

    test('offers no day that has passed', () {
      expect(wishPlanDays(_monday, _today).first, _today);
      expect(wishPlanDays(_monday, _today), hasLength(5));
      // A week wholly past keeps its days rather than offering none.
      expect(wishPlanDays(_monday, DateTime(2026, 11, 9)), hasLength(7));
    });

    testWidgets('names the dish and who wished it', (t) async {
      await open(t);
      expect(find.text('Pizza einplanen'), findsOneWidget);
      expect(find.text('Wunsch von Jack'), findsOneWidget);
    });

    testWidgets('shows what each meal already has and starts on a free one', (
      t,
    ) async {
      await open(t);
      expect(find.text('Linsen'), findsOneWidget);
      expect(find.text('Noch nichts geplant'), findsOneWidget);
      // Dinner is the warm meal but taken; lunch is free, so lunch is chosen.
      final lunch = t.widget<ListTile>(
        find.byKey(const ValueKey('wish-slot-lunch')),
      );
      expect(lunch.selected, isTrue);
    });

    testWidgets('asks before a wish replaces a planned meal', (t) async {
      PlannedWish? picked;
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showDialog<PlannedWish>(
                  context: context,
                  builder: (_) => WishPlanDialog(
                    wish: _wish('w-1', 'Pizza'),
                    weekStart: _monday,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
          entries: [chiliToday],
          register: UiRegister.adult,
          acting: 'm-dad',
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('wish-slot-dinner')));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Einplanen'));
      await t.pumpAndSettle();
      expect(find.text('Essen ersetzen?'), findsOneWidget);
      expect(find.textContaining('Linsen'), findsWidgets);

      // Not replacing leaves the planning dialog open and nothing picked.
      await t.tap(find.text('Abbrechen').last);
      await t.pumpAndSettle();
      expect(picked, isNull);
      expect(find.text('Essen ersetzen?'), findsNothing);

      await t.tap(find.widgetWithText(FilledButton, 'Einplanen'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ersetzen'));
      await t.pumpAndSettle();
      expect(picked, (day: _today, slot: PlanSlot.dinner, replace: true));
    });

    testWidgets('a free meal is planned without asking', (t) async {
      final picked = await open(t);
      expect(picked, isNull);
      await t.tap(find.widgetWithText(FilledButton, 'Einplanen'));
      await t.pumpAndSettle();
      expect(find.text('Essen ersetzen?'), findsNothing);
    });
  });

  group('the table question', () {
    const riddle = TableQuestion(
      key: 'de:q-0001',
      text: 'Was hat Zähne, aber kann nicht beißen?',
      category: 'riddle',
      answer: 'Ein Kamm, der ganz besonders lange Zinken hat',
    );
    final moment = (
      window: 7,
      dinner: true,
      questions: const [riddle],
      householdId: 'h',
      cycleLength: 1,
    );

    testWidgets('is set at 34 on the wall, without a Wusel of its own, and its '
        'answer opens below it', (t) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          const IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 600),
                Expanded(child: Center(child: BoardTableQuestion())),
                SizedBox(width: 120),
              ],
            ),
          ),
          moment: moment,
          register: UiRegister.kiosk,
        ),
      );
      await t.pumpAndSettle();
      final text = t.widget<Text>(
        find.byKey(const ValueKey('board-table-question')),
      );
      expect(text.style!.fontSize, greaterThanOrEqualTo(34));
      expect(find.byType(FamilyWusel), findsNothing);

      await t.tap(find.byTooltip('Antwort zeigen'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('board-table-answer')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    test('shrinks only a question too long for three lines', () {
      TextStyle style(double size) => TextStyle(fontSize: size);
      expect(
        boardQuestionSize('Was war heute schön?', width: 500, style: style),
        34,
      );
      expect(
        boardQuestionSize('Wort ' * 60, width: 500, style: style),
        lessThan(34),
      );
    });

    testWidgets('is put away on Today until the next meal', (t) async {
      await t.pumpWidget(
        _app(
          const TableQuestionCard(),
          moment: moment,
          register: UiRegister.adult,
          acting: 'm-dad',
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(riddle.text), findsOneWidget);
      expect(find.byType(FamilyWusel), findsNothing);
      await t.tap(find.byKey(const ValueKey('table-question-dismiss')));
      await t.pumpAndSettle();
      expect(find.text(riddle.text), findsNothing);
    });

    testWidgets('lets a child add a question of their own', (t) async {
      await t.pumpWidget(
        _app(const TableQuestionCard(kid: true), moment: moment),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('table-question-dismiss')),
        findsNothing,
      );
      // A slim line on the kid home until tapped: the question, no buttons yet.
      expect(find.text(riddle.text), findsOneWidget);
      expect(find.text('Frage hinzufügen'), findsNothing);
      await t.tap(find.text(riddle.text));
      await t.pumpAndSettle();
      expect(find.text('Frage hinzufügen'), findsOneWidget);
    });
  });
}

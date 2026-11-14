import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_mode_store.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_mode.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_tasks.dart';
import '../support/fakes.dart';
import '../support/shopping_flow.dart';
import 'shopping_tiles_test.dart' show entry;

/// Telling the other adults when somebody starts shopping (specs/07 "Telling the
/// others", issue #242): the calls the shopping tab and the trip page make.

final _de = AppLocalizationsDe();

const _startKey = ValueKey('shopping-start');
const _planKey = ValueKey('shopping-mode-plan');
final _tripTitle = find.byKey(const ValueKey('shopping-trip-title'));

void main() {
  final catalog = [entry('Milch', 9), entry('Brot', 7)];

  Future<FakeShoppingRepository> pump(
    WidgetTester t, {
    Result<TripStart>? answer,
    List<String>? serverFeatures,
    ShoppingModeStore? modeStore,
  }) async {
    final items = [item('1', 'Milch'), item('2', 'Brot')];
    final repo = FakeShoppingRepository(items);
    if (answer != null) repo.tripStart = answer;
    await pumpShoppingFlow(
      t,
      catalog,
      items: items,
      repo: repo,
      serverFeatures: serverFeatures,
      modeStore: modeStore,
    );
    return repo;
  }

  Future<void> startShopping(WidgetTester t) async {
    await t.tap(find.byKey(_startKey));
    await t.pumpAndSettle();
  }

  group('"Einkaufen gehen"', () {
    testWidgets(
      'tells the server once, for the current list, and opens the trip',
      (t) async {
        final repo = await pump(t);
        expect(repo.tripStarts, isEmpty);

        await startShopping(t);

        expect(repo.tripStarts, ['l1']);
        expect(_tripTitle, findsOneWidget);
      },
    );

    testWidgets('says that the others are told when somebody was told', (
      t,
    ) async {
      await pump(t, answer: const Ok(TripStart(id: 'r', isNew: true, told: 2)));
      await startShopping(t);

      expect(find.text(_de.shoppingStartTold), findsOneWidget);
      expect(_tripTitle, findsOneWidget);
    });

    testWidgets('says nothing when nobody else is told', (t) async {
      final repo = await pump(
        t,
        answer: const Ok(TripStart(id: 'r', isNew: true, told: 0)),
      );
      await startShopping(t);

      expect(repo.tripStarts, hasLength(1));
      expect(find.text(_de.shoppingStartTold), findsNothing);
      expect(_tripTitle, findsOneWidget);
    });

    testWidgets('says nothing when the trip was only continued', (t) async {
      await pump(
        t,
        answer: const Ok(TripStart(id: 'r', isNew: false, told: 2)),
      );
      await startShopping(t);

      expect(find.text(_de.shoppingStartTold), findsNothing);
      expect(_tripTitle, findsOneWidget);
    });

    testWidgets('shows nothing on a failure, and the trip still opens', (
      t,
    ) async {
      final repo = await pump(t, answer: const Err(NetworkFailure()));
      await startShopping(t);

      expect(repo.tripStarts, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
      expect(t.takeException(), isNull);
      expect(_tripTitle, findsOneWidget);
    });

    testWidgets(
      'a server without the feature is not called, for start or leave',
      (t) async {
        final repo = await pump(t, serverFeatures: const []);
        await startShopping(t);
        expect(_tripTitle, findsOneWidget);

        await t.tap(find.byKey(_planKey));
        await t.pumpAndSettle();

        expect(_tripTitle, findsNothing);
        expect(repo.tripStarts, isEmpty);
        expect(repo.tripLeaves, 0);
      },
    );

    testWidgets('a server that announces the feature is called', (t) async {
      final repo = await pump(t, serverFeatures: const [featureShoppingStart]);
      await startShopping(t);
      await t.tap(find.byKey(_planKey));
      await t.pumpAndSettle();

      expect(repo.tripStarts, ['l1']);
      expect(repo.tripLeaves, 1);
    });
  });

  group('leaving the trip', () {
    testWidgets('"Planen" tells the server once', (t) async {
      final repo = await pump(t);
      await startShopping(t);
      expect(repo.tripLeaves, 0);

      await t.tap(find.byKey(_planKey));
      await t.pumpAndSettle();

      expect(_tripTitle, findsNothing);
      expect(repo.tripLeaves, 1);
    });

    testWidgets('the system back tells the server once', (t) async {
      final repo = await pump(t);
      await startShopping(t);

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();

      expect(_tripTitle, findsNothing);
      expect(repo.tripLeaves, 1);
    });

    testWidgets('finishing the trip tells the server once', (t) async {
      final items = [item('1', 'Milch', checked: true), item('2', 'Brot')];
      final repo = FakeShoppingRepository(items);
      await pumpShoppingFlow(t, catalog, items: items, repo: repo);
      await startShopping(t);

      await t.tap(find.widgetWithText(FilledButton, 'Einkauf beenden'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Einkauf beenden').last);
      await t.pumpAndSettle();

      expect(_tripTitle, findsNothing);
      expect(repo.tripLeaves, 1);
    });
  });

  group('a device left in shopping mode', () {
    testWidgets('reopens the trip without telling anybody', (t) async {
      final repo = await pump(
        t,
        modeStore: MemoryShoppingModeStore(ShoppingMode.shop),
      );
      expect(_tripTitle, findsOneWidget);
      expect(repo.tripStarts, isEmpty);
      expect(find.byType(SnackBar), findsNothing);

      // Leaving it is still the end of a trip.
      await t.tap(find.byKey(_planKey));
      await t.pumpAndSettle();
      expect(repo.tripStarts, isEmpty);
      expect(repo.tripLeaves, 1);
    });
  });

  group('ShoppingRepository', () {
    test(
      'startTrip sends the actor and the list and reads the answer',
      () async {
        final api = FakeTasksApi(
          replies: {
            'shopping_start': {'id': 'run-7', 'new': true, 'told': 2},
          },
        );
        final start = (await ShoppingRepository(
          api,
        ).startTrip(actor: 'p1', listId: 'l1')).unwrap();

        expect(start.id, 'run-7');
        expect(start.isNew, isTrue);
        expect(start.told, 2);
        expect(api.calls.single.name, 'shopping_start');
        expect(api.calls.single.params, {'p_actor': 'p1', 'p_list': 'l1'});
      },
    );

    test('a child\'s trip is recorded nowhere', () async {
      final api = FakeTasksApi(
        replies: {
          'shopping_start': {'id': null, 'new': false, 'told': 0},
        },
      );
      final start = (await ShoppingRepository(api).startTrip(actor: 'kid'))
          .unwrap();

      expect(start.id, isNull);
      expect(start.isNew, isFalse);
      expect(start.told, 0);
      expect(api.calls.single.params, {'p_actor': 'kid', 'p_list': null});
    });

    test('a server without the function is a failure, not a crash', () async {
      final result = await ShoppingRepository(FakeTasksApi())
          .startTrip(actor: 'p1');
      expect(result, isA<Err<TripStart>>());
    });

    test('leaveTrip sends the actor', () async {
      final api = FakeTasksApi(replies: {'shopping_leave': null});
      final result = await ShoppingRepository(api).leaveTrip(actor: 'p1');

      expect(result.isOk, isTrue);
      expect(api.calls.single.name, 'shopping_leave');
      expect(api.calls.single.params, {'p_actor': 'p1'});
    });
  });
}

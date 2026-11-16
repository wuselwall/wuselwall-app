import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/features/trips/application/trip_compare_state.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_trips.dart';
import '../support/trip_page_harness.dart';

final _de = AppLocalizationsDe();

DateTime _d(int day, [int month = 7]) => DateTime(2027, month, day);

String _chf(int cents) => NumberFormat.currency(
  locale: 'de',
  name: 'CHF',
  decimalDigits: cents % 100 == 0 ? 0 : 2,
).format(cents / 100).trim();

Trip _trip({bool dates = true}) => Trip(
  id: 't1',
  title: 'Sardinien',
  stage: dates ? TripStage.planned : TripStage.idea,
  startsOn: dates ? _d(10) : null,
  endsOn: dates ? _d(19) : null,
  currency: 'CHF',
);

TripEntry _flight(
  String id,
  String title, {
  int? price,
  int startDay = 10,
  int? endDay,
  EntryState state = EntryState.option,
  int position = 0,
}) => TripEntry(
  id: id,
  tripId: 't1',
  kind: EntryKind.transport,
  mode: TransportMode.flight,
  title: title,
  state: state,
  priceCents: price,
  fromPlace: 'ZRH',
  toPlace: 'OLB',
  startsOn: _d(startDay),
  startsTime: const TimeOfDay(hour: 10, minute: 40),
  endsOn: _d(endDay ?? startDay),
  endsTime: const TimeOfDay(hour: 12, minute: 5),
  details: '1 Stopp',
  cancelUntil: _d(5),
  priceCheckedOn: _d(12, 6),
  position: position,
);

TripEntry _stay(
  String id,
  String title, {
  int? price,
  required int from,
  required int to,
  EntryState state = EntryState.option,
  int position = 10,
}) => TripEntry(
  id: id,
  tripId: 't1',
  kind: EntryKind.stay,
  title: title,
  state: state,
  priceCents: price,
  startsOn: _d(from),
  endsOn: _d(to),
  position: position,
);

TripEntry _car(
  String id,
  String title, {
  int? price,
  required int from,
  required int to,
  int position = 20,
}) => TripEntry(
  id: id,
  tripId: 't1',
  kind: EntryKind.rental,
  title: title,
  priceCents: price,
  fromPlace: 'OLB',
  toPlace: 'OLB',
  startsOn: _d(from),
  endsOn: _d(to),
  position: position,
);

List<TripEntry> _entries() => [
  _flight('out', 'Flug hin', price: 84000, position: 0),
  _flight('cheap', 'Flug billig', price: 62000, position: 1),
  _flight('back', 'Flug zurück', price: 70000, startDay: 19, position: 2),
  _stay('casa', 'Casa Mare', price: 140000, from: 10, to: 17),
  _stay('sole', 'Hotel Sole', price: 60000, from: 17, to: 19, position: 11),
  _stay(
    'over',
    'Villa Ueberlapp',
    price: 90000,
    from: 14,
    to: 18,
    position: 12,
  ),
  _stay('free', 'Zelt ohne Preis', from: 10, to: 12, position: 13),
  _car('car', 'Mietwagen Alpha', price: 45000, from: 10, to: 19),
  _car('early', 'Mietwagen früh', price: 30000, from: 8, to: 19, position: 21),
  _car('late', 'Mietwagen spät', price: 30000, from: 10, to: 21, position: 22),
];

Future<void> _tick(WidgetTester t, String id) async {
  final tick = find.byKey(ValueKey('tick-$id'));
  await t.ensureVisible(tick);
  await t.pumpAndSettle();
  await t.tap(tick);
  await t.pumpAndSettle();
}

Future<void> _ticks(WidgetTester t, List<String> ids) async {
  for (final id in ids) {
    await _tick(t, id);
  }
}

Future<void> _openWarnings(WidgetTester t) async {
  final toggle = find.byKey(const ValueKey('combo-warnings-toggle'));
  if (toggle.evaluate().isNotEmpty) {
    await t.tap(toggle);
    await t.pumpAndSettle();
  }
}

FakeTripsRepository _repo({
  List<TripEntry>? entries,
  List<TripCombo> combos = const [],
  bool dates = true,
}) => FakeTripsRepository(
  trips: [_trip(dates: dates)],
  entries: entries ?? _entries(),
  combos: combos,
);

void main() {
  group('the options of a kind', () {
    testWidgets('are cards with the same rows, the cheapest marked', (t) async {
      await pumpTripPages(t, trips: _repo());
      expect(find.text('Transport · 3'), findsOneWidget);
      expect(find.text('Unterkünfte · 4'), findsOneWidget);
      expect(find.text('Mietwagen · 3'), findsOneWidget);
      for (final id in ['out', 'cheap', 'back', 'casa', 'car']) {
        expect(
          find.byKey(ValueKey('option-$id'), skipOffstage: false),
          findsOneWidget,
        );
      }
      // One cheapest per kind: the cheap flight, the Zelt has no price so the 600 stay
      // wins, and the two 300 rentals tie.
      expect(
        find.text(_de.tripCompareCheapest, skipOffstage: false),
        findsNWidgets(4),
      );
      final cheapCard = find.byKey(const ValueKey('option-cheap'));
      expect(
        find.descendant(
          of: cheapCard,
          matching: find.text(_de.tripCompareCheapest),
        ),
        findsOneWidget,
      );
      // The same rows: price, the date's rows, the details line, the cancellation, the
      // price's date.
      expect(
        find.descendant(of: cheapCard, matching: find.text(_chf(62000))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cheapCard, matching: find.text('ZRH – OLB')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cheapCard, matching: find.text('1 Stopp')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cheapCard,
          matching: find.text(_de.tripCompareFreeCancel('5. Juli')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cheapCard,
          matching: find.text(_de.tripEntryPriceFrom('12. Juni')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a stay shows its price per night, a rental per day', (
      t,
    ) async {
      await pumpTripPages(t, trips: _repo());
      final casa = find.byKey(const ValueKey('option-casa'));
      await t.ensureVisible(casa);
      expect(
        find.descendant(
          of: casa,
          matching: find.text(_de.tripComparePerNight(_chf(20000))),
        ),
        findsOneWidget,
      );
      final car = find.byKey(const ValueKey('option-car'));
      await t.ensureVisible(car);
      expect(
        find.descendant(
          of: car,
          matching: find.text(_de.tripComparePerDay(_chf(4500))),
        ),
        findsOneWidget,
      );
    });

    testWidgets('say when free cancellation has passed', (t) async {
      await pumpTripPages(t, trips: _repo(), now: DateTime(2027, 7, 6, 10));
      final card = find.byKey(const ValueKey('option-out'));
      expect(
        find.descendant(
          of: card,
          matching: find.text(_de.tripCompareCancelPassed),
        ),
        findsOneWidget,
      );
    });

    testWidgets('mark the chosen and booked ones, which start ticked', (
      t,
    ) async {
      await pumpTripPages(
        t,
        trips: _repo(
          entries: [
            _flight('out', 'Flug hin', price: 84000),
            _stay(
              'casa',
              'Casa Mare',
              price: 140000,
              from: 10,
              to: 17,
              state: EntryState.booked,
            ),
          ],
        ),
      );
      final casa = find.byKey(const ValueKey('option-casa'));
      await t.ensureVisible(casa);
      expect(
        find.descendant(of: casa, matching: find.text(_de.tripStateBooked)),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('combo-total')), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('combo-total'))).data,
        _de.tripComboTotal(_chf(140000)),
      );
    });

    testWidgets('can be added in each section', (t) async {
      final app = await pumpTripPages(t, trips: _repo());
      final add = find.byKey(const ValueKey('add-stay'));
      await t.ensureVisible(add);
      await t.pumpAndSettle();
      await t.tap(add);
      await t.pumpAndSettle();
      expect(app.router.state.uri.path, '/trips/t1/entry');
      expect(find.text(_de.tripEntryNewTitle), findsOneWidget);
      // The stay's check-in label is among the details.
      await t.tap(find.byKey(const ValueKey('trip-entry-more')));
      await t.pumpAndSettle();
      expect(find.text(_de.tripEntryStartStay), findsOneWidget);
    });

    testWidgets('can be edited and copied', (t) async {
      final repo = _repo();
      final app = await pumpTripPages(t, trips: repo);
      await t.tap(find.byKey(const ValueKey('copy-out')));
      await t.pumpAndSettle();
      expect(repo.copiedEntries, ['out']);
      expect(find.text(_de.tripEntryCopied), findsOneWidget);

      await t.ensureVisible(find.byKey(const ValueKey('edit-cheap')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('edit-cheap')));
      await t.pumpAndSettle();
      expect(app.router.state.uri.path, '/trips/t1/entry');
      expect(find.text(_de.tripEntryEditTitle), findsOneWidget);
    });

    testWidgets('scroll to the kind asked for', (t) async {
      await pumpTripPages(
        t,
        trips: _repo(),
        start: '/trips/t1/compare?kind=rental',
      );
      final header = find.text('Mietwagen · 3');
      expect(header, findsOneWidget);
      expect(t.getTopLeft(header).dy, lessThan(300));
    });
  });

  group('trying a combination', () {
    testWidgets('shows the total and the dates of the ticks', (t) async {
      await pumpTripPages(t, trips: _repo());
      expect(find.text(_de.tripCompareHint), findsNWidgets(2));
      await _ticks(t, ['out', 'casa']);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('combo-total'))).data,
        _de.tripComboTotal(_chf(84000 + 140000)),
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('combo-dates'))).data,
        contains('7 Nächte'),
      );
      await _tick(t, 'casa');
      expect(
        t.widget<Text>(find.byKey(const ValueKey('combo-total'))).data,
        _de.tripComboTotal(_chf(84000)),
      );
    });

    testWidgets('says "fits together" when nothing is wrong', (t) async {
      await pumpTripPages(t, trips: _repo());
      await _ticks(t, ['out', 'back', 'casa', 'sole', 'car']);
      expect(find.byKey(const ValueKey('combo-fits')), findsOneWidget);
      expect(find.text(_de.tripComboFits), findsOneWidget);
    });

    testWidgets('names the nights without accommodation', (t) async {
      await pumpTripPages(t, trips: _repo());
      await _ticks(t, ['out', 'back', 'casa']);
      expect(
        find.text(_de.tripComboWarnNights(2, '17. Juli – 19. Juli')),
        findsOneWidget,
      );
    });

    testWidgets('names a rental that starts before the arrival', (t) async {
      await pumpTripPages(t, trips: _repo());
      await _ticks(t, ['out', 'back', 'casa', 'sole', 'early']);
      await _openWarnings(t);
      expect(
        find.text(_de.tripComboWarnRentalBefore('Mietwagen früh')),
        findsOneWidget,
      );
    });

    testWidgets('names a rental that ends after the departure', (t) async {
      await pumpTripPages(t, trips: _repo());
      await _ticks(t, ['out', 'back', 'casa', 'sole', 'late']);
      await _openWarnings(t);
      expect(
        find.text(_de.tripComboWarnRentalAfter('Mietwagen spät')),
        findsOneWidget,
      );
    });

    testWidgets('names a rental without any transport', (t) async {
      await pumpTripPages(t, trips: _repo());
      await _ticks(t, ['car']);
      expect(
        find.text(_de.tripComboWarnRentalNoTransport('Mietwagen Alpha')),
        findsOneWidget,
      );
    });

    testWidgets('names two stays that overlap', (t) async {
      await pumpTripPages(t, trips: _repo());
      await _ticks(t, ['casa', 'over']);
      // The shared nights are the 14th to the 16th: 14. – 17. Juli.
      expect(
        find.text(
          _de.tripComboWarnOverlap(
            'Casa Mare',
            'Villa Ueberlapp',
            '14. Juli – 17. Juli',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('says "at least" for an option without a price', (t) async {
      await pumpTripPages(t, trips: _repo());
      await _ticks(t, ['free']);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('combo-total'))).data,
        _de.tripComboTotalAtLeast(_chf(0)),
      );
      expect(find.text(_de.tripComboWarnPrice(1)), findsOneWidget);
    });

    testWidgets('expands to every warning when there are several', (t) async {
      await pumpTripPages(t, trips: _repo());
      await _ticks(t, ['out', 'free', 'car']);
      // Nights, the rental after... several things do not fit; only the first line shows.
      final all = find.byIcon(Icons.warning_amber_rounded);
      expect(all, findsOneWidget);
      await _openWarnings(t);
      expect(
        find.byIcon(Icons.warning_amber_rounded).evaluate().length,
        greaterThan(1),
      );
    });

    testWidgets('writes nothing while ticking', (t) async {
      final repo = _repo();
      await pumpTripPages(t, trips: repo);
      await _ticks(t, ['out', 'casa', 'car']);
      expect(repo.savedEntries, isEmpty);
      expect(repo.savedCombos, isEmpty);
    });
  });

  group('keeping combinations', () {
    testWidgets('asks for a name and stores the ticked ids', (t) async {
      final repo = _repo();
      await pumpTripPages(t, trips: repo);
      await _ticks(t, ['out', 'casa']);
      await t.tap(find.byKey(const ValueKey('combo-keep')));
      await t.pumpAndSettle();
      // Prefilled with the stay's title.
      expect(find.widgetWithText(TextField, 'Casa Mare'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('combo-name')),
        'Direkt und Meer',
      );
      await t.tap(find.text(_de.save));
      await t.pumpAndSettle();
      expect(repo.savedCombos, hasLength(1));
      expect(repo.savedCombos.single.name, 'Direkt und Meer');
      expect(repo.savedCombos.single.entryIds, ['out', 'casa']);
      expect(repo.savedCombos.single.tripId, 't1');
      expect(find.text(_de.tripComboKept), findsOneWidget);
      // The combination now stands in the row of kept ones.
      expect(find.text('Direkt und Meer'), findsOneWidget);
    });

    testWidgets('are cards with total, dates, entries and warnings', (t) async {
      final combos = [
        const TripCombo(
          id: 'c1',
          tripId: 't1',
          name: 'Günstig',
          entryIds: ['cheap', 'back', 'sole', 'free'],
        ),
        const TripCombo(
          id: 'c2',
          tripId: 't1',
          name: 'Komfort',
          entryIds: ['out', 'back', 'casa', 'sole', 'car'],
        ),
        const TripCombo(
          id: 'c3',
          tripId: 't1',
          name: 'Teuer',
          entryIds: ['out', 'back', 'casa', 'sole', 'car', 'over'],
        ),
      ];
      await pumpTripPages(t, trips: _repo(combos: combos));
      final komfort = find.byKey(const ValueKey('combo-c2'));
      expect(
        find.descendant(
          of: komfort,
          matching: find.text(
            _de.tripComboTotal(_chf(84000 + 70000 + 140000 + 60000 + 45000)),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: komfort,
          matching: find.text('Flug hin\nFlug zurück'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: komfort, matching: find.text(_de.tripComboFits)),
        findsOneWidget,
      );
      // The cheapest complete total is marked (the one with a missing price is not
      // complete, so it does not compete).
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('combo-c3')),
          matching: find.text(_de.tripComboWarningsCount(2)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('combo-c2')),
          matching: find.text(_de.tripCompareCheapest),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('combo-c1')),
          matching: find.text(
            _de.tripComboTotalAtLeast(_chf(62000 + 70000 + 60000)),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('load back into the ticks; the same name updates', (t) async {
      final repo = _repo(
        combos: const [
          TripCombo(
            id: 'c1',
            tripId: 't1',
            name: 'Komfort',
            entryIds: ['out', 'casa'],
          ),
        ],
      );
      await pumpTripPages(t, trips: repo);
      await t.tap(find.byKey(const ValueKey('load-c1')));
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const ValueKey('combo-total'))).data,
        _de.tripComboTotal(_chf(224000)),
      );
      // Change it and keep it again under the same name: an update.
      await _tick(t, 'casa');
      await _tick(t, 'sole');
      await t.tap(find.byKey(const ValueKey('combo-keep')));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Komfort'), findsOneWidget);
      await t.tap(find.text(_de.save));
      await t.pumpAndSettle();
      expect(repo.savedCombos.single.id, 'c1');
      expect(repo.savedCombos.single.entryIds, ['out', 'sole']);

      // A new name makes a new combination.
      await t.tap(find.byKey(const ValueKey('combo-keep')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('combo-name')), 'Anders');
      await t.tap(find.text(_de.save));
      await t.pumpAndSettle();
      expect(repo.savedCombos, hasLength(2));
      expect(repo.savedCombos.last.id, isNot('c1'));
      expect(repo.savedCombos.last.name, 'Anders');
    });

    testWidgets('can be renamed and deleted after a question', (t) async {
      final repo = _repo(
        combos: const [
          TripCombo(id: 'c1', tripId: 't1', name: 'Alt', entryIds: ['out']),
        ],
      );
      await pumpTripPages(t, trips: repo);
      await t.tap(find.byKey(const ValueKey('rename-c1')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('combo-name')), 'Neu');
      await t.tap(find.text(_de.save));
      await t.pumpAndSettle();
      expect(repo.savedCombos.single.name, 'Neu');
      expect(repo.savedCombos.single.entryIds, ['out']);

      await t.tap(find.byKey(const ValueKey('delete-c1')));
      await t.pumpAndSettle();
      expect(repo.deletedCombos, isEmpty);
      await t.tap(find.text(_de.cancel));
      await t.pumpAndSettle();
      expect(repo.deletedCombos, isEmpty);
      await t.tap(find.byKey(const ValueKey('delete-c1')));
      await t.pumpAndSettle();
      await t.tap(find.text(_de.delete));
      await t.pumpAndSettle();
      expect(repo.deletedCombos, ['c1']);
      expect(find.byKey(const ValueKey('combo-c1')), findsNothing);
    });
  });

  group('taking a combination (Diese nehmen)', () {
    const combo = TripCombo(
      id: 'c1',
      tripId: 't1',
      name: 'Komfort',
      entryIds: ['out', 'back', 'casa', 'sole'],
    );

    testWidgets('asks, says what happens, keeps the dates by default', (
      t,
    ) async {
      final repo = _repo(combos: const [combo]);
      repo.choice = const ComboChoice(chosen: 4, released: 1, datesSet: false);
      final app = await pumpTripPages(t, trips: repo);
      await t.tap(find.byKey(const ValueKey('take-c1')));
      await t.pumpAndSettle();
      expect(find.text(_de.tripComboTakeBody), findsOneWidget);
      final toggle = find.byKey(const ValueKey('take-dates'));
      expect(toggle, findsOneWidget);
      expect(t.widget<SwitchListTile>(toggle).value, isFalse);
      await t.tap(find.byKey(const ValueKey('take-confirm')));
      await t.pumpAndSettle();
      expect(repo.chosenCombos, [(id: 'c1', setDates: false)]);
      expect(find.text(_de.tripComboTaken(4, 1)), findsOneWidget);
      expect(find.text(tripPageStandIn), findsOneWidget);
      expect(app.router.state.uri.path, '/trips/t1');
    });

    testWidgets('can set the trip\'s dates, on by default for a trip without', (
      t,
    ) async {
      final repo = _repo(combos: const [combo], dates: false);
      repo.choice = const ComboChoice(chosen: 4, released: 0, datesSet: true);
      await pumpTripPages(t, trips: repo);
      await t.tap(find.byKey(const ValueKey('take-c1')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<SwitchListTile>(find.byKey(const ValueKey('take-dates')))
            .value,
        isTrue,
      );
      await t.tap(find.byKey(const ValueKey('take-confirm')));
      await t.pumpAndSettle();
      expect(repo.chosenCombos, [(id: 'c1', setDates: true)]);
      expect(find.text(_de.tripComboTakenDates(4, 0)), findsOneWidget);
    });

    testWidgets('switching the dates on for a trip that has some', (t) async {
      final repo = _repo(combos: const [combo]);
      await pumpTripPages(t, trips: repo);
      await t.tap(find.byKey(const ValueKey('take-c1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('take-dates')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('take-confirm')));
      await t.pumpAndSettle();
      expect(repo.chosenCombos, [(id: 'c1', setDates: true)]);
    });

    testWidgets('hides the switch for a combination without dates', (t) async {
      final repo = _repo(
        combos: const [
          TripCombo(
            id: 'c9',
            tripId: 't1',
            name: 'Leer',
            entryIds: ['free-less'],
          ),
        ],
        entries: [
          const TripEntry(
            id: 'free-less',
            tripId: 't1',
            kind: EntryKind.stay,
            title: 'Irgendwo',
          ),
        ],
      );
      await pumpTripPages(t, trips: repo);
      await t.tap(find.byKey(const ValueKey('take-c9')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('take-dates')), findsNothing);
      await t.tap(find.text(_de.cancel));
      await t.pumpAndSettle();
      expect(repo.chosenCombos, isEmpty);
    });

    testWidgets('shows the server\'s refusal and stays', (t) async {
      final repo = _repo(combos: const [combo]);
      await pumpTripPages(t, trips: repo);
      repo.failure = const ValidationFailure(code: 'trip_combo_invalid');
      await t.tap(find.byKey(const ValueKey('take-c1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('take-confirm')));
      await t.pumpAndSettle();
      expect(find.text(_de.errTripComboInvalid), findsOneWidget);
      expect(find.text(tripPageStandIn), findsNothing);
    });
  });

  group('the page', () {
    testWidgets('invites to the first option when there is none', (t) async {
      final app = await pumpTripPages(t, trips: _repo(entries: const []));
      expect(find.text(_de.tripCompareEmptyTitle), findsOneWidget);
      expect(find.text(_de.tripCompareHint), findsNothing);
      expect(find.byKey(const ValueKey('combo-keep')), findsNothing);
      expect(find.byKey(const ValueKey('empty-add-transport')), findsOneWidget);
      expect(find.byKey(const ValueKey('empty-add-stay')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('empty-add-rental')));
      await t.pumpAndSettle();
      expect(app.router.state.uri.path, '/trips/t1/entry');
      expect(find.text(_de.tripKindRental), findsWidgets);
    });

    testWidgets('is not on offer on a kid\'s device', (t) async {
      await pumpTripPages(t, trips: _repo(), register: UiRegister.kid);
      expect(find.text(_de.tripCompareUnavailable), findsOneWidget);
      expect(find.byKey(const ValueKey('option-out')), findsNothing);
    });

    for (final (name, size, scale) in [
      ('a phone', const Size(360, 800), 1.0),
      ('a phone at text scale 1.3', const Size(360, 800), 1.3),
      ('a wide window', const Size(1000, 800), 1.0),
      ('a wide window at text scale 1.3', const Size(1000, 800), 1.3),
    ]) {
      testWidgets('has no overflow on $name with many options', (t) async {
        final many = [
          for (var i = 0; i < 8; i++)
            _flight(
              'f$i',
              'Flug mit einem recht langen Namen Nummer $i',
              price: 60000 + i * 1000,
              position: i,
            ),
          for (var i = 0; i < 6; i++)
            _stay(
              's$i',
              'Unterkunft mit einem recht langen Namen $i',
              price: 100000 + i,
              from: 10,
              to: 12 + i,
              position: 20 + i,
            ),
          for (var i = 0; i < 4; i++)
            _car(
              'c$i',
              'Mietwagen mit einem recht langen Namen $i',
              price: 40000 + i,
              from: 10,
              to: 19,
              position: 40 + i,
            ),
        ];
        final app = await pumpTripPages(
          t,
          trips: _repo(
            entries: many,
            combos: const [
              TripCombo(
                id: 'k1',
                tripId: 't1',
                name: 'Eine Kombination mit langem Namen',
                entryIds: ['f0', 's1', 'c2'],
              ),
              TripCombo(
                id: 'k2',
                tripId: 't1',
                name: 'Zweite',
                entryIds: ['f1', 's2'],
              ),
            ],
          ),
          size: size,
          textScale: scale,
        );
        await _ticks(t, ['f0', 's1', 'c0', 'c1']);
        await _openWarnings(t);
        expect(t.takeException(), isNull);
        expect(app.container, isNotNull);
        // Scroll to the end: the last card is not under the bar.
        await t.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -5000),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final add = find.byKey(const ValueKey('add-rental'));
        final bar = find.byKey(const ValueKey('combo-keep'));
        expect(
          t.getBottomLeft(add).dy,
          lessThanOrEqualTo(t.getTopLeft(bar).dy),
        );
      });
    }

    final eight = [
      for (var i = 0; i < 8; i++)
        _flight('f$i', 'Flug $i', price: 60000 + i, position: i),
    ];

    testWidgets('scrolls sideways on a phone', (t) async {
      final entries = eight;
      await pumpTripPages(t, trips: _repo(entries: entries));
      final first = find.byKey(const ValueKey('option-f0'));
      final last = find.byKey(const ValueKey('option-f7'), skipOffstage: false);
      expect(t.getSize(first).width, inInclusiveRange(260, 300));
      expect(t.getTopLeft(last).dx, greaterThan(360));
      // The next card peeks in.
      expect(
        t.getTopLeft(find.byKey(const ValueKey('option-f1'))).dx,
        lessThan(360),
      );
    });

    testWidgets('wraps in rows from 840', (t) async {
      await pumpTripPages(
        t,
        trips: _repo(entries: eight),
        size: const Size(1000, 800),
      );
      final a = t.getTopLeft(find.byKey(const ValueKey('option-f0')));
      final b = t.getTopLeft(find.byKey(const ValueKey('option-f1')));
      expect(a.dy, b.dy);
      final h = t.getTopLeft(
        find.byKey(const ValueKey('option-f7'), skipOffstage: false),
      );
      expect(h.dy, greaterThan(a.dy));
    });
  });

  group('accessibility', () {
    testWidgets('meets the tap target, label and contrast guidelines', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await pumpTripPages(
        t,
        trips: _repo(
          combos: const [
            TripCombo(
              id: 'c',
              tripId: 't1',
              name: 'K',
              entryIds: ['out', 'casa'],
            ),
          ],
        ),
      );
      await _ticks(t, ['out', 'casa', 'car']);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('the ticks', () {
    test('start with the chosen and booked entries', () {
      expect(
        defaultTicks([
          _flight('a', 'A', state: EntryState.chosen),
          _flight('b', 'B'),
          _stay('c', 'C', from: 1, to: 2, state: EntryState.booked),
        ]),
        {'a', 'c'},
      );
    });
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/features/trips/domain/trip_entry_args.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_price_input.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_trips.dart';
import '../support/trip_page_harness.dart';

final _de = AppLocalizationsDe();

const _trip = Trip(
  id: 't1',
  title: 'Sardinien',
  stage: TripStage.idea,
  currency: 'CHF',
);

TripEntry _flight({
  DateTime? endsOn,
  TimeOfDay? startsTime,
  TimeOfDay? endsTime,
  DateTime? startsOn,
  int? price = 84000,
}) => TripEntry(
  id: 'out',
  tripId: 't1',
  kind: EntryKind.transport,
  mode: TransportMode.train,
  title: 'Zug via Mailand',
  priceCents: price,
  priceCheckedOn: DateTime(2027, 6, 12),
  url: 'https://example.com/zug',
  details: '1 Umstieg',
  fromPlace: 'Zürich',
  toPlace: 'Olbia',
  startsOn: startsOn ?? DateTime(2027, 7, 10),
  startsTime: startsTime,
  endsOn: endsOn ?? DateTime(2027, 7, 11),
  endsTime: endsTime,
  note: 'Sitzplätze reservieren',
);

Future<TripPageApp> _open(
  WidgetTester t,
  FakeTripsRepository repo,
  TripEntryArgs? args, {
  Size size = const Size(360, 800),
  double textScale = 1,
  UiRegister register = UiRegister.adult,
}) async {
  final app = await pumpTripPages(
    t,
    trips: repo,
    start: '/trips/t1',
    size: size,
    textScale: textScale,
    register: register,
  );
  // The push completes when the page pops, so it is not awaited.
  unawaited(app.router.push<void>('/trips/t1/entry', extra: args));
  await t.pumpAndSettle();
  return app;
}

FakeTripsRepository _repo([List<TripEntry> entries = const []]) =>
    FakeTripsRepository(trips: const [_trip], entries: entries);

Future<void> _type(WidgetTester t, String key, String text) async {
  await t.enterText(find.byKey(ValueKey(key)), text);
  await t.pump();
}

Future<void> _save(WidgetTester t) async {
  await t.tap(find.byTooltip(_de.save));
  await t.pumpAndSettle();
}

void main() {
  group('the price a person types', () {
    int? parse(String text, {String locale = 'de'}) {
      final p = parsePriceInput(text, locale: locale);
      expect(p.valid, isTrue, reason: text);
      return p.cents;
    }

    test('reads a comma or a point as the decimal separator', () {
      expect(parse('840'), 84000);
      expect(parse('1249.50'), 124950);
      expect(parse('1249,50'), 124950);
      expect(parse('12,5'), 1250);
      expect(parse('0,99'), 99);
      expect(parse(',99'), 99);
    });

    test('reads thousands separators', () {
      expect(parse('1.249,50'), 124950);
      expect(parse('1,249.50'), 124950);
      expect(parse("1'249.50"), 124950);
      expect(parse('1 249,50'), 124950);
      expect(parse('1.249'), 124900);
      expect(parse('1,249', locale: 'en'), 124900);
      expect(parse('1.249.500'), 124950000);
    });

    test('an empty field is no price, nonsense is not valid', () {
      expect(parse(''), isNull);
      expect(parse('   '), isNull);
      for (final bad in ['abc', '12,345,6', '1.5.5', '12.345,678', '-5', '.']) {
        expect(parsePriceInput(bad, locale: 'de').valid, isFalse, reason: bad);
      }
      expect(parsePriceInput('1.249', locale: 'en').valid, isFalse);
    });

    test('is written back the way it is typed', () {
      expect(priceInputText(84000, locale: 'de'), '840');
      expect(priceInputText(124950, locale: 'de'), '1249,50');
      expect(priceInputText(124950, locale: 'en'), '1249.50');
      expect(priceInputText(5, locale: 'de'), '0,05');
    });
  });

  group('a new entry (quick capture)', () {
    testWidgets('saves with a name and a price only', (t) async {
      final repo = _repo();
      final args = TripEntryArgs.seed('t1', EntryKind.transport);
      await _open(t, repo, args);
      expect(find.text(_de.tripEntryNewTitle), findsOneWidget);
      // Only the quick fields; the rest is behind "more details".
      expect(find.byKey(const ValueKey('trip-entry-details')), findsNothing);
      await _type(t, 'trip-entry-name', 'Flug ZRH–OLB');
      await _type(t, 'trip-entry-price', '840,50');
      await _save(t);
      expect(repo.savedEntries, hasLength(1));
      final saved = repo.savedEntries.single;
      expect(saved.id, args.entry.id);
      expect(saved.title, 'Flug ZRH–OLB');
      expect(saved.priceCents, 84050);
      expect(saved.kind, EntryKind.transport);
      expect(saved.mode, TransportMode.flight);
      expect(saved.state, EntryState.option);
      expect(saved.url, isNull);
      expect(saved.startsOn, isNull);
      // Back on the page it came from.
      expect(find.text(tripPageStandIn), findsOneWidget);
    });

    testWidgets('takes a decimal point as well', (t) async {
      final repo = _repo();
      await _open(t, repo, TripEntryArgs.seed('t1', EntryKind.stay));
      await _type(t, 'trip-entry-name', 'Casa Mare');
      await _type(t, 'trip-entry-price', '1249.50');
      await _save(t);
      expect(repo.savedEntries.single.priceCents, 124950);
      expect(repo.savedEntries.single.kind, EntryKind.stay);
      expect(repo.savedEntries.single.mode, isNull);
    });

    testWidgets('saves without a price', (t) async {
      final repo = _repo();
      await _open(t, repo, TripEntryArgs.seed('t1', EntryKind.rental));
      await _type(t, 'trip-entry-name', 'Mietwagen');
      await _save(t);
      expect(repo.savedEntries.single.priceCents, isNull);
    });

    testWidgets('wants a name and an amount that is one', (t) async {
      final repo = _repo();
      await _open(t, repo, TripEntryArgs.seed('t1', EntryKind.transport));
      await _save(t);
      expect(find.text(_de.tripEntryNameRequired), findsOneWidget);
      await _type(t, 'trip-entry-name', 'Zug');
      await _type(t, 'trip-entry-price', '12,3,4');
      await _save(t);
      expect(find.text(_de.tripEntryPriceInvalid), findsOneWidget);
      expect(repo.savedEntries, isEmpty);
    });

    testWidgets('lets the kind and the way of travelling be changed', (
      t,
    ) async {
      final repo = _repo();
      await _open(t, repo, TripEntryArgs.seed('t1', EntryKind.transport));
      await t.tap(find.text(_de.tripModeTrain));
      await t.pump();
      await _type(t, 'trip-entry-name', 'Nachtzug');
      await _save(t);
      expect(repo.savedEntries.single.mode, TransportMode.train);

      final other = _repo();
      await _open(t, other, TripEntryArgs.seed('t1', EntryKind.transport));
      await t.tap(find.text(_de.tripKindActivity));
      await t.pump();
      expect(find.text(_de.tripModeTrain), findsNothing);
      await _type(t, 'trip-entry-name', 'Bootstour');
      await _save(t);
      expect(other.savedEntries.single.kind, EntryKind.activity);
      expect(other.savedEntries.single.mode, isNull);
    });

    testWidgets('pastes a web address from the clipboard', (t) async {
      var clip = 'https://example.com/flug?id=1';
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? {'text': clip} : null,
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repo = _repo();
      await _open(t, repo, TripEntryArgs.seed('t1', EntryKind.transport));
      await t.tap(find.byKey(const ValueKey('trip-entry-paste')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('trip-entry-link')))
            .controller!
            .text,
        'https://example.com/flug?id=1',
      );
      // Not an address: the field is left alone and the person is told.
      clip = 'ein Satz';
      await _type(t, 'trip-entry-link', '');
      await t.tap(find.byKey(const ValueKey('trip-entry-paste')));
      await t.pumpAndSettle();
      expect(find.text(_de.tripEntryPasteNone), findsOneWidget);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('trip-entry-link')))
            .controller!
            .text,
        isEmpty,
      );
      await _type(t, 'trip-entry-name', 'Flug');
      await _type(t, 'trip-entry-link', 'https://example.com/flug?id=1');
      await _save(t);
      expect(repo.savedEntries.single.url, 'https://example.com/flug?id=1');
    });

    testWidgets('refuses a link that is no web address', (t) async {
      final repo = _repo();
      await _open(t, repo, TripEntryArgs.seed('t1', EntryKind.transport));
      await _type(t, 'trip-entry-name', 'Flug');
      await _type(t, 'trip-entry-link', 'flug.example.com');
      await _save(t);
      expect(find.text(_de.tripEntryLinkInvalid), findsOneWidget);
      expect(repo.savedEntries, isEmpty);
    });

    testWidgets('puts the details behind a button, labelled by the kind', (
      t,
    ) async {
      final repo = _repo();
      await _open(t, repo, TripEntryArgs.seed('t1', EntryKind.rental));
      await t.tap(find.byKey(const ValueKey('trip-entry-more')));
      await t.pumpAndSettle();
      expect(find.text(_de.tripEntryPickUpPlace), findsOneWidget);
      expect(find.text(_de.tripEntryReturnPlace), findsOneWidget);
      expect(find.text(_de.tripEntryStartRental), findsOneWidget);
      expect(find.text(_de.tripEntryEndRental), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-entry-address')), findsNothing);
    });

    testWidgets('a time needs its date, and both are saved', (t) async {
      final repo = _repo();
      await _open(t, repo, TripEntryArgs.seed('t1', EntryKind.transport));
      await t.tap(find.byKey(const ValueKey('trip-entry-more')));
      await t.pumpAndSettle();
      await _type(t, 'trip-entry-name', 'Flug');
      // No date yet: the time does not open.
      await t.ensureVisible(
        find.byKey(const ValueKey('trip-entry-start-time')),
      );
      await t.tap(find.byKey(const ValueKey('trip-entry-start-time')));
      await t.pumpAndSettle();
      expect(find.text(_de.timeWheelDone), findsNothing);

      await t.tap(find.byKey(const ValueKey('trip-entry-start-date')));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('trip-entry-start-time')));
      await t.pumpAndSettle();
      await t.tap(find.text(_de.timeWheelDone));
      await t.pumpAndSettle();
      await _save(t);
      final saved = repo.savedEntries.single;
      expect(saved.startsOn, DateUtils.dateOnly(DateTime.now()));
      expect(saved.startsTime, const TimeOfDay(hour: 12, minute: 0));
      expect(saved.endsOn, isNull);
    });
  });

  group('changing an entry', () {
    testWidgets('has its details open and shows the price\'s date', (t) async {
      final repo = _repo([_flight()]);
      await _open(t, repo, TripEntryArgs.edit(_flight()));
      expect(find.text(_de.tripEntryEditTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-entry-details')), findsOneWidget);
      expect(find.text(_de.tripEntryPriceFrom('12. Juni')), findsOneWidget);
      // A new price has no date yet: the server stamps it.
      await _type(t, 'trip-entry-price', '900');
      expect(find.text(_de.tripEntryPriceFrom('12. Juni')), findsNothing);
      await _save(t);
      final saved = repo.savedEntries.single;
      expect(saved.id, 'out');
      expect(saved.priceCents, 90000);
      expect(saved.mode, TransportMode.train);
      expect(saved.fromPlace, 'Zürich');
      expect(saved.details, '1 Umstieg');
      expect(saved.note, 'Sitzplätze reservieren');
    });

    testWidgets('says inline that the end is before the start', (t) async {
      final repo = _repo([_flight(endsOn: DateTime(2027, 7, 9))]);
      await _open(
        t,
        repo,
        TripEntryArgs.edit(_flight(endsOn: DateTime(2027, 7, 9))),
      );
      expect(
        find.byKey(const ValueKey('trip-entry-range-error')),
        findsOneWidget,
      );
      expect(find.text(_de.tripEntryEndBeforeStart), findsOneWidget);
      await _save(t);
      expect(repo.savedEntries, isEmpty);
    });

    testWidgets('compares the times on the same day', (t) async {
      final entry = _flight(
        endsOn: DateTime(2027, 7, 10),
        startsTime: const TimeOfDay(hour: 10, minute: 0),
        endsTime: const TimeOfDay(hour: 9, minute: 30),
      );
      final repo = _repo([entry]);
      await _open(t, repo, TripEntryArgs.edit(entry));
      expect(find.text(_de.tripEntryEndBeforeStart), findsOneWidget);
      await _save(t);
      expect(repo.savedEntries, isEmpty);

      final fine = _flight(
        endsOn: DateTime(2027, 7, 10),
        startsTime: const TimeOfDay(hour: 10, minute: 0),
        endsTime: const TimeOfDay(hour: 10, minute: 0),
      );
      final other = _repo([fine]);
      await _open(t, other, TripEntryArgs.edit(fine));
      expect(find.text(_de.tripEntryEndBeforeStart), findsNothing);
      await _save(t);
      expect(other.savedEntries, hasLength(1));
    });

    testWidgets('moves to the reference when it is set to booked', (t) async {
      final repo = _repo([_flight()]);
      await _open(t, repo, TripEntryArgs.edit(_flight()));
      await t.ensureVisible(
        find.byKey(const ValueKey('trip-entry-state-booked')),
      );
      await t.tap(find.byKey(const ValueKey('trip-entry-state-booked')));
      await t.pumpAndSettle();
      final ref = t.widget<TextField>(
        find.byKey(const ValueKey('trip-entry-ref')),
      );
      expect(ref.focusNode!.hasFocus, isTrue);
      await t.enterText(find.byKey(const ValueKey('trip-entry-ref')), 'ABC123');
      await _save(t);
      expect(repo.savedEntries.single.state, EntryState.booked);
      expect(repo.savedEntries.single.bookingRef, 'ABC123');
    });

    testWidgets('can be copied as another option, which is then opened', (
      t,
    ) async {
      final repo = _repo([_flight()]);
      final app = await _open(t, repo, TripEntryArgs.edit(_flight()));
      await t.tap(find.byTooltip(_de.tripEntryCopy));
      await t.pumpAndSettle();
      expect(repo.copiedEntries, ['out']);
      expect(find.text(_de.tripEntryCopied), findsOneWidget);
      final shown = app.router.state.extra! as TripEntryArgs;
      expect(shown.entry.id, 'copy-1');
      expect(shown.isNew, isFalse);
      expect(find.text(_de.tripEntryEditTitle), findsOneWidget);
    });

    testWidgets('can be deleted after a question', (t) async {
      final repo = _repo([_flight()]);
      await _open(t, repo, TripEntryArgs.edit(_flight()));
      await t.tap(find.byTooltip(_de.tripEntryDelete));
      await t.pumpAndSettle();
      expect(find.text(_de.tripEntryDeleteTitle), findsOneWidget);
      await t.tap(find.text(_de.cancel));
      await t.pumpAndSettle();
      expect(repo.deletedEntries, isEmpty);
      await t.tap(find.byTooltip(_de.tripEntryDelete));
      await t.pumpAndSettle();
      await t.tap(find.text(_de.delete));
      await t.pumpAndSettle();
      expect(repo.deletedEntries, ['out']);
      expect(find.text(tripPageStandIn), findsOneWidget);
    });

    testWidgets('shows the server\'s refusal and stays', (t) async {
      final repo = _repo([_flight()]);
      await _open(t, repo, TripEntryArgs.edit(_flight()));
      repo.failure = const ValidationFailure(code: 'trip_entry_invalid');
      await _save(t);
      expect(find.text(_de.errTripEntryInvalid), findsOneWidget);
      expect(find.text(_de.tripEntryEditTitle), findsOneWidget);
    });

    testWidgets('a stay has an address and a phone', (t) async {
      final stay = const TripEntry(
        id: 's1',
        tripId: 't1',
        kind: EntryKind.stay,
        title: 'Casa Mare',
        address: 'Via Mare 1, Olbia',
        phone: '+39 0789 1234',
      );
      final repo = _repo([stay]);
      await _open(t, repo, TripEntryArgs.edit(stay));
      await t.ensureVisible(find.byKey(const ValueKey('trip-entry-address')));
      expect(find.byTooltip(_de.tripEntryOpenAddress), findsOneWidget);
      expect(find.byTooltip(_de.tripEntryCallPhone), findsOneWidget);
      expect(find.text(_de.tripEntryStartStay), findsOneWidget);
      await _save(t);
      expect(repo.savedEntries.single.address, 'Via Mare 1, Olbia');
      expect(repo.savedEntries.single.phone, '+39 0789 1234');
    });
  });

  group('the page', () {
    testWidgets('goes back to the trip on a restored route', (t) async {
      await _open(t, _repo(), null);
      expect(find.text(tripPageStandIn), findsOneWidget);
      expect(find.text(_de.tripEntryNewTitle), findsNothing);
    });

    testWidgets('is not on offer on a kid\'s device', (t) async {
      await _open(
        t,
        _repo(),
        TripEntryArgs.seed('t1', EntryKind.stay),
        register: UiRegister.kid,
      );
      expect(find.text(_de.tripEntryUnavailable), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-entry-name')), findsNothing);
    });

    testWidgets('meets the tap target, label and contrast guidelines', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await _open(t, _repo(), TripEntryArgs.seed('t1', EntryKind.stay));
      await t.tap(find.byKey(const ValueKey('trip-entry-more')));
      await t.pumpAndSettle();
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    for (final (name, size, scale) in [
      ('a phone', const Size(360, 800), 1.0),
      ('a phone at text scale 1.3', const Size(360, 800), 1.3),
      ('a wide window', const Size(1000, 800), 1.0),
    ]) {
      testWidgets('has no overflow on $name', (t) async {
        final stay = TripEntry(
          id: 's1',
          tripId: 't1',
          kind: EntryKind.stay,
          title: 'Casa Mare mit einem sehr langen Namen, der umbrechen muss',
          priceCents: 124950,
          priceCheckedOn: DateTime(2027, 6, 12),
          url: 'https://example.com/a/very/long/address/that/goes/on',
          details: 'Frühstück inklusive, Parkplatz, Meerblick, Klimaanlage',
          address: 'Via Mare 1, Olbia',
          phone: '+39 0789 1234',
          startsOn: DateTime(2027, 7, 10),
          startsTime: const TimeOfDay(hour: 15, minute: 0),
          endsOn: DateTime(2027, 7, 17),
          endsTime: const TimeOfDay(hour: 10, minute: 0),
          cancelUntil: DateTime(2027, 7, 1),
          bookingRef: 'ABC-123',
          note: 'Ein langer Hinweis\nüber mehrere Zeilen.',
        );
        await _open(
          t,
          _repo([stay]),
          TripEntryArgs.edit(stay),
          size: size,
          textScale: scale,
        );
        expect(t.takeException(), isNull);
        await t.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -3000),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  });
}

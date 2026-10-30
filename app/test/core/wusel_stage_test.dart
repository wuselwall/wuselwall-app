import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/core/wusel/wusel_stage.dart';

final _appearance = WuselAppearance(
  colors: WuselColors.of(Shade.light, const []),
);

/// A screen with Wusel's home at the top and a card further down.
Widget _screen({
  required GlobalKey card,
  bool home = true,
  bool travels = true,
  bool afterglow = false,
  bool enter = false,
  double cardTop = 400,
}) => MaterialApp(
  builder: (context, child) => WuselStage(child: child!),
  home: Scaffold(
    body: Stack(
      children: [
        if (home)
          Positioned(
            left: 20,
            top: 20,
            child: WuselHome(
              appearance: _appearance,
              size: 88,
              travels: travels,
              afterglow: afterglow,
              enter: enter,
              child: Wusel(colors: _appearance.colors, size: 88),
            ),
          ),
        Positioned(
          left: 20,
          top: cardTop,
          child: SizedBox(key: card, width: 300, height: 80),
        ),
      ],
    ),
  ),
);

WuselStageState _stage(WidgetTester tester) =>
    tester.state<WuselStageState>(find.byType(WuselStage));

double _homeOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(WuselHome),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

Future<void> _frames(WidgetTester tester, Duration span) async {
  for (var t = Duration.zero; t < span; t += const Duration(milliseconds: 16)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

extension on WuselTrip {
  /// Pumps frames until Wusel has reached the target.
  Future<void> arrivedWithin(WidgetTester tester) async {
    var arrived = false;
    unawaited(this.arrived.then((_) => arrived = true));
    for (var i = 0; i < 150 && !arrived; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(arrived, isTrue);
  }
}

void main() {
  tearDown(() => StillMode.enabled = false);

  testWidgets(
    'a visit leaves the home empty, reaches the card and comes back',
    (tester) async {
      final card = GlobalKey();
      await tester.pumpWidget(_screen(card: card));
      await tester.pump(const Duration(seconds: 9));

      final trip = _stage(tester).visit(card);
      expect(trip, isNotNull);
      await tester.pump();
      // Away: the home keeps its space and shows nothing.
      expect(_homeOpacity(tester), 0);
      expect(tester.getSize(find.byType(WuselHome)), const Size(88, 88));

      var arrived = false;
      unawaited(trip!.arrived.then((_) => arrived = true));
      await _frames(tester, const Duration(milliseconds: 1500));
      expect(arrived, isTrue);
      // Sitting on the card's upper edge at its start.
      final cardBox = tester.getRect(find.byKey(card));
      expect(trip.position.dy, lessThan(cardBox.top));
      expect(trip.position.dx, lessThan(cardBox.center.dx));

      Offset? hand;
      trip.goHome(carry: true, onHome: (h) => hand = h);
      var done = false;
      unawaited(trip.done.then((_) => done = true));
      await _frames(tester, const Duration(seconds: 2));
      expect(done, isTrue);
      expect(hand, isNotNull);
      expect(_homeOpacity(tester), 1);
      expect(_stage(tester).trip, isNull);
      // Home again, the stage draws no more frames.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a visit nobody ends goes home by itself after four seconds', (
    tester,
  ) async {
    final card = GlobalKey();
    await tester.pumpWidget(_screen(card: card));
    final trip = _stage(tester).visit(card)!;
    var done = false;
    unawaited(trip.done.then((_) => done = true));
    await _frames(tester, WuselStage.visitFor + const Duration(seconds: 3));
    expect(done, isTrue);
    expect(_homeOpacity(tester), 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a celebrating visit jumps and still comes home', (tester) async {
    final card = GlobalKey();
    await tester.pumpWidget(_screen(card: card));
    final trip = _stage(tester).visit(card)!..goHome(celebrate: true);
    var top = double.infinity;
    var done = false;
    unawaited(trip.done.then((_) => done = true));
    await trip.arrivedWithin(tester);
    final atCard = trip.position.dy;
    for (var i = 0; i < 120 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (trip.position.dy < top) top = trip.position.dy;
    }
    // The jump rises well above the card spot.
    expect(top, lessThan(atCard - 88));
    await _frames(tester, const Duration(seconds: 2));
    expect(done, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'no trip without motion, in still mode, or from a home that stays',
    (tester) async {
      final card = GlobalKey();
      StillMode.enabled = true;
      await tester.pumpWidget(_screen(card: card));
      expect(_stage(tester).visit(card), isNull);
      StillMode.enabled = false;

      await tester.pumpWidget(_screen(card: card, travels: false));
      expect(_stage(tester).visit(card), isNull);

      await tester.pumpWidget(_screen(card: card, home: false));
      expect(_stage(tester).visit(card), isNull);
      expect(_stage(tester).canVisit, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('no trip to a card that is out of sight', (tester) async {
    final card = GlobalKey();
    await tester.pumpWidget(_screen(card: card, cardTop: 5000));
    expect(_stage(tester).visit(card), isNull);
    expect(_homeOpacity(tester), 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a card that goes away sends Wusel straight home', (
    tester,
  ) async {
    final card = GlobalKey();
    await tester.pumpWidget(_screen(card: card));
    final trip = _stage(tester).visit(card)!;
    var done = false;
    unawaited(trip.done.then((_) => done = true));
    await _frames(tester, const Duration(milliseconds: 200));
    // The card is gone (another key in its place).
    await tester.pumpWidget(_screen(card: GlobalKey()));
    await _frames(tester, const Duration(seconds: 2));
    expect(done, isTrue);
    expect(_homeOpacity(tester), 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a home that goes away ends the trip', (tester) async {
    final card = GlobalKey();
    await tester.pumpWidget(_screen(card: card));
    final trip = _stage(tester).visit(card)!;
    var done = false;
    unawaited(trip.done.then((_) => done = true));
    await _frames(tester, const Duration(milliseconds: 200));
    await tester.pumpWidget(_screen(card: card, home: false));
    await tester.pump();
    expect(done, isTrue);
    expect(_stage(tester).trip, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a home that enters is empty until Wusel has hopped in', (
    tester,
  ) async {
    final card = GlobalKey();
    await tester.pumpWidget(_screen(card: card, enter: true));
    expect(_homeOpacity(tester), 0);
    await tester.pump();
    expect(_stage(tester).trip, isNotNull);
    await _frames(tester, const Duration(seconds: 2));
    expect(_stage(tester).trip, isNull);
    expect(_homeOpacity(tester), 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the eyes follow the finger only in the afterglow', (
    tester,
  ) async {
    final card = GlobalKey();
    await tester.pumpWidget(_screen(card: card, afterglow: true));
    final stage = _stage(tester);
    await tester.tapAt(const Offset(400, 500));
    expect(stage.finger.value, isNull);

    stage.moment();
    expect(stage.afterglow.value, isTrue);
    await tester.tapAt(const Offset(400, 500));
    expect(stage.finger.value, const Offset(400, 500));

    await tester.pump(WuselStage.afterglowFor);
    expect(stage.afterglow.value, isFalse);
    expect(stage.finger.value, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a trip that ends at a kid home starts the afterglow', (
    tester,
  ) async {
    final card = GlobalKey();
    await tester.pumpWidget(_screen(card: card, afterglow: true));
    final stage = _stage(tester);
    stage.visit(card)!.goHome();
    await _frames(tester, const Duration(seconds: 3));
    expect(stage.afterglow.value, isTrue);
    await tester.pump(WuselStage.afterglowFor);
    await tester.pumpWidget(const SizedBox());
  });
}

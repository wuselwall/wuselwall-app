import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/ui/swipe_stepper.dart';

/// A 400 px wide stepper that counts its steps.
class _Steps {
  int previous = 0;
  int next = 0;
}

Future<_Steps> _pump(
  WidgetTester t, {
  bool hasPrevious = true,
  bool hasNext = true,
  bool arrowKeys = true,
  TextDirection direction = TextDirection.ltr,
  bool disableAnimations = false,
  EdgeInsets gestureInsets = EdgeInsets.zero,
  Widget? extra,
}) async {
  t.view.physicalSize = const Size(400, 600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final steps = _Steps();
  await t.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 600),
          disableAnimations: disableAnimations,
          systemGestureInsets: gestureInsets,
        ),
        child: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Column(
              children: [
                ?extra,
                Expanded(
                  child: SwipeStepper(
                    key: const ValueKey('stepper'),
                    onPrevious: hasPrevious ? () => steps.previous++ : null,
                    onNext: hasNext ? () => steps.next++ : null,
                    arrowKeys: arrowKeys,
                    child: const SizedBox.expand(
                      child: ColoredBox(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return steps;
}

/// A short, quick flick: 60 px at 1000 px/s, far below a quarter of the width, so
/// only its speed can step.
Future<void> _fling(
  WidgetTester t,
  double dx, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
  Offset? from,
}) async {
  final start = from ?? t.getCenter(find.byKey(const ValueKey('stepper')));
  await t.flingFrom(start, Offset(dx, 0), 1000, deviceKind: kind);
  await t.pumpAndSettle();
}

/// A slow drag of [dx] in 10 px steps, 200 ms apart, so only its distance can step.
Future<void> _drag(WidgetTester t, double dx) async {
  final center = t.getCenter(find.byKey(const ValueKey('stepper')));
  final gesture = await t.startGesture(center);
  var time = Duration.zero;
  for (var i = 1; i <= (dx.abs() / 10).round(); i++) {
    time += const Duration(milliseconds: 200);
    await gesture.moveTo(
      center + Offset(10.0 * i * dx.sign, 0),
      timeStamp: time,
    );
    await t.pump(const Duration(milliseconds: 200));
  }
  await gesture.up(timeStamp: time);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('a flick towards the start goes on, towards the end goes back', (
    t,
  ) async {
    final steps = await _pump(t);

    await _fling(t, -200);
    expect((steps.previous, steps.next), (0, 1));

    await _fling(t, 200);
    expect((steps.previous, steps.next), (1, 1));
  });

  testWidgets('a slow drag steps once it has gone a quarter of the width', (
    t,
  ) async {
    final steps = await _pump(t);

    // 60 px of 400, slowly: springs back.
    await _drag(t, -60);
    expect(steps.next, 0);

    // 140 px, as slowly: steps (the touch slop is not counted).
    await _drag(t, -140);
    expect(steps.next, 1);
  });

  testWidgets('a mouse drag does not step: the web keeps it for selecting', (
    t,
  ) async {
    final steps = await _pump(t);

    await _fling(t, -200, kind: PointerDeviceKind.mouse);
    expect((steps.previous, steps.next), (0, 0));
  });

  testWidgets('right to left: a flick to the left goes back', (t) async {
    final steps = await _pump(t, direction: TextDirection.rtl);

    await _fling(t, -200);
    expect((steps.previous, steps.next), (1, 0));
  });

  testWidgets('at the end of the sequence nothing steps', (t) async {
    final steps = await _pump(t, hasNext: false);

    await _fling(t, -200);
    expect((steps.previous, steps.next), (0, 0));
    expect(t.takeException(), isNull);
  });

  testWidgets('a swipe from the system gesture edge is left to the system', (
    t,
  ) async {
    final steps = await _pump(
      t,
      gestureInsets: const EdgeInsets.symmetric(horizontal: 24),
    );

    await _fling(t, 200, from: const Offset(10, 300));
    expect(steps.previous, 0);

    await _fling(t, 200, from: const Offset(60, 300));
    expect(steps.previous, 1);
  });

  testWidgets('under reduced motion the step comes without a slide', (t) async {
    final steps = await _pump(t, disableAnimations: true);
    final center = t.getCenter(find.byKey(const ValueKey('stepper')));

    final gesture = await t.startGesture(center);
    var time = Duration.zero;
    for (var i = 1; i <= 15; i++) {
      time += const Duration(milliseconds: 200);
      await gesture.moveTo(center + Offset(-10.0 * i, 0), timeStamp: time);
      await t.pump(const Duration(milliseconds: 200));
    }
    // The content never followed the finger.
    final moved = t.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('stepper')),
        matching: find.byType(Transform),
      ),
    );
    expect(moved.transform.getTranslation().x, 0);
    await gesture.up(timeStamp: time);
    // A slow drag counts by its distance here too, with no animation to wait for.
    await t.pump();
    expect(steps.next, 1);
  });

  testWidgets('the arrow keys step while no control has the focus', (t) async {
    final steps = await _pump(t);

    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect((steps.previous, steps.next), (2, 1));
  });

  testWidgets('the arrow keys stay with a focused text field', (t) async {
    final steps = await _pump(t, extra: const TextField());

    await t.tap(find.byType(TextField));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(steps.next, 0);
  });

  testWidgets('the arrow keys can be left to the screen', (t) async {
    final steps = await _pump(t, arrowKeys: false);

    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(steps.next, 0);
  });

  testWidgets('the arrow keys stay with a dialog over the screen', (t) async {
    final steps = await _pump(t);

    final context = t.element(find.byKey(const ValueKey('stepper')));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('x')),
      ),
    );
    await t.pumpAndSettle();
    // The dialog's scope takes the focus; unfocus to the bare scope to be sure the
    // route check, not the focus check, is what holds the keys.
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(steps.next, 0);
  });
}

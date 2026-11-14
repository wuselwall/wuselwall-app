import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/time_wheel.dart';

const _hour = ValueKey('time-wheel-hour');
const _minute = ValueKey('time-wheel-minute');
const _period = ValueKey('time-wheel-period');
const _exact = ValueKey('time-wheel-exact');
const _done = ValueKey('time-wheel-done');

/// What the sheet resolved to: unset until it closes, then the time or null.
class _Answer {
  bool closed = false;
  TimeOfDay? time;
}

/// Opens the sheet on [initial] and returns where its answer lands.
Future<_Answer> _open(
  WidgetTester t,
  TimeOfDay initial, {
  Locale locale = const Locale('de'),
  bool device24Hour = false,
  bool? use24Hour,
  String? title,
  double textScale = 1,
  Size? size,
}) async {
  if (size != null) {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }
  final answer = _Answer();
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(UiRegister.adult, Shade.light),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          alwaysUse24HourFormat: device24Hour,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              answer.time = await showTimeWheel(
                context,
                initial: initial,
                title: title,
                use24Hour: use24Hour,
              );
              answer.closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return answer;
}

/// Whether the minute wheel shows every minute.
bool _everyMinute(WidgetTester t) =>
    t.widget<FilterChip>(find.byKey(_exact)).selected;

/// How many values the minute wheel holds: 12 in steps of five, 60 for every minute.
int _minutes(WidgetTester t) =>
    (t
                .widget<CupertinoPicker>(
                  find.descendant(
                    of: find.byKey(_minute),
                    matching: find.byType(CupertinoPicker),
                  ),
                )
                .childDelegate
            as ListWheelChildLoopingListDelegate)
        .children
        .length;

/// One row of a wheel, whatever the text size.
double _row(WidgetTester t, Key wheel) => t
    .widget<CupertinoPicker>(
      find.descendant(
        of: find.byKey(wheel),
        matching: find.byType(CupertinoPicker),
      ),
    )
    .itemExtent;

/// Turns [wheel] by [items] rows: positive to later values.
Future<void> _turn(WidgetTester t, Key wheel, int items) async {
  await t.drag(find.byKey(wheel), Offset(0, -_row(t, wheel) * items));
  await t.pumpAndSettle();
}

Future<void> _finish(WidgetTester t) async {
  await t.tap(find.byKey(_done));
  await t.pumpAndSettle();
}

void main() {
  test('nothing in the app opens the Material clock dial', () {
    final hits = [
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') &&
            file.readAsStringSync().contains('showTimePicker('))
          file.path,
    ];
    expect(hits, isEmpty, reason: 'ask for a time with showTimeWheel');
  });

  testWidgets('Fertig returns the time it opened on', (t) async {
    final answer = await _open(t, const TimeOfDay(hour: 14, minute: 30));
    expect(find.text('Uhrzeit'), findsOneWidget);
    await _finish(t);
    expect(answer.time, const TimeOfDay(hour: 14, minute: 30));
  });

  testWidgets('the field names the sheet when it has a name', (t) async {
    await _open(t, const TimeOfDay(hour: 8, minute: 0), title: 'Beginn');
    expect(find.text('Beginn'), findsOneWidget);
    expect(find.text('Uhrzeit'), findsNothing);
  });

  testWidgets('the wheels turn the hour and the minute in steps of five', (
    t,
  ) async {
    final answer = await _open(t, const TimeOfDay(hour: 14, minute: 30));
    await _turn(t, _hour, 2);
    await _turn(t, _minute, 3);
    await _finish(t);
    expect(answer.time, const TimeOfDay(hour: 16, minute: 45));
  });

  testWidgets('both wheels go round', (t) async {
    final answer = await _open(t, const TimeOfDay(hour: 23, minute: 55));
    await _turn(t, _hour, 1);
    await _turn(t, _minute, 1);
    await _finish(t);
    // The hour does not carry: each wheel is its own value.
    expect(answer.time, const TimeOfDay(hour: 0, minute: 0));
  });

  testWidgets('closing the sheet without Fertig chooses nothing', (t) async {
    final answer = await _open(t, const TimeOfDay(hour: 14, minute: 30));
    await _turn(t, _hour, 1);
    await t.tap(find.text('Abbrechen'));
    await t.pumpAndSettle();
    expect(answer.closed, isTrue);
    expect(answer.time, isNull);
  });

  testWidgets('Jede Minute shows every minute and keeps the one chosen', (
    t,
  ) async {
    final answer = await _open(t, const TimeOfDay(hour: 7, minute: 35));
    expect(_minutes(t), 12);
    await t.tap(find.byKey(_exact));
    await t.pumpAndSettle();
    expect(_minutes(t), 60);
    await _turn(t, _minute, 2);
    await _finish(t);
    expect(answer.time, const TimeOfDay(hour: 7, minute: 37));
  });

  testWidgets('a time on no step opens with every minute', (t) async {
    final answer = await _open(t, const TimeOfDay(hour: 8, minute: 17));
    expect(_minutes(t), 60);
    expect(_everyMinute(t), isTrue);
    await _finish(t);
    expect(answer.time, const TimeOfDay(hour: 8, minute: 17));
  });

  testWidgets('back to steps of five takes the nearest step', (t) async {
    final answer = await _open(t, const TimeOfDay(hour: 8, minute: 58));
    await t.tap(find.byKey(_exact));
    await t.pumpAndSettle();
    expect(_minutes(t), 12);
    await _finish(t);
    // 58 rounds to the full hour's minute, not past it: the hour stays.
    expect(answer.time, const TimeOfDay(hour: 8, minute: 0));
  });

  testWidgets('German never shows a wheel for before and after noon', (
    t,
  ) async {
    await _open(t, const TimeOfDay(hour: 14, minute: 30));
    expect(find.byKey(_period), findsNothing);
  });

  testWidgets('English on a 12-hour device chooses with AM and PM', (t) async {
    final answer = await _open(
      t,
      const TimeOfDay(hour: 14, minute: 30),
      locale: const Locale('en'),
    );
    expect(find.byKey(_period), findsOneWidget);
    // 2 PM, one hour on is 3 PM; then before noon.
    await _turn(t, _hour, 1);
    await _turn(t, _period, -1);
    await _finish(t);
    expect(answer.time, const TimeOfDay(hour: 3, minute: 30));
  });

  testWidgets('twelve on a 12-hour wheel is midnight or noon', (t) async {
    final answer = await _open(
      t,
      const TimeOfDay(hour: 0, minute: 15),
      locale: const Locale('en'),
    );
    await _turn(t, _period, 1);
    await _finish(t);
    expect(answer.time, const TimeOfDay(hour: 12, minute: 15));
  });

  testWidgets('English on a 24-hour device, and a setting, use 24 hours', (
    t,
  ) async {
    await _open(
      t,
      const TimeOfDay(hour: 14, minute: 30),
      locale: const Locale('en'),
      device24Hour: true,
    );
    expect(find.byKey(_period), findsNothing);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();

    await _open(
      t,
      const TimeOfDay(hour: 14, minute: 30),
      locale: const Locale('en'),
      use24Hour: true,
    );
    expect(find.byKey(_period), findsNothing);
  });

  testWidgets('a screen reader hears each wheel as one adjustable value', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final answer = await _open(t, const TimeOfDay(hour: 14, minute: 30));
    final hour = find.bySemanticsLabel('Stunde');
    final minute = find.bySemanticsLabel('Minute');
    expect(
      t.getSemantics(hour),
      isSemantics(
        label: 'Stunde',
        value: '14',
        increasedValue: '15',
        decreasedValue: '13',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    expect(
      t.getSemantics(minute),
      isSemantics(
        label: 'Minute',
        value: '30',
        increasedValue: '35',
        decreasedValue: '25',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    t.semantics.increase(find.semantics.byLabel('Stunde'));
    await t.pumpAndSettle();
    t.semantics.decrease(find.semantics.byLabel('Minute'));
    await t.pumpAndSettle();
    await _finish(t);
    expect(answer.time, const TimeOfDay(hour: 15, minute: 25));
    handle.dispose();
  });

  testWidgets('a keyboard types the time and Enter takes it', (t) async {
    final answer = await _open(t, const TimeOfDay(hour: 14, minute: 30));
    // The hours have the focus: "0", "7" is seven o'clock, then the minutes follow.
    await t.sendKeyEvent(LogicalKeyboardKey.digit0, character: '0');
    await t.sendKeyEvent(LogicalKeyboardKey.digit7, character: '7');
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.digit4, character: '4');
    await t.sendKeyEvent(LogicalKeyboardKey.digit5, character: '5');
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(answer.time, const TimeOfDay(hour: 7, minute: 45));
  });

  testWidgets('a typed minute that is on no step opens every minute', (
    t,
  ) async {
    final answer = await _open(t, const TimeOfDay(hour: 14, minute: 30));
    await t.sendKeyEvent(LogicalKeyboardKey.digit9, character: '9');
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
    await t.sendKeyEvent(LogicalKeyboardKey.digit7, character: '7');
    await t.pumpAndSettle();
    expect(_everyMinute(t), isTrue);
    await _finish(t);
    expect(answer.time, const TimeOfDay(hour: 9, minute: 17));
  });

  testWidgets('the arrow keys step the wheel that has the focus', (t) async {
    final answer = await _open(t, const TimeOfDay(hour: 14, minute: 30));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pumpAndSettle();
    await _finish(t);
    expect(answer.time, const TimeOfDay(hour: 15, minute: 25));
  });

  testWidgets('fits a small phone at the largest text size', (t) async {
    final answer = await _open(
      t,
      const TimeOfDay(hour: 14, minute: 30),
      locale: const Locale('en'),
      textScale: 2,
      size: const Size(320, 568),
    );
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.byKey(_done));
    await _finish(t);
    expect(answer.time, const TimeOfDay(hour: 14, minute: 30));
  });

  testWidgets('fits a phone lying on its side', (t) async {
    await _open(
      t,
      const TimeOfDay(hour: 14, minute: 30),
      size: const Size(640, 360),
    );
    expect(t.takeException(), isNull);
  });
}

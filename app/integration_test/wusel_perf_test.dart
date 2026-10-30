// Frame statistics for Wusel's movement (specs/25 "Wusel on the move"), on a device in
// profile mode, on the in-memory demo household:
//
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/wusel_perf_test.dart -d <device> \
//     --dart-define=PERF_SCENARIO=kid|kiosk|adult
//
// Each moment is measured on its own with `binding.watchPerformance`; the driver
// (test_driver/perf_driver.dart) writes the summaries to $PERF_OUT/$PERF_NAME.json.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/demo/demo_notifications.dart';
import 'package:wuselwall/demo/demo_overrides.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';

const _scenario = String.fromEnvironment('PERF_SCENARIO', defaultValue: 'kid');

/// Names in English and German, so the test runs in either demo language.
Finder _text(List<String> any) => find.byWidgetPredicate(
  (w) =>
      (w is Text && any.contains(w.data)) ||
      (w is RichText && any.contains(w.text.toPlainText())),
);

/// Waits in real time, pumping every frame (a lively screen is measured like this).
Future<void> _wait(WidgetTester tester, double seconds) async {
  final end = DateTime.now().add(
    Duration(milliseconds: (seconds * 1000).round()),
  );
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Waits pumping only every 250 ms: the binding runs the frames something asks for by
/// itself (fullyLive), so an idle screen shows about four frames a second (the pumps)
/// instead of sixty, and a screen that keeps animating shows its own frames.
Future<void> _quiet(WidgetTester tester, double seconds) async {
  final end = DateTime.now().add(
    Duration(milliseconds: (seconds * 1000).round()),
  );
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

final _taskCards = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_TaskCard',
);

/// Ticks the first open chore of "Mein Tag", scrolling the list to it first when the
/// cards above (badge, question at the table) push it below the fold.
void _dump(String what) => debugPrint(
  'PERF $what: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}',
);

Future<void> _tapFirstChore(WidgetTester tester) async {
  _dump('before-scroll');
  if (_taskCards.evaluate().isEmpty) {
    try {
      await tester.scrollUntilVisible(_taskCards, 250, maxScrolls: 12);
    } catch (e) {
      debugPrint('PERF scroll failed: $e');
    }
    await _wait(tester, 0.5);
  }
  debugPrint('PERF cards found: ${_taskCards.evaluate().length}');
  if (_taskCards.evaluate().isEmpty) {
    debugPrint(
      'PERF texts: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}',
    );
    debugPrint(
      'PERF types: ${find.byType(Scrollable).evaluate().length} ${find.byType(KidCard).evaluate().length}',
    );
  }
  expect(_taskCards, findsWidgets);
  // Bring the card to the upper part of the screen, so the tap cannot land on the
  // navigation bar or the snackbar that lie over the list's lower part.
  await Scrollable.ensureVisible(
    _taskCards.first.evaluate().first,
    alignment: 0.15,
    duration: const Duration(milliseconds: 300),
  );
  await _wait(tester, 0.5);
  await tester.tapAt(
    tester.getTopLeft(_taskCards.first) + const Offset(80, 30),
  );
}

/// Taps the match that lies lowest on the screen when [last] is set (the avatar bar
/// at the bottom, not a name somewhere on a page), else the first one.
Future<void> _tapText(
  WidgetTester tester,
  List<String> any, {
  bool last = false,
}) async {
  final f = _text(any);
  expect(f, findsWidgets, reason: 'one of $any');
  var target = f.first;
  if (last) {
    var best = -1.0;
    for (var i = 0; i < f.evaluate().length; i++) {
      final y = tester.getCenter(f.at(i)).dy;
      if (y > best) {
        best = y;
        target = f.at(i);
      }
    }
  }
  final c = tester.getCenter(target);
  debugPrint('PERF tap $any at ${c.dx},${c.dy} of ${f.evaluate().length}');
  await tester.tap(target, warnIfMissed: false);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('wusel moves: $_scenario', (tester) async {
    StillMode.enabled = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...demoOverrides(scenario: _scenario),
          notificationSchedulerProvider.overrideWithValue(
            const DemoNotificationScheduler(),
          ),
        ],
        child: const WuselWallApp(),
      ),
    );
    await _wait(tester, 3);

    Future<void> measure(String name, Future<void> Function() action) async {
      await binding.watchPerformance(action, reportKey: name);
    }

    switch (_scenario) {
      case 'kid':
        // Pick the child with one open chore first (Olivia / Emma), then the other.
        await _tapText(tester, ['Olivia', 'Emma']);
        await _wait(tester, 3);
        await measure('kid_idle_2s', () => _quiet(tester, 2));
        // Whatever she has open: tick until the list is done (the last one cheers).
        await measure('kid_tick_and_trip', () async {
          await _tapFirstChore(tester);
          await _wait(tester, 7);
        });
        // Second child: normal trips, coin home.
        await _tapText(tester, ['Jack', 'Paul'], last: true);
        await _wait(tester, 2);
        // (In this run the avatar tap lands on the Points tab; go back to My day.)
        await measure('kid_hop_in_after_avatar_switch', () async {
          await _tapText(tester, ['My day', 'Mein Tag'], last: true);
          await _wait(tester, 4);
        });
        debugPrint(
          'PERF jack texts: ${_text(['Jack', 'Paul']).evaluate().length}',
        );
        await measure('kid_afterglow_idle_2s', () => _quiet(tester, 2));
        for (final n in ['trip1', 'trip2']) {
          await measure('kid_$n', () async {
            await _tapFirstChore(tester);
            await _wait(tester, 7);
          });
        }
        // The list was scrolled to the chores; scroll back to Wusel's home.
        for (var i = 0; i < 6 && find.byType(Wusel).evaluate().isEmpty; i++) {
          final view = tester.view.physicalSize / tester.view.devicePixelRatio;
          await tester.dragFrom(
            Offset(view.width / 2, view.height * 0.3),
            const Offset(0, 300),
          );
          await _wait(tester, 0.4);
        }
        await _wait(tester, 2);
        await measure('kid_tickles', () async {
          final w = find.byType(Wusel).first;
          final c = tester.getCenter(w);
          final s = tester.getSize(w).height;
          await tester.tapAt(c + Offset(0, -s * 0.42)); // tuft
          await _wait(tester, 0.8);
          await tester.tapAt(c + Offset(-s * 0.12, -s * 0.12)); // eyes
          await _wait(tester, 0.8);
          await tester.tapAt(c + Offset(0, s * 0.18)); // body
          await _wait(tester, 0.8);
          for (var i = 0; i < 3; i++) {
            await tester.tapAt(c);
            await _wait(tester, 0.15);
          }
          await _wait(tester, 2);
        });
        await measure('kid_hop_in_after_tab_switch', () async {
          await _tapText(tester, ['Timetable', 'Stundenplan']);
          await _wait(tester, 1);
          await _tapText(tester, ['My day', 'Mein Tag']);
          await _wait(tester, 4);
        });
        await measure('kid_tab_switches_only', () async {
          for (final t in [
            ['Points', 'Punkte'],
            ['Shopping', 'Einkauf'],
            ['Family', 'Familie'],
            ['My day', 'Mein Tag'],
          ]) {
            await _tapText(tester, t);
            await _wait(tester, 0.6);
          }
        });
        // After the 30 s afterglow Wusel rests: frames should (nearly) stop.
        await _wait(tester, 33);
        await measure('kid_rested_2s', () => _quiet(tester, 2));
      case 'kiosk':
        await measure('kiosk_idle_2s', () => _quiet(tester, 2));
        await measure('kiosk_tickle_corner', () async {
          final w = find.byType(Wusel).first;
          await tester.tap(w, warnIfMissed: false);
          await _wait(tester, 2);
        });
        await _tapText(tester, ['Open today', 'Heute offen'], last: false);
        await _wait(tester, 2);
        await _tapText(tester, ['Jack', 'Paul'], last: true);
        await _wait(tester, 1);
        await measure('kiosk_first_tick', () async {
          await _tapText(tester, [
            'Empty the dishwasher',
            'Geschirrspüler ausräumen',
          ]);
          await _wait(tester, 2);
        });
        await measure('kiosk_last_tick_trip', () async {
          // Jack's (Paul's) last open chore: Wusel goes to the column.
          await _tapText(tester, [
            'Tidy your room',
            'Zimmer aufräumen',
          ], last: true);
          await _wait(tester, 9);
        });
        // The wall's Wusel rests after 60 s.
        await _wait(tester, 62);
        await measure('kiosk_rested_2s', () => _quiet(tester, 2));
      default:
        await measure('adult_idle_2s', () => _quiet(tester, 2));
        await measure('adult_tab_switches', () async {
          for (final t in [
            ['Shopping', 'Einkauf'],
            ['Calendar', 'Kalender'],
            ['Tasks', 'Aufgaben'],
            ['Today', 'Heute'],
          ]) {
            await _tapText(tester, t);
            await _wait(tester, 0.8);
          }
        });
    }
  });
}

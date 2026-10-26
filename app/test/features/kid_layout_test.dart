import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/kid/ui/kid_picker.dart';
import 'package:wuselwall/features/kid/ui/kid_today_page.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';

import '../support/fake_tasks.dart';
import '../support/fakes.dart';

const _emma = 'p-emma';

const _members = [
  Member(
    id: _emma,
    displayName: 'Emma',
    color: Color(0xFFB5306B),
    role: Role.member,
    active: true,
    isChild: true,
  ),
  Member(
    id: 'p-paul',
    displayName: 'Paul',
    color: Color(0xFF1D4E89),
    role: Role.member,
    active: true,
    isChild: true,
  ),
  Member(
    id: 'p-mama',
    displayName: 'Sabine',
    color: Color(0xFF8A4FFF),
    role: Role.guardian,
    active: true,
  ),
  Member(
    id: 'p-papa',
    displayName: 'Thomas',
    color: Color(0xFF0B7A75),
    role: Role.guardian,
    active: true,
  ),
];

class _KidIdentity extends FakeIdentityRepository {
  _KidIdentity()
    : super(
        current: device(
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
          profileId: null,
        ),
      );

  @override
  Future<Result<List<Member>>> members({bool includeInactive = false}) async =>
      Ok(_members);
}

FakeTasksApi _chores() => FakeTasksApi(
  tables: {
    'task_instances': [
      instanceRow(id: 'i-1', title: 'Tisch decken', assignee: _emma),
      instanceRow(id: 'i-2', title: 'Blumen gießen', assignee: _emma),
      instanceRow(
        id: 'i-3',
        title: 'Zimmer aufräumen',
        assignee: _emma,
        status: 'done',
        verification: true,
        completedBy: _emma,
      ),
      instanceRow(id: 'i-4', title: 'Müll rausbringen'),
    ],
  },
);

const _phone = Size(390, 844);

Future<void> _pickEmma(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('kid-pick-$_emma')));
  await tester.pumpAndSettle();
}

/// The labels of the bottom navigation bar, as laid out.
Iterable<RenderParagraph> _navLabels(WidgetTester tester) =>
    tester.renderObjectList<RenderParagraph>(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(RichText),
      ),
    );

/// Whether every nav label sits on one line: all its glyph boxes share one top.
void _expectOneLine(WidgetTester tester) {
  for (final p in _navLabels(tester)) {
    final text = p.text.toPlainText();
    final boxes = p.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    expect(
      {for (final b in boxes) b.top.round()},
      hasLength(1),
      reason: '"$text" wraps',
    );
  }
}

/// Whether every word of [text] stays on one line wherever the text wraps.
void _expectWholeWords(WidgetTester tester, String text) {
  final p = tester.renderObject<RenderParagraph>(
    find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText() == text,
    ),
  );
  var start = 0;
  for (final word in text.split(' ')) {
    final boxes = p.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + word.length),
    );
    expect(
      {for (final b in boxes) b.top.round()},
      hasLength(1),
      reason: '"$word" in "$text" breaks',
    );
    start += word.length + 1;
  }
}

void main() {
  // The app's real font: the test font draws every glyph a full em wide, which no
  // label could fit (see ios_layout_regression_test).
  setUpAll(() async {
    final loader = FontLoader('AtkinsonHyperlegibleNext');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(
        rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$weight.ttf'),
      );
    }
    await loader.load();
  });

  group('the picker grid', () {
    test('four people are 2 × 2 on a phone and one row on a wide tablet', () {
      final phone = pickerGrid(count: 4, width: 358, height: 600, label: 40);
      expect(phone.columns, 2);
      expect(phone.size, greaterThan(120));
      final wide = pickerGrid(count: 4, width: 1200, height: 560, label: 40);
      expect(wide.columns, 4);
      expect(wide.size, 200);
    });

    test('never three and one', () {
      for (final width in [500.0, 600.0, 700.0]) {
        final g = pickerGrid(count: 4, width: width, height: 700, label: 40);
        expect(g.columns, isNot(3), reason: 'width $width');
      }
    });

    test('a family too large for the screen scrolls two across', () {
      final g = pickerGrid(count: 12, width: 300, height: 300, label: 40);
      expect(g.columns, 2);
      expect(g.size, greaterThanOrEqualTo(56));
    });
  });

  testWidgets(
    'on a small phone the tab labels stay whole, "Schule" for short',
    (tester) async {
      final container = await pumpApp(
        tester,
        overrides: baseOverrides(identity: _KidIdentity()),
        tasks: _chores(),
        size: const Size(320, 568),
      );
      await _pickEmma(tester);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Schule'),
        ),
        findsOneWidget,
      );
      _expectOneLine(tester);
      // The whole family in one row, every name whole.
      final tops = {
        for (final m in _members)
          tester.getTopLeft(find.byKey(ValueKey('avatar-${m.id}'))).dy,
      };
      expect(tops, hasLength(1));
      for (final m in _members) {
        expect(
          tester.getRect(find.byKey(ValueKey('avatar-${m.id}'))).right,
          lessThanOrEqualTo(320),
        );
      }
      await unmountApp(tester, container);
    },
  );

  testWidgets('the picker shows the whole family on a 320 × 568 phone', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _chores(),
      size: const Size(320, 568),
    );
    for (final m in _members) {
      final r = tester.getRect(find.byKey(ValueKey('kid-pick-${m.id}')));
      expect(r.bottom, lessThanOrEqualTo(568), reason: m.displayName);
    }
    await unmountApp(tester, container);
  });

  testWidgets('a grown-up\'s tab labels stay whole at text scale 1.3', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: FakeIdentityRepository()),
      size: _phone,
    );
    _expectOneLine(tester);
    await unmountApp(tester, container);
  });

  testWidgets('on a phone the family fits one row of the avatar bar', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _chores(),
      size: _phone,
    );
    await _pickEmma(tester);
    final tops = {
      for (final m in _members)
        tester.getTopLeft(find.byKey(ValueKey('avatar-${m.id}'))).dy,
    };
    expect(tops, hasLength(1));
    expect(tester.getSize(find.byType(ActingProfileBar)).height, lessThan(130));
    await unmountApp(tester, container);
  });

  testWidgets('on a phone Wusel sits above a bubble of the full width', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _chores(),
      size: _phone,
    );
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await _pickEmma(tester);
    final says = tester.widget<WuselSays>(
      find.descendant(
        of: find.byKey(const ValueKey('kid-greeting')),
        matching: find.byType(WuselSays),
      ),
    );
    expect(says.stacked, isTrue);
    expect(says.trailing, isNotNull);
    await unmountApp(tester, container);
  });

  testWidgets('a phone keeps the kid home upright, a tablet turns freely', (
    tester,
  ) async {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _chores(),
      size: _phone,
    );
    expect(calls.last, ['DeviceOrientation.portraitUp']);
    await unmountApp(tester, container);
    // Leaving the kid home turns the lock off again.
    expect(calls.last, isEmpty);

    calls.clear();
    container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _chores(),
      size: const Size(1280, 800),
    );
    expect(calls.where((c) => (c! as List).isNotEmpty), isEmpty);
    await unmountApp(tester, container);
  });

  testWidgets('a tick\'s undo goes when the child switches tab', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _chores(),
    );
    await _pickEmma(tester);
    await tester.tap(find.text('Tisch decken'));
    await tester.pumpAndSettle();
    expect(find.text('Rückgängig'), findsOneWidget);
    await tester.tap(find.text('Punkte'));
    await tester.pumpAndSettle();
    expect(find.text('Rückgängig'), findsNothing);
    await unmountApp(tester, container);
  });

  testWidgets('a chore waiting for a check shows an hourglass, not a tick', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _chores(),
    );
    await _pickEmma(tester);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    // A chore open to anyone says so.
    expect(find.text('Offen für alle'), findsOneWidget);
    await unmountApp(tester, container);
  });

  testWidgets('the picker sizes its circles to the screen', (tester) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _chores(),
      size: _phone,
    );
    expect(find.byType(KidPicker), findsOneWidget);
    final first = tester.getTopLeft(
      find.byKey(const ValueKey('kid-pick-$_emma')),
    );
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('kid-pick-p-paul')),
    );
    // Two across: Emma and Paul share the first row.
    expect(second.dy, first.dy);
    await unmountApp(tester, container);
  });

  testWidgets('on a 320 px phone no word of a chore or the badge breaks', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _chores(),
      size: const Size(320, 568),
    );
    await _pickEmma(tester);
    await tester.scrollUntilVisible(
      find.text('Müll rausbringen'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(KidTodayPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    _expectWholeWords(tester, 'Müll rausbringen');
    _expectWholeWords(tester, 'Blumen gießen');
    await unmountApp(tester, container);
  });
}

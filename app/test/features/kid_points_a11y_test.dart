import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

import '../support/fake_tasks.dart';
import '../support/fakes.dart';

const _mia = 'p-mia';
const _emma = 'p-emma';

/// A violet child on a shared kid device: the member colour is the accent, so the
/// Redeem button is the violet ink with the member's onInk on it.
final _members = [
  const Member(
    id: _mia,
    displayName: 'Mia',
    color: Color(0xFF7B3FE4),
    role: Role.member,
    active: true,
    isChild: true,
  ),
  const Member(
    id: _emma,
    displayName: 'Emma',
    color: Color(0xFFB5306B),
    role: Role.member,
    active: true,
    isChild: true,
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
  Future<Result<List<Member>>> members() async => Ok(_members);
}

FakeTasksApi _api() => FakeTasksApi(
  tables: {
    'point_balances': [
      {'profile_id': _mia, 'balance': 12},
      {'profile_id': _emma, 'balance': 4},
    ],
    'rewards': [
      {
        'id': 'r-film',
        'title': 'Film aussuchen',
        'cost_points': 5,
        'requires_approval': false,
        'is_active': true,
      },
      {
        'id': 'r-late',
        'title': 'Länger aufbleiben',
        'cost_points': 50,
        'requires_approval': true,
        'is_active': true,
      },
    ],
    'badge_definitions': [
      {'id': 'b-first', 'title': 'Erster Tag', 'icon_key': null},
      {'id': 'b-punkt', 'title': 'Pünktlich', 'icon_key': null},
    ],
    'badge_awards': [
      {'profile_id': _mia, 'badge_definition_id': 'b-first'},
    ],
  },
);

Future<void> _openPoints(WidgetTester tester, {required String tab}) async {
  await tester.tap(find.byKey(const ValueKey('kid-pick-$_mia')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tab));
  await tester.pumpAndSettle();
}

/// Labels of every semantics node below [node], depth first.
List<String> _labelsBelow(SemanticsNode node) {
  final out = <String>[];
  void visit(SemanticsNode n) {
    if (n.label.isNotEmpty) out.add(n.label);
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  node.visitChildren((c) {
    visit(c);
    return true;
  });
  return out;
}

/// WCAG relative luminance and contrast ratio of two opaque colours.
double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('each reward is one node: title, cost and state, with its action '
      'inside (DE)', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _api(),
    );
    await _openPoints(tester, tab: 'Punkte');

    final film = tester.getSemantics(
      find.bySemanticsLabel(RegExp(r'^Film aussuchen, 5 Punkte$')),
    );
    expect(_labelsBelow(film), contains('Einlösen'));
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Länger aufbleiben, 50 Punkte, Noch 38 Punkte$'),
      ),
      findsOneWidget,
    );
    // The title is spoken once, by its reward node, not again as a loose text.
    expect(find.bySemanticsLabel(RegExp(r'^Film aussuchen$')), findsNothing);
    // The unaffordable reward has no action of its own.
    final late = tester.getSemantics(
      find.bySemanticsLabel(RegExp(r'^Länger aufbleiben, 50 Punkte')),
    );
    expect(_labelsBelow(late), isNot(contains('Einlösen')));

    handle.dispose();
    await unmountApp(tester, container);
  });

  testWidgets('each badge is one node that says earned or not yet (DE)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _api(),
    );
    await _openPoints(tester, tab: 'Punkte');

    expect(
      find.bySemanticsLabel(RegExp(r'^Erster Tag, Verdient$')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Pünktlich, Noch nicht verdient$')),
      findsOneWidget,
    );
    // No title is spoken twice: the visible text is hidden behind the node.
    expect(find.bySemanticsLabel(RegExp(r'^Erster Tag$')), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Pünktlich ·$')), findsNothing);
    // Unearned titles are not faded: the medal is, the text keeps full ink.
    expect(
      find.ancestor(of: find.text('Pünktlich'), matching: find.byType(Opacity)),
      findsNothing,
    );

    handle.dispose();
    await unmountApp(tester, container);
  });

  testWidgets('badge state labels are localised (EN)', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _api(),
      locale: const Locale('en'),
    );
    await _openPoints(tester, tab: 'Points');

    expect(
      find.bySemanticsLabel(RegExp(r'^Erster Tag, Earned$')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Pünktlich, Not earned yet$')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Film aussuchen, 5 points$')),
      findsOneWidget,
    );

    handle.dispose();
    await unmountApp(tester, container);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'Redeem label meets 4.5:1 on the violet member fill (${brightness.name})',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final container = await pumpApp(
          tester,
          overrides: baseOverrides(identity: _KidIdentity()),
          tasks: _api(),
        );
        await _openPoints(tester, tab: 'Punkte');

        final label = find.text('Einlösen');
        expect(label, findsOneWidget);
        final fill = Theme.of(tester.element(label)).colorScheme.primary;
        final ink = tester.widget<Text>(label).style!.color!;
        expect(
          _contrast(ink, fill),
          greaterThanOrEqualTo(4.5),
          reason: 'label $ink on fill $fill',
        );
        await unmountApp(tester, container);
      },
    );
  }

  test('every member colour has 4.5:1 for its onInk text, in every shade', () {
    for (final shade in Shade.values) {
      for (final s in MemberPalette.swatches) {
        final m = WwColors(shade: shade).member(s.light);
        expect(
          _contrast(m.onInk, m.ink),
          greaterThanOrEqualTo(4.5),
          reason: '${s.key} in $shade',
        );
      }
    }
  });

  test('unearned badge text keeps 4.5:1 on the page (light and dark)', () {
    for (final shade in [Shade.light, Shade.dark]) {
      final theme = AppTheme.build(UiRegister.kid, shade);
      expect(
        _contrast(theme.colorScheme.onSurface, theme.scaffoldBackgroundColor),
        greaterThanOrEqualTo(4.5),
        reason: '$shade',
      );
    }
  });
}

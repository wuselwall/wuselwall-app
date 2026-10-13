import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';

const _violet = Color(0xFF7B3FE4);

Widget _host(Widget child, {Shade shade = Shade.light, double width = 300}) =>
    MaterialApp(
      theme: AppTheme.build(UiRegister.kiosk, shade),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

PresenceBandView _band(
  PresenceState state, {
  String label = 'Homeoffice',
  String? detail,
  bool tentative = false,
  bool openStart = false,
  bool openEnd = false,
}) => PresenceBandView(
  state: state,
  memberColor: _violet,
  label: label,
  detail: detail,
  tentative: tentative,
  openStart: openStart,
  openEnd: openEnd,
);

void main() {
  group('PresenceBandView', () {
    for (final state in PresenceState.values) {
      for (final width in [160.0, 300.0]) {
        testWidgets('${state.name} renders at width $width without overflow', (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(
              _band(state, detail: '8:30–14', label: 'Homeoffice'),
              width: width,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Homeoffice'), findsOneWidget);
          expect(find.text('8:30–14'), findsOneWidget);
        });
      }
    }

    testWidgets('tentative adds a trailing " ?"', (tester) async {
      await tester.pumpWidget(
        _host(_band(PresenceState.working, label: 'Zahnarzt', tentative: true)),
      );
      expect(find.text('Zahnarzt ?'), findsOneWidget);
    });

    testWidgets('travel shows the flight icon', (tester) async {
      await tester.pumpWidget(
        _host(_band(PresenceState.travel, label: 'Reise')),
      );
      expect(find.byIcon(Icons.flight), findsOneWidget);
    });

    testWidgets('open sides show chevrons', (tester) async {
      await tester.pumpWidget(
        _host(
          _band(
            PresenceState.working,
            label: 'Woche',
            openStart: true,
            openEnd: true,
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('semantics carry label and detail', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(_band(PresenceState.away, label: 'Ferien', detail: '8:30–14')),
      );
      expect(find.bySemanticsLabel('Ferien, 8:30–14'), findsOneWidget);
      handle.dispose();
    });

    for (final shade in Shade.values) {
      testWidgets('all states build in ${shade.name} without errors', (
        tester,
      ) async {
        for (final state in PresenceState.values) {
          await tester.pumpWidget(
            _host(
              _band(state, detail: '8:30–14', tentative: state.index.isEven),
              shade: shade,
            ),
          );
          expect(tester.takeException(), isNull, reason: state.name);
        }
      });
    }
  });

  group('BaselineChip', () {
    testWidgets('shows its label with ellipsis at width 120', (tester) async {
      const label = 'Zu Hause bei der Großmutter in Winterthur';
      await tester.pumpWidget(
        _host(
          const BaselineChip(memberColor: _violet, label: label),
          width: 120,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(label), findsOneWidget);
      final text = tester.widget<Text>(find.text(label));
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
    });
  });

  group('MemberDot and MemberDots', () {
    testWidgets('dot carries its semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const MemberDot(memberColor: _violet, semanticLabel: 'Lukas')),
      );
      expect(find.bySemanticsLabel('Lukas'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('hollow dot builds', (tester) async {
      await tester.pumpWidget(
        _host(
          const MemberDot(
            memberColor: _violet,
            semanticLabel: 'Sabine',
            filled: false,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('many dots wrap without overflow', (tester) async {
      await tester.pumpWidget(
        _host(
          MemberDots(
            size: 20,
            dots: [
              for (var i = 0; i < 30; i++)
                MemberDot(memberColor: _violet, semanticLabel: 'M$i', size: 20),
            ],
          ),
          width: 120,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('MemberAvatar', () {
    testWidgets('shows the initial and the display name as semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      const member = BoardMember(
        id: 'm1',
        displayName: 'Hanna',
        color: _violet,
        kind: MemberKind.child,
      );
      await tester.pumpWidget(_host(const MemberAvatar(member: member)));
      expect(find.text('H'), findsOneWidget);
      expect(find.bySemanticsLabel('Hanna'), findsOneWidget);
      handle.dispose();
    });
  });

  group('PaperTile', () {
    testWidgets('unknown tint renders with the default paper', (tester) async {
      await tester.pumpWidget(
        _host(const PaperTile(tint: 'nope', child: Text('Mathe'))),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Mathe'), findsOneWidget);
    });

    testWidgets('struck-through tile renders', (tester) async {
      await tester.pumpWidget(
        _host(
          const PaperTile(
            tint: 'blue',
            struckThrough: true,
            child: Text('Musik'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Musik'), findsOneWidget);
    });
  });
}

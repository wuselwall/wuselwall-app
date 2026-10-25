import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';
import 'package:wuselwall/features/wusel/ui/ambience_sky.dart';

class _Phase extends Notifier<SkyPhase> {
  @override
  SkyPhase build() => SkyPhase.evening;

  void set(SkyPhase phase) => state = phase;
}

final _phase = NotifierProvider<_Phase, SkyPhase>(_Phase.new);

/// A widget in front of the sky that counts its own builds and initStates.
class _Header extends StatefulWidget {
  const _Header();

  static int inits = 0;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  @override
  void initState() {
    super.initState();
    _Header.inits++;
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 72, child: Text('21:00'));
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  _Header.inits = 0;
  final container = ProviderContainer(
    overrides: [
      lighterDayProvider.overrideWith((ref) => const LighterDay()),
      ambienceProvider.overrideWith(
        (ref) => Ambience(phase: ref.watch(_phase)),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(UiRegister.kiosk, Shade.light),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: const Scaffold(body: AmbienceSky(child: _Header())),
        ),
      ),
    ),
  );
  return container;
}

Iterable<SkyPainter> _skies(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<SkyPainter>();

void main() {
  testWidgets(
    'a phase change cross-fades the sky only: the header stays one, opaque',
    (tester) async {
      final container = await _pump(tester);
      expect(_skies(tester), hasLength(1));

      container.read(_phase.notifier).set(SkyPhase.night);
      await tester.pump();
      await tester.pump(AmbienceSky.skyFade ~/ 2);

      // Halfway: two skies fade, but the text in front exists once and nothing
      // between it and the screen dims it.
      expect(_skies(tester), hasLength(2));
      expect(find.text('21:00'), findsOneWidget);
      for (final fade in tester.widgetList<FadeTransition>(
        find.ancestor(
          of: find.text('21:00'),
          matching: find.byType(FadeTransition),
        ),
      )) {
        expect(fade.opacity.value, 1);
      }
      for (final opacity in tester.widgetList<Opacity>(
        find.ancestor(of: find.text('21:00'), matching: find.byType(Opacity)),
      )) {
        expect(opacity.opacity, 1);
      }
      // Built once: Wusel's animations in the header do not restart.
      expect(_Header.inits, 1);

      await tester.pumpAndSettle();
      expect(_skies(tester), hasLength(1));
      expect(_skies(tester).single.ambience.phase, SkyPhase.night);
      expect(_Header.inits, 1);
    },
  );

  testWidgets('under reduced motion the sky changes at once', (tester) async {
    final container = await _pump(tester, disableAnimations: true);
    container.read(_phase.notifier).set(SkyPhase.morning);
    await tester.pump();
    await tester.pump();
    expect(_skies(tester), hasLength(1));
    expect(_skies(tester).single.ambience.phase, SkyPhase.morning);
  });

  group('the Ferien ribbon (specs/26)', () {
    Future<void> pumpRibbon(
      WidgetTester tester, {
      FerienEdge? ferien,
      LighterDay day = const LighterDay(),
      Shade shade = Shade.light,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lighterDayProvider.overrideWith((ref) => day),
            ambienceProvider.overrideWith(
              (ref) => Ambience(phase: SkyPhase.day, ferien: ferien),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.build(UiRegister.kiosk, shade),
            localizationsDelegates: localizationsDelegates,
            supportedLocales: supportedLocales,
            locale: const Locale('de'),
            home: const Scaffold(
              body: AmbienceSky(child: SizedBox(height: 72, width: 800)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    final ribbon = find.byKey(const ValueKey('ferien-ribbon'));

    testWidgets('the first day says so', (tester) async {
      await pumpRibbon(tester, ferien: FerienEdge.first);
      expect(find.text('Ferien!'), findsOneWidget);
    });

    testWidgets('so does the last', (tester) async {
      await pumpRibbon(tester, ferien: FerienEdge.last);
      expect(find.text('Morgen ist wieder Schule'), findsOneWidget);
    });

    testWidgets('other days have none', (tester) async {
      await pumpRibbon(tester);
      expect(ribbon, findsNothing);
    });

    testWidgets('none without the sky', (tester) async {
      await pumpRibbon(
        tester,
        ferien: FerienEdge.first,
        day: const LighterDay(sky: false),
      );
      expect(ribbon, findsNothing);
    });

    testWidgets('none at night, when decoration is off', (tester) async {
      await pumpRibbon(tester, ferien: FerienEdge.first, shade: Shade.night);
      expect(ribbon, findsNothing);
    });
  });
}

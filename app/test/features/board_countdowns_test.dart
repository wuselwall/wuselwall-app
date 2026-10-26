import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/rituals/ui/countdown_widgets.dart';

void main() {
  testWidgets(
    'the wall footer asks its countdowns for their intrinsic height (review finding)',
    (tester) async {
      // The test font is wide (every glyph a square): room for both in full.
      tester.view.physicalSize = const Size(2400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final today = DateTime(2026, 10, 24);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ritualTodayProvider.overrideWithValue(today),
            countdownsProvider.overrideWithValue([
              Countdown(
                kind: CountdownKind.birthday,
                date: DateTime(2026, 10, 27),
                title: 'Olivia',
                iconKey: 'cake',
              ),
              Countdown(
                kind: CountdownKind.event,
                date: DateTime(2026, 11, 5),
                title: 'Zoo',
                iconKey: 'zoo',
              ),
            ]),
          ],
          child: MaterialApp(
            theme: AppTheme.build(UiRegister.kiosk, Shade.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('de'),
            home: const Scaffold(
              body: IntrinsicHeight(
                child: Row(children: [Expanded(child: BoardCountdowns())]),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // Only the form that fits is painted and hit-tested; the shorter ones wait.
      expect(
        find.textContaining('Geburtstag von Olivia').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.textContaining('noch 3× schlafen').hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a narrow footer says less before it cuts a countdown (review round 3, E-5)',
    (tester) async {
      tester.view.physicalSize = const Size(2400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final today = DateTime(2026, 10, 24);
      Future<void> pumpAt(double width) => tester.pumpWidget(
        ProviderScope(
          overrides: [
            ritualTodayProvider.overrideWithValue(today),
            countdownsProvider.overrideWithValue([
              Countdown(
                kind: CountdownKind.birthday,
                date: DateTime(2026, 10, 27),
                title: 'Emma',
                iconKey: 'cake',
                age: 9,
              ),
              Countdown(
                kind: CountdownKind.event,
                date: DateTime(2026, 11, 5),
                title: 'Zoo',
                iconKey: 'zoo',
              ),
            ]),
          ],
          child: MaterialApp(
            theme: AppTheme.build(UiRegister.kiosk, Shade.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('de'),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: const IntrinsicHeight(
                    child: Row(children: [Expanded(child: BoardCountdowns())]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      String shown() => [
        for (final e in find.byType(RichText).hitTestable().evaluate())
          (e.renderObject! as RenderParagraph).text.toPlainText(),
      ].join(' | ');

      // The test font is wide: every glyph is a square. Wide enough for both in full.
      await pumpAt(2200);
      expect(shown(), contains('Emma wird 9 · noch 3× schlafen'));
      expect(shown(), contains('Zoo'));

      // Both, shortened: the cake says whose birthday it is.
      await pumpAt(1000);
      expect(tester.takeException(), isNull);
      expect(shown(), contains('Emma · in 3 Tagen'));
      expect(shown(), contains('Zoo · in 12 Tagen'));

      // Only the nearest, and nothing ends in an ellipsis while it fits.
      await pumpAt(500);
      expect(tester.takeException(), isNull);
      expect(shown(), isNot(contains('Zoo')));
      for (final e in find.byType(RichText).hitTestable().evaluate()) {
        expect((e.renderObject! as RenderParagraph).didExceedMaxLines, isFalse);
      }
    },
  );
}

import 'package:flutter/material.dart';
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
      expect(find.textContaining('Geburtstag von Olivia'), findsOneWidget);
      expect(find.textContaining('noch 3× schlafen'), findsOneWidget);
    },
  );
}

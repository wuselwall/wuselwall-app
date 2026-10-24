import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/kid/application/kid_providers.dart';
import 'package:wuselwall/features/kid/data/kid_badges_repository.dart';
import 'package:wuselwall/features/reminders/application/reminder_providers.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';
import 'package:wuselwall/features/today/ui/getting_started_card.dart';

class _Items extends Notifier<List<GettingStartedItem>> {
  @override
  List<GettingStartedItem> build() => const [
    GettingStartedItem(item: StartItem.setPin, done: true),
    GettingStartedItem(item: StartItem.subscribeFeed, done: false),
  ];

  void finish() => state = const [
    GettingStartedItem(item: StartItem.setPin, done: true),
    GettingStartedItem(item: StartItem.subscribeFeed, done: true),
  ];
}

final _items = NotifierProvider<_Items, List<GettingStartedItem>>(_Items.new);

Widget _app(List<Override> overrides, Widget child) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: AppTheme.build(UiRegister.adult, Shade.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('de'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets(
    'finishing the last getting-started item makes Wusel cheer once',
    (tester) async {
      await tester.pumpWidget(
        _app([
          gettingStartedProvider.overrideWith((ref) async => ref.watch(_items)),
          reminderCardProvider.overrideWith((ref) async => false),
        ], const GettingStartedCard()),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('Alles eingerichtet'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GettingStartedCard)),
      );
      container.read(_items.notifier).finish();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('Alles eingerichtet'), findsOneWidget);

      await tester.tap(find.text('Gesehen'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('Alles eingerichtet'), findsNothing);
    },
  );

  testWidgets('a card that loads already complete stays hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        gettingStartedProvider.overrideWith(
          (ref) async => const [
            GettingStartedItem(item: StartItem.setPin, done: true),
          ],
        ),
        reminderCardProvider.overrideWith((ref) async => false),
      ], const GettingStartedCard()),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Alles eingerichtet'), findsNothing);
  });

  test('a badge earned in the last two days is new; an older one is not', () {
    final now = DateTime(2026, 10, 24, 15);
    KidBadge badge(String id, DateTime? at) =>
        KidBadge(id: id, title: id, earned: at != null, awardedAt: at);
    final container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(now),
        kidBadgesProvider.overrideWith(
          (ref, profileId) async => [
            badge('old', DateTime(2026, 10, 20)),
            badge('yesterday', DateTime(2026, 10, 23, 2)),
            badge('none', null),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(kidBadgesProvider('emma'), (_, _) {});
    addTearDown(sub.close);
    return Future<void>.delayed(Duration.zero, () {
      expect(container.read(kidNewBadgeProvider('emma'))?.id, 'yesterday');
    });
  });
}

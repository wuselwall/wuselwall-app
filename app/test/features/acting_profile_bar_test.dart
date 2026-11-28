// The floating person bar of a shared device and the wall (specs/09 "Who is here"):
// a dock asks who is here while nobody is chosen, then leaves the page to that person
// and keeps only the way out.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';

import '../support/fakes.dart';

/// What the page under the bar is told about its end.
double? _bottomPadding;

class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) {
    _bottomPadding = MediaQuery.paddingOf(context).bottom;
    return ListView(
      children: [
        for (var i = 0; i < 40; i++)
          ListTile(key: ValueKey('row-$i'), title: Text('Zeile $i')),
      ],
    );
  }
}

Widget _host({required DeviceClass deviceClass, Locale? locale}) =>
    ProviderScope(
      overrides: <Override>[
        deviceProvider.overrideWithValue(
          AsyncData(device(deviceClass: deviceClass)),
        ),
        membersProvider.overrideWith((ref) async => testMembers),
      ],
      child: MaterialApp(
        theme: AppTheme.build(UiRegister.adult, Shade.light),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        locale: locale ?? const Locale('de'),
        home: const Scaffold(body: WithActingProfileBar(child: _Page())),
      ),
    );

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ActingProfileBar)));

void main() {
  const dock = ValueKey('acting-dock');
  const exit = ValueKey('acting-exit');

  testWidgets('the dock asks, a tap chooses, and the dock leaves', (
    tester,
  ) async {
    await tester.pumpWidget(_host(deviceClass: DeviceClass.shared));
    await tester.pumpAndSettle();
    expect(find.byKey(dock), findsOneWidget);
    expect(find.text('Wer bist du?'), findsOneWidget);
    expect(find.byKey(exit), findsNothing);
    // It floats in the middle of the page's end, over the list.
    final page = tester.getRect(find.byType(_Page));
    final floating = tester.getRect(find.byKey(dock));
    expect(floating.center.dx, moreOrLessEquals(page.center.dx, epsilon: 1));
    expect(floating.bottom, lessThan(page.bottom));
    expect(floating.width, lessThan(page.width));

    await tester.tap(find.byKey(const ValueKey('avatar-$kidId')));
    await tester.pumpAndSettle();
    expect(_container(tester).read(actingProfileProvider), kidId);
    expect(find.byKey(dock), findsNothing);
    expect(find.text('Wer bist du?'), findsNothing);
    // The way out sits at the bottom end, at least as large as a touch target.
    final button = tester.getRect(find.byKey(exit));
    expect(button.right, greaterThan(page.right - 40));
    expect(button.bottom, greaterThan(page.bottom - 40));
    expect(button.height, greaterThanOrEqualTo(48));
    expect(
      find.descendant(of: find.byKey(exit), matching: find.text('Anna')),
      findsOneWidget,
    );
  });

  testWidgets('the way out gives the device back to nobody', (tester) async {
    await tester.pumpWidget(_host(deviceClass: DeviceClass.kiosk));
    await tester.pumpAndSettle();
    _container(tester).read(actingProfileProvider.notifier).select(kidId);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(exit));
    await tester.pumpAndSettle();
    expect(_container(tester).read(actingProfileProvider), isNull);
    expect(find.byKey(dock), findsOneWidget);
    expect(find.byKey(exit), findsNothing);
  });

  testWidgets('the way out is a button that names who is done', (tester) async {
    final handle = tester.ensureSemantics();
    for (final (locale, label) in [
      (const Locale('de'), 'Anna ist fertig'),
      (const Locale('en'), 'Anna is done'),
      (const Locale('fr'), 'Anna a terminé'),
      (const Locale('es'), 'Anna ha terminado'),
    ]) {
      await tester.pumpWidget(
        _host(deviceClass: DeviceClass.shared, locale: locale),
      );
      await tester.pumpAndSettle();
      _container(tester).read(actingProfileProvider.notifier).select(kidId);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(exit)),
        matchesSemantics(
          label: label,
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
        ),
        reason: locale.languageCode,
      );
      await tester.pumpWidget(const SizedBox());
    }
    handle.dispose();
  });

  testWidgets(
    'the page learns the room the bar covers, and its last row clears it',
    (tester) async {
      await tester.pumpWidget(_host(deviceClass: DeviceClass.shared));
      await tester.pumpAndSettle();
      final asked = tester.getRect(find.byKey(dock));
      final page = tester.getRect(find.byType(_Page));
      expect(_bottomPadding, greaterThanOrEqualTo(page.bottom - asked.top));

      // Scrolled to its end, the list's last row is above the dock.
      await tester.drag(find.byType(_Page), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('row-39'))).bottom,
        lessThanOrEqualTo(asked.top + 0.5),
      );

      _container(tester).read(actingProfileProvider.notifier).select(kidId);
      await tester.pumpAndSettle();
      final button = tester.getRect(find.byKey(exit));
      expect(_bottomPadding, greaterThanOrEqualTo(page.bottom - button.top));
      expect(_bottomPadding, lessThan(page.bottom - asked.top));
    },
  );

  testWidgets('a tap beside the dock reaches the page under it', (
    tester,
  ) async {
    await tester.pumpWidget(_host(deviceClass: DeviceClass.shared));
    await tester.pumpAndSettle();
    final asked = tester.getRect(find.byKey(dock));
    final result = tester.hitTestOnBinding(Offset(4, asked.center.dy));
    expect(
      result.path.any((e) => e.target is RenderViewport),
      isTrue,
      reason: 'the list is under the bar\'s empty corner',
    );
  });

  testWidgets('a personal device has no bar and no extra padding', (
    tester,
  ) async {
    await tester.pumpWidget(_host(deviceClass: DeviceClass.personal));
    await tester.pumpAndSettle();
    expect(find.byKey(dock), findsNothing);
    expect(find.byKey(exit), findsNothing);
    expect(_bottomPadding, 0);
  });
}

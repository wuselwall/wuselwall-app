import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

import '../support/fakes.dart';

const _phone = Size(390, 844);
const _tablet = Size(1024, 1366);
final _de = lookupAppLocalizations(const Locale('de'));

Future<void> _onIos(Future<void> Function() test) async {
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await test();
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}

Future<void> _swipeBack(
  WidgetTester t,
  Size size, {
  required Element routeContext,
}) async {
  final navigator = Navigator.of(routeContext);
  final gesture = await t.startGesture(Offset(1, size.height / 2));
  await gesture.moveBy(const Offset(32, 0));
  await t.pump(const Duration(milliseconds: 100));
  expect(navigator.userGestureInProgress, isTrue);
  await gesture.moveBy(Offset(size.width * .7, 0));
  await t.pump(const Duration(milliseconds: 30));
  await gesture.up();
  await t.pumpAndSettle();
}

void main() {
  for (final size in [_phone, _tablet]) {
    testWidgets(
      'iOS edge swipe returns from Settings and keeps the adult tab at '
      '${size.width.toInt()}dp',
      (t) => _onIos(() async {
        final container = await pumpApp(
          t,
          size: size,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
          ),
        );
        container.read(homeTabProvider.notifier).select(HomeTab.shopping);
        await t.pumpAndSettle();

        expect(
          Theme.of(t.element(find.byType(NavigationBar))).platform,
          TargetPlatform.iOS,
        );
        await t.tap(find.byTooltip(_de.settingsTitle));
        await t.pumpAndSettle();
        // pumpApp disables animations because kiosk boards have a repeating pulse;
        // restore normal motion so Cupertino's interactive route gesture is active.
        t.platformDispatcher.clearAccessibilityFeaturesTestValue();
        await t.pump();
        final settings = find.byKey(const ValueKey('settings-group-devices'));
        expect(settings, findsOneWidget);
        final settingsRoute = ModalRoute.of(t.element(settings));
        expect(settingsRoute, isA<PageRoute<dynamic>>());
        final pageRoute = settingsRoute! as PageRoute<dynamic>;
        expect(pageRoute.isFirst, isFalse);
        expect(pageRoute.settings, isA<MaterialPage<void>>());
        expect(pageRoute.popDisposition, RoutePopDisposition.pop);
        expect(pageRoute.animation?.status, AnimationStatus.completed);
        expect(pageRoute.popGestureEnabled, isTrue);
        expect(
          Theme.of(t.element(settings))
              .pageTransitionsTheme
              .builders[TargetPlatform.iOS],
          isA<CupertinoPageTransitionsBuilder>(),
        );
        expect(find.byType(CupertinoPageTransition), findsOneWidget);

        await _swipeBack(t, size, routeContext: t.element(settings));

        expect(
          find.byKey(const ValueKey('settings-group-devices')),
          findsNothing,
        );
        expect(container.read(homeTabProvider), HomeTab.shopping);
        expect(
          t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          HomeTab.shopping.index,
        );
        await unmountApp(t, container);
      }),
    );
  }

  testWidgets(
    'toolbar Back from direct Settings entry falls back home on iOS',
    (t) => _onIos(() async {
      final container = await pumpApp(
        t,
        size: _phone,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      expect(
        Theme.of(t.element(find.byType(NavigationBar))).platform,
        TargetPlatform.iOS,
      );

      container.read(routerProvider).go(Routes.settings);
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-group-devices')),
        findsOneWidget,
      );
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings-group-devices')),
        findsNothing,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      await unmountApp(t, container);
    }),
  );

  testWidgets(
    'kid register can open and leave Settings on iOS',
    (t) => _onIos(() async {
      final container = await pumpApp(
        t,
        size: _phone,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(
            current: device(
              deviceClass: DeviceClass.shared,
              register: UiRegister.kid,
              profileId: null,
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('kid-pick-$kidId')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip(_de.settingsTitle));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-group-devices')),
        findsOneWidget,
      );

      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings-group-devices')),
        findsNothing,
      );
      expect(find.byTooltip(_de.settingsTitle), findsOneWidget);
      expect(container.read(routerProvider).canPop(), isFalse);
      await unmountApp(t, container);
    }),
  );

  testWidgets(
    'kiosk register can open and leave Settings on iOS',
    (t) => _onIos(() async {
      final container = await pumpApp(
        t,
        size: _tablet,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(
            current: device(
              deviceClass: DeviceClass.kiosk,
              register: UiRegister.kiosk,
              profileId: null,
            ),
          ),
        ),
      );
      expect(
        Theme.of(t.element(find.byType(Scaffold).first)).platform,
        TargetPlatform.iOS,
      );
      await t.tap(find.byTooltip(_de.settingsTitle));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-group-devices')),
        findsOneWidget,
      );

      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings-group-devices')),
        findsNothing,
      );
      expect(find.byTooltip(_de.settingsTitle), findsOneWidget);
      expect(container.read(routerProvider).canPop(), isFalse);
      await unmountApp(t, container);
    }),
  );
}

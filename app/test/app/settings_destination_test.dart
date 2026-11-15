// Reproduces the native audit's settings destination race: the harness asks the
// real router for /settings while the session is still loading, so the router's
// redirect sends it to the splash and then home. Widget-test harness, never shipped.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/settings/ui/settings_page.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('a route asked for after the session loads reaches its destination', (
    t,
  ) async {
    final container = await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
    );
    final router = container.read(routerProvider);
    router.go('/settings');
    await t.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('the redirect holds a not-yet-loaded session on the splash', (t) async {
    // A session that never finishes loading: the router must not commit a
    // destination yet, which is what swallows an early go('/settings') in the
    // native audit harness.
    final never = Completer<SessionState>();
    addTearDown(() {
      if (!never.isCompleted) never.complete(const SignedOut());
    });
    final container = ProviderContainer(
      overrides: [
        ...baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        sessionStateProvider.overrideWith((ref) => never.future),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const WuselWallApp()),
    );
    await t.pump();
    final router = container.read(routerProvider);
    router.go('/settings');
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    // While the session loads, the app stays on the splash: /settings is not
    // committed and then redirected away to home.
    expect(router.routeInformationProvider.value.uri.path, '/splash');
    expect(find.byType(SettingsPage), findsNothing);
  });
}

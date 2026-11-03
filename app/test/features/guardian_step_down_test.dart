// The PIN step-up ends early on a shared device or the wall (specs/08, security review
// 2026-11-01 F13): when another avatar is tapped and when the wall reverts to nobody, the
// client forgets the window and tells the server (api.guardian_step_down). Without an open
// window nothing is sent.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/step_up_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';

import '../support/fakes.dart';

class _CountingStepUp implements StepUpRepository {
  int calls = 0;

  @override
  Future<Result<void>> stepDown() async {
    calls++;
    return const Ok(null);
  }
}

Widget _host(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.build(UiRegister.kiosk, Shade.light),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(body: child),
      ),
    );

void main() {
  late _CountingStepUp stepUp;

  List<Override> overrides(DeviceClass deviceClass) => [
    deviceProvider.overrideWithValue(
      AsyncData(device(deviceClass: deviceClass)),
    ),
    membersProvider.overrideWith((ref) async => testMembers),
    stepUpRepositoryProvider.overrideWithValue(stepUp),
  ];

  setUp(() => stepUp = _CountingStepUp());

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ActingProfileBar)));

  testWidgets('tapping another avatar ends an open PIN window', (tester) async {
    await tester.pumpWidget(
      _host(const ActingProfileBar(), overrides: overrides(DeviceClass.shared)),
    );
    await tester.pumpAndSettle();
    final container = containerOf(tester);
    container.read(actingProfileProvider.notifier).select(guardianId);
    container
        .read(guardianVerifiedProvider.notifier)
        .set(DateTime.now().add(const Duration(minutes: 5)));
    await tester.pump();

    // The same avatar again: nothing changes.
    await tester.tap(find.byKey(const ValueKey('avatar-$guardianId')));
    await tester.pump();
    expect(stepUp.calls, 0);
    expect(container.read(guardianVerifiedProvider), isNotNull);

    await tester.tap(find.byKey(const ValueKey('avatar-$kidId')));
    await tester.pump();
    expect(stepUp.calls, 1);
    expect(container.read(guardianVerifiedProvider), isNull);
    expect(container.read(actingProfileProvider), kidId);

    // Without a window there is nothing to end: no request.
    await tester.tap(find.byKey(const ValueKey('avatar-$guardianId')));
    await tester.pump();
    expect(stepUp.calls, 1);
  });

  testWidgets('the idle revert of the wall ends the window too', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const IdleReverter(
          timeout: Duration(seconds: 2),
          child: ActingProfileBar(),
        ),
        overrides: overrides(DeviceClass.kiosk),
      ),
    );
    await tester.pumpAndSettle();
    final container = containerOf(tester);
    container.read(actingProfileProvider.notifier).select(guardianId);
    container
        .read(guardianVerifiedProvider.notifier)
        .set(DateTime.now().add(const Duration(minutes: 5)));

    await tester.pump(const Duration(seconds: 3));
    expect(stepUp.calls, 1);
    expect(container.read(guardianVerifiedProvider), isNull);
    expect(container.read(actingProfileProvider), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/cache/read_cache.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

import '../support/fakes.dart';

/// FR-8.10: whatever comes from the device's store after a restart without network is
/// marked with the time it was fetched, on the children's home and on a phone alike.
void main() {
  const strip = ValueKey('stale-strip');

  testWidgets('a child\'s home says since when its day dates, and stops '
      'when the server answers again', (tester) async {
    final container = await pumpApp(
      tester,
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
    expect(find.byKey(strip), findsNothing, reason: 'live: nothing to say');

    final now = testNow();
    final marks = container.read(staleReadsProvider.notifier)
      ..stale('members', DateTime(now.year, now.month, now.day, 8, 15))
      ..stale('settings', DateTime(now.year, now.month, now.day, 9));
    await tester.pump();
    expect(find.byKey(strip), findsOneWidget);
    expect(
      find.text('zuletzt aktualisiert 8:15'),
      findsOneWidget,
      reason: 'the oldest answer on screen, today: the time is enough',
    );

    marks.fresh('members');
    await tester.pump();
    expect(find.byKey(strip), findsNothing);
    await unmountApp(tester, container);
  });

  testWidgets('a plan stored on another day is marked with that day', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      locale: const Locale('en'),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(
          current: device(
            deviceClass: DeviceClass.shared,
            register: UiRegister.kid,
            profileId: null,
          ),
        ),
        now: DateTime(2026, 11, 10, 7),
      ),
    );
    container
        .read(staleReadsProvider.notifier)
        .stale('board-week', DateTime(2026, 11, 7, 17, 5));
    await tester.pump();
    expect(find.text('last updated Sat 11/7, 5:05 PM'), findsOneWidget);
    await unmountApp(tester, container);
  });

  testWidgets('a phone shows the same strip above its pages', (tester) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
    );
    expect(find.byKey(strip), findsNothing);
    final now = testNow();
    container
        .read(staleReadsProvider.notifier)
        .stale('members', DateTime(now.year, now.month, now.day, 6, 40));
    await tester.pump();
    expect(find.text('zuletzt aktualisiert 6:40'), findsOneWidget);
    await unmountApp(tester, container);
  });
}

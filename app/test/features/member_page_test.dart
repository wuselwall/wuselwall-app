import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';

import '../support/fake_pairing.dart';
import '../support/fakes.dart';

final _de = lookupAppLocalizations(const Locale('de'));

/// Step 10.1: a person's name, colour, picture, kind and role can be corrected after J1,
/// and the member order is changed by dragging (specs/16).
void main() {
  Future<FakeIdentityRepository> openSettings(
    WidgetTester t, {
    SettingsView view = SettingsView.basic,
    List<Member>? members,
  }) async {
    final identity = FakeIdentityRepository(
      current: device(),
      members: members,
    );
    final container = await pumpApp(
      t,
      overrides: baseOverrides(identity: identity, settingsView: view),
    );
    container.read(routerProvider).go(Routes.settingsMembers);
    await t.pumpAndSettle();
    return identity;
  }

  Future<void> scrollTo(WidgetTester t, Finder f) =>
      t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);

  testWidgets('a member row opens the member page, where a guardian renames', (
    t,
  ) async {
    final identity = await openSettings(t);
    await scrollTo(t, find.byKey(const ValueKey('member-$kidId')));
    await t.tap(find.byKey(const ValueKey('member-$kidId')));
    await t.pumpAndSettle();

    expect(find.byKey(const ValueKey('member-name')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('member-name')), 'Anna-Lena');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('member-save-name')));
    await t.pumpAndSettle();

    expect(identity.memberUpdates.single.id, kidId);
    expect(identity.memberUpdates.single.name, 'Anna-Lena');
    expect(find.text('Anna-Lena'), findsWidgets);
  });

  testWidgets(
    'colour, picture and kind apply at once; role waits under Advanced',
    (t) async {
      final identity = await openSettings(t);
      await scrollTo(t, find.byKey(const ValueKey('member-$kidId')));
      await t.tap(find.byKey(const ValueKey('member-$kidId')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('member-colour-petrol')));
      await t.pumpAndSettle();
      expect(identity.memberUpdates.last.colorHex, '#08737F');

      await scrollTo(t, find.byKey(const ValueKey('member-avatar-fox')));
      await t.tap(find.byKey(const ValueKey('member-avatar-fox')));
      await t.pumpAndSettle();
      expect(identity.memberUpdates.last.avatarKey, 'fox');

      await scrollTo(t, find.byKey(const ValueKey('member-kind')));
      await t.tap(find.text(_de.householdKindAdult));
      await t.pumpAndSettle();
      expect(identity.memberUpdates.last.isChild, false);

      // Basic hides the role and "Nicht mehr dabei"; Advanced shows them.
      expect(find.byKey(const ValueKey('member-role')), findsNothing);
      expect(find.byKey(const ValueKey('member-deactivate')), findsNothing);
      await t.tap(find.text(_de.settingsViewAdvanced));
      await t.pumpAndSettle();
      await scrollTo(t, find.byKey(const ValueKey('member-role')));
      expect(find.byKey(const ValueKey('member-role')), findsOneWidget);
      await t.tap(find.text(_de.roleGuardian).last);
      await t.pumpAndSettle();
      expect(identity.roleChanges.single, (id: kidId, role: Role.guardian));
    },
  );

  testWidgets(
    '"Nicht mehr dabei" asks, then retires the person and goes back',
    (t) async {
      final identity = await openSettings(t, view: SettingsView.advanced);
      await scrollTo(t, find.byKey(const ValueKey('member-$kidId')));
      await t.tap(find.byKey(const ValueKey('member-$kidId')));
      await t.pumpAndSettle();

      await scrollTo(t, find.byKey(const ValueKey('member-deactivate')));
      await t.tap(find.byKey(const ValueKey('member-deactivate')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, _de.memberDeactivate));
      await t.pumpAndSettle();

      expect(identity.activeChanges.single, (id: kidId, active: false));
      // Back on the settings page, the person sits at the end, marked.
      await scrollTo(t, find.text(_de.memberInactive));
      expect(find.text(_de.memberInactive), findsOneWidget);
    },
  );

  testWidgets(
    'a guardian cannot retire themself, and an account leaves instead',
    (t) async {
      await openSettings(
        t,
        view: SettingsView.advanced,
        members: [
          testMembers.first,
          const Member(
            id: 'p-oma',
            displayName: 'Oma',
            color: Color(0xFF08737F),
            role: Role.member,
            active: true,
            hasAccount: true,
          ),
        ],
      );
      await scrollTo(t, find.byKey(const ValueKey('member-$guardianId')));
      await t.tap(find.byKey(const ValueKey('member-$guardianId')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('member-deactivate')), findsNothing);

      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      await scrollTo(t, find.byKey(const ValueKey('member-p-oma')));
      await t.tap(find.byKey(const ValueKey('member-p-oma')));
      await t.pumpAndSettle();
      await scrollTo(t, find.text(_de.memberHasAccountHint('Oma')));
      expect(find.byKey(const ValueKey('member-deactivate')), findsNothing);
      expect(find.text(_de.memberHasAccountHint('Oma')), findsOneWidget);
    },
  );

  testWidgets('dragging a member handle reorders the family', (t) async {
    final identity = await openSettings(t);
    await scrollTo(t, find.byKey(const ValueKey('member-$kidId')));
    final handles = find.byType(ReorderableDragStartListener);
    expect(handles, findsNWidgets(2));

    // Drag Anna's handle above Papa's row.
    final from = t.getCenter(handles.last);
    final to = t.getCenter(handles.first) - const Offset(0, 20);
    final gesture = await t.startGesture(from);
    await t.pump(const Duration(milliseconds: 100));
    // In steps: the list picks the drop slot as the pointer passes the other row.
    for (var i = 1; i <= 8; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 8)!);
      await t.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await t.pumpAndSettle();

    expect(identity.reorders.single, [kidId, guardianId]);
  });

  testWidgets('a device row renames the device and shows when it was active', (
    t,
  ) async {
    final identity = FakeIdentityRepository(current: device())
      ..devices_ = [
        DeviceEntry(
          id: 'd-ipad',
          label: 'iPad',
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
          revoked: false,
          lastSeenAt: testNow().subtract(const Duration(days: 3)),
        ),
      ];
    final container = await pumpApp(
      t,
      overrides: baseOverrides(identity: identity),
    );
    container.read(routerProvider).go(Routes.settingsDevices);
    await t.pumpAndSettle();

    await scrollTo(t, find.byKey(const ValueKey('device-d-ipad')));
    expect(
      find.textContaining(_de.deviceLastSeen(_de.feedAgoDays(3))),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('device-d-ipad')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'Kinder-iPad');
    await t.tap(find.text(_de.save));
    await t.pumpAndSettle();

    expect(identity.deviceRenames.single, (id: 'd-ipad', label: 'Kinder-iPad'));
  });

  testWidgets(
    'on the wall display the member page only shows: the server refuses a kiosk',
    (t) async {
      final identity = FakeIdentityRepository(
        current: device(
          deviceClass: DeviceClass.kiosk,
          register: UiRegister.kiosk,
        ),
      );
      final container = await pumpApp(
        t,
        size: const Size(1920, 1200),
        overrides: [
          ...baseOverrides(
            identity: identity,
            shopping: FakeShoppingRepository([]),
          ),
          firstRunStoreProvider.overrideWithValue(
            FakeFirstRunStore()..seen.add('d1'),
          ),
        ],
      );
      // The wall opens settings only for someone who picked themselves.
      container.read(actingProfileProvider.notifier).select(guardianId);
      container.read(routerProvider).go(Routes.member, extra: kidId);
      await t.pumpAndSettle();

      expect(find.text(_de.memberKioskReadOnly), findsOneWidget);
      final name = t.widget<TextField>(
        find.byKey(const ValueKey('member-name')),
      );
      expect(name.enabled, isFalse);
      final birthday = find.byKey(const ValueKey('member-birthday'));
      if (birthday.evaluate().isNotEmpty) {
        expect(t.widget<OutlinedButton>(birthday).onPressed, isNull);
      }
      expect(identity.memberUpdates, isEmpty);
      await unmountApp(t, container);
    },
  );
}

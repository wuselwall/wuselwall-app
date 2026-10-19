// A11y A1: the kid picker, the members row, every board cell and the
// "all events" toggle wrap their tappable child in
// `Semantics(excludeSemantics: true)`, which used to drop the child's own tap
// action and focusability. These tests pin the fix: the merged semantics node
// itself must carry `SemanticsAction.tap` and be focusable.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_zones.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/kid/ui/kid_picker.dart';

import '../support/fakes.dart';

Widget _host(
  Widget child, {
  List<Override> overrides = const [],
  Shade shade = Shade.light,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: AppTheme.build(UiRegister.kiosk, shade),
    localizationsDelegates: localizationsDelegates,
    supportedLocales: supportedLocales,
    locale: const Locale('de'),
    home: Scaffold(body: child),
  ),
);

void main() {
  group('KidPicker', () {
    testWidgets('a member choice is focusable and has a tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const KidPicker(),
          overrides: [
            deviceProvider.overrideWithValue(
              AsyncData(device(deviceClass: DeviceClass.shared)),
            ),
            membersProvider.overrideWith((ref) async => testMembers),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final node = tester.getSemantics(find.byKey(ValueKey('kid-pick-$kidId')));
      expect(
        node,
        matchesSemantics(
          label: 'Anna',
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('ActingProfileBar', () {
    testWidgets('a member-row avatar is focusable and has a tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const ActingProfileBar(),
          overrides: [
            deviceProvider.overrideWithValue(
              AsyncData(device(deviceClass: DeviceClass.kiosk)),
            ),
            membersProvider.overrideWith((ref) async => testMembers),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final node = tester.getSemantics(find.byKey(ValueKey('avatar-$kidId')));
      expect(
        node,
        matchesSemantics(
          label: 'Anna',
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasSelectedState: true,
        ),
      );
      handle.dispose();
    });
  });

  group('BoardTap', () {
    testWidgets('a board cell is focusable and has a tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var tapped = false;
      await tester.pumpWidget(
        _host(
          BoardTap(
            label: 'Emma, Montag',
            onTap: () => tapped = true,
            child: const SizedBox(key: ValueKey('cell'), width: 80, height: 80),
          ),
        ),
      );

      final node = tester.getSemantics(find.byKey(const ValueKey('cell')));
      expect(
        node,
        matchesSemantics(
          label: 'Emma, Montag',
          isButton: true,
          isFocusable: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('cell')), warnIfMissed: false);
      expect(tapped, isTrue);
      handle.dispose();
    });
  });

  group('BoardAllEventsToggle', () {
    testWidgets('the toggle is focusable, has a tap action and keeps state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.build(UiRegister.kiosk, Shade.light),
            localizationsDelegates: localizationsDelegates,
            supportedLocales: supportedLocales,
            locale: const Locale('de'),
            home: const Scaffold(body: BoardAllEventsToggle()),
          ),
        ),
      );

      final finder = find.byType(BoardAllEventsToggle);
      var node = tester.getSemantics(finder);
      expect(
        node,
        matchesSemantics(
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasToggledState: true,
          isToggled: false,
          hasFocusAction: true,
        ),
      );

      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(container.read(boardAllEventsProvider), isTrue);

      node = tester.getSemantics(finder);
      expect(
        node,
        matchesSemantics(
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasToggledState: true,
          isToggled: true,
          hasFocusAction: true,
          isFocused: true,
        ),
      );
      handle.dispose();
    });
  });
}
